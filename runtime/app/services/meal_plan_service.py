from __future__ import annotations

from datetime import date, timedelta

from app.repositories.user_repository import UserRepository


class MealPlanService:
    MEAL_TYPES = ("breakfast", "lunch", "dinner")

    def __init__(self) -> None:
        self.repo = UserRepository()

    @staticmethod
    def _to_float(value) -> float:
        try:
            return float(value or 0)
        except Exception:
            return 0.0

    def generate_7d_plan(
        self,
        user_id: str,
        budget_vnd_per_day: int,
        max_cook_time_min: int,
        target_calories_per_day: int,
    ) -> dict:
        resolved_user_id = self.repo.resolve_user_id(user_id)
        if not resolved_user_id:
            raise RuntimeError("Invalid user_id")

        per_meal_budget = max(int(budget_vnd_per_day / 3), 1000)
        per_meal_target_kcal = max(float(target_calories_per_day) / 3.0, 200.0)

        candidates = self.repo.list_meal_candidates_by_constraints(
            max_price_vnd=per_meal_budget,
            max_total_time_min=max_cook_time_min,
            max_items=300,
        )
        if not candidates:
            # Check if database has no active foods/recipes at all
            all_items = self.repo.list_meal_candidates_by_constraints(
                max_price_vnd=99999999,
                max_total_time_min=99999,
                max_items=10
            )
            if not all_items:
                raise RuntimeError("Database holds no active foods or recipes. Please run database seeding.")

            # Check if budget alone is too low
            items_by_time_only = self.repo.list_meal_candidates_by_constraints(
                max_price_vnd=99999999,
                max_total_time_min=max_cook_time_min,
                max_items=10
            )
            if items_by_time_only:
                raise RuntimeError(
                    f"Insufficient budget. No food or recipe in the database costs less than or equal to {per_meal_budget:,} VND per meal."
                )

            # Check if time alone is too short
            items_by_budget_only = self.repo.list_meal_candidates_by_constraints(
                max_price_vnd=per_meal_budget,
                max_total_time_min=99999,
                max_items=10
            )
            if items_by_budget_only:
                raise RuntimeError(
                    f"Max cook time is too short. No recipe in the database can be completed within {max_cook_time_min} minutes."
                )

            # Default fallback
            raise RuntimeError(
                f"No meal candidates match both the budget limit ({per_meal_budget:,} VND/meal) and max cook time ({max_cook_time_min} mins) constraints."
            )

        ranked = sorted(
            candidates,
            key=lambda x: abs(self._to_float(x.get("calories_kcal")) - per_meal_target_kcal),
        )
        top = ranked[:20]

        rows_to_insert: list[dict] = []
        response_items: list[dict] = []
        start = date.today()
        idx = 0
        for d in range(7):
            plan_date = (start + timedelta(days=d)).isoformat()
            for meal_type in self.MEAL_TYPES:
                item = top[idx % len(top)]
                idx += 1
                rows_to_insert.append(
                    {
                        "user_id": resolved_user_id,
                        "plan_date": plan_date,
                        "meal_type": meal_type,
                        "target_calories": int(per_meal_target_kcal),
                        "food_name": item.get("name"),
                        "food_id": item.get("id") if item.get("source") == "food" else None,
                        "recipe_id": item.get("id") if item.get("source") == "recipe" else None,
                    }
                )
                response_items.append(
                    {
                        "plan_date": plan_date,
                        "meal_type": meal_type,
                        "name": item.get("name"),
                        "calories_kcal": round(self._to_float(item.get("calories_kcal")), 1),
                        "estimated_price_vnd": item.get("estimated_price_vnd"),
                        "prep_time_min": item.get("prep_time_min"),
                        "cook_time_min": item.get("cook_time_min"),
                        "source": item.get("source"),
                    }
                )

        self.repo.insert_meal_plan_rows(rows_to_insert)
        return {
            "user_id": user_id,
            "total_days": 7,
            "total_items": len(response_items),
            "plan": response_items,
        }

