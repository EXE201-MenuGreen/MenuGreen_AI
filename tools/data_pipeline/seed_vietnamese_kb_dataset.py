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


DISHES: list[dict] = [
    {"name": "Phở bò", "category": "noodle", "ingredients": ["bánh phở", "thịt bò", "hành", "gừng", "quế", "hoa hồi"], "protein": 28, "carbs": 45, "fat": 8, "calories": 380, "method": "boiled", "difficulty": "medium", "region": "north", "meal_type": "breakfast", "cost": 50000},
    {"name": "Phở gà", "category": "noodle", "ingredients": ["bánh phở", "thịt gà", "hành", "gừng", "rau thơm"], "protein": 25, "carbs": 43, "fat": 7, "calories": 350, "method": "boiled", "difficulty": "medium", "region": "north", "meal_type": "breakfast", "cost": 45000},
    {"name": "Bún bò Huế", "category": "noodle", "ingredients": ["bún", "thịt bò", "sả", "mắm ruốc", "rau sống"], "protein": 30, "carbs": 55, "fat": 14, "calories": 520, "method": "boiled", "difficulty": "hard", "region": "central", "meal_type": "breakfast", "cost": 55000},
    {"name": "Bún riêu", "category": "noodle", "ingredients": ["bún", "cua đồng", "cà chua", "đậu hũ", "rau sống"], "protein": 22, "carbs": 50, "fat": 10, "calories": 430, "method": "boiled", "difficulty": "medium", "region": "north", "meal_type": "lunch", "cost": 45000},
    {"name": "Hủ tiếu Nam Vang", "category": "noodle", "ingredients": ["hủ tiếu", "tôm", "thịt heo", "trứng cút", "hẹ"], "protein": 29, "carbs": 58, "fat": 11, "calories": 500, "method": "boiled", "difficulty": "medium", "region": "south", "meal_type": "breakfast", "cost": 55000},
    {"name": "Mì Quảng", "category": "noodle", "ingredients": ["mì quảng", "thịt gà", "tôm", "đậu phộng", "rau sống"], "protein": 31, "carbs": 60, "fat": 16, "calories": 560, "method": "boiled", "difficulty": "medium", "region": "central", "meal_type": "lunch", "cost": 55000},
    {"name": "Bánh canh cua", "category": "noodle", "ingredients": ["bánh canh", "cua", "tôm", "nấm rơm", "hành lá"], "protein": 27, "carbs": 52, "fat": 9, "calories": 440, "method": "boiled", "difficulty": "medium", "region": "south", "meal_type": "lunch", "cost": 60000},
    {"name": "Bún mắm", "category": "noodle", "ingredients": ["bún", "mắm cá", "tôm", "cá", "rau sống"], "protein": 32, "carbs": 54, "fat": 12, "calories": 520, "method": "boiled", "difficulty": "hard", "region": "south", "meal_type": "lunch", "cost": 60000},
    {"name": "Bún cá", "category": "noodle", "ingredients": ["bún", "cá", "cà chua", "thì là", "rau sống"], "protein": 27, "carbs": 50, "fat": 8, "calories": 430, "method": "boiled", "difficulty": "medium", "region": "north", "meal_type": "lunch", "cost": 45000},
    {"name": "Bún mọc", "category": "noodle", "ingredients": ["bún", "mọc heo", "nấm mèo", "hành", "rau sống"], "protein": 24, "carbs": 52, "fat": 10, "calories": 450, "method": "boiled", "difficulty": "medium", "region": "north", "meal_type": "breakfast", "cost": 42000},
    {"name": "Bún thang", "category": "noodle", "ingredients": ["bún", "gà xé", "trứng", "giò lụa", "nấm hương"], "protein": 26, "carbs": 50, "fat": 9, "calories": 430, "method": "boiled", "difficulty": "hard", "region": "north", "meal_type": "breakfast", "cost": 55000},
    {"name": "Cháo gà", "category": "porridge", "ingredients": ["gạo", "thịt gà", "gừng", "hành", "tiêu"], "protein": 22, "carbs": 46, "fat": 6, "calories": 350, "method": "boiled", "difficulty": "easy", "region": "north", "meal_type": "breakfast", "cost": 35000},
    {"name": "Cháo lòng", "category": "porridge", "ingredients": ["gạo", "lòng heo", "hành", "gừng", "giá"], "protein": 23, "carbs": 45, "fat": 12, "calories": 430, "method": "boiled", "difficulty": "medium", "region": "south", "meal_type": "breakfast", "cost": 40000},
    {"name": "Cơm tấm", "category": "rice", "ingredients": ["cơm tấm", "sườn heo", "trứng", "bì", "nước mắm"], "protein": 35, "carbs": 75, "fat": 22, "calories": 720, "method": "grilled", "difficulty": "medium", "region": "south", "meal_type": "lunch", "cost": 55000},
    {"name": "Cơm gà", "category": "rice", "ingredients": ["cơm", "thịt gà", "dưa leo", "rau răm", "nước mắm gừng"], "protein": 34, "carbs": 65, "fat": 14, "calories": 560, "method": "boiled", "difficulty": "medium", "region": "central", "meal_type": "lunch", "cost": 50000},
    {"name": "Cơm chiên dương châu", "category": "rice", "ingredients": ["cơm", "trứng", "tôm", "lạp xưởng", "đậu Hà Lan"], "protein": 24, "carbs": 70, "fat": 18, "calories": 620, "method": "stir_fried", "difficulty": "easy", "region": "south", "meal_type": "lunch", "cost": 45000},
    {"name": "Cơm bò lúc lắc", "category": "rice", "ingredients": ["cơm", "thịt bò", "ớt chuông", "hành tây", "xà lách"], "protein": 38, "carbs": 68, "fat": 18, "calories": 650, "method": "stir_fried", "difficulty": "medium", "region": "south", "meal_type": "dinner", "cost": 75000},
    {"name": "Cơm cá kho", "category": "rice", "ingredients": ["cơm", "cá", "nước mắm", "tiêu", "hành"], "protein": 30, "carbs": 66, "fat": 12, "calories": 560, "method": "braised", "difficulty": "medium", "region": "south", "meal_type": "lunch", "cost": 50000},
    {"name": "Cơm thịt kho trứng", "category": "rice", "ingredients": ["cơm", "thịt heo", "trứng", "nước dừa", "nước mắm"], "protein": 32, "carbs": 68, "fat": 24, "calories": 720, "method": "braised", "difficulty": "medium", "region": "south", "meal_type": "dinner", "cost": 55000},
    {"name": "Cá kho tộ", "category": "braised", "ingredients": ["cá", "nước mắm", "tiêu", "hành", "ớt"], "protein": 32, "carbs": 8, "fat": 14, "calories": 310, "method": "braised", "difficulty": "medium", "region": "south", "meal_type": "dinner", "cost": 60000},
    {"name": "Thịt kho tàu", "category": "braised", "ingredients": ["thịt heo", "trứng", "nước dừa", "nước mắm", "hành"], "protein": 30, "carbs": 10, "fat": 32, "calories": 470, "method": "braised", "difficulty": "medium", "region": "south", "meal_type": "dinner", "cost": 60000},
    {"name": "Cá basa kho tiêu", "category": "braised", "ingredients": ["cá basa", "tiêu", "nước mắm", "hành", "ớt"], "protein": 28, "carbs": 6, "fat": 12, "calories": 270, "method": "braised", "difficulty": "easy", "region": "south", "meal_type": "dinner", "cost": 45000},
    {"name": "Gà kho gừng", "category": "braised", "ingredients": ["thịt gà", "gừng", "nước mắm", "hành", "tiêu"], "protein": 33, "carbs": 7, "fat": 13, "calories": 310, "method": "braised", "difficulty": "easy", "region": "south", "meal_type": "dinner", "cost": 50000},
    {"name": "Rau muống xào tỏi", "category": "stir_fried", "ingredients": ["rau muống", "tỏi", "dầu ăn"], "protein": 5, "carbs": 12, "fat": 8, "calories": 150, "method": "stir_fried", "difficulty": "easy", "region": "north", "meal_type": "dinner", "cost": 20000},
    {"name": "Bò xào cần tây", "category": "stir_fried", "ingredients": ["thịt bò", "cần tây", "hành tây", "tỏi"], "protein": 35, "carbs": 12, "fat": 14, "calories": 350, "method": "stir_fried", "difficulty": "easy", "region": "south", "meal_type": "dinner", "cost": 70000},
    {"name": "Mực xào chua ngọt", "category": "stir_fried", "ingredients": ["mực", "dứa", "cà chua", "ớt chuông", "hành tây"], "protein": 30, "carbs": 18, "fat": 9, "calories": 320, "method": "stir_fried", "difficulty": "medium", "region": "central", "meal_type": "dinner", "cost": 80000},
    {"name": "Tôm xào rau củ", "category": "stir_fried", "ingredients": ["tôm", "bông cải", "cà rốt", "đậu Hà Lan"], "protein": 30, "carbs": 20, "fat": 8, "calories": 330, "method": "stir_fried", "difficulty": "easy", "region": "south", "meal_type": "dinner", "cost": 75000},
    {"name": "Đậu hũ xào nấm", "category": "stir_fried", "ingredients": ["đậu hũ", "nấm", "hành", "tỏi"], "protein": 18, "carbs": 16, "fat": 12, "calories": 290, "method": "stir_fried", "difficulty": "easy", "region": "south", "meal_type": "dinner", "cost": 35000},
    {"name": "Gỏi cuốn", "category": "roll", "ingredients": ["bánh tráng", "tôm", "thịt heo", "bún", "rau sống"], "protein": 22, "carbs": 38, "fat": 7, "calories": 320, "method": "rolled", "difficulty": "easy", "region": "south", "meal_type": "snack", "cost": 35000},
    {"name": "Bò bía", "category": "roll", "ingredients": ["bánh tráng", "lạp xưởng", "trứng", "củ sắn", "rau"], "protein": 16, "carbs": 42, "fat": 12, "calories": 380, "method": "rolled", "difficulty": "easy", "region": "south", "meal_type": "snack", "cost": 30000},
    {"name": "Chả giò", "category": "fried", "ingredients": ["bánh tráng", "thịt heo", "miến", "nấm mèo", "cà rốt"], "protein": 18, "carbs": 35, "fat": 20, "calories": 430, "method": "fried", "difficulty": "medium", "region": "south", "meal_type": "snack", "cost": 40000},
    {"name": "Bánh mì thịt", "category": "bread", "ingredients": ["bánh mì", "thịt heo", "pate", "dưa leo", "đồ chua"], "protein": 24, "carbs": 55, "fat": 18, "calories": 520, "method": "assembled", "difficulty": "easy", "region": "south", "meal_type": "breakfast", "cost": 30000},
    {"name": "Bánh xèo", "category": "cake", "ingredients": ["bột gạo", "tôm", "thịt heo", "giá", "rau sống"], "protein": 22, "carbs": 48, "fat": 22, "calories": 560, "method": "pan_fried", "difficulty": "medium", "region": "south", "meal_type": "dinner", "cost": 45000},
    {"name": "Bánh khọt", "category": "cake", "ingredients": ["bột gạo", "tôm", "nước cốt dừa", "hành lá"], "protein": 18, "carbs": 42, "fat": 20, "calories": 490, "method": "pan_fried", "difficulty": "medium", "region": "south", "meal_type": "snack", "cost": 40000},
    {"name": "Bánh cuốn", "category": "cake", "ingredients": ["bột gạo", "thịt heo", "nấm mèo", "hành phi"], "protein": 18, "carbs": 50, "fat": 10, "calories": 390, "method": "steamed", "difficulty": "medium", "region": "north", "meal_type": "breakfast", "cost": 35000},
    {"name": "Bánh bèo", "category": "cake", "ingredients": ["bột gạo", "tôm khô", "hành phi", "nước mắm"], "protein": 10, "carbs": 45, "fat": 9, "calories": 330, "method": "steamed", "difficulty": "medium", "region": "central", "meal_type": "snack", "cost": 30000},
    {"name": "Bánh bột lọc", "category": "cake", "ingredients": ["bột năng", "tôm", "thịt heo", "nước mắm"], "protein": 16, "carbs": 48, "fat": 8, "calories": 360, "method": "boiled", "difficulty": "medium", "region": "central", "meal_type": "snack", "cost": 35000},
    {"name": "Cao lầu", "category": "regional", "ingredients": ["mì cao lầu", "thịt heo", "rau sống", "bánh đa"], "protein": 28, "carbs": 58, "fat": 16, "calories": 540, "method": "mixed", "difficulty": "medium", "region": "central", "meal_type": "lunch", "cost": 55000},
    {"name": "Cơm hến", "category": "regional", "ingredients": ["cơm", "hến", "rau thơm", "đậu phộng", "mắm ruốc"], "protein": 20, "carbs": 60, "fat": 12, "calories": 460, "method": "mixed", "difficulty": "medium", "region": "central", "meal_type": "lunch", "cost": 40000},
    {"name": "Lẩu cá kèo", "category": "hotpot", "ingredients": ["cá kèo", "rau đắng", "bún", "nước lẩu"], "protein": 30, "carbs": 45, "fat": 10, "calories": 450, "method": "hotpot", "difficulty": "medium", "region": "south", "meal_type": "dinner", "cost": 90000},
    {"name": "Bánh tằm bì", "category": "regional", "ingredients": ["bánh tằm", "bì heo", "nước cốt dừa", "rau sống"], "protein": 18, "carbs": 62, "fat": 18, "calories": 560, "method": "mixed", "difficulty": "medium", "region": "south", "meal_type": "lunch", "cost": 45000},
    {"name": "Bánh cống", "category": "fried", "ingredients": ["bột gạo", "đậu xanh", "tôm", "thịt heo"], "protein": 20, "carbs": 50, "fat": 22, "calories": 560, "method": "fried", "difficulty": "medium", "region": "south", "meal_type": "snack", "cost": 35000},
    {"name": "Bánh đa cua", "category": "noodle", "ingredients": ["bánh đa", "cua đồng", "rau muống", "chả lá lốt"], "protein": 25, "carbs": 55, "fat": 12, "calories": 480, "method": "boiled", "difficulty": "medium", "region": "north", "meal_type": "breakfast", "cost": 45000},
    {"name": "Nem nướng Nha Trang", "category": "grilled", "ingredients": ["nem nướng", "bánh tráng", "rau sống", "nước chấm"], "protein": 25, "carbs": 44, "fat": 18, "calories": 500, "method": "grilled", "difficulty": "medium", "region": "central", "meal_type": "dinner", "cost": 55000},
    {"name": "Bún chả", "category": "noodle", "ingredients": ["bún", "thịt heo nướng", "nước mắm", "rau sống"], "protein": 30, "carbs": 58, "fat": 20, "calories": 620, "method": "grilled", "difficulty": "medium", "region": "north", "meal_type": "lunch", "cost": 55000},
]

