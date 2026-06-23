import asyncio
import json

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
import psycopg
from psycopg.rows import dict_row

from app.core.config import get_settings
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
from app.schemas.actions import ExecuteActionRequest, ExecuteActionResponse
from app.schemas.context import WorkerContextResponse
from app.schemas.meal_plan import MealPlan7dRequest, MealPlan7dResponse
from app.schemas.recommendations import RecommendationRequest, RecommendationResponse
from app.repositories.user_repository import UserRepository
from app.services.action_service import ActionService
from app.services.context_service import ContextService
from app.services.curation_service import CurationService
from app.services.coach_service import CoachService
from app.services.crawler_service import ingest_normalized, normalize_payload
from app.services.meal_plan_service import MealPlanService
from app.services.recommendation_service import RecommendationMode, RecommendationService

router = APIRouter()
coach_service = CoachService()
user_repo = UserRepository()
curation_service = CurationService()
meal_plan_service = MealPlanService()
context_service = ContextService(user_repo)
recommendation_service = RecommendationService(user_repo, context_service)
action_service = ActionService()


@router.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "runtime"}


@router.get("/debug/db")
def debug_db(user_id: str = "11111111-1111-1111-1111-111111111111") -> dict:
    profile = user_repo.get_profile(user_id)
    logs = user_repo.get_meal_logs_7d(user_id)
    recipes = user_repo.list_active_recipes(limit=5)
    foods = user_repo.list_active_foods(limit=5)
    return {
        "user_id": user_id,
        "profile_found": profile is not None,
        "target_calories": (profile or {}).get("target_calories"),
        "meal_logs_count": len(logs),
        "recipes": recipes,
        "foods": foods,
    }


@router.get("/debug/postgres")
def debug_postgres(user_id: str = "11111111-1111-1111-1111-111111111111") -> dict:
    def quote_ident(name: str) -> str:
        return '"' + str(name).replace('"', '""') + '"'

    def first_existing(columns: set[str], *candidates: str) -> str | None:
        for candidate in candidates:
            if candidate in columns:
                return candidate
        return None

    settings = get_settings()
    postgres_url = settings.postgres_url.strip()
    if postgres_url.startswith("POSTGRES_URL="):
        postgres_url = postgres_url.split("=", 1)[1].strip()
    safe_url = postgres_url
    if "@" in safe_url and ":" in safe_url.split("@", 1)[0]:
        prefix, suffix = safe_url.split("@", 1)
        safe_url = prefix.split(":", 2)[0] + ":***@" + suffix
    try:
        with psycopg.connect(postgres_url, row_factory=dict_row) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT current_database() AS database, current_user AS user, inet_server_port() AS port")
                info = dict(cur.fetchone() or {})
                counts = {}
                for table in ["users", "profiles", "health_profiles", "meal_logs", "foods", "recipes"]:
                    cur.execute(f'SELECT COUNT(*) AS count FROM "{table}"')
                    counts[table] = cur.fetchone()["count"]
                cur.execute(
                    """
                    SELECT table_name, column_name
                    FROM information_schema.columns
                    WHERE table_schema = 'public'
                      AND table_name IN ('health_profiles', 'meal_logs')
                    ORDER BY table_name, ordinal_position
                    """
                )
                schema_rows = cur.fetchall() or []
                schema_columns: dict[str, set[str]] = {"health_profiles": set(), "meal_logs": set()}
                for row in schema_rows:
                    schema_columns.setdefault(row["table_name"], set()).add(row["column_name"])

                hp_columns = schema_columns.get("health_profiles", set())
                ml_columns = schema_columns.get("meal_logs", set())
                hp_user_col = first_existing(hp_columns, "UserId", "user_id")
                hp_target_col = first_existing(hp_columns, "TargetCalories", "target_calories")
                hp_goal_col = first_existing(hp_columns, "Goal", "goal")
                ml_user_col = first_existing(ml_columns, "UserId", "user_id")
                ml_id_col = first_existing(ml_columns, "Id", "id")

                seeded_user = None
                if hp_user_col and hp_target_col and hp_goal_col and ml_user_col and ml_id_col:
                    cur.execute(
                        f"""
                        SELECT
                          hp.{quote_ident(hp_target_col)} AS target_calories,
                          hp.{quote_ident(hp_goal_col)} AS goal,
                          COUNT(ml.{quote_ident(ml_id_col)}) AS meal_logs_count
                        FROM health_profiles hp
                        LEFT JOIN meal_logs ml ON ml.{quote_ident(ml_user_col)} = hp.{quote_ident(hp_user_col)}
                        WHERE hp.{quote_ident(hp_user_col)} = %s
                        GROUP BY hp.{quote_ident(hp_target_col)}, hp.{quote_ident(hp_goal_col)}
                        """,
                        [user_id],
                    )
                    seeded_user = cur.fetchone()
        return {
            "ok": True,
            "postgres_url": safe_url,
            "connection": info,
            "table_counts": counts,
            "schema_columns": {
                "health_profiles": sorted(schema_columns.get("health_profiles", set())),
                "meal_logs": sorted(schema_columns.get("meal_logs", set())),
            },
            "seeded_user": dict(seeded_user) if seeded_user else None,
        }
    except Exception as exc:
        return {
            "ok": False,
            "postgres_url": safe_url,
            "error": str(exc),
        }


