from __future__ import annotations

import re
import unicodedata
from typing import Any


class AllergySafetyService:
    @staticmethod
    def normalize_text(value: Any) -> str:
        text = str(value or "").strip().lower()
        if not text:
            return ""
        text = unicodedata.normalize("NFKD", text)
        text = "".join(ch for ch in text if not unicodedata.combining(ch))
        text = text.replace("đ", "d")
        text = re.sub(r"[^a-z0-9\s]", " ", text)
        return re.sub(r"\s+", " ", text).strip()

    @classmethod
    def _tokens_from_context(cls, context: Any) -> list[str]:
        if hasattr(context, "model_dump"):
            context = context.model_dump()
        safety = (context or {}).get("safety_and_allergies") or {}
        preferences = (context or {}).get("preferences") or {}
        raw_tokens = [
            *(safety.get("allergen_keys") or []),
            *(safety.get("allergen_names") or []),
            *(safety.get("blocked_ingredients") or []),
            *(preferences.get("disliked_ingredients") or []),
        ]
        normalized = [cls.normalize_text(x) for x in raw_tokens]
        return [x for x in dict.fromkeys(normalized) if x]

    @classmethod
    def _candidate_text(cls, item: dict) -> str:
        values: list[Any] = [
            item.get("name"),
            item.get("description"),
            item.get("ingredients"),
            item.get("ingredient_names"),
            item.get("allergens"),
            item.get("allergen_keys"),
            item.get("allergen_names"),
            item.get("tags"),
        ]
        flattened: list[str] = []
        for value in values:
            if isinstance(value, list):
                flattened.extend(str(x) for x in value)
            elif isinstance(value, dict):
                flattened.extend(str(x) for x in value.values())
            elif value:
                flattened.append(str(value))
        return cls.normalize_text(" ".join(flattened))

    def filter_candidates(self, items: list[dict], context: Any) -> tuple[list[dict], list[dict], list[str]]:
        tokens = self._tokens_from_context(context)
        if not tokens:
            return items, [], []

        safe: list[dict] = []
        excluded: list[dict] = []
        for item in items:
            candidate_text = self._candidate_text(item)
            matched = next((token for token in tokens if token and token in candidate_text), None)
            if matched:
                excluded.append(
                    {
                        "id": item.get("id"),
                        "name": item.get("name") or item.get("title") or "unknown",
                        "reason": f"Matched blocked allergy/preference token: {matched}",
                    }
                )
                continue
            safe.append(item)

        flags = ["allergy-filter-applied"] if excluded else []
        return safe, excluded, flags
