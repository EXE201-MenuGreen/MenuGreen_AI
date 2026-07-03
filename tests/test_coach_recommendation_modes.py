from __future__ import annotations

import sys
import asyncio
from datetime import date
from pathlib import Path
from types import SimpleNamespace


RUNTIME_DIR = Path(__file__).resolve().parents[1] / "runtime"
if str(RUNTIME_DIR) not in sys.path:
    sys.path.insert(0, str(RUNTIME_DIR))

from app.services.coach_service import CoachService
from app.schemas.chat import ChatRequest
from app.services.action_service import ActionService
from app.services.context_builder import build_context_snapshot
from app.services.safety_service import SafetyService


class FakeCoachRepo:
    items = [
        {
            "id": "chicken-rice",
            "name": "Cơm gà áp chảo",
            "calories_kcal": 520,
            "protein_g": 42,
            "carbs_g": 58,
            "fat_g": 14,
            "instructions": ["Ướp gà", "Áp chảo", "Dùng cùng cơm"],
        },
        {
            "id": "salmon-salad",
            "name": "Salad cá hồi",
            "calories_kcal": 410,
            "protein_g": 35,
            "carbs_g": 24,
            "fat_g": 18,
        },
        {
            "id": "tofu",
            "name": "Đậu hũ sốt cà",
            "calories_kcal": 360,
            "protein_g": 22,
            "carbs_g": 32,
            "fat_g": 12,
        },
    ]

    def suggest_meal_plan_items(self, **_kwargs):
        return self.items

    def search_recipes_by_name(self, _query: str, limit: int = 5):
        return self.items[:limit]

    def search_foods_by_name(self, _query: str, limit: int = 5):
        return []

    def list_meal_candidates_by_constraints(self, **_kwargs):
        return self.items


def build_service() -> CoachService:
    service = CoachService.__new__(CoachService)
    service.repo = FakeCoachRepo()
    return service


def build_context() -> dict:
    return {
        "today_totals": {
            "calories_kcal": 900,
            "protein_g": 55,
            "carbs_g": 100,
            "fat_g": 24,
        },
        "remaining_totals": {
            "calories_kcal": 1100,
            "protein_g": 65,
            "carbs_g": 120,
            "fat_g": 36,
        },
        "targets": {"calories_kcal": 2000},
        "profile": {"goal": "maintain"},
    }


def test_recommend_and_rcm_are_dish_recommendations():
    assert CoachService._heuristic_intent("recommend món ăn cho tui") == "meal_plan"
    assert CoachService._heuristic_intent("rcm món khoảng 500 calo") == "meal_plan"


def test_recipe_words_select_recipe_mode():
    assert CoachService._heuristic_intent("recommend món ăn và công thức") == "recipe_search"
    assert CoachService._heuristic_intent("cách nấu cơm gà áp chảo") == "recipe_search"


def test_dish_recommendation_returns_only_name_and_calories():
    response, flags = build_service()._compose_contextual_response(
        "meal_plan",
        build_context(),
        "recommend món ăn cho tui",
    )

    assert response == (
        "Mình gợi ý 3 món: Cơm gà áp chảo (520 kcal); "
        "Salad cá hồi (410 kcal); Đậu hũ sốt cà (360 kcal)."
    )
    assert "P/C/F" not in response
    assert "cách làm" not in response
    assert "dish-only" in flags


def test_recipe_recommendation_keeps_recipe_details():
    response, flags = build_service()._compose_contextual_response(
        "recipe_search",
        build_context(),
        "recommend công thức cơm gà áp chảo",
    )

    assert "Cơm gà áp chảo" in response
    assert "520 kcal" in response
    assert "cách làm: Ướp gà → Áp chảo → Dùng cùng cơm" in response
    assert "recipe-detail" in flags


def test_mixed_query_is_not_overridden_to_nutrition_calc():
    # Containing both "kcal" and "gợi ý" should not be forcefully overridden to nutrition_calc
    assert CoachService._heuristic_intent("Hôm nay tôi còn bao nhiêu kcal và gợi ý bữa trưa nhanh dưới 60k?") != "nutrition_calc"


def test_dish_recommendation_with_remaining_kcal():
    response, flags = build_service()._compose_contextual_response(
        "meal_plan",
        build_context(),
        "Hôm nay tôi còn bao nhiêu kcal và gợi ý bữa trưa nhanh dưới 60k?",
    )
    assert "còn khoảng 1100 kcal" in response
    assert "Cơm gà áp chảo" in response
    assert "dish-only" in flags