VARIANTS = [
    {"suffix": "ít dầu", "kcal": 0.92, "fat": 0.75, "cost": 1.0, "note": "giảm dầu khi chế biến"},
    {"suffix": "nhiều đạm", "kcal": 1.08, "protein": 1.25, "cost": 1.12, "note": "tăng phần thịt/cá/đậu"},
    {"suffix": "ít tinh bột", "kcal": 0.86, "carbs": 0.65, "cost": 0.95, "note": "giảm bún/cơm/bánh"},
    {"suffix": "nhiều rau", "kcal": 0.96, "carbs": 0.9, "cost": 1.03, "note": "tăng rau ăn kèm"},
    {"suffix": "phần nhỏ", "kcal": 0.72, "protein": 0.78, "carbs": 0.72, "fat": 0.72, "cost": 0.75, "note": "khẩu phần nhỏ"},
    {"suffix": "phần lớn", "kcal": 1.25, "protein": 1.2, "carbs": 1.25, "fat": 1.18, "cost": 1.25, "note": "khẩu phần lớn"},
    {"suffix": "healthy", "kcal": 0.9, "protein": 1.05, "carbs": 0.82, "fat": 0.7, "cost": 1.08, "note": "ưu tiên ít dầu, ít đường"},
    {"suffix": "tiết kiệm", "kcal": 0.95, "cost": 0.78, "note": "chọn nguyên liệu phổ thông"},
]


