from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def dedupe_rows(rows: list[dict]) -> list[dict]:
    seen: set[tuple[str, int]] = set()
    out: list[dict] = []
    for r in rows:
        text = str(r.get("text", "")).strip()
        label = int(r.get("label", -1))
        if not text or label < 0:
            continue
        key = (text, label)
        if key in seen:
            continue
        seen.add(key)
        out.append({"text": text, "label": label, "label_name": r.get("label_name", "")})
    return out


def stratified_split(rows: list[dict], label_order: list[str], val_ratio: float = 0.2) -> tuple[list[dict], list[dict]]:
    grouped: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        grouped[str(r.get("label_name", ""))].append(r)
    train: list[dict] = []
    val: list[dict] = []
    for label in label_order:
        items = grouped.get(label, [])
        n_val = max(1, int(round(len(items) * val_ratio))) if items else 0
        val.extend(items[:n_val])
        train.extend(items[n_val:])
    return train, val


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True, help="Base dataset json path")
    parser.add_argument("--new", required=True, help="New dataset json path")
    parser.add_argument("--out", required=True, help="Output merged dataset json path")
    args = parser.parse_args()

    base = load_json(Path(args.base))
    new = load_json(Path(args.new))

    label_order = base.get("label_order") or new.get("label_order")
    if not label_order:
        raise ValueError("Missing label_order in datasets")

    combined = []
    combined.extend(base.get("train", []))
    combined.extend(base.get("val", []))
    combined.extend(new.get("train", []))
    combined.extend(new.get("val", []))
    merged = dedupe_rows(combined)
    train, val = stratified_split(merged, label_order, val_ratio=0.2)

    label_map = {name: idx for idx, name in enumerate(label_order)}
    result = {
        "train": train,
        "val": val,
        "label_map": label_map,
        "label_order": label_order,
        "num_labels": len(label_order),
        "total": len(merged),
    }
    out_path = Path(args.out)
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    cnt = Counter(r["label_name"] for r in merged)
    print(f"Merged total: {len(merged)}")
    for label in label_order:
        print(f"  {label:<20} {cnt.get(label, 0)}")
    print(f"Saved: {out_path}")


if __name__ == "__main__":
    main()

