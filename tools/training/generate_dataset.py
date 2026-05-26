"""
Generate a large intent dataset with template-based augmentation.

Run:
    python -X utf8 tools/training/generate_dataset.py
"""

from __future__ import annotations

import json
import os
import random
import re
from collections import Counter, defaultdict
from pathlib import Path

LABEL_ORDER = [
    "recipe_search",
    "nutrition_calc",
    "inventory_check",
    "meal_plan",
    "web_browsing",
    "calorie_lookup",
    "general",
    "unknown",
]

LABEL_MAP = {name: index for index, name in enumerate(LABEL_ORDER)}

SEED_DATASET = {
    "recipe_search": [
        "Tìm món ăn với cà chua và trứng",
        "Món gì ngon cho bữa trưa",
        "Cách làm phở bò",
        "Gợi ý món ăn với gà",
        "Tôi muốn nấu bún bò Huế",
        "Có công thức cơm rang không",
        "Món chay nào ngon",
        "Cách làm bánh mì thịt",
        "Tìm công thức salad thanh mát",
        "Món nào nấu nhanh dưới 30 phút",
        "Tim mon an tu ca chua va trung",
        "Mon gi ngon cho bua trua",
        "Cach lam pho bo",
        "Goi y mon an voi ga",
        "Toi muon nau bun bo Hue",
        "Co cong thuc com rang khong",
        "Mon chay nao ngon",
        "Cach lam banh mi thit",
        "Tim cong thuc salad thanh mat",
        "Mon nao nau nhanh duoi 30 phut",
    ],
    "nutrition_calc": [
        "Tính BMR cho tôi",
        "TDEE của tôi là bao nhiêu",
        "Tôi cần bao nhiêu protein mỗi ngày",
        "Tính lượng calo cần thiết",
        "Macro của tôi nên như thế nào",
        "Tính nhu cầu dinh dưỡng hằng ngày",
        "Tôi muốn giảm 5kg cần ăn bao nhiêu calo",
        "Lượng carb tôi cần nạp mỗi ngày",
        "Tinh BMR cho toi",
        "TDEE cua toi la bao nhieu",
        "Toi can bao nhieu protein moi ngay",
        "Tinh luong calo can thiet",
        "Macro cua toi nen nhu the nao",
        "Tinh nhu cau dinh duong hang ngay",
        "Toi muon giam 5kg can an bao nhieu calo",
        "Luong carb toi can nap moi ngay",
    ],
    "inventory_check": [
        "Nguyên liệu nào sắp hết hạn",
        "Kiểm tra tủ lạnh của tôi",
        "Còn gì trong kho nguyên liệu",
        "Nguyên liệu nào cần mua thêm",
        "Rau củ nào sắp hỏng",
        "Nguyen lieu nao sap het han",
        "Kiem tra tu lanh cua toi",
        "Con gi trong kho nguyen lieu",
        "Nguyen lieu nao can mua them",
        "Rau cu nao sap hong",
        "Kiem tra inventory",
        "What is in my fridge",
    ],
    "meal_plan": [
        "Lên thực đơn tuần cho tôi",
        "Kế hoạch ăn 7 ngày giảm cân",
        "Meal prep cho 1 tuần",
        "Lập thực đơn dinh dưỡng",
        "Len thuc don tuan cho toi",
        "Ke hoach an 7 ngay giam can",
        "Meal prep cho 1 tuan",
        "Lap thuc don dinh duong",
        "Create a 7-day meal plan",
        "Weekly meal planning for weight loss",
    ],
    "web_browsing": [
        "https://cookpad.com/vn/recipe/123456",
        "Tóm tắt link này https://giaoducyte.vn/dinh-duong",
        "Tom tat link nay https://giaoducyte.vn/dinh-duong",
        "Read this recipe: https://tasty.co/recipe/chicken-soup",
        "Check this article https://example.org/nutrition",
    ],
    "calorie_lookup": [
        "Phở bò bao nhiêu calo",
        "Bún bò có bao nhiêu protein",
        "Tính calo cơm tấm",
        "Một quả trứng bao nhiêu calo",
        "Pho bo bao nhieu calo",
        "Bun bo co bao nhieu protein",
        "Tinh calo com tam",
        "How many calories are in pho",
        "Nutrition facts for banh mi",
        "Mot qua trung bao nhieu calo",
    ],
    "general": [
        "Ăn gì tốt cho tim mạch",
        "Ăn gì để tăng cơ",
        "Lợi ích của rau xanh là gì",
        "Tại sao nên ăn sáng",
        "Tôi muốn sống khỏe hơn",
        "An gi de tang co",
        "Loi ich cua rau xanh la gi",
        "Tai sao nen an sang",
        "Tips for healthy eating",
        "Foods that boost immune system",
        "Toi muon song khoe hon",
    ],
    "unknown": [
        "Thời tiết hôm nay thế nào",
        "Giá vàng hôm nay",
        "Giá USD hôm nay",
        "Ai thắng trận bóng tối qua",
        "Code Python làm sao",
        "How to center a div in CSS",
        "Bảng giá chứng khoán",
        "Thoi tiet hom nay the nao",
        "Gia vang hom nay",
        "Code Python lam sao",
        "Who won the last election",
        "How to center a div in CSS",
        "Bang gia chung khoan",
    ],
}

