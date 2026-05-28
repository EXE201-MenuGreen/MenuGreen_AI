import argparse
import csv

from db import get_client
from config import get_settings


def to_int(value, default=0):
    try:
        return int(float(value))
    except Exception:
        return default


def to_float(value, default=0.0):
    try:
        return float(value)
    except Exception:
        return default


def parse_instructions(value: str):
    raw = (value or "").strip()
    if not raw:
        return []
    return [line.strip() for line in raw.replace("|", "\n").splitlines() if line.strip()]


def run(csv_path: str):
    settings = get_settings()
    client = get_client()

    rows = []
    with open(csv_path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            title = (r.get("title") or r.get("name") or "").strip()
            if not title:
                continue
            rows.append(
                {
                    "title": title,
                    "description": (r.get("description") or "").strip() or None,
                    "instructions": parse_instructions(r.get("instructions") or ""),
                    "prep_time_min": to_int(r.get("prep_time_min") or r.get("prep_time_minutes"), 0) or None,
                    "cook_time_min": to_int(r.get("cook_time_min") or r.get("cook_time_minutes"), 0) or None,
                    "total_time_min": to_int(r.get("total_time_min"), 0) or None,
                    "servings": to_int(r.get("servings"), 0) or None,
                    "difficulty": (r.get("difficulty") or "").strip() or None,
                    "meal_type": (r.get("meal_type") or "").strip() or None,
                    "estimated_price_vnd": to_int(r.get("estimated_price_vnd"), 0) or None,
                    "image_url": (r.get("image_url") or "").strip() or None,
                    "calories_kcal": to_float(r.get("calories_kcal") or r.get("calories_per_serving"), 0.0) or None,
                    "protein_g": to_float(r.get("protein_g") or r.get("protein_per_serving"), 0.0) or None,
                    "carbs_g": to_float(r.get("carbs_g") or r.get("carbs_per_serving"), 0.0) or None,
                    "fat_g": to_float(r.get("fat_g") or r.get("fat_per_serving"), 0.0) or None,
                }
            )

    if not rows:
        print("No valid recipe rows")
        return

    written = 0
    for row in rows:
        existing = (
            client.table(settings.recipes_table)
            .select("id")
            .eq("title", row["title"])
            .limit(1)
            .execute()
            .data
            or []
        )
        if existing:
            client.table(settings.recipes_table).update(row).eq("id", existing[0]["id"]).execute()
        else:
            client.table(settings.recipes_table).insert(row).execute()
        written += 1
    print(f"Upserted recipes: {written}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, help="Path to recipes CSV")
    args = parser.parse_args()
    run(args.csv)
