from pathlib import Path
import sys

from config import get_settings


def get_client():
    settings = get_settings()
    if not settings.postgres_url:
        raise RuntimeError("POSTGRES_URL is missing")

    runtime_path = Path(__file__).resolve().parents[2] / "runtime"
    sys.path.insert(0, str(runtime_path))
    from app.core.postgres_provider import PostgresProvider

    return PostgresProvider(settings.postgres_url)
