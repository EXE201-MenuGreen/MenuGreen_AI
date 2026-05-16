"""
Ingest normalized crawler data into Supabase tables:
- recipes
- ingredients
- recipe_ingredients

Input format is output of `viet_food_crawler_adapter.py`:
{
  "recipes": [...],
  "parsed_ingredients": [...]
}

Default mode is append/update-safe (no destructive delete).
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

from db import get_client


@dataclass
class Counters:
    recipes_inserted: int = 0
    recipes_updated: int = 0
    ingredients_inserted: int = 0
    recipe_links_inserted: int = 0
    skipped: int = 0


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def get_or_create_ingredient_id(client, name: str, counters: Counters) -> str | None:
    n = (name or "").strip()
    if not n:
        return None

    q = client.table("ingredients").select("id,name").ilike("name", n).limit(1).execute()
    rows = q.data or []
    if rows:
        return rows[0]["id"]

    ins = client.table("ingredients").insert(
        {
            "name": n,
            "calories_per_100g": 0,
            "protein_per_100g": 0,
            "carbs_per_100g": 0,
            "fat_per_100g": 0,
            "fiber_per_100g": 0,
            "category": "unknown",
        }
    ).execute()
    data = ins.data or []
    if not data:
        return None

    counters.ingredients_inserted += 1
    return data[0]["id"]


def upsert_recipe_by_name(client, row: dict, counters: Counters) -> str | None:
    name = (row.get("name") or "").strip()
    if not name:
        return None

    existing = client.table("recipes").select("id,name").eq("name", name).limit(1).execute().data or []
    payload = {
        "name": name,
        "description": row.get("description"),
        "instructions": row.get("instructions"),
        "prep_time_minutes": row.get("prep_time_minutes"),
        "cook_time_minutes": row.get("cook_time_minutes"),
        "servings": row.get("servings"),
        "image_url": row.get("image_url"),
        "dietary_tags": row.get("dietary_tags") or [],
    }

    if existing:
        recipe_id = existing[0]["id"]
        client.table("recipes").update(payload).eq("id", recipe_id).execute()
        counters.recipes_updated += 1
        return recipe_id

    inserted = client.table("recipes").insert(payload).execute().data or []
    if not inserted:
        return None
    counters.recipes_inserted += 1
    return inserted[0]["id"]


def link_recipe_ingredient(client, recipe_id: str, ingredient_id: str, amount: float | None, unit: str | None, counters: Counters):
    amount_val = amount if amount is not None else 0
    unit_val = (unit or "unit").strip() or "unit"

    # simple duplicate guard
    exists = (
        client.table("recipe_ingredients")
        .select("id")
        .eq("recipe_id", recipe_id)
        .eq("ingredient_id", ingredient_id)
        .eq("amount", amount_val)
        .eq("unit", unit_val)
        .limit(1)
        .execute()
        .data
        or []
    )
    if exists:
        return

    client.table("recipe_ingredients").insert(
        {
            "recipe_id": recipe_id,
            "ingredient_id": ingredient_id,
            "amount": amount_val,
            "unit": unit_val,
        }
    ).execute()
    counters.recipe_links_inserted += 1


def run(input_path: Path):
    data = load_json(input_path)
    recipes = data.get("recipes", [])
    parsed_ingredients = data.get("parsed_ingredients", [])

    client = get_client()
    counters = Counters()

    local_to_recipe_id: dict[str, str] = {}

    for r in recipes:
        local_id = r.get("_local_id")
        recipe_id = upsert_recipe_by_name(client, r, counters)
        if not recipe_id:
            counters.skipped += 1
            continue
        if local_id:
            local_to_recipe_id[str(local_id)] = recipe_id

    for ing in parsed_ingredients:
        local_id = str(ing.get("recipe_local_id") or "")
        recipe_id = local_to_recipe_id.get(local_id)
        if not recipe_id:
            counters.skipped += 1
            continue

        ingredient_id = get_or_create_ingredient_id(client, ing.get("ingredient_name") or "", counters)
        if not ingredient_id:
            counters.skipped += 1
            continue

        link_recipe_ingredient(
            client,
            recipe_id=recipe_id,
            ingredient_id=ingredient_id,
            amount=ing.get("quantity"),
            unit=ing.get("unit"),
            counters=counters,
        )

    print("Ingest completed")
    print(f"  recipes_inserted: {counters.recipes_inserted}")
    print(f"  recipes_updated: {counters.recipes_updated}")
    print(f"  ingredients_inserted: {counters.ingredients_inserted}")
    print(f"  recipe_links_inserted: {counters.recipe_links_inserted}")
    print(f"  skipped: {counters.skipped}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Path to crawler_normalized.json")
    args = parser.parse_args()
    run(Path(args.input))
