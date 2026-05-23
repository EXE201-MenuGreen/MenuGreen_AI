from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field

FeedbackType = Literal["thumbs_up", "thumbs_down", "correction", "rating"]
FeatureArea = Literal[
    "nutrition_chat",
    "meal_recommendation",
    "meal_plan_generation",
    "ingredient_utilization",
    "office_program",
    "gym_program",
]
SampleStatus = Literal["pending", "approved", "rejected", "trained"]


class CreateFeedbackRequest(BaseModel):
    user_id: str
    conversation_id: str | None = None
    message_id: str | None = None
    thread_id: str | None = None
    feedback_type: FeedbackType
    rating: int | None = Field(default=None, ge=1, le=5)
    user_note: str | None = None
    assistant_response: str | None = None
    corrected_response: str | None = None
    feature_area: FeatureArea | None = None


class CreateFeedbackResponse(BaseModel):
    feedback_id: str
    created_at: datetime | None = None


class CreateTrainingSampleRequest(BaseModel):
    feedback_id: str | None = None
    source: str = "user_feedback"
    input_text: str
    context_json: dict[str, Any] | None = None
    expected_output: str
    labels: list[str] = Field(default_factory=list)
    status: SampleStatus = "pending"


class CreateSampleFromFeedbackRequest(BaseModel):
    input_text: str | None = None
    expected_output: str | None = None
    labels: list[str] = Field(default_factory=list)


class CreateTrainingSampleResponse(BaseModel):
    sample_id: str
    status: SampleStatus
    created_at: datetime | None = None


class ReviewTrainingSampleRequest(BaseModel):
    status: Literal["approved", "rejected", "trained"]
    reviewer_user_id: str | None = None
    review_note: str | None = None


class TrainingSample(BaseModel):
    id: str
    feedback_id: str | None = None
    source: str
    input_text: str
    context_json: dict[str, Any] | None = None
    expected_output: str
    labels: list[str] = Field(default_factory=list)
    status: SampleStatus
    reviewed_by: str | None = None
    reviewed_at: datetime | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None

