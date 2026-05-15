from supabase import create_client

from config import get_settings


def get_client():
    settings = get_settings()
    if not settings.supabase_url or not settings.supabase_key:
        raise RuntimeError("SUPABASE_URL/SUPABASE_KEY is missing")
    return create_client(settings.supabase_url, settings.supabase_key)
