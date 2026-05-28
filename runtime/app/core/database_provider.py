from __future__ import annotations

from typing import Any

from app.core.config import get_settings
from app.core.postgres_provider import PostgresProvider


class DatabaseProvider:
    _client: PostgresProvider | None = None

    @classmethod
    def get_client(cls) -> PostgresProvider | None:
        if cls._client is not None:
            return cls._client

        settings = get_settings()
        if not settings.postgres_url:
            return None

        cls._client = PostgresProvider(settings.postgres_url)
        return cls._client


def to_dict(value: Any) -> dict:
    return value if isinstance(value, dict) else dict(value)
