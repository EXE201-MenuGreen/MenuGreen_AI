from pydantic import BaseModel, Field
from typing import Any, Literal

from app.schemas.actions import ActionSuggestion

SubscriptionTier = Literal["free", "saving", "energy", "performance"]


class ConversationMessage(BaseModel):
    role: Literal["user", "assistant", "system"]
    content: str


class ChatRequest(BaseModel):
    message: str = Field(min_length=1)
    user_id: str | None = None
    thread_id: str | None = None
    request_id: str | None = None
    conversation_history: list[ConversationMessage] = Field(default_factory=list)
    skip_save: bool = False


class ChatResponse(BaseModel):
    response: str
    intent: str | None = None
    source: str = "onnx"
    request_id: str | None = None
    thread_id: str | None = None
    intent_confidence: float | None = None
    subscription_tier: SubscriptionTier = "free"
    actions: list[ActionSuggestion] = Field(default_factory=list)
    suggested_prompts: list[str] = Field(default_factory=list)
    safety_flags: list[str] = Field(default_factory=list)
    context_summary: dict[str, Any] = Field(default_factory=dict)
    recommendation_refs: list[dict[str, Any]] = Field(default_factory=list)


class CrawlerNormalizeRequest(BaseModel):
    data: Any


class CrawlerNormalizeResponse(BaseModel):
    total_recipes: int
    total_ingredients: int
    normalized: dict


class CrawlerIngestRequest(BaseModel):
    normalized: dict


class CrawlerIngestResponse(BaseModel):
    recipes_inserted: int
    recipes_updated: int
    ingredients_inserted: int
    recipe_links_inserted: int
    skipped: int
