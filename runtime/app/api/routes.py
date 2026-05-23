from fastapi import APIRouter, HTTPException

from app.schemas.chat import (
    ChatRequest,
    ChatResponse,
    CrawlerIngestRequest,
    CrawlerIngestResponse,
    CrawlerNormalizeRequest,
    CrawlerNormalizeResponse,
)
from app.schemas.feedback import (
    CreateFeedbackRequest,
    CreateFeedbackResponse,
    CreateSampleFromFeedbackRequest,
    CreateTrainingSampleRequest,
    CreateTrainingSampleResponse,
    ReviewTrainingSampleRequest,
    TrainingSample,
)
from app.schemas.meal_plan import MealPlan7dRequest, MealPlan7dResponse
from app.repositories.user_repository import UserRepository
from app.services.curation_service import CurationService
from app.services.coach_service import CoachService
from app.services.crawler_service import ingest_normalized, normalize_payload
from app.services.meal_plan_service import MealPlanService

router = APIRouter()
coach_service = CoachService()
user_repo = UserRepository()
curation_service = CurationService()
meal_plan_service = MealPlanService()


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
    try:
        counters = ingest_normalized(request.normalized)
    except RuntimeError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Crawler ingest failed: {exc}") from exc

    return CrawlerIngestResponse(
        recipes_inserted=counters.recipes_inserted,
        recipes_updated=counters.recipes_updated,
        ingredients_inserted=counters.ingredients_inserted,
        recipe_links_inserted=counters.recipe_links_inserted,
        skipped=counters.skipped,
    )


@router.post("/api/ai/feedback", response_model=CreateFeedbackResponse, status_code=201)
def create_feedback(request: CreateFeedbackRequest) -> CreateFeedbackResponse:
    payload = request.model_dump()
    created = user_repo.create_feedback_event(payload)
    if not created:
        raise HTTPException(status_code=500, detail="Cannot create feedback event")
    return CreateFeedbackResponse(
        feedback_id=str(created.get("id")),
        created_at=created.get("created_at"),
    )


@router.post("/api/ai/feedback/{feedbackId}/to-training-sample", response_model=CreateTrainingSampleResponse, status_code=201)
def create_sample_from_feedback(
    feedbackId: str,
    request: CreateSampleFromFeedbackRequest,
) -> CreateTrainingSampleResponse:
    feedback = user_repo.get_feedback_event(feedbackId)
    if not feedback:
        raise HTTPException(status_code=404, detail="Feedback not found")

    input_text = request.input_text or feedback.get("user_note") or ""
    expected_output = request.expected_output or feedback.get("corrected_response") or ""
    if not input_text or not expected_output:
        raise HTTPException(status_code=400, detail="input_text and expected_output are required")

    payload = {
        "feedback_id": feedbackId,
        "source": "user_feedback",
        "input_text": input_text,
        "context_json": {
            "thread_id": feedback.get("thread_id"),
            "feature_area": feedback.get("feature_area"),
            "feedback_type": feedback.get("feedback_type"),
        },
        "expected_output": expected_output,
        "labels": request.labels,
        "status": "pending",
    }
    created = user_repo.create_training_sample(payload)
    if not created:
        raise HTTPException(status_code=500, detail="Cannot create training sample")

    return CreateTrainingSampleResponse(
        sample_id=str(created.get("id")),
        status=str(created.get("status", "pending")),
        created_at=created.get("created_at"),
    )


@router.post("/api/ai/training-samples", response_model=CreateTrainingSampleResponse, status_code=201)
def create_training_sample(request: CreateTrainingSampleRequest) -> CreateTrainingSampleResponse:
    created = user_repo.create_training_sample(request.model_dump())
    if not created:
        raise HTTPException(status_code=500, detail="Cannot create training sample")
    return CreateTrainingSampleResponse(
        sample_id=str(created.get("id")),
        status=str(created.get("status", "pending")),
        created_at=created.get("created_at"),
    )


@router.get("/api/ai/training-samples")
def list_training_samples(status: str | None = None, limit: int = 50) -> dict:
    limit = max(1, min(limit, 500))
    rows = user_repo.list_training_samples(status=status, limit=limit)
    return {"items": [TrainingSample(**row).model_dump() for row in rows]}


@router.patch("/api/ai/training-samples/{sampleId}/review", response_model=TrainingSample)
def review_training_sample(sampleId: str, request: ReviewTrainingSampleRequest) -> TrainingSample:
    updated = user_repo.review_training_sample(
        sample_id=sampleId,
        status=request.status,
        reviewer_user_id=request.reviewer_user_id,
        review_note=request.review_note,
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Sample not found")
    return TrainingSample(**updated)


@router.post("/api/ai/curation/nightly")
def run_nightly_curation(limit: int = 200) -> dict:
    limit = max(1, min(limit, 2000))
    return curation_service.run_nightly(limit=limit)


@router.post("/api/ai/meal-plans/7d", response_model=MealPlan7dResponse)
def create_meal_plan_7d(request: MealPlan7dRequest) -> MealPlan7dResponse:
    try:
        plan = meal_plan_service.generate_7d_plan(
            user_id=request.user_id,
            budget_vnd_per_day=request.budget_vnd_per_day,
            max_cook_time_min=request.max_cook_time_min,
            target_calories_per_day=request.target_calories_per_day,
        )
        return MealPlan7dResponse(**plan)
    except RuntimeError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
