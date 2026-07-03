from __future__ import annotations

from datetime import date, datetime
from typing import Any

from app.repositories.user_repository import UserRepository
from app.services.context_builder import apply_system_nutrition_metrics
from app.schemas.context import (
    ActualIntakeContext,
    CurrentMealPlanContext,
    DataQualityContext,
    NutritionalTargetContext,
    PreferencesContext,
    RemainingBudgetContext,
    SafetyAndAllergiesContext,
    UserProfileContext,
    WorkerContextResponse,
)


class ContextService:
    def __init__(self, repo: UserRepository | None = None) -> None:
        self.repo = repo or UserRepository()

    @staticmethod
    def _to_float(value: Any) -> float:
        try:
            return round(float(value or 0), 1)
        except Exception:
            return 0.0

    @staticmethod
    def _as_dict(value: Any) -> dict:
        return value if isinstance(value, dict) else {}

    @staticmethod
    def _as_list(value: Any) -> list:
        if value is None:
            return []
        if isinstance(value, list):
            return value
        if isinstance(value, tuple):
            return list(value)
        if isinstance(value, str):
            stripped = value.strip()
            return [stripped] if stripped else []
        return []

    def _summarize_logs_for_date(self, logs: list[dict], target_date: str) -> ActualIntakeContext:
        totals = {
            "calories_kcal": 0.0,
            "protein_g": 0.0,
            "carbs_g": 0.0,
            "fat_g": 0.0,
            "fiber_g": 0.0,
        }
        for row in logs:
            row_date = str(row.get("date") or "")
            logged_at = str(row.get("logged_at") or "")
            if row_date != target_date and not logged_at.startswith(target_date):
                continue
            totals["calories_kcal"] += self._to_float(row.get("calories_kcal", row.get("calories_consumed")))
            totals["protein_g"] += self._to_float(row.get("protein_g", row.get("protein_consumed")))
            totals["carbs_g"] += self._to_float(row.get("carbs_g", row.get("carbs_consumed")))
            totals["fat_g"] += self._to_float(row.get("fat_g", row.get("fat_consumed")))
            totals["fiber_g"] += self._to_float(row.get("fiber_g"))
        return ActualIntakeContext(**{k: round(v, 1) for k, v in totals.items()})

    def build_context(self, user_id: str, target_date: str | None = None) -> WorkerContextResponse:
        target_date = target_date or date.today().isoformat()
        missing_sources: list[str] = []
        warnings: list[str] = []

        profile = self.repo.get_profile(user_id) or {}
        if not profile:
            missing_sources.append("profile")
        profile, target_source = apply_system_nutrition_metrics(profile)

        ai_profile = self.repo.get_ai_profile(user_id) or {}
        if not ai_profile:
            missing_sources.append("user_ai_profile")

        logs_7d = self.repo.get_meal_logs_7d(user_id) or []
        if not logs_7d:
            missing_sources.append("meal_logs")

        allergies = self.repo.get_user_allergies(user_id) or []
        meal_plan = self.repo.get_current_meal_plan(user_id, target_date) or {}
        water_ml = self.repo.get_water_intake(user_id, target_date)
        subscription = self.repo.get_subscription_plan(user_id) or "free"

        actual = self._summarize_logs_for_date(logs_7d, target_date)
        actual.water_ml = self._to_float(water_ml)

        target = NutritionalTargetContext(
            calories_kcal=self._to_float(profile.get("target_calories", profile.get("target_calories_kcal"))),
            protein_g=self._to_float(profile.get("target_protein_g")),
            carbs_g=self._to_float(profile.get("target_carbs_g")),
            fat_g=self._to_float(profile.get("target_fat_g")),
            calculation_source=target_source,
        )
        remaining = RemainingBudgetContext(
            calories_kcal=max(round(target.calories_kcal - actual.calories_kcal, 1), 0),
            protein_g=max(round(target.protein_g - actual.protein_g, 1), 0),
            carbs_g=max(round(target.carbs_g - actual.carbs_g, 1), 0),
            fat_g=max(round(target.fat_g - actual.fat_g, 1), 0),
        )

        allergy_names = [
            str(row.get("name") or row.get("allergen_name") or row.get("key") or "").strip()
            for row in allergies
        ]
        allergy_names = [x for x in dict.fromkeys(allergy_names) if x]
        allergy_keys = [
            str(row.get("key") or row.get("allergen_key") or row.get("name") or "").strip().lower()
            for row in allergies
        ]
        allergy_keys = [x for x in dict.fromkeys(allergy_keys) if x]
        risk = "High" if allergy_names or allergy_keys else "None"

        preferences_dict = self._as_dict(ai_profile.get("preferences"))
        eating_pattern = self._as_dict(ai_profile.get("eating_pattern"))
        disliked = self._as_list(ai_profile.get("disliked_foods")) + self._as_list(ai_profile.get("disliked_ingredients"))
        dietary_type = ai_profile.get("dietary_type") or preferences_dict.get("dietary_type")

        if target.calories_kcal <= 0:
            warnings.append("Missing target calories; recommendation scoring will use defaults.")
        elif target_source == "system_formula_v1":
            warnings.append("Target calories were derived with the MenuGreenSystem health formula because no stored target was available.")

        return WorkerContextResponse(
            user_id=user_id,
            target_date=target_date,
            user_profile=UserProfileContext(
                user_id=str(profile.get("user_id") or profile.get("id") or user_id),
                full_name=profile.get("full_name"),
                gender=profile.get("gender"),
                date_of_birth=str(profile.get("date_of_birth")) if profile.get("date_of_birth") else None,
                age=self._calculate_age(profile.get("date_of_birth")),
                weight_kg=self._to_float(profile.get("weight_kg")) or None,
                height_cm=self._to_float(profile.get("height_cm")) or None,
                goal_mode=profile.get("goal") or profile.get("goal_mode"),
                activity_level=profile.get("activity_level"),
                bmi=self._to_float(profile.get("bmi")) or None,
                bmr_kcal=self._to_float(profile.get("bmr_kcal")) or None,
                tdee_kcal=self._to_float(profile.get("tdee_kcal")) or None,
                vietnamese_region=profile.get("vietnamese_region"),
                preferred_cuisine=profile.get("preferred_cuisine"),
            ),
            nutritional_target=target,
            actual_intake_today=actual,
            remaining_budget_today=remaining,
            safety_and_allergies=SafetyAndAllergiesContext(
                allergen_keys=allergy_keys,
                allergen_names=allergy_names,
                allergy_risk_level=risk,
                blocked_ingredients=allergy_names,
            ),
            preferences=PreferencesContext(
                dietary_type=dietary_type,
                disliked_ingredients=[str(x) for x in dict.fromkeys(disliked) if str(x).strip()],
                preferences=preferences_dict,
                eating_pattern=eating_pattern,
            ),
            current_meal_plan=CurrentMealPlanContext(
                planned_meals=[str(x) for x in meal_plan.get("planned_meals", [])],
                completed_meals=[str(x) for x in meal_plan.get("completed_meals", [])],
            ),
            subscription=subscription,
            data_quality=DataQualityContext(missing_sources=missing_sources, warnings=warnings),
        )

    @staticmethod
    def _calculate_age(raw_date: Any) -> int | None:
        if not raw_date:
            return None
        try:
            born = datetime.fromisoformat(str(raw_date).replace("Z", "+00:00")).date()
            today = date.today()
            return today.year - born.year - ((today.month, today.day) < (born.month, born.day))
        except Exception:
            return None
