from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path
import random
import sys
import uuid

from config import get_settings


RUNTIME_PATH = Path(__file__).resolve().parents[2] / "runtime"
sys.path.insert(0, str(RUNTIME_PATH))

from app.core.postgres_provider import PostgresProvider  # noqa: E402


PROTEINS = [
    ("ức gà", "chicken breast", 165, 31, 0, 3.6, 25000),
    ("đùi gà", "chicken thigh", 209, 26, 0, 10.9, 32000),
    ("thịt bò nạc", "lean beef", 217, 26, 0, 12, 85000),
    ("cá hồi", "salmon", 208, 20, 0, 13, 180000),
    ("cá basa", "basa fish", 120, 18, 0, 4, 55000),
    ("tôm", "shrimp", 99, 24, 0.2, 0.3, 120000),
    ("trứng gà", "egg", 155, 13, 1.1, 11, 30000),
    ("đậu hũ", "tofu", 76, 8, 1.9, 4.8, 18000),
    ("thịt heo nạc", "lean pork", 242, 27, 0, 14, 70000),
    ("cá ngừ", "tuna", 132, 28, 0, 1, 95000),
]

CARBS = [
    ("gạo trắng", "white rice", 130, 2.7, 28, 0.3, 18000),
    ("gạo lứt", "brown rice", 111, 2.6, 23, 0.9, 28000),
    ("bún", "rice vermicelli", 110, 1.8, 25, 0.2, 16000),
    ("phở", "pho noodle", 120, 2.2, 26, 0.4, 18000),
    ("khoai lang", "sweet potato", 86, 1.6, 20, 0.1, 22000),
    ("yến mạch", "oats", 389, 17, 66, 7, 65000),
    ("bánh mì", "bread", 265, 9, 49, 3.2, 25000),
    ("miến", "glass noodle", 351, 0.2, 86, 0.1, 30000),
]

VEGGIES = [
    ("cải thìa", "bok choy", 13, 1.5, 2.2, 0.2, 18000),
    ("bông cải xanh", "broccoli", 34, 2.8, 7, 0.4, 45000),
    ("rau xà lách", "lettuce", 15, 1.4, 2.9, 0.2, 12000),
    ("cà chua", "tomato", 18, 0.9, 3.9, 0.2, 18000),
    ("dưa leo", "cucumber", 16, 0.7, 3.6, 0.1, 16000),
    ("cà rốt", "carrot", 41, 0.9, 10, 0.2, 22000),
    ("bí đỏ", "pumpkin", 26, 1, 6.5, 0.1, 20000),
    ("rau muống", "water spinach", 19, 2.6, 3.1, 0.2, 12000),
]

METHODS = [
    ("áp chảo", "pan_seared", 5, 12),
    ("luộc", "boiled", 5, 15),
    ("hấp", "steamed", 8, 18),
    ("nướng", "grilled", 10, 25),
    ("xào ít dầu", "stir_fried", 8, 12),
    ("sốt cà", "tomato_sauce", 10, 20),
    ("kho tiêu", "pepper_braised", 10, 25),
    ("trộn salad", "salad", 12, 5),
]

MEAL_TYPES = ["breakfast", "lunch", "dinner", "snack"]
DIFFICULTIES = ["easy", "medium"]


def stable_uuid(namespace: str, value: str) -> str:
    return str(uuid.uuid5(uuid.uuid5(uuid.NAMESPACE_URL, "menugreen-large-seed"), f"{namespace}:{value}"))


def chunked(items: list[dict], size: int):
    for index in range(0, len(items), size):
        yield items[index : index + size]


def macro_for(items: list[tuple], quantities: list[float]) -> tuple[float, float, float, float]:
    kcal = protein = carbs = fat = 0.0
    for item, grams in zip(items, quantities):
        factor = grams / 100.0
        kcal += item[2] * factor
        protein += item[3] * factor
        carbs += item[4] * factor
        fat += item[5] * factor
    return round(kcal, 2), round(protein, 2), round(carbs, 2), round(fat, 2)


def seed_ingredients(client: PostgresProvider) -> dict[str, str]:
    rows = []
    for category, source in [("protein", PROTEINS), ("carb", CARBS), ("vegetable", VEGGIES)]:
        for name_vi, name_en, kcal, protein, carbs, fat, price in source:
            rows.append(
                {
                    "id": stable_uuid("ingredient", name_vi),
                    "name_vi": name_vi,
                    "name_en": name_en,
                    "category": category,
                    "calories_kcal": kcal,
                    "protein_g": protein,
                    "carbs_g": carbs,
                    "fat_g": fat,
                    "estimated_price_vnd": price,
                    "unit_default": "g",
                    "is_active": True,
                }
            )
    for batch in chunked(rows, 200):
        client.table("ingredients").upsert(batch, on_conflict="id").execute()
    return {row["name_vi"]: row["id"] for row in rows}


