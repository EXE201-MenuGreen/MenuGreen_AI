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
            name = (r.get("name_vi") or r.get("name") or "").strip()
            if not name:
                continue
            rows.append(
                {
                    "name_vi": name,
                    "name_en": (r.get("name_en") or "").strip() or None,
                    "category": (r.get("category") or "").strip() or None,
                    "calories_kcal": to_float(r.get("calories_kcal") or r.get("calories_kcal_per_100g")),
                    "protein_g": to_float(r.get("protein_g") or r.get("protein_g_per_100g")),
                    "carbs_g": to_float(r.get("carbs_g") or r.get("carbs_g_per_100g")),
                    "fat_g": to_float(r.get("fat_g") or r.get("fat_g_per_100g")),
                    "fiber_g": to_float(r.get("fiber_g") or r.get("fiber_g_per_100g")),
                    "default_serving_g": to_float(r.get("default_serving_g"), 0.0) or None,
                    "estimated_price_vnd": int(to_float(r.get("estimated_price_vnd"), 0.0)) or None,
                    "image_url": (r.get("image_url") or "").strip() or None,
                }
            )

    if not rows:
        print("No valid rows")
        return

    written = 0
    for row in rows:
        existing = (
            client.table(settings.foods_table)
            .select("id")
            .eq("name_vi", row["name_vi"])
            .limit(1)
            .execute()
            .data
            or []
        )
        if existing:
            client.table(settings.foods_table).update(row).eq("id", existing[0]["id"]).execute()
        else:
            client.table(settings.foods_table).insert(row).execute()
        written += 1
    print(f"Upserted foods: {written}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, help="Path to foods CSV")
    args = parser.parse_args()
    run(args.csv)
