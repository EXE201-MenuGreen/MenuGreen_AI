from __future__ import annotations

import uuid
from pathlib import Path

from app.core.config import get_settings
from app.core.onnx_intent import OnnxIntentClassifier
from app.repositories.user_repository import UserRepository
from app.schemas.chat import ChatRequest, ChatResponse
from app.services.context_builder import build_context_snapshot
from app.services.safety_service import SafetyService


class CoachService:
    """Single fallback policy lives here."""

    def __init__(self) -> None:
        self.settings = get_settings()
        self.repo = UserRepository()
        self.safety = SafetyService()
        self.model_dir = Path(__file__).resolve().parents[2] / self.settings.intent_model_dir
        self.classifier = self._try_load_onnx()

    def _try_load_onnx(self) -> OnnxIntentClassifier | None:
        try:
            return OnnxIntentClassifier(self.model_dir)
        except Exception:
            return None

    @staticmethod
    def _heuristic_intent(message: str) -> str | None:
        text = (message or "").lower().strip()
        if not text:
            return None
        meal_keywords = ["an gi", "ăn gì", "goi y bua", "gợi ý bữa", "thuc don", "thực đơn"]
        nutrition_keywords = ["bao nhieu carb", "bao nhieu protein", "bao nhieu fat", "con bao nhieu", "calo", "kcal"]
        recipe_keywords = ["pho", "phở", "bun", "bún", "com", "cơm", "mon", "món", "recipe", "cong thuc", "công thức"]
        if any(k in text for k in meal_keywords):
            return "meal_plan"
        if any(k in text for k in nutrition_keywords):
            return "nutrition_calc"
        if any(k in text for k in recipe_keywords):
            return "recipe_search"
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
            threshold = float(getattr(self.settings, "intent_confidence_threshold", 0.45))
            heuristic_intent = self._heuristic_intent(request.message)
            if score < threshold:
                intent = heuristic_intent or "general"
            elif intent in ("unknown", ""):
                intent = heuristic_intent or "general"
            response_text = self._compose_contextual_response(intent, context, request.message)
            source = "onnx"
            confidence = round(score, 4)
        else:
            intent = self._heuristic_intent(request.message) or "general"
            response_text = self._compose_contextual_response(intent, context, request.message)
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
        safe_response, safety_flags = self.safety.apply(
            user_message=request.message,
            response_text=response_text,
            context=context,
        )

        self.repo.save_chat_session(
            user_id=request.user_id,
            thread_id=thread_id,
            role="assistant",
            content=safe_response,
            context_snapshot=context,
            model_name=self.settings.llm_model,
        )
        final_source = f"{source}+safety" if safety_flags else source

        return ChatResponse(
            response=safe_response,
            intent=intent,
            source=final_source,
            request_id=request_id,
            thread_id=thread_id,
            intent_confidence=confidence,
            subscription_tier=plan if plan in ("free", "saving", "energy", "performance") else "free",
        )

    def _compose_contextual_response(self, intent: str, context: dict, message: str) -> str:
        totals = context.get("today_totals", {})
        remaining = context.get("remaining_totals", {})
        targets = context.get("targets", {})
        profile = context.get("profile", {})
        goal = profile.get("goal", "maintain")
        if intent == "nutrition_calc":
            return (
                f"Hôm nay (mục tiêu: {goal}) bạn đã nạp {totals.get('calories_kcal', 0)} kcal, "
                f"P/C/F = {totals.get('protein_g', 0)}/{totals.get('carbs_g', 0)}/{totals.get('fat_g', 0)}g. "
                f"Còn lại: {remaining.get('calories_kcal', 0)} kcal, "
                f"P/C/F = {remaining.get('protein_g', 0)}/{remaining.get('carbs_g', 0)}/{remaining.get('fat_g', 0)}g "
                f"(target: {targets.get('calories_kcal', 0)} kcal)."
            )

        if intent == "recipe_search":
            query = (message or "").strip()
            recipes = self.repo.search_recipes_by_name(query, limit=3)
            foods = self.repo.search_foods_by_name(query, limit=3)
            suggestions: list[str] = []
            for row in recipes:
                name = row.get("name", "unknown")
                kcal = row.get("calories_kcal", "?")
                suggestions.append(f"{name} ({kcal} kcal)")
            if not suggestions:
                for row in foods:
                    name = row.get("name", "unknown")
                    kcal = row.get("calories_kcal", "?")
                    suggestions.append(f"{name} ({kcal} kcal)")
            suggestion_text = ", ".join(suggestions) if suggestions else "chưa có món khớp trong DB"
            return (
                f"Theo từ khóa '{query}', mình gợi ý: {suggestion_text}. "
                f"Hôm nay bạn đang ở mức {totals.get('calories_kcal', 0)} kcal "
                f"và còn {remaining.get('calories_kcal', 0)} kcal cho ngày hôm nay."
            )

        if intent == "meal_plan":
            remain_kcal = remaining.get("calories_kcal", 0)
            remain_protein = remaining.get("protein_g", 0)
            remain_carbs = remaining.get("carbs_g", 0)
            remain_fat = remaining.get("fat_g", 0)
            suggestions = self.repo.suggest_meal_plan_items(
                remaining_kcal=float(remain_kcal or 0),
                remaining_protein=float(remain_protein or 0),
                remaining_carbs=float(remain_carbs or 0),
                remaining_fat=float(remain_fat or 0),
                limit=3,
            )
            if suggestions:
                lines: list[str] = []
                for item in suggestions:
                    name = item.get("name", "unknown")
                    kcal = item.get("calories_kcal", "?")
                    p = item.get("protein_g", "?")
                    c = item.get("carbs_g", "?")
                    f = item.get("fat_g", "?")
                    lines.append(f"{name} ({kcal} kcal, P/C/F {p}/{c}/{f})")
                return (
                    f"Gợi ý 3 món theo dữ liệu món Việt hiện có: {'; '.join(lines)}. "
                    f"Phần còn lại trong ngày: {remain_kcal} kcal, "
                    f"P/C/F = {remain_protein}/{remain_carbs}/{remain_fat}g."
                )
            return (
                f"Mình chưa tìm thấy đủ món có dữ liệu macro trong DB hiện tại. "
                "Chưa đủ dữ liệu món trong DB để gợi ý 3 món cụ thể. "
                f"Phần còn lại trong ngày: {remain_kcal} kcal, "
                f"P/C/F = {remain_protein}/{remain_carbs}/{remain_fat}g."
            )

        return (
            f"Hôm nay bạn đã nạp khoảng {totals.get('calories_kcal', 0)} kcal, "
            f"P/C/F = {totals.get('protein_g', 0)}/{totals.get('carbs_g', 0)}/{totals.get('fat_g', 0)}g. "
            f"Nếu bạn muốn, tôi có thể tính phần còn lại theo mục tiêu hôm nay."
        )
