from __future__ import annotations

import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

RUNTIME_DIR = Path(__file__).resolve().parents[1] / "runtime"
if str(RUNTIME_DIR) not in sys.path:
    sys.path.insert(0, str(RUNTIME_DIR))

from app.api import routes
from app.core.config import get_settings
from app.main import create_app
from app.schemas.actions import ActionSuggestion
from app.schemas.chat import ChatResponse
from app.schemas.context import (
    ActualIntakeContext,
    CurrentMealPlanContext,
    NutritionalTargetContext,
    PreferencesContext,
    RemainingBudgetContext,
    SafetyAndAllergiesContext,
    UserProfileContext,
    WorkerContextResponse,
)
from app.services.recommendation_service import RecommendationService


class FakeContextService:
    def build_context(self, user_id: str, target_date: str | None = None) -> WorkerContextResponse:
        return WorkerContextResponse(
            user_id=user_id,
            target_date=target_date or "2026-06-23",
            user_profile=UserProfileContext(
                user_id=user_id,
                full_name="Contract User",
                gender="male",
                weight_kg=72.5,
                height_cm=175,
                goal_mode="cut",
                vietnamese_region="South",
            ),
            nutritional_target=NutritionalTargetContext(
                calories_kcal=2000,
                protein_g=120,
                carbs_g=220,
                fat_g=60,
            ),
            actual_intake_today=ActualIntakeContext(
                calories_kcal=900,
                protein_g=55,
                carbs_g=100,
                fat_g=24,
                water_ml=1200,
            ),
            remaining_budget_today=RemainingBudgetContext(
                calories_kcal=1100,
                protein_g=65,
                carbs_g=120,
                fat_g=36,
            ),
            safety_and_allergies=SafetyAndAllergiesContext(
                allergen_keys=["seafood"],
                allergen_names=["Hải sản"],
                allergy_risk_level="High",
                blocked_ingredients=["seafood"],
            ),
            preferences=PreferencesContext(
                dietary_type="CleanEating",
                disliked_ingredients=["cilantro"],
            ),
            current_meal_plan=CurrentMealPlanContext(
                planned_meals=["Ức gà áp chảo"],
                completed_meals=["Cơm lứt"],
            ),
            subscription="free",
        )


class FakeRecommendationRepo:
    def list_recommendation_candidates(self, limit: int = 400) -> list[dict]:
        return [
            {
                "id": "chicken",
                "source": "recipe",
                "name": "Ức gà áp chảo",
                "meal_type": "lunch",
                "calories_kcal": 430,
                "protein_g": 42,
                "carbs_g": 35,
                "fat_g": 10,
                "estimated_price_vnd": 28000,
                "prep_time_min": 10,
                "cook_time_min": 15,
                "ingredient_names": ["chicken", "rice"],
            },
            {
                "id": "shrimp",
                "source": "recipe",
                "name": "Salad tôm",
                "meal_type": "dinner",
                "calories_kcal": 360,
                "protein_g": 30,
                "carbs_g": 20,
                "fat_g": 9,
                "estimated_price_vnd": 45000,
                "prep_time_min": 10,
                "cook_time_min": 5,
                "ingredient_names": ["shrimp", "seafood"],
                "allergen_keys": ["seafood"],
            },
            {
                "id": "tofu",
                "source": "food",
                "name": "Đậu hũ sốt cà",
                "meal_type": "dinner",
                "calories_kcal": 390,
                "protein_g": 24,
                "carbs_g": 32,
                "fat_g": 12,
                "estimated_price_vnd": 18000,
                "prep_time_min": 8,
                "cook_time_min": 12,
                "ingredient_names": ["tofu", "tomato"],
            },
        ]


class FakeCoachService:
    async def reply(self, request):
        return ChatResponse(
            response="AI Coach ready for streaming contract.",
            intent="meal_plan",
            source="fake",
            request_id=request.request_id or "req-1",
            thread_id=request.thread_id or "thread-1",
            actions=[
                ActionSuggestion(
                    type="generate_meal_plan",
                    title="Tạo meal plan",
                    description="Generate a plan.",
                    payload={"source": "test"},
                )
            ],
            suggested_prompts=["Tôi còn bao nhiêu kcal?"],
            safety_flags=["contract-safe"],
            context_summary={
                "remaining_totals": {"calories_kcal": 1100},
                "request_context": request.context,
            },
        )


class FakeMealPlanService:
    def generate_7d_plan(self, user_id: str, budget_vnd_per_day: int, max_cook_time_min: int, target_calories_per_day: int):
        return {
            "user_id": user_id,
            "total_days": 7,
            "total_items": 21,
            "plan": [
                {
                    "plan_date": "2026-06-23",
                    "meal_type": "breakfast",
                    "name": f"Meal {index}",
                    "calories_kcal": 450,
                    "estimated_price_vnd": 20000,
                    "prep_time_min": 5,
                    "cook_time_min": 10,
                    "source": "food",
                }
                for index in range(21)
            ],
        }


@pytest.fixture(autouse=True)
def reset_settings(monkeypatch):
    monkeypatch.delenv("AI_RUNTIME_INTERNAL_KEY", raising=False)
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


