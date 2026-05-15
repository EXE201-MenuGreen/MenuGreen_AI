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
        if not self.is_uuid(user_id):
            return None

        client = SupabaseProvider.get_client()
        if client is None:
            return None
        try:
            res = (
                client.table(self.settings.profiles_table)
                .select("*")
                .eq("id", user_id)
                .limit(1)
                .execute()
            )
            data = res.data or []
            return data[0] if data else None
        except Exception:
            return None

    def get_subscription_plan(self, user_id: str) -> str:
        if not self.is_uuid(user_id):
            return "free"

        client = SupabaseProvider.get_client()
        if client is None:
            return "free"
        try:
            res = (
                client.table(self.settings.subscriptions_table)
                .select("tier,is_active,plan,status")
                .eq("user_id", user_id)
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
            return "free"

    def get_meal_logs_7d(self, user_id: str) -> list[dict]:
        if not self.is_uuid(user_id):
            return []

        client = SupabaseProvider.get_client()
        if client is None:
            return []

        start_date = (date.today() - timedelta(days=6)).isoformat()
        try:
            res = (
                client.table(self.settings.meal_logs_table)
                .select("*")
                .eq("user_id", user_id)
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
                    .eq("user_id", user_id)
                    .gte("logged_at", f"{start_date}T00:00:00")
                    .order("logged_at", desc=False)
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
        if not self.is_uuid(user_id):
            return False

        client = SupabaseProvider.get_client()
        if client is None:
            return False

        try:
            payload = {
                "user_id": user_id,
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