def build_rows(count: int, ingredient_ids: dict[str, str]) -> tuple[list[dict], list[dict], list[dict]]:
    foods: list[dict] = []
    recipes: list[dict] = []
    links: list[dict] = []
    random.seed(42)
    combinations = []
    for protein in PROTEINS:
        for carb in CARBS:
            for veggie in VEGGIES:
                for method in METHODS:
                    combinations.append((protein, carb, veggie, method))

    for index in range(count):
        protein, carb, veggie, method = combinations[index % len(combinations)]
        variant = index // len(combinations) + 1
        protein_g = random.choice([120, 150, 180, 200, 220])
        carb_g = random.choice([120, 150, 180, 220, 250])
        veggie_g = random.choice([80, 100, 120, 150, 180])
        kcal, p, c, f = macro_for([protein, carb, veggie], [protein_g, carb_g, veggie_g])
        method_vi, method_key, prep, cook = method
        meal_type = MEAL_TYPES[index % len(MEAL_TYPES)]
        difficulty = DIFFICULTIES[index % len(DIFFICULTIES)]
        base_title = f"{protein[0].capitalize()} {method_vi} với {carb[0]} và {veggie[0]}"
        title = base_title if variant == 1 else f"{base_title} phiên bản {variant}"
        slug = f"{protein[1]}-{method_key}-{carb[1]}-{veggie[1]}-{variant}".replace(" ", "-")
        food_id = stable_uuid("food", slug)
        recipe_id = stable_uuid("recipe", slug)
        price = int((protein[6] * protein_g + carb[6] * carb_g + veggie[6] * veggie_g) / 1000)

        foods.append(
            {
                "id": food_id,
                "name_vi": title,
                "name_en": title,
                "category": meal_type,
                "description": f"Món {meal_type} giàu dinh dưỡng, gồm {protein[0]}, {carb[0]} và {veggie[0]}.",
                "calories_kcal": kcal,
                "protein_g": p,
                "carbs_g": c,
                "fat_g": f,
                "fiber_g": round(veggie_g / 100 * 2.5 + carb_g / 100 * 1.2, 2),
                "estimated_price_vnd": max(price, 12000),
                "default_serving_g": int(protein_g + carb_g + veggie_g),
                "is_active": True,
            }
        )
        recipes.append(
            {
                "id": recipe_id,
                "food_id": food_id,
                "title": title,
                "description": f"Công thức {title.lower()} tối ưu cho bữa {meal_type}.",
                "prep_time_min": prep,
                "cook_time_min": cook,
                "total_time_min": prep + cook,
                "servings": 1,
                "difficulty": difficulty,
                "meal_type": meal_type,
                "estimated_price_vnd": max(price, 12000),
                "instructions": [
                    f"Sơ chế {protein[0]} và ướp nhẹ với muối tiêu.",
                    f"Chuẩn bị {carb[0]} và {veggie[0]} theo khẩu phần.",
                    f"Chế biến kiểu {method_vi} trong khoảng {cook} phút.",
                    "Nêm lại vừa ăn, ưu tiên ít dầu và ít đường.",
                ],
                "is_active": True,
            }
        )
        for ingredient, quantity in [(protein, protein_g), (carb, carb_g), (veggie, veggie_g)]:
            links.append(
                {
                    "id": stable_uuid("recipe_ingredient", f"{slug}:{ingredient[0]}"),
                    "recipe_id": recipe_id,
                    "ingredient_id": ingredient_ids[ingredient[0]],
                    "quantity": quantity,
                    "unit": "g",
                    "notes": "Generated demo nutrition dataset",
                }
            )
    return foods, recipes, links


def run(count: int, batch_size: int) -> None:
    settings = get_settings()
    postgres_url = settings.postgres_url.strip()
    if postgres_url.startswith("POSTGRES_URL="):
        postgres_url = postgres_url.split("=", 1)[1].strip()
    if not postgres_url:
        raise RuntimeError("POSTGRES_URL is missing")
    client = PostgresProvider(postgres_url)

    started = datetime.now(timezone.utc)
    ingredient_ids = seed_ingredients(client)
    foods, recipes, links = build_rows(count, ingredient_ids)
    for label, table, rows in [
        ("foods", "foods", foods),
        ("recipes", "recipes", recipes),
        ("recipe_ingredients", "recipe_ingredients", links),
    ]:
        written = 0
        for batch in chunked(rows, batch_size):
            client.table(table).upsert(batch, on_conflict="id").execute()
            written += len(batch)
            print(f"{label}: {written}/{len(rows)}")
    elapsed = (datetime.now(timezone.utc) - started).total_seconds()
    print(f"Seeded {len(foods)} foods, {len(recipes)} recipes, {len(links)} recipe links in {elapsed:.1f}s")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate a large PostgreSQL food/recipe dataset.")
    parser.add_argument("--count", type=int, default=100_000, help="Number of food+recipe pairs to generate.")
    parser.add_argument("--batch-size", type=int, default=1000, help="Rows per PostgreSQL upsert batch.")
    args = parser.parse_args()
    run(count=max(1, args.count), batch_size=max(100, args.batch_size))
