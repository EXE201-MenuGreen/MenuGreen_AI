from __future__ import annotations

from typing import Any

from supabase import Client, create_client

from app.core.config import get_settings


class SupabaseProvider:
    _client: Client | None = None

    @classmethod
    def get_client(cls) -> Client | None:
        if cls._client is not None:
            return cls._client

        settings = get_settings()
        if not settings.supabase_url or not settings.supabase_key:
            return None

        cls._client = create_client(settings.supabase_url, settings.supabase_key)
        return cls._client


def to_dict(value: Any) -> dict:
    return value if isinstance(value, dict) else dict(value)