PREFIXES = [
    "ban oi",
    "cho minh hoi",
    "tu van giup",
    "giup toi voi",
    "nhanh giup minh",
    "can gap",
    "please",
]

SUFFIXES = [
    "duoc khong",
    "nhe",
    "cam on",
    "hom nay",
    "trong ngay",
    "cho toi",
    "now",
]

QUESTION_STYLES = [
    "{}",
    "{}?",
    "{} ???",
    "{} !!",
    "xin {}",
    "toi can {}",
    "toi muon {}",
]


def normalize_text(text: str) -> str:
    text = text.strip()
    text = re.sub(r"\s+", " ", text)
    return text


def typo_noise(text: str, rng: random.Random) -> str:
    chars = list(text)
    if len(chars) < 6:
        return text
    op = rng.choice(["drop", "double", "swap", "none", "none"])
    idx = rng.randint(1, len(chars) - 2)
    if op == "drop":
        del chars[idx]
    elif op == "double":
        chars.insert(idx, chars[idx])
    elif op == "swap":
        chars[idx], chars[idx + 1] = chars[idx + 1], chars[idx]
    return "".join(chars)


def augment_one(base: str, rng: random.Random) -> str:
    t = normalize_text(base)

    if rng.random() < 0.65:
        t = rng.choice(QUESTION_STYLES).format(t)

    if rng.random() < 0.45:
        t = f"{rng.choice(PREFIXES)} {t}"

    if rng.random() < 0.45:
        t = f"{t} {rng.choice(SUFFIXES)}"

    if rng.random() < 0.20:
        t = t.lower()
    elif rng.random() < 0.08:
        t = t.upper()

    if rng.random() < 0.25:
        t = typo_noise(t, rng)

    t = normalize_text(t)
    return t


def build_balanced_samples(target_total: int, seed: int) -> list[dict]:
    rng = random.Random(seed)
    samples: list[dict] = []
    per_label = target_total // len(LABEL_ORDER)

    for label in LABEL_ORDER:
        seeds = SEED_DATASET[label]
        bucket: set[str] = set()
        # include seed lines first
        for s in seeds:
            bucket.add(normalize_text(s))

        attempts = 0
        while len(bucket) < per_label and attempts < per_label * 30:
            base = rng.choice(seeds)
            aug = augment_one(base, rng)
            if aug:
                bucket.add(aug)
            attempts += 1

        # if still short, force fill with indexed variants
        while len(bucket) < per_label:
            base = rng.choice(seeds)
            bucket.add(f"{augment_one(base, rng)} #{len(bucket)}")

        for text in sorted(bucket)[:per_label]:
            samples.append(
                {
                    "text": text,
                    "label": LABEL_MAP[label],
                    "label_name": label,
                }
            )

    rng.shuffle(samples)
    return samples


def stratified_split(samples: list[dict], val_ratio: float, seed: int):
    rng = random.Random(seed)
    grouped: dict[str, list[dict]] = defaultdict(list)
    for s in samples:
        grouped[s["label_name"]].append(s)

    train, val = [], []
    for label in LABEL_ORDER:
        rows = grouped[label]
        rng.shuffle(rows)
        n_val = max(1, int(round(len(rows) * val_ratio)))
        val.extend(rows[:n_val])
        train.extend(rows[n_val:])

    rng.shuffle(train)
    rng.shuffle(val)
    return train, val


def generate_dataset(output_path: str | None = None, target_total: int = 10_000, seed: int = 42):
    samples = build_balanced_samples(target_total=target_total, seed=seed)
    train, val = stratified_split(samples, val_ratio=0.2, seed=seed)

    result = {
        "train": train,
        "val": val,
        "label_map": LABEL_MAP,
        "label_order": LABEL_ORDER,
        "num_labels": len(LABEL_ORDER),
        "total": len(samples),
    }

    if output_path is None:
        output_path = str(Path(__file__).resolve().with_name("intent_dataset.json"))

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    total_counts = Counter(x["label_name"] for x in samples)
    train_counts = Counter(x["label_name"] for x in train)
    val_counts = Counter(x["label_name"] for x in val)

    print(f"Dataset generated: {len(samples)} samples")
    print(f"  Train: {len(train)} | Val: {len(val)}")
    print(f"  Labels: {LABEL_ORDER}")
    print("\nPer-class counts:")
    for label in LABEL_ORDER:
        print(
            f"  {label:<20} total={total_counts[label]:<4} "
            f"train={train_counts[label]:<4} val={val_counts[label]:<4}"
        )
    print(f"\nSaved to: {output_path}")


if __name__ == "__main__":
    os.makedirs(Path(__file__).resolve().parent, exist_ok=True)
    generate_dataset(target_total=10_000, seed=42)
