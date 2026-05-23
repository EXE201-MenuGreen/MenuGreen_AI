from functools import lru_cache

from pydantic import ConfigDict
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    model_config = ConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "MenuGreen Runtime"
    debug: bool = False

    supabase_url: str = ""
    supabase_key: str = ""
    postgres_url: str = ""

    # Table names are configurable to support schema drift during migration.
    profiles_table: str = "profiles"
    subscriptions_table: str = "subscriptions"
    meal_logs_table: str = "meal_logs"
    ai_chat_sessions_table: str = "ai_chat_sessions"
    foods_table: str = "foods"
    recipes_table: str = "recipes"
    external_user_map_table: str = "external_user_map"

    # ONNX intent
    intent_model_dir: str = "models/intent_onnx"
    intent_confidence_threshold: float = 0.55

    # Fallback LLM (phase 2 wiring)
    google_api_key: str = ""
    llm_model: str = "gemini-2.5-flash"
    embedding_model: str = "models/gemini-embedding-001"

    # Optional crawler/discovery knobs
    jina_api_key: str = ""
    discovery_delay_seconds: float = 2.0
    discovery_max_per_run: int = 20
    serve_frontend: bool = True
    safety_max_response_chars: int = 1200
    safety_block_medical_keywords: bool = True


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
