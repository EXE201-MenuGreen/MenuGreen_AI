from __future__ import annotations

import re
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
        search_keywords = [
            "search",
            "tra cứu",
            "tra cuu",
            "tìm thông tin",
            "tim thong tin",
            "nguồn tham khảo",
            "nguon tham khao",
            "latest",
            "newest",
            "research",
        ]
        meal_keywords = ["an gi", "ăn gì", "goi y bua", "gợi ý bữa", "thuc don", "thực đơn"]
        nutrition_keywords = ["bao nhieu carb", "bao nhieu protein", "bao nhieu fat", "con bao nhieu", "calo", "kcal"]
        recipe_keywords = ["pho", "phở", "bun", "bún", "com", "cơm", "mon", "món", "recipe", "cong thuc", "công thức"]
        if any(k in text for k in search_keywords):
            return "ai_search"
        if any(k in text for k in meal_keywords):
            return "meal_plan"
        if any(k in text for k in nutrition_keywords):
            return "nutrition_calc"
        if any(k in text for k in recipe_keywords):
            return "recipe_search"
        return None

    @staticmethod
    def _extract_recipe_query(message: str) -> str:
        text = (message or "").strip()
        if not text:
            return ""

        cleaned = text
        prefixes = [
            r"^(công thức|cong thuc|cách nấu|cach nau|làm|lam|nấu|nau)\s+",
            r"^(tìm|tim|gợi ý|goi y|tra cứu|tra cuu)\s+(món|mon|công thức|cong thuc|recipe)\s+",
            r"^(gợi ý|goi y|tìm|tim)\s+",
        ]
        for pattern in prefixes:
            cleaned = re.sub(pattern, "", cleaned, flags=re.IGNORECASE).strip()

        cleaned = re.sub(
            r"\b(công thức|cong thuc|cách nấu|cach nau|recipe|món|mon|nấu|nau|làm|lam|tìm|tim|gợi ý|goi y|cho|của|cua|về|ve)\b",
            " ",
            cleaned,
            flags=re.IGNORECASE,
        )
        cleaned = re.sub(r"\s+", " ", cleaned).strip(" ,.-\t")
        return cleaned or text

    @staticmethod
    def _is_vague_food_request(message: str) -> bool:
        text = (message or "").strip().lower()
        if not text:
            return True
        vague_phrases = {
            "món khác",
            "mon khac",
            "khác",
            "khac",
            "món khác nữa",
            "mon khac nua",
            "đổi món",
            "doi mon",
            "gợi ý khác",
            "goi y khac",
            "món khác đi",
            "mon khac di",
        }
        return text in vague_phrases or len(text.split()) <= 2

    @staticmethod
    def _extract_last_recommended_name(conversation_history) -> str:
        if not conversation_history:
            return ""
        pattern = re.compile(r"(?:gợi ý|goi y|mình gợi ý|theo món)\s+['\"]?([^'\".]+?)['\"]?(?:\s*\(|,|\.|$)", re.IGNORECASE)
        for item in reversed(conversation_history):
            role = getattr(item, "role", None) if not isinstance(item, dict) else item.get("role")
            content = getattr(item, "content", "") if not isinstance(item, dict) else item.get("content", "")
            if role != "assistant":
                continue
            match = pattern.search(content or "")
            if match:
                return match.group(1).strip()
        return ""

    @staticmethod
    def _score_recipe_row(row: dict, query: str, exclude_name: str = "") -> tuple[int, float, int]:
        name = str(row.get("name", "")).lower()
        query_text = (query or "").lower().strip()
        similarity = float(row.get("similarity", 0) or 0)
        exact_match = 0 if query_text and query_text == name else 1
        variant_penalty = 1 if any(
            token in name
            for token in [
                "ít đậu",
                "nhiều đạm",
                "ít tinh bột",
                "ít dầu",
                "healthy",
                "giảm cân",
                "protein",
            ]
        ) else 0
        exclude_penalty = 1 if exclude_name and exclude_name.lower() in name else 0
        return (exact_match + variant_penalty + exclude_penalty, -similarity, len(name))

    async def reply(self, request: ChatRequest) -> ChatResponse:
        request_id = request.request_id or str(uuid.uuid4())
        thread_id = request.thread_id or request.user_id or request_id

        profile = self.repo.get_profile(request.user_id) if request.user_id else None
        plan = self.repo.get_subscription_plan(request.user_id) if request.user_id else "free"
        logs_7d = self.repo.get_meal_logs_7d(request.user_id) if request.user_id else []
        context = build_context_snapshot(profile, logs_7d)
        last_recommended_name = self._extract_last_recommended_name(request.conversation_history)

        if self.classifier is not None:
            intent, score = self.classifier.predict(request.message)
            threshold = float(getattr(self.settings, "intent_confidence_threshold", 0.45))
            heuristic_intent = self._heuristic_intent(request.message)
            if score < threshold:
                intent = heuristic_intent or "general"
            elif intent in ("unknown", ""):
                intent = heuristic_intent or "general"
            response_text = self._compose_contextual_response(
                intent,
                context,
                request.message,
                request.conversation_history,
                last_recommended_name,
            )
            source = "onnx"
            confidence = round(score, 4)
        else:
            intent = self._heuristic_intent(request.message) or "general"
            response_text = self._compose_contextual_response(
                intent,
                context,
                request.message,
                request.conversation_history,
                last_recommended_name,
            )
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

    def _compose_contextual_response(
        self,
        intent: str,
        context: dict,
        message: str,
        conversation_history=None,
        last_recommended_name: str = "",
    ) -> str:
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
            query = self._extract_recipe_query(message)
            if self._is_vague_food_request(message) and conversation_history:
                query = last_recommended_name or query
            recipe_candidates = self.repo.search_recipes_by_name(query, limit=5)
            food_candidates = self.repo.search_foods_by_name(query, limit=5)
            best_item = None

            if recipe_candidates:
                best_item = sorted(recipe_candidates, key=lambda row: self._score_recipe_row(row, query, last_recommended_name))[0]
            elif food_candidates:
                best_item = sorted(food_candidates, key=lambda row: self._score_recipe_row(row, query, last_recommended_name))[0]
            if not best_item:
                # Fallback: always provide at least one practical recommendation
                # from current DB pool so the user never gets an empty answer.
                fallback_items = self.repo.suggest_meal_plan_items(
                    remaining_kcal=float(remaining.get("calories_kcal", 0) or 0),
                    remaining_protein=float(remaining.get("protein_g", 0) or 0),
                    remaining_carbs=float(remaining.get("carbs_g", 0) or 0),
                    remaining_fat=float(remaining.get("fat_g", 0) or 0),
                    limit=1,
                )
                best_item = fallback_items[0] if fallback_items else None
            if not best_item:
                active_pool = self.repo.list_active_recipes(limit=5) + self.repo.list_active_foods(limit=5)
                if active_pool:
                    best_item = sorted(active_pool, key=lambda row: self._score_recipe_row(row, query, last_recommended_name))[0]

            if best_item:
                name = best_item.get("name", "unknown")
                kcal = best_item.get("calories_kcal", "?")
                detail = self._format_recipe_detail(best_item) if best_item.get("instructions") else ""
                suggestion_text = f"{name} ({kcal} kcal{detail})"
            else:
                suggestion_text = "trứng luộc + rau luộc (gợi ý mặc định)"
            display_query = query if query else (message or "").strip()
            return (
                f"Theo món '{display_query}', mình gợi ý 1 món chính: {suggestion_text}. "
                f"Hôm nay bạn đang ở mức {totals.get('calories_kcal', 0)} kcal "
                f"và còn {remaining.get('calories_kcal', 0)} kcal cho ngày hôm nay."
            )

        if intent == "ai_search":
            q = (message or "").strip()
            return (
                f"Mình đã nhận yêu cầu AI search cho: '{q}'. "
                "Hiện runtime này đang trả câu trả lời dạng định hướng để BE tích hợp search provider "
                "(web/search API) ở bước tiếp theo. "
                "Bạn có thể bật pipeline search để mình trả kết quả có nguồn trích dẫn."
            )

        if intent in ("general", "unknown"):
            return (
                "Xin lỗi, câu hỏi này nằm ngoài phạm vi hỗ trợ hiện tại của AI Coach. "
                "Mình đang tập trung vào món ăn, dinh dưỡng, thực đơn và truy vấn công thức. "
                "Bạn có thể hỏi lại theo hướng đó, hoặc đổi sang câu hỏi về calo, món ăn, hay kế hoạch bữa ăn."
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
            "Xin lỗi, câu hỏi này nằm ngoài phạm vi hỗ trợ hiện tại của AI Coach. "
            "Mình đang tập trung vào món ăn, dinh dưỡng, thực đơn và truy vấn công thức."
        )

    @staticmethod
    def _format_recipe_detail(row: dict) -> str:
        details: list[str] = []
        total_time = row.get("total_time_min")
        if total_time:
            details.append(f"{total_time} phút")
        price = row.get("estimated_price_vnd")
        if price:
            details.append(f"~{price:,}đ".replace(",", "."))
        instructions = row.get("instructions")
        if isinstance(instructions, list) and instructions:
            steps = " → ".join(str(x).strip() for x in instructions[:3] if str(x).strip())
            if steps:
                details.append(f"cách làm: {steps}")
        return ", " + ", ".join(details) if details else ""
