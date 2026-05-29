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
        postgres_url = settings.postgres_url.strip()
        if postgres_url.startswith("POSTGRES_URL="):
            postgres_url = postgres_url.split("=", 1)[1].strip()
        if not postgres_url:
            return None

        cls._client = PostgresProvider(postgres_url)
        return cls._client


def to_dict(value: Any) -> dict:
    return value if isinstance(value, dict) else dict(value)
