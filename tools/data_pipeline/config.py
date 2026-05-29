from functools import lru_cache

from pydantic import ConfigDict
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    model_config = ConfigDict(
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    postgres_url: str = ""

    foods_table: str = "foods"
    recipes_table: str = "recipes"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
