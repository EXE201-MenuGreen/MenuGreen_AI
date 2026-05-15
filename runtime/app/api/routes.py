from fastapi import APIRouter

from app.schemas.chat import ChatRequest, ChatResponse
from app.services.coach_service import CoachService

router = APIRouter()
coach_service = CoachService()


@router.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "runtime"}


@router.post("/worker/chat", response_model=ChatResponse)
async def worker_chat(request: ChatRequest) -> ChatResponse:
    return await coach_service.reply(request)