def stable_uuid(namespace: str, value: str) -> str:
    root = uuid.uuid5(uuid.NAMESPACE_URL, "menugreen-vietnamese-kb")
    return str(uuid.uuid5(root, f"{namespace}:{value}"))


def chunked(items: list[dict], size: int):
    for index in range(0, len(items), size):
        yield items[index : index + size]


def scaled(value: float, variant: dict, key: str) -> float:
    return round(value * float(variant.get(key, variant.get("kcal", 1.0))), 2)


def unique_ingredients() -> list[str]:
    names: set[str] = set()
    for dish in DISHES:
        names.update(dish["ingredients"])
    return sorted(names)


def seed_ingredients(client: PostgresProvider) -> dict[str, str]:
    rows = []
    for name in unique_ingredients():
        rows.append(
            {
                "id": stable_uuid("ingredient", name),
                "name_vi": name,
                "name_en": None,
                "category": "vietnamese_food_component",
                "calories_kcal": None,
                "protein_g": None,
                "carbs_g": None,
                "fat_g": None,
                "estimated_price_vnd": None,
                "unit_default": "g",
                "is_active": True,
            }
        )
    for batch in chunked(rows, 500):
        client.table("ingredients").upsert(batch, on_conflict="id").execute()
    return {row["name_vi"]: row["id"] for row in rows}


