from __future__ import annotations

from pydantic import BaseModel, Field


class MealPlan7dRequest(BaseModel):
    user_id: str
    budget_vnd_per_day: int = Field(ge=1000, le=2000000)
    max_cook_time_min: int = Field(ge=5, le=240)
    target_calories_per_day: int = Field(ge=800, le=6000)


class MealPlanItem(BaseModel):
    plan_date: str
    meal_type: str
    name: str
    calories_kcal: float
    estimated_price_vnd: int | None = None
    prep_time_min: int | None = None
    cook_time_min: int | None = None
    source: str


class MealPlan7dResponse(BaseModel):
    user_id: str
    total_days: int
    total_items: int
    plan: list[MealPlanItem]

