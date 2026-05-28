from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

from app.core.database_provider import DatabaseProvider


ING_PATTERN = re.compile(r"^\s*(\d+(?:[\.,]\d+)?)?\s*([a-zA-Z%gmlkgL]+)?\s*(.*)$")


@dataclass
class ParsedIngredient:
    name: str
    quantity: float | None
    unit: str | None
    raw: str


@dataclass
class Counters:
    recipes_inserted: int = 0
    recipes_updated: int = 0
    ingredients_inserted: int = 0
    recipe_links_inserted: int = 0
    skipped: int = 0


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

    return ParsedIngredient(name=(name or t).strip(), quantity=quantity, unit=(unit or "").strip() or None, raw=text)


def normalize_recipe(raw: dict) -> dict:
    raw_instructions = raw.get("steps", []) if isinstance(raw.get("steps"), list) else raw.get("instructions")
    if isinstance(raw_instructions, str):
        instructions = [line.strip() for line in raw_instructions.splitlines() if line.strip()]
    elif isinstance(raw_instructions, list):
        instructions = raw_instructions
    else:
        instructions = []
    return {
        "title": (raw.get("title") or raw.get("name") or "").strip(),
        "description": (raw.get("description") or "").strip() or None,
        "instructions": instructions,
        "image_url": raw.get("image") or raw.get("image_url"),
        "prep_time_min": raw.get("prep_time_min") or raw.get("prep_time_minutes"),
        "cook_time_min": raw.get("cook_time_min") or raw.get("cook_time_minutes"),
        "servings": raw.get("servings"),
        "meal_type": raw.get("meal_type"),
        "difficulty": raw.get("difficulty"),
    }


def normalize_payload(data: Any) -> dict:
    rows = data if isinstance(data, list) else (data.get("recipes", []) if isinstance(data, dict) else [])

    recipes = []
    parsed_ingredients = []
    for idx, item in enumerate(rows):
        if not isinstance(item, dict):
            continue
        r = normalize_recipe(item)
        if not r["title"]:
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


def _get_or_create_ingredient_id(client, name: str, counters: Counters) -> str | None:
    n = (name or "").strip()
    if not n:
        return None

    rows = (
        client.table("ingredients")
        .select("id,name_vi,calories_kcal,protein_g,carbs_g,fat_g")
        .ilike("name_vi", n)
        .limit(1)
        .execute()
        .data
        or []
    )
    if rows:
        found = rows[0]
        # Enrich existing ingredient if it still has empty nutrition.
        if float(found.get("calories_kcal") or 0) <= 0:
            nut = _lookup_food_nutrition(client, n)
            if nut is not None:
                client.table("ingredients").update(nut).eq("id", found["id"]).execute()
        return rows[0]["id"]

    nut = _lookup_food_nutrition(client, n) or {
        "calories_kcal": 0,
        "protein_g": 0,
        "carbs_g": 0,
        "fat_g": 0,
    }
    ins = client.table("ingredients").insert(
        {
            "name_vi": n,
            "calories_kcal": nut["calories_kcal"],
            "protein_g": nut["protein_g"],
            "carbs_g": nut["carbs_g"],
            "fat_g": nut["fat_g"],
            "category": "unknown",
        }
    ).execute().data or []

    if not ins:
        return None

    counters.ingredients_inserted += 1
    return ins[0]["id"]


def _to_float(value: Any) -> float:
    try:
        return float(value or 0)
    except Exception:
        return 0.0


def _lookup_food_nutrition(client, ingredient_name: str) -> dict[str, float] | None:
    q = (ingredient_name or "").strip()
    if not q:
        return None
    try:
        rows = (
            client.table("foods")
            .select("*")
            .ilike("name_vi", f"%{q}%")
            .limit(1)
            .execute()
            .data
            or []
        )
    except Exception:
        return None
    if not rows:
        return None
    r = rows[0]
    return {
        "calories_kcal": _to_float(r.get("calories_kcal")),
        "protein_g": _to_float(r.get("protein_g")),
        "carbs_g": _to_float(r.get("carbs_g")),
        "fat_g": _to_float(r.get("fat_g")),
    }