def make_title(dish: dict, variant: dict, cycle: int) -> str:
    if cycle == 0:
        return f"{dish['name']} {variant['suffix']}"
    return f"{dish['name']} {variant['suffix']} kiểu {cycle + 1}"


def build_rows(count: int, ingredient_ids: dict[str, str]) -> tuple[list[dict], list[dict], list[dict]]:
    foods: list[dict] = []
    recipes: list[dict] = []
    links: list[dict] = []
    total_patterns = len(DISHES) * len(VARIANTS)
    random.seed(20260529)

    for index in range(count):
        dish = DISHES[index % len(DISHES)]
        variant = VARIANTS[(index // len(DISHES)) % len(VARIANTS)]
        cycle = index // total_patterns
        title = make_title(dish, variant, cycle)
        slug = f"{dish['name']}:{variant['suffix']}:{cycle}"
        food_id = stable_uuid("food", slug)
        recipe_id = stable_uuid("recipe", slug)
        calories = scaled(float(dish["calories"]), variant, "kcal")
        protein = scaled(float(dish["protein"]), variant, "protein")
        carbs = scaled(float(dish["carbs"]), variant, "carbs")
        fat = scaled(float(dish["fat"]), variant, "fat")
        cost = max(12000, int(float(dish["cost"]) * float(variant.get("cost", 1.0))))
        prep = random.choice([8, 10, 12, 15, 18])
        cook = random.choice([12, 15, 20, 25, 30])
        ingredient_text = ", ".join(dish["ingredients"][:5])

        foods.append(
            {
                "id": food_id,
                "name_vi": title,
                "name_en": None,
                "category": dish["category"],
                "description": f"Món Việt vùng {dish['region']}, phù hợp bữa {dish['meal_type']}. Biến thể {variant['note']}.",
                "calories_kcal": calories,
                "protein_g": protein,
                "carbs_g": carbs,
                "fat_g": fat,
                "fiber_g": round(max(2.0, carbs * 0.06), 2),
                "estimated_price_vnd": cost,
                "default_serving_g": random.choice([300, 350, 400, 450, 500]),
                "is_active": True,
            }
        )
        recipes.append(
            {
                "id": recipe_id,
                "food_id": food_id,
                "title": title,
                "description": f"Công thức {title.lower()} từ nền món {dish['name']}. Nguyên liệu chính: {ingredient_text}.",
                "prep_time_min": prep,
                "cook_time_min": cook,
                "total_time_min": prep + cook,
                "servings": 1,
                "difficulty": dish["difficulty"],
                "meal_type": dish["meal_type"],
                "estimated_price_vnd": cost,
                "instructions": [
                    f"Chuẩn bị nguyên liệu: {ingredient_text}.",
                    f"Sơ chế sạch, cắt vừa ăn; áp dụng biến thể {variant['note']}.",
                    f"Chế biến theo phương pháp {dish['method']} trong khoảng {cook} phút.",
                    "Nêm vừa ăn, ưu tiên kiểm soát dầu, đường và muối theo mục tiêu dinh dưỡng.",
                ],
                "is_active": True,
            }
        )
        portion = round(100 / max(len(dish["ingredients"]), 1), 2)
        for ingredient in dish["ingredients"]:
            links.append(
                {
                    "id": stable_uuid("recipe_ingredient", f"{slug}:{ingredient}"),
                    "recipe_id": recipe_id,
                    "ingredient_id": ingredient_ids[ingredient],
                    "quantity": portion,
                    "unit": "g",
                    "notes": "Vietnamese KB generated dataset",
                }
            )
    return foods, recipes, links


def run(count: int, batch_size: int, export: Path | None) -> None:
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

    if export:
        import json

        export.parent.mkdir(parents=True, exist_ok=True)
        export.write_text(
            json.dumps({"foods": foods, "recipes": recipes, "recipe_ingredients": links}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(f"Exported JSON: {export}")

    elapsed = (datetime.now(timezone.utc) - started).total_seconds()
    print(f"Seeded Vietnamese KB: {len(foods)} foods, {len(recipes)} recipes, {len(links)} links in {elapsed:.1f}s")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Seed Vietnamese food KB + generated variants into PostgreSQL.")
    parser.add_argument("--count", type=int, default=50_000, help="Number of food+recipe variants.")
    parser.add_argument("--batch-size", type=int, default=1000, help="Rows per PostgreSQL upsert batch.")
    parser.add_argument("--export", type=Path, default=None, help="Optional JSON export path.")
    args = parser.parse_args()
    run(count=max(1, args.count), batch_size=max(100, args.batch_size), export=args.export)