@pytest.fixture()
def client(monkeypatch):
    monkeypatch.setattr(routes, "context_service", FakeContextService())
    monkeypatch.setattr(
        routes,
        "recommendation_service",
        RecommendationService(repo=FakeRecommendationRepo(), context_service=FakeContextService()),
    )
    monkeypatch.setattr(routes, "coach_service", FakeCoachService())
    monkeypatch.setattr(routes, "meal_plan_service", FakeMealPlanService())
    return TestClient(create_app())


def test_health_is_open_when_internal_key_is_set(monkeypatch):
    monkeypatch.setenv("AI_RUNTIME_INTERNAL_KEY", "secret")
    get_settings.cache_clear()
    client = TestClient(create_app())

    assert client.get("/health").status_code == 200
    assert client.get("/worker/context?user_id=user-1").status_code == 401


def test_internal_key_allows_worker_routes(monkeypatch):
    monkeypatch.setenv("AI_RUNTIME_INTERNAL_KEY", "secret")
    get_settings.cache_clear()
    monkeypatch.setattr(routes, "context_service", FakeContextService())
    client = TestClient(create_app())

    response = client.get(
        "/worker/context?user_id=user-1",
        headers={"X-AI-Runtime-Key": "secret"},
    )

    assert response.status_code == 200
    assert response.json()["user_id"] == "user-1"


def test_worker_context_contract_shape(client):
    response = client.get("/worker/context?user_id=user-1&date=2026-06-23")

    assert response.status_code == 200
    body = response.json()
    assert set(
        [
            "user_profile",
            "nutritional_target",
            "actual_intake_today",
            "remaining_budget_today",
            "safety_and_allergies",
            "preferences",
            "current_meal_plan",
            "subscription",
            "data_quality",
        ]
    ).issubset(body.keys())
    assert body["safety_and_allergies"]["allergy_risk_level"] == "High"


def test_safe_recommendation_filters_allergy(client):
    response = client.post(
        "/api/ai/recommendations/safe",
        json={"user_id": "user-1", "limit": 5},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["mode"] == "safe"
    assert "Salad tôm" not in [item["name"] for item in body["items"]]
    assert any(item["id"] == "shrimp" for item in body["excluded_items"])
    assert "unsafe-candidates-excluded" in body["safety_flags"]


def test_budget_daily_weekly_and_schedule_contracts(client):
    budget = client.post(
        "/api/ai/recommendations/budget-aware",
        json={"user_id": "user-1", "budget_vnd": 20000, "limit": 1},
    )
    assert budget.status_code == 200
    assert budget.json()["items"][0]["estimated_price_vnd"] <= 20000

    daily = client.post(
        "/api/ai/recommendations/daily-menu",
        json={"user_id": "user-1", "date": "2026-06-23"},
    )
    assert daily.status_code == 200
    assert len(daily.json()["items"]) == 3

    weekly = client.post(
        "/api/ai/recommendations/weekly-plan",
        json={"user_id": "user-1", "date": "2026-06-23"},
    )
    assert weekly.status_code == 200
    assert len(weekly.json()["items"]) == 21

    schedule = client.post(
        "/api/ai/recommendations/smart-schedule",
        json={"user_id": "user-1", "meal_slot": "dinner", "limit": 1},
    )
    assert schedule.status_code == 200
    assert schedule.json()["items"][0]["recommended_time"] == "18:30"


def test_worker_chat_backward_compatible_fields(client):
    response = client.post(
        "/worker/chat",
        json={"message": "gợi ý bữa tối", "user_id": "user-1", "request_id": "req-1"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["response"]
    assert body["intent"] == "meal_plan"
    assert body["actions"][0]["type"] == "generate_meal_plan"
    assert body["safety_flags"] == ["contract-safe"]


def test_worker_chat_accepts_structured_system_context(client):
    response = client.post(
        "/worker/chat",
        json={
            "message": "Hôm nay tôi cần nạp bao nhiêu calo?",
            "user_id": "user-1",
            "context": {
                "health_profile": {"target_calories": 1800, "tdee_kcal": 2300},
                "recent_nutrition": {"snapshot_date": "2026-07-03", "total_calories": 600},
            },
        },
    )

    assert response.status_code == 200
    request_context = response.json()["context_summary"]["request_context"]
    assert request_context["health_profile"]["target_calories"] == 1800
    assert request_context["recent_nutrition"]["total_calories"] == 600


def test_worker_chat_stream_event_order(client):
    response = client.post(
        "/worker/chat/stream",
        json={"message": "stream giúp tôi", "user_id": "user-1", "request_id": "req-stream"},
    )

    assert response.status_code == 200
    text = response.text
    positions = [text.index(f"event: {event}") for event in ["start", "delta", "final", "done"]]
    assert positions == sorted(positions)


def test_existing_meal_plan_7d_endpoint_still_works(client):
    response = client.post(
        "/api/ai/meal-plans/7d",
        json={
            "user_id": "user-1",
            "budget_vnd_per_day": 100000,
            "max_cook_time_min": 60,
            "target_calories_per_day": 2000,
        },
    )

    assert response.status_code == 200
    assert response.json()["total_items"] == 21
