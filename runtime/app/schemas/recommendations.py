from __future__ import annotations

from typing import Literal
from uuid import uuid4

from pydantic import BaseModel, Field

from app.schemas.actions import ActionSuggestion


MealSlot = Literal["breakfast", "lunch", "dinner", "snack", "any"]


class RecommendationRequest(BaseModel):
    user_id: str
    date: str | None = None
    budget_vnd: int | None = Field(default=None, ge=0)
    meal_slot: MealSlot | None = None
    max_cook_time_min: int | None = Field(default=None, ge=0)
    target_calories: int | None = Field(default=None, ge=0)
    exclude_food_ids: list[str] = Field(default_factory=list)
    limit: int = Field(default=5, ge=1, le=50)


class RecommendationItem(BaseModel):
    id: str | None = None
    source: str = "food"
    name: str
    description: str | None = None
    meal_type: str | None = None
    plan_date: str | None = None
    recommended_time: str | None = None
    calories_kcal: float = 0
    protein_g: float = 0
    carbs_g: float = 0
    fat_g: float = 0
    estimated_price_vnd: int | None = None
    prep_time_min: int | None = None
    cook_time_min: int | None = None
    total_time_min: int | None = None
    default_serving_g: float | None = None
    instructions: list[str] | str | None = None


class RecommendationScore(BaseModel):
    macro_fit: float = 0
    budget_fit: float = 0
    time_fit: float = 0
    allergy_safety: float = 1
    meal_slot_fit: float = 0
    personalization_fit: float = 0
    total: float = 0


class ExcludedRecommendationItem(BaseModel):
    id: str | None = None
    name: str
    reason: str


class RecommendationResponse(BaseModel):
    request_id: str = Field(default_factory=lambda: str(uuid4()))
    mode: Literal["generate", "safe", "daily-menu", "weekly-plan", "budget-aware", "smart-schedule"]
    items: list[RecommendationItem] = Field(default_factory=list)
    reasons: dict[str, list[str]] = Field(default_factory=dict)
    scores: dict[str, RecommendationScore] = Field(default_factory=dict)
    safety_flags: list[str] = Field(default_factory=list)
    excluded_items: list[ExcludedRecommendationItem] = Field(default_factory=list)
    actions: list[ActionSuggestion] = Field(default_factory=list)
    context_summary: dict[str, object] = Field(default_factory=dict)
