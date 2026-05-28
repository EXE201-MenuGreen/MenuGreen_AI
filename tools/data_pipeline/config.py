import os
from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    postgres_url: str = ""

    foods_table: str = "foods"
    recipes_table: str = "recipes"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
