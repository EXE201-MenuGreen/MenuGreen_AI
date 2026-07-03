from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Literal

from pydantic import BaseModel, Field


class UserProfileContext(BaseModel):
    user_id: str | None = None
    full_name: str | None = None
    gender: str | None = None
    date_of_birth: str | None = None
    age: int | None = None
    weight_kg: float | None = None
    height_cm: float | None = None
    goal_mode: str | None = None
    activity_level: str | None = None
    bmi: float | None = None
    bmr_kcal: float | None = None
    tdee_kcal: float | None = None
    vietnamese_region: str | None = None
    preferred_cuisine: str | None = None


class NutritionalTargetContext(BaseModel):
    calories_kcal: float = 0
    protein_g: float = 0
    carbs_g: float = 0
    fat_g: float = 0
    calculation_source: str = "health_profile"
    formula_version: str = "menugreen-health-v1"


class ActualIntakeContext(BaseModel):
    calories_kcal: float = 0
    protein_g: float = 0
    carbs_g: float = 0
    fat_g: float = 0
    fiber_g: float = 0
    water_ml: float = 0


class RemainingBudgetContext(BaseModel):
    calories_kcal: float = 0
    protein_g: float = 0
    carbs_g: float = 0
    fat_g: float = 0


class SafetyAndAllergiesContext(BaseModel):
    allergen_keys: list[str] = Field(default_factory=list)
    allergen_names: list[str] = Field(default_factory=list)
    allergy_risk_level: Literal["None", "Low", "Medium", "High"] = "None"
    blocked_ingredients: list[str] = Field(default_factory=list)


class PreferencesContext(BaseModel):
    dietary_type: str | None = None
    disliked_ingredients: list[str] = Field(default_factory=list)
    preferences: dict[str, Any] = Field(default_factory=dict)
    eating_pattern: dict[str, Any] = Field(default_factory=dict)


class CurrentMealPlanContext(BaseModel):
    planned_meals: list[str] = Field(default_factory=list)
    completed_meals: list[str] = Field(default_factory=list)


class DataQualityContext(BaseModel):
    generated_at: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    source: str = "postgres"
    missing_sources: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)


class WorkerContextResponse(BaseModel):
    user_id: str
    target_date: str
    user_profile: UserProfileContext = Field(default_factory=UserProfileContext)
    nutritional_target: NutritionalTargetContext = Field(default_factory=NutritionalTargetContext)
    actual_intake_today: ActualIntakeContext = Field(default_factory=ActualIntakeContext)
    remaining_budget_today: RemainingBudgetContext = Field(default_factory=RemainingBudgetContext)
    safety_and_allergies: SafetyAndAllergiesContext = Field(default_factory=SafetyAndAllergiesContext)
    preferences: PreferencesContext = Field(default_factory=PreferencesContext)
    current_meal_plan: CurrentMealPlanContext = Field(default_factory=CurrentMealPlanContext)
    subscription: str = "free"
    data_quality: DataQualityContext = Field(default_factory=DataQualityContext)
