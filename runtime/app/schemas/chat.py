from pydantic import BaseModel, Field
from typing import Literal

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
