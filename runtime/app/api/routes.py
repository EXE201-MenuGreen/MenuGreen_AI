from fastapi import APIRouter

from app.schemas.chat import (
    ChatRequest,
    ChatResponse,
    CrawlerIngestRequest,
    CrawlerIngestResponse,
    CrawlerNormalizeRequest,
    CrawlerNormalizeResponse,
)
from app.services.coach_service import CoachService
from app.services.crawler_service import ingest_normalized, normalize_payload

router = APIRouter()
coach_service = CoachService()


@router.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "runtime"}


@router.post("/worker/chat", response_model=ChatResponse)
async def worker_chat(request: ChatRequest) -> ChatResponse:
    return await coach_service.reply(request)


@router.post("/admin/crawler/normalize", response_model=CrawlerNormalizeResponse)
def admin_crawler_normalize(request: CrawlerNormalizeRequest) -> CrawlerNormalizeResponse:
    normalized = normalize_payload(request.data)
    return CrawlerNormalizeResponse(
        total_recipes=normalized.get("total_recipes", 0),
        total_ingredients=normalized.get("total_ingredients", 0),
        normalized=normalized,
    )


@router.post("/admin/crawler/ingest", response_model=CrawlerIngestResponse)
def admin_crawler_ingest(request: CrawlerIngestRequest) -> CrawlerIngestResponse:
    counters = ingest_normalized(request.normalized)
    return CrawlerIngestResponse(
        recipes_inserted=counters.recipes_inserted,
        recipes_updated=counters.recipes_updated,
        ingredients_inserted=counters.ingredients_inserted,
        recipe_links_inserted=counters.recipe_links_inserted,
        skipped=counters.skipped,
    )
