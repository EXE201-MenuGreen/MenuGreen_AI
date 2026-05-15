from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "MenuGreen Runtime"
    debug: bool = False

    supabase_url: str = ""
    supabase_key: str = ""

    # Table names are configurable to support schema drift during migration.
    profiles_table: str = "profiles"
    subscriptions_table: str = "subscriptions"
    meal_logs_table: str = "meal_logs"
    ai_chat_sessions_table: str = "ai_chat_sessions"

    # ONNX intent
    intent_model_dir: str = "models/intent_onnx"
    intent_confidence_threshold: float = 0.55

    # Fallback LLM (phase 2 wiring)
    google_api_key: str = ""
    llm_model: str = "gemini-2.5-flash"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
