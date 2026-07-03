from __future__ import annotations

from datetime import date, timedelta
from itertools import cycle, islice
from typing import Literal

from app.repositories.user_repository import UserRepository
from app.schemas.actions import ActionSuggestion
from app.schemas.recommendations import (
    ExcludedRecommendationItem,
    RecommendationItem,
    RecommendationRequest,
    RecommendationResponse,
    RecommendationScore,
)
from app.services.allergy_safety_service import AllergySafetyService
from app.services.context_service import ContextService


RecommendationMode = Literal["generate", "safe", "daily-menu", "weekly-plan", "budget-aware", "smart-schedule"]


class RecommendationService:
    SLOT_SEQUENCE = ("breakfast", "lunch", "dinner")
    SLOT_TIMES = {
        "breakfast": "07:30",
        "lunch": "12:00",
        "dinner": "18:30",
        "snack": "15:30",
    }

    def __init__(
        self,
        repo: UserRepository | None = None,
        context_service: ContextService | None = None,
        allergy_service: AllergySafetyService | None = None,
    ) -> None:
        self.repo = repo or UserRepository()
        self.context_service = context_service or ContextService(self.repo)
        self.allergy_service = allergy_service or AllergySafetyService()

    @staticmethod
    def _to_float(value) -> float:
        try:
            return float(value or 0)
        except Exception:
            return 0.0

    @staticmethod
    def _item_key(row: dict) -> str:
        return str(row.get("id") or row.get("name") or row.get("title") or "item")

    def recommend(self, request: RecommendationRequest, mode: RecommendationMode) -> RecommendationResponse:
        context = self.context_service.build_context(request.user_id, request.date)
        context_dict = context.model_dump()
        excluded_ids = {str(x) for x in request.exclude_food_ids}
        candidates = [
            row
            for row in self.repo.list_recommendation_candidates(limit=400)
            if str(row.get("id") or "") not in excluded_ids
        ]

        safe_candidates, excluded, safety_flags = self.allergy_service.filter_candidates(candidates, context_dict)
        if excluded:
            safety_flags.append("unsafe-candidates-excluded")

        budget_per_item = self._budget_per_item(request, mode)
        if mode == "budget-aware" and budget_per_item:
            within_budget = [
                row
                for row in safe_candidates
                if self._to_float(row.get("estimated_price_vnd")) <= budget_per_item
                or self._to_float(row.get("estimated_price_vnd")) <= 0
            ]
            if within_budget:
                safe_candidates = within_budget
        target_kcal = self._target_kcal(request, context_dict, mode)
        ranked = self._rank(safe_candidates, request, target_kcal, budget_per_item, context_dict, mode)
        items = self._shape_items(ranked, request, mode)

        reasons: dict[str, list[str]] = {}
        scores: dict[str, RecommendationScore] = {}
        score_map = {self._item_key(row): score for row, score in ranked}
        for item in items:
            key = str(item.id or item.name)
            raw_score = score_map.get(key) or score_map.get(item.name) or RecommendationScore()
            scores[key] = raw_score
            reasons[key] = self._reasons(item, request, raw_score, mode)

        return RecommendationResponse(
            mode=mode,
            items=items,
            reasons=reasons,
            scores=scores,
            safety_flags=list(dict.fromkeys(safety_flags)),
            excluded_items=[ExcludedRecommendationItem(**row) for row in excluded],
            actions=self._actions_for_mode(request, mode, items),
            context_summary={
                "target_date": context.target_date,
                "remaining_budget_today": context.remaining_budget_today.model_dump(),
                "allergy_risk_level": context.safety_and_allergies.allergy_risk_level,
                "subscription": context.subscription,
            },
        )

    def _budget_per_item(self, request: RecommendationRequest, mode: RecommendationMode) -> int | None:
        if not request.budget_vnd:
            return None
        divisor = 21 if mode == "weekly-plan" else 3 if mode == "daily-menu" else 1
        return max(int(request.budget_vnd / divisor), 1)

    def _target_kcal(self, request: RecommendationRequest, context: dict, mode: RecommendationMode) -> float:
        if request.target_calories:
            return float(request.target_calories)
        remaining = ((context or {}).get("remaining_budget_today") or {}).get("calories_kcal")
        if remaining:
            divisor = 3 if mode in {"daily-menu", "weekly-plan", "generate"} else 1
            return max(float(remaining) / divisor, 250.0)
        target = ((context or {}).get("nutritional_target") or {}).get("calories_kcal")
        if target:
            return max(float(target) / 3.0, 250.0)
        return 450.0

    def _rank(
        self,
        candidates: list[dict],
        request: RecommendationRequest,
        target_kcal: float,
        budget_per_item: int | None,
        context: dict,
        mode: RecommendationMode,
    ) -> list[tuple[dict, RecommendationScore]]:
        ranked: list[tuple[dict, RecommendationScore]] = []
        for row in candidates:
            kcal = self._to_float(row.get("calories_kcal"))
            if kcal <= 0:
                continue
            price = self._to_float(row.get("estimated_price_vnd"))
            total_time = self._to_float(row.get("total_time_min")) or self._to_float(row.get("prep_time_min")) + self._to_float(row.get("cook_time_min"))
            macro_fit = max(0.0, 1.0 - abs(kcal - target_kcal) / max(target_kcal, 1.0))
            budget_fit = 1.0
            if budget_per_item and price > 0:
                budget_fit = max(0.0, 1.0 - max(price - budget_per_item, 0.0) / max(budget_per_item, 1))
            time_fit = 1.0
            if request.max_cook_time_min and total_time > 0:
                time_fit = max(0.0, 1.0 - max(total_time - request.max_cook_time_min, 0.0) / max(request.max_cook_time_min, 1))
            meal_slot_fit = self._meal_slot_fit(row, request.meal_slot)
            personalization_fit = self._personalization_fit(row, context, mode)
            total = round(
                macro_fit * 0.35
                + budget_fit * 0.20
                + time_fit * 0.15
                + meal_slot_fit * 0.15
                + 0.15
                + personalization_fit * 0.12,
                4,
            )
            total = max(0.0, min(total, 1.0))
            if budget_per_item and price > budget_per_item * 1.5:
                total *= 0.6
            if request.max_cook_time_min and total_time > request.max_cook_time_min * 1.5:
                total *= 0.6
            ranked.append(
                (
                    row,
                    RecommendationScore(
                        macro_fit=round(macro_fit, 4),
                        budget_fit=round(budget_fit, 4),
                        time_fit=round(time_fit, 4),
                        allergy_safety=1,
                        meal_slot_fit=round(meal_slot_fit, 4),
                        personalization_fit=round(personalization_fit, 4),
                        total=round(total, 4),
                    ),
                )
            )
        ranked.sort(key=lambda pair: (-pair[1].total, str(pair[0].get("name") or "")))
        return ranked

    def _personalization_fit(self, row: dict, context: dict, mode: RecommendationMode) -> float:
        preferences = ((context or {}).get("preferences") or {}).get("preferences") or {}
        if not isinstance(preferences, dict):
            return 0.0
        tuning = preferences.get("recommendationTuning") or preferences.get("recommendation_tuning") or {}
        if not isinstance(tuning, dict):
            return 0.0

        candidate_name = self.allergy_service.normalize_text(row.get("name"))
        preferred = [self.allergy_service.normalize_text(x) for x in tuning.get("preferredItems", [])]
        avoided = [self.allergy_service.normalize_text(x) for x in tuning.get("avoidedItems", [])]
        fit = 0.0
        if candidate_name and any(name and (name in candidate_name or candidate_name in name) for name in preferred):
            fit += 0.7
        if candidate_name and any(name and (name in candidate_name or candidate_name in name) for name in avoided):
            fit -= 1.0

        weights = tuning.get("ruleWeights") or {}
        mode_tuning = weights.get(mode) if isinstance(weights, dict) else None
        if isinstance(mode_tuning, dict):
            weight = self._to_float(mode_tuning.get("weight"))
            if weight > 0:
                fit += max(-0.3, min((weight - 1.0) * 0.4, 0.3))
        return max(-1.0, min(fit, 1.0))

    def _meal_slot_fit(self, row: dict, meal_slot: str | None) -> float:
        if not meal_slot or meal_slot == "any":
            return 1.0
        raw = str(row.get("meal_type") or "").lower()
        if not raw:
            return 0.6
        return 1.0 if meal_slot in raw else 0.35

    def _shape_items(
        self,
        ranked: list[tuple[dict, RecommendationScore]],
        request: RecommendationRequest,
        mode: RecommendationMode,
    ) -> list[RecommendationItem]:
        rows = [row for row, _ in ranked]
        if not rows:
            return []

        target_date = request.date or date.today().isoformat()

        if mode == "daily-menu":
            selected = list(islice(cycle(rows), 3))
            return [self._to_item(row, meal_slot=slot, plan_date=target_date) for row, slot in zip(selected, self.SLOT_SEQUENCE)]

        if mode == "weekly-plan":
            start = date.fromisoformat(request.date) if request.date else date.today()
            selected = list(islice(cycle(rows), 21))
            shaped: list[RecommendationItem] = []
            for index, row in enumerate(selected):
                day = start + timedelta(days=index // 3)
                slot = self.SLOT_SEQUENCE[index % 3]
                shaped.append(self._to_item(row, meal_slot=slot, plan_date=day.isoformat()))
            return shaped

        selected = rows[: max(1, request.limit)]
        if mode == "smart-schedule":
            slot = request.meal_slot if request.meal_slot and request.meal_slot != "any" else None
            return [
                self._to_item(
                    row,
                    meal_slot=slot or self.SLOT_SEQUENCE[index % 3],
                    recommended_time=self.SLOT_TIMES.get(slot or self.SLOT_SEQUENCE[index % 3]),
                    plan_date=target_date,
                )
                for index, row in enumerate(selected)
            ]
        return [self._to_item(row, plan_date=target_date) for row in selected]

    def _to_item(
        self,
        row: dict,
        meal_slot: str | None = None,
        plan_date: str | None = None,
        recommended_time: str | None = None,
    ) -> RecommendationItem:
        total_time = self._to_float(row.get("total_time_min")) or self._to_float(row.get("prep_time_min")) + self._to_float(row.get("cook_time_min"))
        effective_slot = meal_slot or row.get("meal_type")
        if recommended_time is None and effective_slot:
            slot_normalized = str(effective_slot).lower().strip()
            if "breakfast" in slot_normalized or "sáng" in slot_normalized:
                recommended_time = self.SLOT_TIMES["breakfast"]
            elif "lunch" in slot_normalized or "trưa" in slot_normalized:
                recommended_time = self.SLOT_TIMES["lunch"]
            elif "dinner" in slot_normalized or "tối" in slot_normalized:
                recommended_time = self.SLOT_TIMES["dinner"]
            elif "snack" in slot_normalized or "xế" in slot_normalized or "phụ" in slot_normalized:
                recommended_time = self.SLOT_TIMES["snack"]
            else:
                recommended_time = self.SLOT_TIMES.get(slot_normalized)

        return RecommendationItem(
            id=str(row.get("id")) if row.get("id") else None,
            source=str(row.get("source") or row.get("_source") or "food"),
            name=str(row.get("name") or row.get("title") or "unknown"),
            description=row.get("description"),
            meal_type=meal_slot or row.get("meal_type"),
            plan_date=plan_date,
            recommended_time=recommended_time,
            calories_kcal=round(self._to_float(row.get("calories_kcal")), 1),
            protein_g=round(self._to_float(row.get("protein_g")), 1),
            carbs_g=round(self._to_float(row.get("carbs_g")), 1),
            fat_g=round(self._to_float(row.get("fat_g")), 1),
            estimated_price_vnd=int(self._to_float(row.get("estimated_price_vnd"))) if row.get("estimated_price_vnd") is not None else None,
            prep_time_min=int(self._to_float(row.get("prep_time_min"))) if row.get("prep_time_min") is not None else None,
            cook_time_min=int(self._to_float(row.get("cook_time_min"))) if row.get("cook_time_min") is not None else None,
            total_time_min=int(total_time) if total_time else None,
            default_serving_g=self._to_float(row.get("default_serving_g")) or None,
            instructions=row.get("instructions"),
        )

    def _reasons(
        self,
        item: RecommendationItem,
        request: RecommendationRequest,
        score: RecommendationScore,
        mode: RecommendationMode,
    ) -> list[str]:
        reasons = ["Đã qua bộ lọc an toàn dị ứng."]
        if score.macro_fit >= 0.75:
            reasons.append("Macro/calorie gần mục tiêu.")
        if request.budget_vnd:
            reasons.append("Phù hợp ràng buộc ngân sách.")
        if request.max_cook_time_min:
            reasons.append("Phù hợp thời gian nấu.")
        if mode == "smart-schedule":
            reasons.append(f"Gợi ý giờ ăn {item.recommended_time or 'phù hợp'} theo bữa.")
        if score.personalization_fit > 0:
            reasons.append("Phù hợp với feedback gợi ý trước đó của bạn.")
        elif score.personalization_fit < 0:
            reasons.append("Đã giảm ưu tiên dựa trên feedback trước đó.")
        return reasons

    def _actions_for_mode(
        self,
        request: RecommendationRequest,
        mode: RecommendationMode,
        items: list[RecommendationItem],
    ) -> list[ActionSuggestion]:
        actions: list[ActionSuggestion] = []
        if mode in {"generate", "daily-menu", "weekly-plan"}:
            actions.append(
                ActionSuggestion(
                    type="generate_meal_plan",
                    title="Tạo meal plan",
                    description="Lưu các gợi ý này thành kế hoạch ăn uống sau khi user xác nhận.",
                    payload={"user_id": request.user_id, "mode": mode},
                )
            )
        if mode in {"budget-aware", "generate"}:
            actions.append(
                ActionSuggestion(
                    type="budget_optimize",
                    title="Tối ưu ngân sách",
                    description="Tìm lựa chọn rẻ hơn nhưng vẫn giữ mục tiêu macro.",
                    payload={"user_id": request.user_id, "budget_vnd": request.budget_vnd},
                )
            )
        if mode == "smart-schedule":
            selected = items[0] if items else None
            schedule_payload = {
                "user_id": request.user_id,
                "meal_slot": request.meal_slot,
            }
            if selected:
                schedule_payload.update(
                    {
                        "food_id" if selected.source == "food" else "recipe_id": selected.id,
                        "planned_date": selected.plan_date,
                        "scheduled_time": selected.recommended_time,
                        "meal_type": selected.meal_type,
                        "target_calories": int(selected.calories_kcal),
                    }
                )
            actions.append(
                ActionSuggestion(
                    type="schedule_meal",
                    title="Lên lịch bữa ăn",
                    description="Đặt khung giờ gợi ý cho các món đã chọn.",
                    payload=schedule_payload,
                )
            )
        return actions
