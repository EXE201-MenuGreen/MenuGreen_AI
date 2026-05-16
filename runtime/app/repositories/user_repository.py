from __future__ import annotations

from datetime import date, timedelta
import uuid

from app.core.config import get_settings
from app.core.supabase_provider import SupabaseProvider


class UserRepository:
    def __init__(self) -> None:
        self.settings = get_settings()

    @staticmethod
    def is_uuid(value: str | None) -> bool:
        if not value:
            return False
        try:
            uuid.UUID(str(value))
            return True
        except Exception:
            return False

    def get_profile(self, user_id: str) -> dict | None:
        resolved_id = self.resolve_user_id(user_id)
        if not resolved_id:
            return None

        client = SupabaseProvider.get_client()
        if client is None:
            return None
        try:
            res = (
                client.table(self.settings.profiles_table)
                .select("*")
                .eq("id", resolved_id)
                .limit(1)
                .execute()
            )
            data = res.data or []
            return data[0] if data else None
        except Exception:
            try:
                # Compatibility fallback for legacy schema/view.
                res = (
                    client.table("user_profiles")
                    .select("*")
                    .eq("id", resolved_id)
                    .limit(1)
                    .execute()
                )
                data = res.data or []
                return data[0] if data else None
            except Exception:
                return None

    def get_subscription_plan(self, user_id: str) -> str:
        resolved_id = self.resolve_user_id(user_id)
        if not resolved_id:
            return "free"

        client = SupabaseProvider.get_client()
        if client is None:
            return "free"
        try:
            res = (
                client.table(self.settings.subscriptions_table)
                .select("tier,is_active,plan,status")
                .eq("user_id", resolved_id)
                .limit(1)
                .execute()
            )
            data = res.data or []
            if not data:
                return "free"
            row = data[0]
            if row.get("tier"):
                return row.get("tier", "free")
            return row.get("plan", "free")
        except Exception:
            try:
                res = (
                    client.table("user_subscriptions")
                    .select("tier,is_active")
                    .eq("user_id", resolved_id)
                    .limit(1)
                    .execute()
                )
                data = res.data or []
                if not data:
                    return "free"
                row = data[0]
                if not row.get("is_active", False):
                    return "free"
                return row.get("tier", "free")
            except Exception:
                return "free"

    def get_meal_logs_7d(self, user_id: str) -> list[dict]:
        resolved_id = self.resolve_user_id(user_id)
        if not resolved_id:
            return []

        client = SupabaseProvider.get_client()
        if client is None:
            return []

        start_date = (date.today() - timedelta(days=6)).isoformat()
        try:
            res = (
                client.table(self.settings.meal_logs_table)
                .select("*")
                .eq("user_id", resolved_id)
                .gte("date", start_date)
                .order("date", desc=False)
                .execute()
            )
            return res.data or []
        except Exception:
            try:
                # fallback for schema with logged_at timestamp
                res = (
                    client.table(self.settings.meal_logs_table)
                    .select("*")
                    .eq("user_id", resolved_id)
                    .gte("logged_at", f"{start_date}T00:00:00")
                    .order("logged_at", desc=False)
                    .execute()
                )
                return res.data or []
            except Exception:
                try:
                    # compatibility fallback: legacy/materialized view
                    res = (
                        client.table("daily_logs")
                        .select("*")
                        .eq("user_id", resolved_id)
                        .gte("date", start_date)
                        .order("date", desc=False)
                        .execute()
                    )
                    return res.data or []
                except Exception:
                    return []

    def save_chat_session(
        self,
        user_id: str | None,
        thread_id: str,
        role: str,
        content: str,
        context_snapshot: dict | None = None,
        tokens_used: int | None = None,
        model_name: str | None = None,
    ) -> bool:
        resolved_id = self.resolve_user_id(user_id)
        if not resolved_id:
            return False

        client = SupabaseProvider.get_client()
        if client is None:
            return False

        try:
            payload = {
                "user_id": resolved_id,
                "thread_id": thread_id,
                "role": role,
                "content": content,
                "context_snapshot": context_snapshot,
                "tokens_used": tokens_used,
                "model_name": model_name,
            }
            client.table(self.settings.ai_chat_sessions_table).insert(payload).execute()
            return True
        except Exception:
            return False

    def search_recipes_by_name(self, keyword: str, limit: int = 5) -> list[dict]:
        query = (keyword or "").strip()
        if not query:
            return []
        client = SupabaseProvider.get_client()
        if client is None:
            return []
        try:
            res = (
                client.table(self.settings.recipes_table)
                .select("*")
                .ilike("name", f"%{query}%")
                .limit(limit)
                .execute()
            )
            return [self._normalize_macro_row(r) for r in (res.data or [])]
        except Exception:
            return []

    def search_foods_by_name(self, keyword: str, limit: int = 5) -> list[dict]:
        query = (keyword or "").strip()
        if not query:
            return []
        client = SupabaseProvider.get_client()
        if client is None:
            return []
        try:
            res = (
                client.table(self.settings.foods_table)
                .select("*")
                .ilike("name", f"%{query}%")
                .limit(limit)
                .execute()
            )
            return [self._normalize_macro_row(r) for r in (res.data or [])]
        except Exception:
            return []

    def resolve_user_id(self, incoming_user_id: str | None, auto_create: bool = True) -> str | None:
        if not incoming_user_id:
            return None
        raw = str(incoming_user_id).strip()
        if not raw:
            return None
        if self.is_uuid(raw):
            return raw

        client = SupabaseProvider.get_client()
        if client is None:
            return None
        try:
            found = (
                client.table(self.settings.external_user_map_table)
                .select("user_id")
                .eq("external_user_id", raw)
                .limit(1)
                .execute()
                .data
                or []
            )
            if found:
                mapped = found[0].get("user_id")
                return str(mapped) if mapped else None
        except Exception:
            return None

        if not auto_create:
            return None

        try:
            created_profile = (
                client.table(self.settings.profiles_table)
                .insert(
                    {
                        "full_name": f"External-{raw[:16]}",
                        "goal": "maintain",
                        "target_calories": 2000,
                        "target_protein_g": 120,
                        "target_carbs_g": 220,
                        "target_fat_g": 60,
                    }
                )
                .execute()
                .data
                or []
            )
            if not created_profile:
                return None
            internal_id = str(created_profile[0]["id"])
            client.table(self.settings.external_user_map_table).insert(
                {"external_user_id": raw, "user_id": internal_id}
            ).execute()
            return internal_id
        except Exception:
            return None

    @staticmethod
    def _to_float(value) -> float:
        try:
            return float(value or 0)
        except Exception:
            return 0.0

    def _normalize_macro_row(self, row: dict) -> dict:
        kcal = self._to_float(
            row.get("calories_kcal", row.get("calories_per_serving", row.get("calories_kcal_per_100g")))
        )
        protein = self._to_float(
            row.get("protein_g", row.get("protein_per_serving", row.get("protein_g_per_100g")))
        )
        carbs = self._to_float(
            row.get("carbs_g", row.get("carbs_per_serving", row.get("carbs_g_per_100g")))
        )
        fat = self._to_float(
            row.get("fat_g", row.get("fat_per_serving", row.get("fat_g_per_100g")))
        )
        return {
            "id": row.get("id"),
            "name": row.get("name"),
            "calories_kcal": round(kcal, 1),
            "protein_g": round(protein, 1),
            "carbs_g": round(carbs, 1),
            "fat_g": round(fat, 1),
            "default_serving_g": row.get("default_serving_g"),
        }

    def suggest_meal_plan_items(
        self,
        remaining_kcal: float,
        remaining_protein: float,
        remaining_carbs: float,
        remaining_fat: float,
        limit: int = 3,
    ) -> list[dict]:
        client = SupabaseProvider.get_client()
        if client is None:
            return []

        recipes: list[dict] = []
        foods: list[dict] = []
        try:
            recipes = (
                client.table(self.settings.recipes_table)
                .select("*")
                .limit(80)
                .execute()
                .data
                or []
            )
        except Exception:
            recipes = []

        try:
            foods = (
                client.table(self.settings.foods_table)
                .select("*")
                .limit(80)
                .execute()
                .data
                or []
            )
        except Exception:
            foods = []

        pool: list[dict] = []
        for row in recipes:
            pool.append({**self._normalize_macro_row(row), "_source": "recipe"})
        for row in foods:
            pool.append({**self._normalize_macro_row(row), "_source": "food"})
        if not pool:
            return []

        # Aim for 3 remaining meals in day.
        per_meal_kcal = max(self._to_float(remaining_kcal) / 3.0, 350.0)
        per_meal_protein = max(self._to_float(remaining_protein) / 3.0, 20.0)
        per_meal_carbs = max(self._to_float(remaining_carbs) / 3.0, 30.0)
        per_meal_fat = max(self._to_float(remaining_fat) / 3.0, 10.0)

        def score(row: dict) -> float:
            kcal = self._to_float(row.get("calories_kcal"))
            protein = self._to_float(row.get("protein_g"))
            carbs = self._to_float(row.get("carbs_g"))
            fat = self._to_float(row.get("fat_g"))
            if kcal <= 0:
                return 1e9
            return (
                abs(kcal - per_meal_kcal) * 0.45
                + abs(protein - per_meal_protein) * 1.25
                + abs(carbs - per_meal_carbs) * 0.75
                + abs(fat - per_meal_fat) * 0.95
            )

        ranked = sorted(pool, key=score)
        picked: list[dict] = []
        seen_names: set[str] = set()
        for item in ranked:
            name = str(item.get("name", "")).strip().lower()
            if not name or name in seen_names:
                continue
            seen_names.add(name)
            picked.append(item)
            if len(picked) >= limit:
                break
        return picked