def _upsert_recipe(client, row: dict, counters: Counters) -> str | None:
    title = (row.get("title") or "").strip()
    if not title:
        return None

    payload = {
        "title": title,
        "description": row.get("description"),
        "instructions": row.get("instructions"),
        "prep_time_min": row.get("prep_time_min"),
        "cook_time_min": row.get("cook_time_min"),
        "total_time_min": _to_float(row.get("prep_time_min")) + _to_float(row.get("cook_time_min")),
        "servings": row.get("servings"),
        "image_url": row.get("image_url"),
        "meal_type": row.get("meal_type"),
        "difficulty": row.get("difficulty"),
    }

    existing = client.table("recipes").select("id,title").eq("title", title).limit(1).execute().data or []
    if existing:
        rid = existing[0]["id"]
        client.table("recipes").update(payload).eq("id", rid).execute()
        counters.recipes_updated += 1
        return rid

    created = client.table("recipes").insert(payload).execute().data or []
    if not created:
        return None

    counters.recipes_inserted += 1
    return created[0]["id"]


def ingest_normalized(normalized: dict) -> Counters:
    client = DatabaseProvider.get_client()
    if client is None:
        raise RuntimeError("PostgreSQL is not configured")

    recipes = normalized.get("recipes", [])
    parsed_ingredients = normalized.get("parsed_ingredients", [])
    counters = Counters()

    local_map: dict[str, str] = {}

    for r in recipes:
        local_id = str(r.get("_local_id") or "")
        rid = _upsert_recipe(client, r, counters)
        if not rid:
            counters.skipped += 1
            continue
        if local_id:
            local_map[local_id] = rid

    touched_recipe_ids: set[str] = set()
    for ing in parsed_ingredients:
        local_id = str(ing.get("recipe_local_id") or "")
        rid = local_map.get(local_id)
        if not rid:
            counters.skipped += 1
            continue

        iid = _get_or_create_ingredient_id(client, str(ing.get("ingredient_name") or ""), counters)
        if not iid:
            counters.skipped += 1
            continue

        amount_val = ing.get("quantity") if ing.get("quantity") is not None else 0
        unit_val = (ing.get("unit") or "unit").strip() or "unit"

        exists = (
            client.table("recipe_ingredients")
            .select("id")
            .eq("recipe_id", rid)
            .eq("ingredient_id", iid)
            .eq("quantity", amount_val)
            .eq("unit", unit_val)
            .limit(1)
            .execute()
            .data
            or []
        )
        if exists:
            continue

        client.table("recipe_ingredients").insert(
            {
                "recipe_id": rid,
                "ingredient_id": iid,
                "quantity": amount_val,
                "unit": unit_val,
            }
        ).execute()
        counters.recipe_links_inserted += 1
        touched_recipe_ids.add(rid)

    for rid in touched_recipe_ids:
        _recompute_recipe_nutrition(client, rid)

    return counters


def _recompute_recipe_nutrition(client, recipe_id: str) -> None:
    try:
        recipe_rows = (
            client.table("recipes").select("id,servings").eq("id", recipe_id).limit(1).execute().data or []
        )
        if not recipe_rows:
            return
        servings = max(_to_float(recipe_rows[0].get("servings")), 1.0)

        links = (
            client.table("recipe_ingredients")
            .select("ingredient_id,quantity")
            .eq("recipe_id", recipe_id)
            .execute()
            .data
            or []
        )
        if not links:
            return

        ing_ids = [x.get("ingredient_id") for x in links if x.get("ingredient_id")]
        if not ing_ids:
            return
        ingredients = (
            client.table("ingredients")
            .select("id,calories_kcal,protein_g,carbs_g,fat_g")
            .in_("id", ing_ids)
            .execute()
            .data
            or []
        )
        ing_map = {x["id"]: x for x in ingredients}

        total_kcal = 0.0
        total_p = 0.0
        total_c = 0.0
        total_f = 0.0
        for link in links:
            iid = link.get("ingredient_id")
            amount_g = _to_float(link.get("quantity"))
            if not iid or amount_g <= 0:
                continue
            ing = ing_map.get(iid)
            if not ing:
                continue
            factor = amount_g / 100.0
            total_kcal += factor * _to_float(ing.get("calories_kcal"))
            total_p += factor * _to_float(ing.get("protein_g"))
            total_c += factor * _to_float(ing.get("carbs_g"))
            total_f += factor * _to_float(ing.get("fat_g"))

        client.table("recipes").update(
            {
                "calories_kcal": round(total_kcal / servings, 1),
                "protein_g": round(total_p / servings, 1),
                "carbs_g": round(total_c / servings, 1),
                "fat_g": round(total_f / servings, 1),
            }
        ).eq("id", recipe_id).execute()
    except Exception:
        # Keep ingest resilient; do not fail whole batch because one nutrition update failed.
        return