@router.post("/worker/chat", response_model=ChatResponse)
async def worker_chat(request: ChatRequest) -> ChatResponse:
    return await coach_service.reply(request)


def _sse(event: str, payload: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(payload, ensure_ascii=False)}\n\n"


@router.post("/worker/chat/stream")
async def worker_chat_stream(request: ChatRequest) -> StreamingResponse:
    async def event_stream():
        try:
            yield _sse("start", {"request_id": request.request_id, "thread_id": request.thread_id})
            response = await coach_service.reply(request)
            text = response.response or ""
            for index in range(0, len(text), 120):
                yield _sse("delta", {"text": text[index:index + 120]})
                await asyncio.sleep(0)
            if response.actions:
                yield _sse("actions", {"items": [action.model_dump(mode="json") for action in response.actions]})
            if response.safety_flags:
                yield _sse("safety", {"flags": response.safety_flags})
            yield _sse("final", response.model_dump(mode="json"))
            yield _sse("done", {"ok": True, "request_id": response.request_id})
        except Exception as exc:
            yield _sse("error", {"detail": str(exc)})

    return StreamingResponse(event_stream(), media_type="text/event-stream")


@router.get("/worker/context", response_model=WorkerContextResponse)
def worker_context(user_id: str, date: str | None = None) -> WorkerContextResponse:
    return context_service.build_context(user_id=user_id, target_date=date)


def _recommend(request: RecommendationRequest, mode: RecommendationMode) -> RecommendationResponse:
    return recommendation_service.recommend(request, mode)


@router.post("/api/ai/recommendations/generate", response_model=RecommendationResponse)
def generate_recommendations(request: RecommendationRequest) -> RecommendationResponse:
    return _recommend(request, "generate")


@router.post("/api/ai/recommendations/safe", response_model=RecommendationResponse)
def generate_safe_recommendations(request: RecommendationRequest) -> RecommendationResponse:
    return _recommend(request, "safe")


@router.post("/api/ai/recommendations/daily-menu", response_model=RecommendationResponse)
def generate_daily_menu(request: RecommendationRequest) -> RecommendationResponse:
    return _recommend(request, "daily-menu")


@router.post("/api/ai/recommendations/weekly-plan", response_model=RecommendationResponse)
def generate_weekly_plan(request: RecommendationRequest) -> RecommendationResponse:
    return _recommend(request, "weekly-plan")


@router.post("/api/ai/recommendations/budget-aware", response_model=RecommendationResponse)
def generate_budget_aware(request: RecommendationRequest) -> RecommendationResponse:
    return _recommend(request, "budget-aware")


@router.post("/api/ai/recommendations/smart-schedule", response_model=RecommendationResponse)
def generate_smart_schedule(request: RecommendationRequest) -> RecommendationResponse:
    return _recommend(request, "smart-schedule")


@router.post("/api/ai/actions/execute", response_model=ExecuteActionResponse)
def execute_action(request: ExecuteActionRequest) -> ExecuteActionResponse:
    return action_service.execute_basic(request)


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
    try:
        created = user_repo.create_feedback_event(payload)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
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
    try:
        created = user_repo.create_training_sample(payload)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    if not created:
        raise HTTPException(status_code=500, detail="Cannot create training sample")

    return CreateTrainingSampleResponse(
        sample_id=str(created.get("id")),
        status=str(created.get("status", "pending")),
        created_at=created.get("created_at"),
    )


@router.post("/api/ai/training-samples", response_model=CreateTrainingSampleResponse, status_code=201)
def create_training_sample(request: CreateTrainingSampleRequest) -> CreateTrainingSampleResponse:
    try:
        created = user_repo.create_training_sample(request.model_dump())
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
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
    try:
        updated = user_repo.review_training_sample(
            sample_id=sampleId,
            status=request.status,
            reviewer_user_id=request.reviewer_user_id,
            review_note=request.review_note,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
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
