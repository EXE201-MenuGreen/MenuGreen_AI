from __future__ import annotations

import json
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
        self.hybrid_llm = self._try_load_gemini_llm()

    def _try_load_onnx(self) -> OnnxIntentClassifier | None:
        try:
            return OnnxIntentClassifier(self.model_dir)
        except Exception:
            return None

    def _try_load_gemini_llm(self):
        if not self.settings.google_api_key.strip():
            return None
        try:
            from langchain_google_genai import ChatGoogleGenerativeAI
        except Exception:
            return None
        try:
            return ChatGoogleGenerativeAI(
                model=self.settings.llm_model,
                google_api_key=self.settings.google_api_key,
                temperature=0.2,
            )
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
    def _clean_bullet_lines(text: str) -> list[str]:
        lines: list[str] = []
        for raw_line in (text or "").splitlines():
            line = raw_line.strip()
            if not line:
                continue
            line = re.sub(r"^[\-\*\d\.\)\s]+", "", line).strip()
            if line:
                lines.append(line)
        return lines

    def _invoke_gemini_text(self, prompt: str) -> str | None:
        if self.hybrid_llm is None:
            return None
        try:
            result = self.hybrid_llm.invoke(prompt)
        except Exception:
            return None
        content = getattr(result, "content", None)
        if isinstance(content, str):
            return content.strip() or None
        if isinstance(content, list):
            parts: list[str] = []
            for item in content:
                if isinstance(item, str):
                    parts.append(item)
                elif isinstance(item, dict):
                    text = item.get("text")
                    if text:
                        parts.append(str(text))
                else:
                    text = getattr(item, "text", None)
                    if text:
                        parts.append(str(text))
            joined = "\n".join(part.strip() for part in parts if str(part).strip()).strip()
            return joined or None
        return None

    def _rewrite_recipe_queries_with_gemini(self, message: str, base_query: str) -> list[str]:
        if not self.settings.gemini_query_rewrite_enabled:
            return []
        seed_query = (base_query or message or "").strip()
        if not seed_query:
            return []
        prompt = (
            "Bạn là bộ chuẩn hóa query search món ăn cho app dinh dưỡng.\n"
            "Nhiệm vụ: đổi câu user thành tối đa 3 query ngắn, dễ search trong DB món ăn.\n"
            "Giữ nguyên ý chính, sửa typo, chuyển từ Anh-Việt lẫn lộn thành từ khóa food tự nhiên.\n"
            "Không giải thích. Trả đúng JSON array string.\n"
            f"User message: {message.strip()}\n"
            f"Base query: {seed_query}\n"
            'Ví dụ output: ["pho bo", "phở bò", "món bò nước"]'
        )
        raw = self._invoke_gemini_text(prompt)
        if not raw:
            return []
        try:
            parsed = json.loads(raw)
            if not isinstance(parsed, list):
                return []
            candidates = [str(item).strip() for item in parsed if str(item).strip()]
        except Exception:
            candidates = self._clean_bullet_lines(raw)
        seen: set[str] = set()
        result: list[str] = []
        for item in [seed_query, *candidates]:
            key = item.lower()
            if key in seen:
                continue
            seen.add(key)
            result.append(item)
            if len(result) >= 4:
                break
        return result[1:]

    def _generate_recipe_fallback_with_gemini(self, message: str, context: dict) -> str | None:
        if not self.settings.gemini_response_fallback_enabled:
            return None
        remaining = context.get("remaining_totals", {})
        prompt = (
            "Bạn là AI Coach dinh dưỡng cho app MenuGreen.\n"
            "Hãy trả lời NGẮN bằng tiếng Việt, tối đa 4 câu.\n"
            "Mục tiêu: khi DB chưa có món khớp, vẫn gợi ý hướng ăn uống thực tế và nói rõ đây là gợi ý AI.\n"
            "Không bịa như thể có dữ liệu DB. Không chẩn đoán y khoa. Không nói quá chắc chắn.\n"
            f"User message: {message.strip()}\n"
            f"Remaining calories today: {remaining.get('calories_kcal', 0)}\n"
            f"Remaining protein/carbs/fat: {remaining.get('protein_g', 0)}/{remaining.get('carbs_g', 0)}/{remaining.get('fat_g', 0)}\n"
            "Hãy gợi ý 1-2 hướng món hoặc nhóm thực phẩm dễ áp dụng."
        )
        return self._invoke_gemini_text(prompt)

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
            response_text, route_flags = self._compose_contextual_response(
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
            response_text, route_flags = self._compose_contextual_response(
                intent,
                context,
                request.message,
                request.conversation_history,
                last_recommended_name,
            )
            source = "fallback"
            confidence = None

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
        source_parts = [source, *route_flags]
        if safety_flags:
            source_parts.append("safety")
        final_source = "+".join(dict.fromkeys(part for part in source_parts if part))

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
    ) -> tuple[str, list[str]]:
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
                f"(target: {targets.get('calories_kcal', 0)} kcal).",
                [],
            )

        if intent == "recipe_search":
            query = self._extract_recipe_query(message)
            if self._is_vague_food_request(message) and conversation_history:
                query = last_recommended_name or query

            hybrid_flags: list[str] = []
            display_query = query if query else (message or "").strip()
            recipe_candidates = self.repo.search_recipes_by_name(query, limit=5)
            food_candidates = self.repo.search_foods_by_name(query, limit=5)

            if not recipe_candidates and not food_candidates:
                rewritten_queries = self._rewrite_recipe_queries_with_gemini(message, query)
                for rewritten_query in rewritten_queries:
                    recipe_candidates = self.repo.search_recipes_by_name(rewritten_query, limit=5)
                    food_candidates = self.repo.search_foods_by_name(rewritten_query, limit=5)
                    if recipe_candidates or food_candidates:
                        query = rewritten_query
                        display_query = rewritten_query
                        hybrid_flags.append("gemini-rewrite")
                        break

            best_item = None
            if recipe_candidates:
                best_item = sorted(recipe_candidates, key=lambda row: self._score_recipe_row(row, query, last_recommended_name))[0]
            elif food_candidates:
                best_item = sorted(food_candidates, key=lambda row: self._score_recipe_row(row, query, last_recommended_name))[0]
            if not best_item:
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
                return (
                    f"Theo món '{display_query}', mình gợi ý 1 món chính: {suggestion_text}. "
                    f"Hôm nay bạn đang ở mức {totals.get('calories_kcal', 0)} kcal "
                    f"và còn {remaining.get('calories_kcal', 0)} kcal cho ngày hôm nay.",
                    hybrid_flags,
                )

            gemini_fallback = self._generate_recipe_fallback_with_gemini(message, context)
            if gemini_fallback:
                hybrid_flags.append("gemini-fallback")
                return gemini_fallback, hybrid_flags

            return (
                f"Theo món '{display_query}', mình tạm gợi ý mặc định: trứng luộc + rau luộc. "
                f"Hôm nay bạn đang ở mức {totals.get('calories_kcal', 0)} kcal "
                f"và còn {remaining.get('calories_kcal', 0)} kcal cho ngày hôm nay.",
                hybrid_flags,
            )

        if intent == "ai_search":
            q = (message or "").strip()
            return (
                f"Mình đã nhận yêu cầu AI search cho: '{q}'. "
                "Hiện runtime này đang trả câu trả lời dạng định hướng để BE tích hợp search provider "
                "(web/search API) ở bước tiếp theo. "
                "Bạn có thể bật pipeline search để mình trả kết quả có nguồn trích dẫn.",
                [],
            )

        if intent in ("general", "unknown"):
            return (
                "Xin lỗi, câu hỏi này nằm ngoài phạm vi hỗ trợ hiện tại của AI Coach. "
                "Mình đang tập trung vào món ăn, dinh dưỡng, thực đơn và truy vấn công thức. "
                "Bạn có thể hỏi lại theo hướng đó, hoặc đổi sang câu hỏi về calo, món ăn, hay kế hoạch bữa ăn.",
                [],
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
                    f"P/C/F = {remain_protein}/{remain_carbs}/{remain_fat}g.",
                    [],
                )

            gemini_fallback = self._generate_recipe_fallback_with_gemini(message, context)
            if gemini_fallback:
                return gemini_fallback, ["gemini-fallback"]
            return (
                f"Mình chưa tìm thấy đủ món có dữ liệu macro trong DB hiện tại. "
                "Chưa đủ dữ liệu món trong DB để gợi ý 3 món cụ thể. "
                f"Phần còn lại trong ngày: {remain_kcal} kcal, "
                f"P/C/F = {remain_protein}/{remain_carbs}/{remain_fat}g.",
                [],
            )

        return (
            "Xin lỗi, câu hỏi này nằm ngoài phạm vi hỗ trợ hiện tại của AI Coach. "
            "Mình đang tập trung vào món ăn, dinh dưỡng, thực đơn và truy vấn công thức.",
            [],
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
