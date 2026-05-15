from __future__ import annotations

import uuid
from pathlib import Path

from app.core.config import get_settings
from app.core.onnx_intent import OnnxIntentClassifier
from app.repositories.user_repository import UserRepository
from app.schemas.chat import ChatRequest, ChatResponse
from app.services.context_builder import build_context_snapshot


class CoachService:
    """Single fallback policy lives here."""

    def __init__(self) -> None:
        self.settings = get_settings()
        self.repo = UserRepository()
        self.model_dir = Path(__file__).resolve().parents[2] / self.settings.intent_model_dir
        self.classifier = self._try_load_onnx()

    def _try_load_onnx(self) -> OnnxIntentClassifier | None:
        try:
            return OnnxIntentClassifier(self.model_dir)
        except Exception:
            return None

    async def reply(self, request: ChatRequest) -> ChatResponse:
        request_id = request.request_id or str(uuid.uuid4())
        thread_id = request.thread_id or request.user_id or request_id

        profile = self.repo.get_profile(request.user_id) if request.user_id else None
        plan = self.repo.get_subscription_plan(request.user_id) if request.user_id else "free"
        logs_7d = self.repo.get_meal_logs_7d(request.user_id) if request.user_id else []
        context = build_context_snapshot(profile, logs_7d)

        if self.classifier is not None:
            intent, score = self.classifier.predict(request.message)
            response_text = self._compose_contextual_response(intent, context)
            source = "onnx"
            confidence = round(score, 4)
        else:
            intent = "general"
            response_text = self._compose_contextual_response(intent, context)
            source = "fallback"
            confidence = None

        # Reused from old project's pattern: persist chat turns for observability.
        self.repo.save_chat_session(
            user_id=request.user_id,
            thread_id=thread_id,
            role="user",
            content=request.message,
            context_snapshot=context,
            model_name=self.settings.llm_model,
        )
        self.repo.save_chat_session(
            user_id=request.user_id,
            thread_id=thread_id,
            role="assistant",
            content=response_text,
            context_snapshot=context,
            model_name=self.settings.llm_model,
        )

        return ChatResponse(
            response=response_text,
            intent=intent,
            source=source,
            request_id=request_id,
            thread_id=thread_id,
            intent_confidence=confidence,
            subscription_tier=plan if plan in ("free", "saving", "energy", "performance") else "free",
        )

    @staticmethod
    def _compose_contextual_response(intent: str, context: dict) -> str:
        totals = context.get("today_totals", {})
        profile = context.get("profile", {})
        goal = profile.get("goal", "unknown")
        return (
            f"Intent={intent}. Goal={goal}. "
            f"Hôm nay bạn đã nạp khoảng {totals.get('calories_kcal', 0)} kcal, "
            f"P/C/F = {totals.get('protein_g', 0)}/{totals.get('carbs_g', 0)}/{totals.get('fat_g', 0)}g."
        )
