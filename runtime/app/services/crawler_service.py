from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

from app.core.supabase_provider import SupabaseProvider


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


def normalize_payload(data: Any) -> dict:
    rows = data if isinstance(data, list) else (data.get("recipes", []) if isinstance(data, dict) else [])

    recipes = []
    parsed_ingredients = []
    for idx, item in enumerate(rows):
        if not isinstance(item, dict):
            continue
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


def _get_or_create_ingredient_id(client, name: str, counters: Counters) -> str | None:
    n = (name or "").strip()
    if not n:
        return None

    rows = (
        client.table("ingredients")
        .select("id,name,calories_per_100g,protein_per_100g,carbs_per_100g,fat_per_100g,fiber_per_100g")
        .ilike("name", n)
        .limit(1)
        .execute()
        .data
        or []
    )
    if rows:
        found = rows[0]
        # Enrich existing ingredient if it still has empty nutrition.
        if float(found.get("calories_per_100g") or 0) <= 0:
            nut = _lookup_food_nutrition(client, n)
            if nut is not None:
                client.table("ingredients").update(nut).eq("id", found["id"]).execute()
        return rows[0]["id"]

    nut = _lookup_food_nutrition(client, n) or {
        "calories_per_100g": 0,
        "protein_per_100g": 0,
        "carbs_per_100g": 0,
        "fat_per_100g": 0,
        "fiber_per_100g": 0,
    }
    ins = client.table("ingredients").insert(
        {
            "name": n,
            "calories_per_100g": nut["calories_per_100g"],
            "protein_per_100g": nut["protein_per_100g"],
            "carbs_per_100g": nut["carbs_per_100g"],
            "fat_per_100g": nut["fat_per_100g"],
            "fiber_per_100g": nut["fiber_per_100g"],
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
            .ilike("name", f"%{q}%")
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
        "calories_per_100g": _to_float(r.get("calories_kcal_per_100g", r.get("calories_kcal"))),
        "protein_per_100g": _to_float(r.get("protein_g_per_100g", r.get("protein_g"))),
        "carbs_per_100g": _to_float(r.get("carbs_g_per_100g", r.get("carbs_g"))),
        "fat_per_100g": _to_float(r.get("fat_g_per_100g", r.get("fat_g"))),
        "fiber_per_100g": _to_float(r.get("fiber_g_per_100g", r.get("fiber_g"))),
    }


def _upsert_recipe(client, row: dict, counters: Counters) -> str | None:
    name = (row.get("name") or "").strip()
    if not name:
        return None

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

    existing = client.table("recipes").select("id,name").eq("name", name).limit(1).execute().data or []
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
    client = SupabaseProvider.get_client()
    if client is None:
        raise RuntimeError("Supabase is not configured")

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
            .eq("amount", amount_val)
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
                "amount": amount_val,
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
            .select("ingredient_id,amount")
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
            .select("id,calories_per_100g,protein_per_100g,carbs_per_100g,fat_per_100g")
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
            amount_g = _to_float(link.get("amount"))
            if not iid or amount_g <= 0:
                continue
            ing = ing_map.get(iid)
            if not ing:
                continue
            factor = amount_g / 100.0
            total_kcal += factor * _to_float(ing.get("calories_per_100g"))
            total_p += factor * _to_float(ing.get("protein_per_100g"))
            total_c += factor * _to_float(ing.get("carbs_per_100g"))
            total_f += factor * _to_float(ing.get("fat_per_100g"))

        client.table("recipes").update(
            {
                "calories_per_serving": round(total_kcal / servings, 1),
                "protein_per_serving": round(total_p / servings, 1),
                "carbs_per_serving": round(total_c / servings, 1),
                "fat_per_serving": round(total_f / servings, 1),
            }
        ).eq("id", recipe_id).execute()
    except Exception:
        # Keep ingest resilient; do not fail whole batch because one nutrition update failed.
        return
