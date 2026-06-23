from __future__ import annotations

from typing import Any, Literal
from uuid import uuid4

from pydantic import BaseModel, Field


ActionType = Literal[
    "generate_meal_plan",
    "replace_food",
    "budget_optimize",
    "schedule_meal",
    "show_recipe",
    "log_meal",
    "ask_followup",
]


class ActionSuggestion(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid4()))
    type: ActionType
    title: str
    description: str
    requires_confirmation: bool = True
    payload: dict[str, Any] = Field(default_factory=dict)
    safety_notes: list[str] = Field(default_factory=list)


class ExecuteActionRequest(BaseModel):
    user_id: str
    type: ActionType
    payload: dict[str, Any] = Field(default_factory=dict)
    confirmed: bool = False


class ExecuteActionResponse(BaseModel):
    status: Literal["completed", "needs_confirmation", "unsupported"]
    action: ActionType
    result: dict[str, Any] = Field(default_factory=dict)
    safety_notes: list[str] = Field(default_factory=list)