def test_daily_calorie_target_question_uses_health_profile_values():
    context = build_context()
    context["profile"] = {
        "goal": "lose weight",
        "bmr_kcal": 1600,
        "tdee_kcal": 2300,
    }
    context["target_source"] = "health_profile"

    response, flags = build_service()._compose_contextual_response(
        "nutrition_calc",
        context,
        "Ý là hôm nay tôi cần nạp bao nhiêu calo?",
    )

    assert "mục tiêu của bạn là 2000 kcal" in response
    assert "đã nạp 900 kcal" in response
    assert "còn khoảng 1100 kcal" in response
    assert "daily-calorie-target" in flags

    for variant in (
        "Mỗi ngày tôi nên ăn bao nhiêu kcal?",
        "Nhu cầu calo của tôi hôm nay là bao nhiêu?",
        "Tôi cần ăn bao nhiêu calo một ngày?",
    ):
        assert CoachService._wants_daily_target_kcal(variant)


def test_supplied_system_context_overrides_worker_db_context():
    snapshot = build_context_snapshot(
        profile={"target_calories": 2000, "goal": "maintain"},
        logs_7d=[],
        supplied_context={
            "profile": {"gender": "male", "date_of_birth": "2000-01-01"},
            "health_profile": {
                "goal": "lose weight",
                "target_calories": 1800,
                "bmr_kcal": 1550,
                "tdee_kcal": 2300,
            },
            "recent_nutrition": {
                "snapshot_date": date.today().isoformat(),
                "total_calories": 650,
                "total_protein_g": 40,
                "total_carbs_g": 80,
                "total_fat_g": 20,
            },
        },
    )

    assert snapshot["targets"]["calories_kcal"] == 1800
    assert snapshot["today_totals"]["calories_kcal"] == 650
    assert snapshot["remaining_totals"]["calories_kcal"] == 1150
    assert snapshot["target_source"] == "health_profile"


def test_missing_target_uses_same_formula_as_system():
    snapshot = build_context_snapshot(
        profile={
            "gender": "male",
            "weight_kg": 80,
            "height_cm": 180,
            "activity_level": "moderate",
            "goal": "lose weight",
        },
        logs_7d=[],
    )

    assert snapshot["profile"]["bmr_kcal"] == 1805
    assert snapshot["profile"]["tdee_kcal"] == 2798
    assert snapshot["targets"]["calories_kcal"] == 2298
    assert snapshot["target_source"] == "system_formula_v1"


def test_missing_target_can_be_derived_from_existing_tdee():
    snapshot = build_context_snapshot(
        profile={"goal": "build muscle", "tdee_kcal": 2400},
        logs_7d=[],
    )

    assert snapshot["targets"]["calories_kcal"] == 2600
    assert snapshot["targets"]["protein_g"] == 227
    assert snapshot["target_source"] == "system_formula_v1"


def test_pascal_case_health_profile_columns_are_canonicalized():
    snapshot = build_context_snapshot(
        profile={
            "Goal": "maintain",
            "TargetCalories": 2100,
            "TargetProteinG": 130,
            "TargetCarbsG": 240,
            "TargetFatG": 65,
            "BmrKcal": 1650,
            "TdeeKcal": 2100,
        },
        logs_7d=[],
    )

    assert snapshot["targets"] == {
        "calories_kcal": 2100,
        "protein_g": 130,
        "carbs_g": 240,
        "fat_g": 65,
    }
    assert snapshot["profile"]["goal"] == "maintain"
    assert snapshot["profile"]["tdee_kcal"] == 2100
    assert snapshot["target_source"] == "health_profile"


class FakeGeneralClassifier:
    def predict(self, _message: str):
        return "general", 0.99


class FakeReplyRepo(FakeCoachRepo):
    def get_profile(self, _user_id: str):
        return None

    def get_subscription_plan(self, _user_id: str):
        return "free"

    def get_meal_logs_7d(self, _user_id: str):
        return []


def test_worker_reply_overrides_wrong_onnx_intent_and_uses_request_context():
    service = build_service()
    service.repo = FakeReplyRepo()
    service.classifier = FakeGeneralClassifier()
    service.settings = SimpleNamespace(
        intent_confidence_threshold=0.55,
        llm_model="test",
        safety_block_medical_keywords=False,
        safety_max_response_chars=1200,
    )
    service.safety = SafetyService()
    service.safety.settings = service.settings
    service.action_service = ActionService()

    result = asyncio.run(
        service.reply(
            ChatRequest(
                message="Ý là hôm nay tôi cần nạp bao nhiêu calo?",
                user_id="user-1",
                skip_save=True,
                context={
                    "health_profile": {
                        "goal": "lose weight",
                        "target_calories": 1750,
                        "bmr_kcal": 1500,
                        "tdee_kcal": 2250,
                    },
                    "recent_nutrition": {
                        "snapshot_date": date.today().isoformat(),
                        "total_calories": 500,
                    },
                },
            )
        )
    )

    assert result.intent == "nutrition_calc"
    assert "mục tiêu của bạn là 1750 kcal" in result.response
    assert "còn khoảng 1250 kcal" in result.response
    assert result.context_summary["targets"]["calories_kcal"] == 1750

