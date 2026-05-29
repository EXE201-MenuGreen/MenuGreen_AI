from __future__ import annotations

from datetime import date, timedelta
import re
import uuid
from typing import Any
from datetime import datetime, timezone

import psycopg
from psycopg.rows import dict_row

from app.core.config import get_settings
from app.core.database_provider import DatabaseProvider


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

        client = DatabaseProvider.get_client()
        if client is None:
            return None
        try:
            res = (
                client.table(self.settings.profiles_table)
                .select("*")
                .eq("user_id", resolved_id)
                .limit(1)
                .execute()
            )
            data = res.data or []
            profile = data[0] if data else {}
            health = (
                client.table("health_profiles")
                .select("*")
                .eq("user_id", resolved_id)
                .limit(1)
                .execute()
                .data
                or []
            )
            if health:
                profile.update(health[0])
            return profile or None
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

        client = DatabaseProvider.get_client()
        if client is None:
            return "free"
        try:
            res = (
                client.table(self.settings.subscriptions_table)
                .select("*")
                .eq("user_id", resolved_id)
                .eq("status", "active")
                .limit(1)
                .execute()
            )
            data = res.data or []
            if not data:
                return "free"
            row = data[0]
            plan_id = row.get("plan_id")
            if not plan_id:
                return "free"
            plans = (
                client.table("subscription_plans")
                .select("name,feature_group")
                .eq("id", plan_id)
                .limit(1)
                .execute()
                .data
                or []
            )
            if not plans:
                return "free"
            return plans[0].get("feature_group") or plans[0].get("name") or "free"
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

        client = DatabaseProvider.get_client()
        if client is None:
            return []

        start_date = (date.today() - timedelta(days=6)).isoformat()
        try:
            res = (
                client.table(self.settings.meal_logs_table)
                .select("*")
                .eq("user_id", resolved_id)
                .gte("logged_at", f"{start_date}T00:00:00+00:00")
                .order("logged_at", desc=False)
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

        client = DatabaseProvider.get_client()
        if client is None:
            return False

        try:
            conversation_id = str(uuid.UUID(thread_id)) if self.is_uuid(thread_id) else str(
                uuid.uuid5(uuid.NAMESPACE_URL, f"menugreen:{resolved_id}:{thread_id}")
            )
            existing = (
                client.table(self.settings.ai_conversations_table)
                .select("id")
                .eq("id", conversation_id)
                .limit(1)
                .execute()
                .data
                or []
            )
            if not existing:
                client.table(self.settings.ai_conversations_table).insert(
                    {
                        "id": conversation_id,
                        "user_id": resolved_id,
                        "title": (context_snapshot or {}).get("intent") or "AI chat",
                    }
                ).execute()
            client.table(self.settings.ai_messages_table).insert(
                {
                    "conversation_id": conversation_id,
                    "role": role,
                    "content": content,
                    "tokens_used": tokens_used,
                }
            ).execute()
            return True
        except Exception:
            return False

    def search_recipes_by_name(self, keyword: str, limit: int = 5) -> list[dict]:
        query = (keyword or "").strip()
        if not query:
            return []
        semantic_rows = self.search_recipes_by_embedding(query, limit=limit)
        if semantic_rows:
            return semantic_rows
        client = DatabaseProvider.get_client()
        if client is None:
            return []
        try:
            fields = ("title", "name", "description", "slug")
            rows: list[dict] = []
            seen_ids: set[str] = set()
            for field in fields:
                res = (
                    client.table(self.settings.recipes_table)
                    .select("*")
                    .ilike(field, f"%{query}%")
                    .limit(limit)
                    .execute()
                )
                for row in res.data or []:
                    row_id = str(row.get("id") or "")
                    if row_id and row_id in seen_ids:
                        continue
                    if row_id:
                        seen_ids.add(row_id)
                    rows.append(row)
                    if len(rows) >= limit:
                        break
                if len(rows) >= limit:
                    break
            return [self._normalize_macro_row(r) for r in rows]
        except Exception:
            return []

    def search_recipes_by_embedding(self, query_text: str, limit: int = 5) -> list[dict]:
        query = (query_text or "").strip()
        if not query:
            return []
        client = DatabaseProvider.get_client()
        if client is None or not getattr(client, "connection_string", ""):
            return []

        settings = get_settings()
        embedding_model = getattr(settings, "embedding_model", "") or ""
        try:
            from google import generativeai as genai
        except Exception:
            return []

        try:
            if settings.google_api_key:
                genai.configure(api_key=settings.google_api_key)
            embedding = genai.embed_content(
                model=embedding_model,
                content=query,
                task_type="retrieval_query",
            )
            values = embedding.get("embedding", {}).get("values") if isinstance(embedding, dict) else None
            if not values:
                return []
        except Exception:
            return []

        try:
            vector_literal = "[" + ",".join(f"{float(value):.8f}" for value in values) + "]"
            with psycopg.connect(client.connection_string, row_factory=dict_row) as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        SELECT id, name, description, prep_time_minutes, cook_time_minutes, servings, dietary_tags, similarity
                        FROM match_recipes(%s::vector, %s, %s)
                        """,
                        [vector_literal, 0.35, limit],
                    )
                    rows = cur.fetchall() or []
            return [self._normalize_macro_row(row) | {"similarity": float(row.get("similarity", 0) or 0)} for row in rows]
        except Exception:
            return []

    def list_active_recipes(self, limit: int = 5) -> list[dict]:
        client = DatabaseProvider.get_client()
        if client is None:
            return []
        try:
            rows = (
                client.table(self.settings.recipes_table)
                .select("*")
                .eq("is_active", True)
                .limit(limit)
                .execute()
                .data
                or []
            )
            return [self._normalize_macro_row(r) for r in rows]
        except Exception:
            return []

    def list_active_foods(self, limit: int = 5) -> list[dict]:
        client = DatabaseProvider.get_client()
        if client is None:
            return []
        try:
            rows = (
                client.table(self.settings.foods_table)
                .select("*")
                .eq("is_active", True)
                .limit(limit)
                .execute()
                .data
                or []
            )
            return [self._normalize_macro_row(r) for r in rows]
        except Exception:
            return []

    def search_foods_by_name(self, keyword: str, limit: int = 5) -> list[dict]:
        query = (keyword or "").strip()
        if not query:
            return []
        client = DatabaseProvider.get_client()
        if client is None:
            return []
        try:
            rows: list[dict] = []
            seen_ids: set[str] = set()
            for field in ("name_vi", "name_en", "name", "slug", "description"):
                res = (
                    client.table(self.settings.foods_table)
                    .select("*")
                    .ilike(field, f"%{query}%")
                    .limit(limit)
                    .execute()
                )
                for row in res.data or []:
                    row_id = str(row.get("id") or "")
                    if row_id and row_id in seen_ids:
                        continue
                    if row_id:
                        seen_ids.add(row_id)
                    rows.append(row)
                    if len(rows) >= limit:
                        break
                if len(rows) >= limit:
                    break
            return [self._normalize_macro_row(r) for r in rows]
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

        client = DatabaseProvider.get_client()
        if client is None:
            return None
        if not self.settings.external_user_map_table:
            return self._ensure_external_user(raw, client) if auto_create else None

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
            # Keep going: mapping table may be missing in some environments.
            pass

        if not auto_create:
            return None

        try:
            return None
        except Exception:
            return None

    def _ensure_external_user(self, external_user_id: str, client) -> str | None:
        user_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"menugreen-user:{external_user_id}"))
        try:
            existing = client.table("users").select("id").eq("id", user_id).limit(1).execute().data or []
            if existing:
                return user_id

            role_rows = client.table("roles").select("id").eq("name", "user").limit(1).execute().data or []
            if role_rows:
                role_id = str(role_rows[0]["id"])
            else:
                role_id = str(uuid.uuid5(uuid.NAMESPACE_URL, "menugreen-role:user"))
                client.table("roles").insert(
                    {
                        "id": role_id,
                        "name": "user",
                        "description": "Default application user",
                    }
                ).execute()

            profile_rows = client.table("profiles").select("user_id").eq("user_id", user_id).limit(1).execute().data or []
            if not profile_rows:
                client.table("profiles").insert(
                    {
                        "user_id": user_id,
                        "full_name": f"External-{external_user_id[:16]}",
                    }
                ).execute()

            health_rows = (
                client.table("health_profiles").select("user_id").eq("user_id", user_id).limit(1).execute().data or []
            )
            if not health_rows:
                client.table("health_profiles").insert(
                    {
                        "user_id": user_id,
                        "goal": "maintain",
                        "target_calories": 2000,
                        "target_protein_g": 120,
                        "target_carbs_g": 220,
                        "target_fat_g": 60,
                    }
                ).execute()

            ai_profile_rows = (
                client.table("user_ai_profiles").select("user_id").eq("user_id", user_id).limit(1).execute().data or []
            )
            if not ai_profile_rows:
                client.table("user_ai_profiles").insert(
                    {
                        "user_id": user_id,
                        "preferences": {},
                        "disliked_foods": [],
                        "eating_pattern": {},
                        "favorite_cuisines": [],
                        "calorie_preference": {},
                    }
                ).execute()

            email_local = re.sub(r"[^a-zA-Z0-9._-]+", "-", external_user_id).strip("-._")[:48] or "external"
            client.table("users").insert(
                {
                    "id": user_id,
                    "role_id": role_id,
                    "email": f"{email_local}@local.menugreen",
                    "password_hash": "external-user",
                    "email_confirmed": True,
                    "is_active": True,
                }
            ).execute()
            return user_id
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
            "name": row.get("title") or row.get("name_vi") or row.get("name_en") or row.get("name"),
            "description": row.get("description"),
            "instructions": row.get("instructions"),
            "prep_time_min": row.get("prep_time_min"),
            "cook_time_min": row.get("cook_time_min"),
            "total_time_min": row.get("total_time_min"),
            "difficulty": row.get("difficulty"),
            "meal_type": row.get("meal_type"),
            "estimated_price_vnd": row.get("estimated_price_vnd"),
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
        client = DatabaseProvider.get_client()
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

    def create_feedback_event(self, payload: dict[str, Any]) -> dict | None:
        client = DatabaseProvider.get_client()
        if client is None:
            return None
        try:
            raw_user_id = payload.get("user_id")
            resolved_id = self.resolve_user_id(str(raw_user_id) if raw_user_id else None)
            if not resolved_id:
                return None
            insert_payload = dict(payload)
            insert_payload["user_id"] = resolved_id
            res = client.table("activity_logs").insert(
                {
                    "user_id": resolved_id,
                    "action": "ai_feedback",
                    "entity_type": "ai_message",
                    "entity_id": payload.get("message_id") if self.is_uuid(payload.get("message_id")) else None,
                    "metadata": insert_payload,
                }
            ).execute()
            rows = res.data or []
            if not rows:
                return None
            return {"id": rows[0].get("id"), "created_at": rows[0].get("created_at"), **insert_payload}
        except Exception as exc:
            raise RuntimeError(f"create_feedback_event failed: {exc}") from exc

    def get_feedback_event(self, feedback_id: str) -> dict | None:
        client = DatabaseProvider.get_client()
        if client is None:
            return None
        try:
            rows = (
                client.table("activity_logs")
                .select("*")
                .eq("id", feedback_id)
                .eq("action", "ai_feedback")
                .limit(1)
                .execute()
                .data
                or []
            )
            if not rows:
                return None
            metadata = rows[0].get("metadata") or {}
            return {"id": rows[0].get("id"), "created_at": rows[0].get("created_at"), **metadata}
        except Exception:
            return None

    def create_training_sample(self, payload: dict[str, Any]) -> dict | None:
        client = DatabaseProvider.get_client()
        if client is None:
            return None
        try:
            user_id = None
            if payload.get("feedback_id"):
                feedback = self.get_feedback_event(str(payload.get("feedback_id")))
                user_id = feedback.get("user_id") if feedback else None
            if not user_id:
                user_id = payload.get("user_id")
            if not user_id:
                user_id = payload.get("reviewer_user_id")
            if not user_id or not self.is_uuid(str(user_id)):
                return None
            sample_payload = dict(payload)
            sample_payload.setdefault("status", "pending")
            res = client.table("activity_logs").insert(
                {
                    "user_id": str(user_id),
                    "action": "ai_training_sample",
                    "entity_type": "ai_feedback",
                    "entity_id": payload.get("feedback_id") if self.is_uuid(payload.get("feedback_id")) else None,
                    "metadata": sample_payload,
                }
            ).execute()
            rows = res.data or []
            if not rows:
                return None
            return self._activity_log_to_training_sample(rows[0])
        except Exception as exc:
            raise RuntimeError(f"create_training_sample failed: {exc}") from exc

    def list_training_samples(self, status: str | None = None, limit: int = 50) -> list[dict]:
        client = DatabaseProvider.get_client()
        if client is None:
            return []
        try:
            query = (
                client.table("activity_logs")
                .select("*")
                .eq("action", "ai_training_sample")
                .order("created_at", desc=True)
                .limit(limit)
            )
            res = query.execute()
            rows = [self._activity_log_to_training_sample(row) for row in (res.data or [])]
            if status:
                rows = [row for row in rows if row.get("status") == status]
            return rows
        except Exception:
            return []

    def review_training_sample(
        self,
        sample_id: str,
        status: str,
        reviewer_user_id: str | None = None,
        review_note: str | None = None,
    ) -> dict | None:
        client = DatabaseProvider.get_client()
        if client is None:
            return None
        try:
            payload: dict[str, Any] = {
                "status": status,
                "reviewed_at": datetime.now(timezone.utc).isoformat(),
            }
            if reviewer_user_id:
                payload["reviewed_by"] = reviewer_user_id
            rows = (
                client.table("activity_logs")
                .select("*")
                .eq("id", sample_id)
                .eq("action", "ai_training_sample")
                .limit(1)
                .execute()
                .data
                or []
            )
            if not rows:
                return None
            metadata = dict(rows[0].get("metadata") or {})
            metadata.update(payload)
            client.table("activity_logs").update({"metadata": metadata}).eq("id", sample_id).execute()
            rows[0]["metadata"] = metadata
            return self._activity_log_to_training_sample(rows[0])
        except Exception as exc:
            raise RuntimeError(f"review_training_sample failed: {exc}") from exc

    def list_unprocessed_feedback_events(self, limit: int = 200) -> list[dict]:
        client = DatabaseProvider.get_client()
        if client is None:
            return []
        try:
            existing = (
                client.table("activity_logs")
                .select("metadata")
                .eq("action", "ai_training_sample")
                .limit(5000)
                .execute()
                .data
                or []
            )
            used_ids = {str((x.get("metadata") or {}).get("feedback_id")) for x in existing if (x.get("metadata") or {}).get("feedback_id")}
            events = (
                client.table("activity_logs")
                .select("*")
                .eq("action", "ai_feedback")
                .order("created_at", desc=False)
                .limit(limit)
                .execute()
                .data
                or []
            )
            normalized = [
                {"id": e.get("id"), "created_at": e.get("created_at"), **(e.get("metadata") or {})}
                for e in events
            ]
            return [e for e in normalized if str(e.get("id")) not in used_ids]
        except Exception:
            return []

    @staticmethod
    def _activity_log_to_training_sample(row: dict) -> dict:
        metadata = dict(row.get("metadata") or {})
        return {
            "id": str(row.get("id")),
            "feedback_id": metadata.get("feedback_id"),
            "source": metadata.get("source", "user_feedback"),
            "input_text": metadata.get("input_text", ""),
            "context_json": metadata.get("context_json"),
            "expected_output": metadata.get("expected_output", ""),
            "labels": metadata.get("labels") or [],
            "status": metadata.get("status", "pending"),
            "reviewed_by": metadata.get("reviewed_by"),
            "reviewed_at": metadata.get("reviewed_at"),
            "created_at": row.get("created_at"),
            "updated_at": None,
        }

    def list_meal_candidates_by_constraints(
        self,
        max_price_vnd: int,
        max_total_time_min: int,
        max_items: int = 200,
    ) -> list[dict]:
        client = DatabaseProvider.get_client()
        if client is None:
            return []
        pool: list[dict] = []
        try:
            recipes = (
                client.table(self.settings.recipes_table)
                .select("*")
                .lte("estimated_price_vnd", max_price_vnd)
                .lte("total_time_min", max_total_time_min)
                .limit(max_items)
                .execute()
                .data
                or []
            )
            for row in recipes:
                pool.append(
                    {
                        "id": row.get("id"),
                        "source": "recipe",
                "name": row.get("title"),
                "calories_kcal": self._to_float(
                            row.get("calories_kcal")
                        ),
                "estimated_price_vnd": row.get("estimated_price_vnd"),
                        "prep_time_min": row.get("prep_time_min"),
                        "cook_time_min": row.get("cook_time_min"),
                    }
                )
        except Exception:
            pass
        try:
            foods = (
                client.table(self.settings.foods_table)
                .select("*")
                .lte("estimated_price_vnd", max_price_vnd)
                .limit(max_items)
                .execute()
                .data
                or []
            )
            for row in foods:
                pool.append(
                    {
                        "id": row.get("id"),
                        "source": "food",
                    "name": row.get("name_vi") or row.get("name_en"),
                        "calories_kcal": self._to_float(row.get("calories_kcal")),
                        "estimated_price_vnd": row.get("estimated_price_vnd"),
                        "prep_time_min": 0,
                        "cook_time_min": 0,
                    }
                )
        except Exception:
            pass
        return [x for x in pool if x.get("name") and self._to_float(x.get("calories_kcal")) > 0]

    def insert_meal_plan_rows(self, rows: list[dict]) -> int:
        if not rows:
            return 0
        client = DatabaseProvider.get_client()
        if client is None:
            return 0
        plan_headers: dict[tuple[str, str], str] = {}
        count = 0
        for row in rows:
            try:
                user_id = str(row.get("user_id"))
                plan_date = str(row.get("plan_date"))
                key = (user_id, plan_date)
                header_id = plan_headers.get(key)
                if not header_id:
                    header = client.table("meal_plan_headers").insert(
                        {
                            "user_id": user_id,
                            "title": f"Meal plan {plan_date}",
                            "plan_type": "ai_7d_budget_time_calories",
                            "start_date": plan_date,
                            "end_date": plan_date,
                            "target_calories": int(self._to_float(row.get("target_calories")) * 3),
                            "generated_by": "ai",
                            "is_active": True,
                        }
                    ).execute().data or []
                    if not header:
                        continue
                    header_id = str(header[0]["id"])
                    plan_headers[key] = header_id
                payload = {
                    "meal_plan_id": header_id,
                    "meal_type": row.get("meal_type"),
                    "target_calories": int(self._to_float(row.get("target_calories"))),
                    "planned_date": plan_date,
                    "food_id": row.get("food_id"),
                    "recipe_id": row.get("recipe_id"),
                }
                client.table("meal_plan_items").insert(payload).execute()
                count += 1
            except Exception:
                continue
        return count
