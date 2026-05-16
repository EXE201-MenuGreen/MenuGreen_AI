from pydantic import BaseModel, Field
from typing import Any, Literal

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


class ChatResponse(BaseModel):
    response: str
    intent: str | None = None
    source: str = "onnx"
    request_id: str | None = None
    thread_id: str | None = None
    intent_confidence: float | None = None
    subscription_tier: SubscriptionTier = "free"


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
