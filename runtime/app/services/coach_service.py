from __future__ import annotations

import json
import re
import unicodedata
import uuid
from pathlib import Path

from app.core.config import get_settings
from app.core.gemini_pool import get_gemini_pool
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
        self.gemini_pool = get_gemini_pool()

    def _try_load_onnx(self) -> OnnxIntentClassifier | None:
        try:
            return OnnxIntentClassifier(self.model_dir)
        except Exception:
            return None

    @staticmethod
    def _heuristic_intent(message: str) -> str | None:
        text = (message or "").strip()
        normalized_text = CoachService._normalize_match_text(text)
        if not normalized_text:
            return None
        search_keywords = [
            "search",
            "tra cuu",
            "tim thong tin",
            "nguon tham khao",
            "latest",
            "newest",
            "research",
        ]
        meal_keywords = [
            "an gi",
            "nen an gi",
            "muon an",
            "toi muon an",
            "thich an",
            "toi thich an",
            "them",
            "goi y bua",
            "goi y bua an",
            "thuc don",
            "ke hoach bua an",
            "hom nay an gi",
            "hom nay nen an gi",
            "hom nay toi muon an",
            "hom nay toi thich an",
        ]
        nutrition_keywords = ["bao nhieu carb", "bao nhieu protein", "bao nhieu fat", "con bao nhieu", "calo", "kcal"]
        recipe_keywords = ["pho", "bun", "com", "mon", "recipe", "cong thuc"]
        if any(k in normalized_text for k in search_keywords):
            return "ai_search"
        if any(k in normalized_text for k in meal_keywords):
            return "meal_plan"
        if any(k in normalized_text for k in nutrition_keywords):
            return "nutrition_calc"
        if any(k in normalized_text for k in recipe_keywords):
            return "recipe_search"
        return None

    @staticmethod
    def _normalize_match_text(message: str) -> str:
        text = (message or "").strip().lower()
        if not text:
            return ""
        text = unicodedata.normalize("NFKD", text)
        text = "".join(ch for ch in text if not unicodedata.combining(ch))
        text = text.replace("đ", "d")
        text = re.sub(r"[^a-z0-9\s]", " ", text)
        return re.sub(r"\s+", " ", text).strip()

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
    def _extract_preference_query(message: str) -> str:
        text = (message or "").strip()
        if not text:
            return ""
        patterns = [
            r"(?:hôm nay\s+)?(?:tôi\s+)?muốn ăn\s+(.+)",
            r"(?:hom nay\s+)?(?:toi\s+)?muon an\s+(.+)",
            r"(?:hôm nay\s+)?(?:tôi\s+)?thích ăn\s+(.+)",
            r"(?:hom nay\s+)?(?:toi\s+)?thich an\s+(.+)",
            r"(?:hôm nay\s+)?(?:tôi\s+)?thèm\s+(.+)",
            r"(?:hom nay\s+)?(?:toi\s+)?them\s+(.+)",
        ]
        for pattern in patterns:
            match = re.search(pattern, text, flags=re.IGNORECASE)
            if match:
                extracted = re.sub(r"[?.!,]+$", "", match.group(1).strip())
                return extracted
        return ""

    @staticmethod
    def _is_vague_food_request(message: str) -> bool:
        text = (message or "").strip().lower()
        if not text:
            return True
        vague_phrases = [
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
        ]
        return any(phrase in text for phrase in vague_phrases) or len(text.split()) <= 2

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

    def _invoke_gemini_text(self, prompt: str, cache_namespace: str) -> str | None:
        return self.gemini_pool.invoke_text(
            prompt=prompt,
            model=self.settings.llm_model,
            temperature=0.2,
            cache_namespace=cache_namespace,
        )

    @staticmethod
    def _is_hard_query(message: str, base_query: str = "") -> bool:
        text = (message or "").strip()
        query = (base_query or "").strip()
        if not text:
            return False
        if len(text) >= 18:
            return True
        if len(query.split()) >= 2:
            return True
        if "?" in text or "/" in text or "," in text:
            return True
        return len(text.split()) <= 2

    def _should_try_gemini_rewrite(
        self,
        message: str,
        query: str,
        recipe_candidates: list[dict],
        food_candidates: list[dict],
    ) -> bool:
        return (
            self.settings.gemini_query_rewrite_enabled
            and self.gemini_pool.is_available()
            and not recipe_candidates
            and not food_candidates
            and self._is_hard_query(message, query)
        )

    def _should_try_gemini_fallback(self, message: str, best_item: dict | None) -> bool:
        return (
            self.settings.gemini_response_fallback_enabled
            and self.gemini_pool.is_available()
            and best_item is None
            and self._is_hard_query(message, message)
        )

    def _score_meal_plan_candidate(
        self,
        row: dict,
        remaining_kcal: float,
        remaining_protein: float,
        remaining_carbs: float,
        remaining_fat: float,
    ) -> float:
        per_meal_kcal = max(float(remaining_kcal or 0) / 3.0, 350.0)
        per_meal_protein = max(float(remaining_protein or 0) / 3.0, 20.0)
        per_meal_carbs = max(float(remaining_carbs or 0) / 3.0, 30.0)
        per_meal_fat = max(float(remaining_fat or 0) / 3.0, 10.0)
        kcal = float(row.get("calories_kcal", 0) or 0)
        protein = float(row.get("protein_g", 0) or 0)
        carbs = float(row.get("carbs_g", 0) or 0)
        fat = float(row.get("fat_g", 0) or 0)
        if kcal <= 0:
            return 1e9
        return (
            abs(kcal - per_meal_kcal) * 0.45
            + abs(protein - per_meal_protein) * 1.25
            + abs(carbs - per_meal_carbs) * 0.75
            + abs(fat - per_meal_fat) * 0.95
        )

    def _rank_meal_plan_candidates(
        self,
        candidates: list[dict],
        remaining_kcal: float,
        remaining_protein: float,
        remaining_carbs: float,
        remaining_fat: float,
        limit: int = 3,
        exclude_names: set[str] | None = None,
    ) -> list[dict]:
        exclude_names = exclude_names or set()
        ranked = sorted(
            candidates,
            key=lambda row: self._score_meal_plan_candidate(
                row,
                remaining_kcal,
                remaining_protein,
                remaining_carbs,
                remaining_fat,
            ),
        )
        picked: list[dict] = []
        seen_names = set(exclude_names)
        for item in ranked:
            name = str(item.get("name", "")).strip().lower()
            if not name or name in seen_names:
                continue
            seen_names.add(name)
            picked.append(item)
            if len(picked) >= limit:
                break
        return picked

    def _find_related_meal_plan_items(
        self,
        message: str,
        preference_query: str,
        remaining_kcal: float,
        remaining_protein: float,
        remaining_carbs: float,
        remaining_fat: float,
        limit: int = 3,
    ) -> tuple[list[dict], list[str]]:
        if not preference_query:
            return [], []

        related_flags: list[str] = []
        candidate_pool: list[dict] = []
        seen_ids: set[str] = set()

        def add_candidates(rows: list[dict]) -> None:
            for row in rows:
                row_id = str(row.get("id") or "")
                if row_id and row_id in seen_ids:
                    continue
                if row_id:
                    seen_ids.add(row_id)
                candidate_pool.append(row)

        add_candidates(self.repo.search_recipes_by_name(preference_query, limit=12))
        add_candidates(self.repo.search_foods_by_name(preference_query, limit=12))

        if not candidate_pool and self._should_try_gemini_rewrite(message, preference_query, [], []):
            rewritten_queries = self._rewrite_recipe_queries_with_gemini(message, preference_query)
            for rewritten_query in rewritten_queries:
                before_count = len(candidate_pool)
                add_candidates(self.repo.search_recipes_by_name(rewritten_query, limit=12))
                add_candidates(self.repo.search_foods_by_name(rewritten_query, limit=12))
                if len(candidate_pool) > before_count:
                    related_flags.append("gemini-rewrite")
                    break

        if not candidate_pool:
            return [], related_flags

        ranked = self._rank_meal_plan_candidates(
            candidate_pool,
            remaining_kcal=remaining_kcal,
            remaining_protein=remaining_protein,
            remaining_carbs=remaining_carbs,
            remaining_fat=remaining_fat,
            limit=limit,
        )
        return ranked, related_flags

    def _rewrite_recipe_queries_with_gemini(self, message: str, base_query: str) -> list[str]:
        if not self.settings.gemini_query_rewrite_enabled or not self.gemini_pool.is_available():
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
        raw = self._invoke_gemini_text(prompt, cache_namespace="recipe-rewrite")
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
        if not self.settings.gemini_response_fallback_enabled or not self.gemini_pool.is_available():
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
        return self._invoke_gemini_text(prompt, cache_namespace="recipe-fallback")

    @staticmethod
    def _extract_budget_vnd(message: str) -> int | None:
        text = CoachService._normalize_match_text(message)
        if not text:
            return None
        patterns = [
            r"(?:duoi|khong qua|toi da|max)\s*(\d+(?:[.,]\d+)?)\s*(k|nghin|ngan|trieu|vnd|d)?",
            r"(\d+(?:[.,]\d+)?)\s*(k|nghin|ngan|trieu|vnd)\b",
        ]
        for pattern in patterns:
            match = re.search(pattern, text)
            if not match:
                continue
            raw_value = match.group(1).replace(",", ".")
            unit = (match.group(2) or "").strip()
            try:
                value = float(raw_value)
            except Exception:
                continue
            if unit in {"k", "nghin", "ngan"}:
                return int(value * 1000)
            if unit == "trieu":
                return int(value * 1_000_000)
            return int(value)
        return None

    @staticmethod
    def _extract_time_limit_min(message: str) -> int | None:
        text = CoachService._normalize_match_text(message)
        if not text:
            return None
        match = re.search(r"(\d+)\s*(phut|p)\b", text)
        if match:
            try:
                return max(int(match.group(1)), 1)
            except Exception:
                return None
        if "nhanh" in text or "gap" in text:
            return 20
        return None

    @staticmethod
    def _extract_meal_slot(message: str) -> str | None:
        text = CoachService._normalize_match_text(message)
        if not text:
            return None
        if any(token in text for token in ("bua trua", "an trua", "trua")):
            return "lunch"
        if any(token in text for token in ("bua sang", "an sang", "sang")):
            return "breakfast"
        if any(token in text for token in ("bua toi", "an toi", "toi nay", "buoi toi")):
            return "dinner"
        return None

    @staticmethod
    def _wants_remaining_kcal(message: str) -> bool:
        text = CoachService._normalize_match_text(message)
        if not text:
            return False
        phrases = (
            "con bao nhieu kcal",
            "con bao nhieu calo",
            "bao nhieu kcal con lai",
            "bao nhieu calo con lai",
            "con lai bao nhieu kcal",
            "con lai bao nhieu calo",
        )
        return any(phrase in text for phrase in phrases)

    @staticmethod
    def _meal_slot_label(slot: str | None) -> str:
        return {
            "breakfast": "bữa sáng",
            "lunch": "bữa trưa",
            "dinner": "bữa tối",
        }.get(slot or "", "bữa ăn")

    @staticmethod
    def _meal_slot_score(slot: str | None, row: dict) -> int:
        if not slot:
            return 0
        meal_type = CoachService._normalize_match_text(str(row.get("meal_type") or ""))
        name = CoachService._normalize_match_text(str(row.get("name") or ""))
        description = CoachService._normalize_match_text(str(row.get("description") or ""))
        haystack = " ".join(part for part in (meal_type, name, description) if part)
        if not haystack:
            return 1

        breakfast_tokens = ("sang", "yen mach", "sinh to", "smoothie", "oat", "chao")
        dinner_tokens = ("toi", "salad", "sup", "canh")

        if slot == "breakfast":
            if any(token in haystack for token in breakfast_tokens):
                return 0
            if "trua" in haystack or any(token in haystack for token in dinner_tokens):
                return 2
            return 1
        if slot == "lunch":
            if any(token in haystack for token in breakfast_tokens):
                return 2
            return 0
        if slot == "dinner":
            if any(token in haystack for token in dinner_tokens):
                return 0
            if any(token in haystack for token in breakfast_tokens):
                return 2
            return 1
        return 0

    def _find_constrained_meal_items(
        self,
        context: dict,
        message: str,
        limit: int = 3,
    ) -> tuple[list[dict], dict]:
        meal_slot = self._extract_meal_slot(message)
        budget_vnd = self._extract_budget_vnd(message)
        time_limit_min = self._extract_time_limit_min(message)
        wants_remaining = self._wants_remaining_kcal(message)

        if not any([meal_slot, budget_vnd, time_limit_min, wants_remaining]):
            return [], {}

        remaining = context.get("remaining_totals", {})
        max_price_vnd = budget_vnd if budget_vnd is not None else 250000
        max_total_time_min = time_limit_min if time_limit_min is not None else 240
        candidates = self.repo.list_meal_candidates_by_constraints(
            max_price_vnd=max_price_vnd,
            max_total_time_min=max_total_time_min,
            max_items=200,
        )
        if not candidates:
            return [], {
                "meal_slot": meal_slot,
                "budget_vnd": budget_vnd,
                "time_limit_min": time_limit_min,
                "wants_remaining": wants_remaining,
            }

        per_meal_target = max(float(remaining.get("calories_kcal", 0) or 0) / 3.0, 350.0)
        if meal_slot == "breakfast":
            per_meal_target = min(per_meal_target, 400.0)
        elif meal_slot == "dinner":
            per_meal_target = max(per_meal_target, 400.0)

        ranked = sorted(
            candidates,
            key=lambda row: (
                self._meal_slot_score(meal_slot, row),
                abs(float(row.get("calories_kcal", 0) or 0) - per_meal_target),
                0 if row.get("source") == "recipe" else 1,
                float(row.get("estimated_price_vnd", 0) or 0),
                float((row.get("prep_time_min", 0) or 0) + (row.get("cook_time_min", 0) or 0)),
            ),
        )
        picked: list[dict] = []
        seen_names: set[str] = set()
        for row in ranked:
            name = str(row.get("name") or "").strip().lower()
            if not name or name in seen_names:
                continue
            seen_names.add(name)
            picked.append(row)
            if len(picked) >= limit:
                break
        return picked, {
            "meal_slot": meal_slot,
            "budget_vnd": budget_vnd,
            "time_limit_min": time_limit_min,
            "wants_remaining": wants_remaining,
        }

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
            elif heuristic_intent == "meal_plan" and intent in ("general", "recipe_search", "nutrition_calc"):
                intent = "meal_plan"
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

            if self._should_try_gemini_rewrite(message, query, recipe_candidates, food_candidates):
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

            gemini_fallback = None
            if self._should_try_gemini_fallback(message, best_item):
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
            has_daily_target = any(
                float(remaining.get(field, 0) or 0) > 0
                for field in ("calories_kcal", "protein_g", "carbs_g", "fat_g")
            )
            preference_query = self._extract_preference_query(message)
            route_flags: list[str] = []
            constrained_items, constraints = self._find_constrained_meal_items(context, message, limit=3)

            remaining_text = ""
            if constraints.get("wants_remaining"):
                if has_daily_target:
                    remaining_text = (
                        f"Hôm nay bạn đã nạp {totals.get('calories_kcal', 0)} kcal "
                        f"và còn khoảng {remain_kcal} kcal cho ngày hôm nay. "
                    )
                else:
                    remaining_text = (
                        f"Hôm nay bạn đã nạp khoảng {totals.get('calories_kcal', 0)} kcal. "
                        "Mình chưa tính chính xác phần còn lại vì bạn chưa thiết lập mục tiêu ngày. "
                    )

            if constrained_items:
                slot_label = self._meal_slot_label(constraints.get("meal_slot"))
                budget_vnd = constraints.get("budget_vnd")
                time_limit_min = constraints.get("time_limit_min")
                condition_parts: list[str] = []
                if constraints.get("meal_slot"):
                    condition_parts.append(slot_label)
                if budget_vnd:
                    condition_parts.append(f"dưới {budget_vnd:,}đ".replace(",", "."))
                if time_limit_min:
                    condition_parts.append(f"trong khoảng {time_limit_min} phút")

                option_lines: list[str] = []
                for item in constrained_items:
                    name = item.get("name", "unknown")
                    kcal = float(item.get("calories_kcal", 0) or 0)
                    price = int(float(item.get("estimated_price_vnd", 0) or 0))
                    total_time = int(
                        float(item.get("total_time_min", 0) or 0)
                        or float(item.get("prep_time_min", 0) or 0) + float(item.get("cook_time_min", 0) or 0)
                    )
                    detail_parts = [f"{kcal:.1f} kcal"]
                    if price > 0:
                        detail_parts.append(f"~{price:,}đ".replace(",", "."))
                    if total_time > 0:
                        detail_parts.append(f"{total_time} phút")
                    option_lines.append(f"{name} ({', '.join(detail_parts)})")

                intro = "Mình gợi ý vài món phù hợp như sau"
                if condition_parts:
                    intro = f"Với yêu cầu {' '.join(condition_parts)}, mình gợi ý {len(option_lines)} lựa chọn"
                return (
                    f"{remaining_text}{intro}: {'; '.join(option_lines)}.",
                    route_flags,
                )
            if constraints and any(
                constraints.get(key) for key in ("meal_slot", "budget_vnd", "time_limit_min")
            ):
                condition_parts: list[str] = []
                if constraints.get("meal_slot"):
                    condition_parts.append(self._meal_slot_label(constraints.get("meal_slot")))
                if constraints.get("budget_vnd"):
                    condition_parts.append(f"dưới {int(constraints['budget_vnd']):,}đ".replace(",", "."))
                if constraints.get("time_limit_min"):
                    condition_parts.append(f"trong khoảng {int(constraints['time_limit_min'])} phút")
                condition_text = " ".join(condition_parts) if condition_parts else "theo ràng buộc bạn đưa ra"
                return (
                    f"{remaining_text}Mình chưa tìm thấy món nào khớp {condition_text} trong DB hiện tại.",
                    route_flags,
                )

            suggestions: list[dict] = []
            if preference_query:
                suggestions, related_flags = self._find_related_meal_plan_items(
                    message=message,
                    preference_query=preference_query,
                    remaining_kcal=float(remain_kcal or 0),
                    remaining_protein=float(remain_protein or 0),
                    remaining_carbs=float(remain_carbs or 0),
                    remaining_fat=float(remain_fat or 0),
                    limit=3,
                )
                route_flags.extend(related_flags)

            if len(suggestions) < 3:
                general_suggestions = self.repo.suggest_meal_plan_items(
                    remaining_kcal=float(remain_kcal or 0),
                    remaining_protein=float(remain_protein or 0),
                    remaining_carbs=float(remain_carbs or 0),
                    remaining_fat=float(remain_fat or 0),
                    limit=6,
                )
                existing_names = {
                    str(item.get("name", "")).strip().lower()
                    for item in suggestions
                    if str(item.get("name", "")).strip()
                }
                for item in general_suggestions:
                    name = str(item.get("name", "")).strip().lower()
                    if not name or name in existing_names:
                        continue
                    existing_names.add(name)
                    suggestions.append(item)
                    if len(suggestions) >= 3:
                        break

            if not suggestions:
                suggestions = self.repo.suggest_meal_plan_items(
                    remaining_kcal=float(remain_kcal or 0),
                    remaining_protein=float(remain_protein or 0),
                    remaining_carbs=float(remain_carbs or 0),
                    remaining_fat=float(remain_fat or 0),
                    limit=3,
                )
            if suggestions:
                meal_slots = ("Sáng", "Trưa", "Tối")
                lines: list[str] = []
                total_kcal = 0.0
                total_protein = 0.0
                total_carbs = 0.0
                total_fat = 0.0
                for idx, item in enumerate(suggestions):
                    name = item.get("name", "unknown")
                    kcal = float(item.get("calories_kcal", 0) or 0)
                    p = float(item.get("protein_g", 0) or 0)
                    c = float(item.get("carbs_g", 0) or 0)
                    f = float(item.get("fat_g", 0) or 0)
                    total_kcal += kcal
                    total_protein += p
                    total_carbs += c
                    total_fat += f
                    meal_label = meal_slots[idx] if idx < len(meal_slots) else f"Bữa {idx + 1}"
                    lines.append(f"{meal_label}: {name} ({kcal:.1f} kcal, P/C/F {p:.1f}/{c:.1f}/{f:.1f})")
                intro = "Hôm nay bạn có thể ăn 3 bữa như sau:"
                if preference_query:
                    intro = f"Vì bạn muốn ăn {preference_query}, mình gợi ý 3 bữa liên quan như sau:"
                target_text = (
                    f"Mục tiêu còn lại trong ngày hiện là {remain_kcal} kcal, "
                    f"P/C/F = {remain_protein}/{remain_carbs}/{remain_fat}g."
                    if has_daily_target
                    else "Bạn chưa thiết lập mục tiêu dinh dưỡng trong ngày, nên mình đang gợi ý theo dữ liệu món hiện có."
                )
                return (
                    f"{intro} {'; '.join(lines)}. "
                    f"Tổng 3 bữa khoảng {total_kcal:.1f} kcal, "
                    f"P/C/F = {total_protein:.1f}/{total_carbs:.1f}/{total_fat:.1f}g. "
                    f"{target_text}",
                    route_flags,
                )

            gemini_fallback = None
            if self._should_try_gemini_fallback(message, None):
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
