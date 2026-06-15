from __future__ import annotations

from collections import OrderedDict
from functools import lru_cache
from hashlib import sha256
import json
import logging
import threading
import time
from typing import Any

from app.core.config import get_settings


class GeminiPool:
    def __init__(self) -> None:
        settings = get_settings()
        self.logger = logging.getLogger("app.gemini_pool")
        self.keys = self._parse_keys(
            multi_keys=settings.google_api_keys,
            single_key=settings.google_api_key,
        )
        self.cache_ttl_seconds = max(int(settings.gemini_cache_ttl_seconds or 0), 0)
        self.cache_max_entries = max(int(settings.gemini_cache_max_entries or 0), 32)
        self._lock = threading.Lock()
        self._embed_lock = threading.Lock()
        self._cache: OrderedDict[str, tuple[float, Any]] = OrderedDict()
        self._llm_clients: dict[tuple[str, float, str], Any] = {}
        self._next_key_index = 0

    @staticmethod
    def _parse_keys(multi_keys: str, single_key: str) -> list[str]:
        seen: set[str] = set()
        result: list[str] = []
        raw_values = [multi_keys or "", single_key or ""]
        for raw in raw_values:
            for item in raw.split(","):
                key = item.strip()
                if not key or key in seen:
                    continue
                seen.add(key)
                result.append(key)
        return result

    @staticmethod
    def _mask_key(api_key: str) -> str:
        if len(api_key) <= 8:
            return "***"
        return f"{api_key[:4]}***{api_key[-4:]}"

    @staticmethod
    def _extract_text(result: Any) -> str | None:
        content = getattr(result, "content", None)
        if isinstance(content, str):
            return content.strip() or None
        if isinstance(content, list):
            parts: list[str] = []
            for item in content:
                if isinstance(item, str):
                    parts.append(item)
                elif isinstance(item, dict):
                    text = item.get("text")
                    if text:
                        parts.append(str(text))
                else:
                    text = getattr(item, "text", None)
                    if text:
                        parts.append(str(text))
            joined = "\n".join(part.strip() for part in parts if str(part).strip()).strip()
            return joined or None
        return None

    @staticmethod
    def _extract_embedding_values(embedding: Any) -> list[float] | None:
        if isinstance(embedding, dict):
            raw_embedding = embedding.get("embedding")
            if isinstance(raw_embedding, list) and raw_embedding:
                return [float(value) for value in raw_embedding]
            if isinstance(raw_embedding, dict):
                values = raw_embedding.get("values")
                if isinstance(values, list) and values:
                    return [float(value) for value in values]
        return None

    @staticmethod
    def _error_kind(exc: Exception) -> str:
        text = str(exc).lower()
        if any(token in text for token in ("429", "quota", "rate limit", "resource exhausted")):
            return "quota-or-rate-limit"
        return exc.__class__.__name__

    def is_available(self) -> bool:
        return bool(self.keys)

    def _cache_key(self, namespace: str, payload: dict[str, Any]) -> str:
        digest = sha256(json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")).hexdigest()
        return f"{namespace}:{digest}"

    def _get_cached(self, cache_key: str) -> Any | None:
        if self.cache_ttl_seconds <= 0:
            return None
        now = time.time()
        with self._lock:
            cached = self._cache.get(cache_key)
            if not cached:
                return None
            expires_at, value = cached
            if expires_at < now:
                self._cache.pop(cache_key, None)
                return None
            self._cache.move_to_end(cache_key)
            return value

    def _set_cached(self, cache_key: str, value: Any) -> None:
        if self.cache_ttl_seconds <= 0:
            return
        expires_at = time.time() + self.cache_ttl_seconds
        with self._lock:
            self._cache[cache_key] = (expires_at, value)
            self._cache.move_to_end(cache_key)
            while len(self._cache) > self.cache_max_entries:
                self._cache.popitem(last=False)

    def _key_indexes(self) -> list[int]:
        with self._lock:
            start = self._next_key_index
        return [((start + offset) % len(self.keys)) for offset in range(len(self.keys))]

    def _mark_success(self, index: int) -> None:
        with self._lock:
            self._next_key_index = (index + 1) % len(self.keys)

    def invoke_text(
        self,
        prompt: str,
        model: str,
        temperature: float = 0.2,
        cache_namespace: str = "text",
    ) -> str | None:
        if not self.keys:
            return None

        cache_key = self._cache_key(
            cache_namespace,
            {"prompt": prompt, "model": model, "temperature": temperature},
        )
        cached = self._get_cached(cache_key)
        if isinstance(cached, str):
            return cached

        try:
            from langchain_google_genai import ChatGoogleGenerativeAI
        except Exception as exc:
            self.logger.warning("Gemini text client unavailable: %s", exc.__class__.__name__)
            return None

        for index in self._key_indexes():
            api_key = self.keys[index]
            client_key = (model, float(temperature), api_key)
            client = self._llm_clients.get(client_key)
            if client is None:
                try:
                    client = ChatGoogleGenerativeAI(
                        model=model,
                        google_api_key=api_key,
                        temperature=temperature,
                    )
                    self._llm_clients[client_key] = client
                except Exception as exc:
                    self.logger.warning(
                        "Gemini client init failed for key %s: %s",
                        self._mask_key(api_key),
                        self._error_kind(exc),
                    )
                    continue

            try:
                result = client.invoke(prompt)
                text = self._extract_text(result)
                if text:
                    self._set_cached(cache_key, text)
                    self._mark_success(index)
                    return text
            except Exception as exc:
                self.logger.warning(
                    "Gemini text request failed for key %s: %s",
                    self._mask_key(api_key),
                    self._error_kind(exc),
                )
        return None

    def invoke_url_context(
        self,
        prompt: str,
        url: str,
        model: str,
        temperature: float = 0.2,
        cache_namespace: str = "url-context",
    ) -> str | None:
        if not self.keys or not url.strip():
            return None

        cache_key = self._cache_key(
            cache_namespace,
            {"prompt": prompt, "url": url.strip(), "model": model, "temperature": temperature},
        )
        cached = self._get_cached(cache_key)
        if isinstance(cached, str):
            return cached

        try:
            from google import genai
            from google.genai import types
        except Exception as exc:
            self.logger.warning("Gemini URL context client unavailable: %s", exc.__class__.__name__)
            return None

        for index in self._key_indexes():
            api_key = self.keys[index]
            try:
                client = genai.Client(api_key=api_key)
                response = client.models.generate_content(
                    model=model,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        temperature=temperature,
                        tools=[{"url_context": {}}],
                    ),
                )
                text = (getattr(response, "text", None) or "").strip()
                if text:
                    self._set_cached(cache_key, text)
                    self._mark_success(index)
                    return text
            except Exception as exc:
                self.logger.warning(
                    "Gemini URL context request failed for key %s: %s",
                    self._mask_key(api_key),
                    self._error_kind(exc),
                )
        return None

    def embed_text(
        self,
        content: str,
        model: str,
        task_type: str,
        cache_namespace: str = "embedding",
    ) -> list[float] | None:
        if not self.keys:
            return None

        cache_key = self._cache_key(
            cache_namespace,
            {"content": content, "model": model, "task_type": task_type},
        )
        cached = self._get_cached(cache_key)
        if isinstance(cached, list):
            return [float(value) for value in cached]

        try:
            from google import generativeai as genai
        except Exception as exc:
            self.logger.warning("Gemini embedding client unavailable: %s", exc.__class__.__name__)
            return None

        for index in self._key_indexes():
            api_key = self.keys[index]
            try:
                with self._embed_lock:
                    genai.configure(api_key=api_key)
                    embedding = genai.embed_content(
                        model=model,
                        content=content,
                        task_type=task_type,
                    )
                values = self._extract_embedding_values(embedding)
                if values:
                    self._set_cached(cache_key, values)
                    self._mark_success(index)
                    return values
            except Exception as exc:
                self.logger.warning(
                    "Gemini embedding request failed for key %s: %s",
                    self._mask_key(api_key),
                    self._error_kind(exc),
                )
        return None


@lru_cache(maxsize=1)
def get_gemini_pool() -> GeminiPool:
    return GeminiPool()
