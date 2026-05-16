"""
Adapter pattern inspired by
https://github.com/linh222/face_cleanser_recommendation_dataset

NOTE:
- This is a pattern adapter only.
- Do not use cleanser items directly for MenuGreen food recommendations.
- Use this to shape interaction-style data for food recommendation experiments.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def map_interactions(input_csv: Path, output_json: Path) -> None:
    interactions = []
    with input_csv.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Flexible mapping: try common names first
            user_id = row.get("user_id") or row.get("userid") or row.get("user")
            item_id = row.get("item_id") or row.get("product_id") or row.get("item")
            event = row.get("event_type") or row.get("event") or "view"
            ts = row.get("timestamp") or row.get("ts")
            if not user_id or not item_id:
                continue
            interactions.append(
                {
                    "user_id": str(user_id),
                    "item_id": str(item_id),
                    "event_type": str(event),
                    "event_ts": ts,
                }
            )

    output_json.parent.mkdir(parents=True, exist_ok=True)
    with output_json.open("w", encoding="utf-8") as f:
        json.dump({"interactions": interactions, "count": len(interactions)}, f, ensure_ascii=False, indent=2)

    print(f"Mapped interactions: {len(interactions)}")
    print(f"Saved: {output_json}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Input interactions CSV")
    parser.add_argument("--output", required=True, help="Output normalized JSON")
    args = parser.parse_args()

    map_interactions(Path(args.input), Path(args.output))


if __name__ == "__main__":
    main()
