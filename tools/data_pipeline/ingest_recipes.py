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


def split_tags(raw: str):
    if not raw:
        return []
    return [x.strip() for x in raw.split("|") if x.strip()]


def run(csv_path: str):
    settings = get_settings()
    client = get_client()

    rows = []
    with open(csv_path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            name = (r.get("name") or "").strip()
            if not name:
                continue
            rows.append(
                {
                    "name": name,
                    "description": (r.get("description") or "").strip() or None,
                    "instructions": (r.get("instructions") or "").strip() or None,
                    "prep_time_minutes": to_int(r.get("prep_time_minutes"), 0) or None,
                    "cook_time_minutes": to_int(r.get("cook_time_minutes"), 0) or None,
                    "servings": to_int(r.get("servings"), 0) or None,
                    "image_url": (r.get("image_url") or "").strip() or None,
                    "dietary_tags": split_tags((r.get("dietary_tags") or "").strip()),
                    "calories_per_serving": to_float(r.get("calories_per_serving"), 0.0) or None,
                    "protein_per_serving": to_float(r.get("protein_per_serving"), 0.0) or None,
                    "carbs_per_serving": to_float(r.get("carbs_per_serving"), 0.0) or None,
                    "fat_per_serving": to_float(r.get("fat_per_serving"), 0.0) or None,
                }
            )

    if not rows:
        print("No valid recipe rows")
        return

    client.table(settings.recipes_table).upsert(rows, on_conflict="name").execute()
    print(f"Upserted recipes: {len(rows)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, help="Path to recipes CSV")
    args = parser.parse_args()
    run(args.csv)
