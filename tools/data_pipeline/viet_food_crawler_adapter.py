"""
Adapter for Vietnamese food crawler outputs.

Purpose:
- Convert crawler raw JSON into normalized rows for:
  - recipes
  - ingredients
  - recipe_ingredients
  - food_aliases (optional)

This script DOES NOT call network and does not execute DB writes by default.
Use it to produce clean intermediate JSON/CSV for ingest scripts.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path


@dataclass
class ParsedIngredient:
    name: str
    quantity: float | None
    unit: str | None
    raw: str


ING_PATTERN = re.compile(r"^\s*(\d+(?:[\.,]\d+)?)?\s*([a-zA-Z%gmlkgL]+)?\s*(.*)$")


def parse_ingredient(text: str) -> ParsedIngredient:
    t = (text or "").strip()
    if not t:
        return ParsedIngredient(name="", quantity=None, unit=None, raw=text)

    m = ING_PATTERN.match(t)
    if not m:
        return ParsedIngredient(name=t, quantity=None, unit=None, raw=text)

    q_raw, unit, name = m.groups()
    quantity = None
    if q_raw:
        try:
            quantity = float(q_raw.replace(",", "."))
        except Exception:
            quantity = None

    name = (name or "").strip() or t
    unit = (unit or "").strip() or None
    return ParsedIngredient(name=name, quantity=quantity, unit=unit, raw=text)


def normalize_recipe(raw: dict) -> dict:
    return {
        "name": (raw.get("name") or "").strip(),
        "description": (raw.get("description") or "").strip() or None,
        "instructions": "\n".join(raw.get("steps", [])) if isinstance(raw.get("steps"), list) else (raw.get("instructions") or None),
        "image_url": raw.get("image") or raw.get("image_url"),
        "dietary_tags": raw.get("tags", []),
        "prep_time_minutes": raw.get("prep_time_minutes"),
        "cook_time_minutes": raw.get("cook_time_minutes"),
        "servings": raw.get("servings"),
    }


def transform(input_path: Path) -> dict:
    with input_path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    rows = data if isinstance(data, list) else data.get("recipes", [])

    recipes = []
    parsed_ingredients = []
    for idx, item in enumerate(rows):
        r = normalize_recipe(item)
        if not r["name"]:
            continue
        local_id = f"recipe_local_{idx}"
        r["_local_id"] = local_id
        recipes.append(r)

        ingredients = item.get("ingredients", [])
        for ing in ingredients:
            p = parse_ingredient(ing if isinstance(ing, str) else str(ing))
            if not p.name:
                continue
            parsed_ingredients.append(
                {
                    "recipe_local_id": local_id,
                    "ingredient_name": p.name,
                    "quantity": p.quantity,
                    "unit": p.unit,
                    "raw": p.raw,
                }
            )

    return {
        "recipes": recipes,
        "parsed_ingredients": parsed_ingredients,
        "total_recipes": len(recipes),
        "total_ingredients": len(parsed_ingredients),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Crawler output JSON")
    parser.add_argument("--output", required=True, help="Normalized JSON output path")
    args = parser.parse_args()

    out = transform(Path(args.input))
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"Normalized: recipes={out['total_recipes']} ingredients={out['total_ingredients']}")
    print(f"Saved: {out_path}")


if __name__ == "__main__":
    main()
