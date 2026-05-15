import argparse
import csv

from db import get_client
from config import get_settings


def to_float(value, default=0.0):
    try:
        return float(value)
    except Exception:
        return default


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
                    "calories_kcal_per_100g": to_float(r.get("calories_kcal_per_100g")),
                    "protein_g_per_100g": to_float(r.get("protein_g_per_100g")),
                    "carbs_g_per_100g": to_float(r.get("carbs_g_per_100g")),
                    "fat_g_per_100g": to_float(r.get("fat_g_per_100g")),
                    "fiber_g_per_100g": to_float(r.get("fiber_g_per_100g")),
                    "default_serving_g": to_float(r.get("default_serving_g"), 0.0) or None,
                    "serving_notes": (r.get("serving_notes") or "").strip() or None,
                }
            )

    if not rows:
        print("No valid rows")
        return

    client.table(settings.foods_table).upsert(rows, on_conflict="name").execute()
    print(f"Upserted foods: {len(rows)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, help="Path to foods CSV")
    args = parser.parse_args()
    run(args.csv)
