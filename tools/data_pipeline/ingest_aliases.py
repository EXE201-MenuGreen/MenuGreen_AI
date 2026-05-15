import argparse
import csv

from db import get_client
from config import get_settings


def run(csv_path: str):
    settings = get_settings()
    client = get_client()

    foods = client.table(settings.foods_table).select("id,name").execute().data or []
    name_to_id = {f["name"].strip().lower(): f["id"] for f in foods if f.get("name")}

    rows = []
    skipped = 0
    with open(csv_path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for r in reader:
            alias = (r.get("alias") or "").strip()
            food_name = (r.get("food_name") or "").strip().lower()
            if not alias or not food_name:
                skipped += 1
                continue
            food_id = name_to_id.get(food_name)
            if not food_id:
                skipped += 1
                continue
            rows.append({"alias": alias, "food_id": food_id})

    if not rows:
        print(f"No valid alias rows. skipped={skipped}")
        return

    client.table(settings.food_aliases_table).upsert(rows, on_conflict="alias").execute()
    print(f"Upserted aliases: {len(rows)} | skipped: {skipped}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, help="Path to aliases CSV")
    args = parser.parse_args()
    run(args.csv)
