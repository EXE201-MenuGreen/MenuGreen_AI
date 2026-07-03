from __future__ import annotations

import sys
from pathlib import Path


RUNTIME_DIR = Path(__file__).resolve().parents[1] / "runtime"
if str(RUNTIME_DIR) not in sys.path:
    sys.path.insert(0, str(RUNTIME_DIR))

from app.services.coach_service import CoachService


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

