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
import argparse
from collections import Counter, defaultdict
from pathlib import Path

LABEL_ORDER = [
    "recipe_search",
    "ai_search",
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
        "Tối nay nên nấu món gì ít dầu cho cả nhà",
        "Có món Việt nào hợp cho người đang giảm cân",
        "Gợi ý món sáng tiện mang đi làm",
        "Món nào dễ nấu cho người mới tập bếp",
        "Tìm món từ trứng và ức gà",
        "Công thức bữa sáng giàu protein",
        "Nên ăn gì sau tập gym buổi tối",
        "Món khác",
        "Đổi món",
        "Có món khác không",
        "Gợi ý món khác đi",
        "Tôi muốn một món chính duy nhất",
        "Chỉ cần 1 món chính thôi",
        "Cho món ít đậu",
        "Đổi sang món ít dầu hơn",
        "Món này hơi nặng, cho món khác",
    ],
    "ai_search": [
        "Tìm giúp tôi thông tin mới nhất về chế độ ăn Địa Trung Hải",
        "Search giúp món nào tốt cho người tiền tiểu đường",
        "Tra cứu nhanh nghiên cứu về intermittent fasting",
        "Cho tôi nguồn tham khảo về protein cho người tập gym",
        "Tìm bài viết uy tín về chất xơ và sức khỏe đường ruột",
        "Tìm giúp thực đơn eat clean cho dân văn phòng",
        "Look up latest guideline for daily protein intake",
        "Search web for low sodium Vietnamese meals",
        "Find trusted sources about omega 3 benefits",
        "Tìm thông tin cập nhật về carb cycling",
        "tim giup thong tin moi nhat ve Mediterranean diet",
        "tra cuu nghien cuu ve intermittent fasting",
        "Tìm guideline mới nhất về khuyến nghị chất béo",
        "Cho mình nguồn nghiên cứu về ăn nhiều chất xơ",
        "Search giúp bài viết về meal timing cho gym",
        "Tìm giúp review khoa học về low carb",
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
        "Tôi nặng 68kg cao 170cm, tính nhanh TDEE giúp",
        "Nên chia macro thế nào để giảm mỡ giữ cơ",
        "Bữa tối còn bao nhiêu calo là hợp lý",
        "Hôm nay tôi dư carb thì nên ăn gì",
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
        "Tủ lạnh còn gì để nấu bữa tối nhanh",
        "Món nào dùng được nguyên liệu sắp hết hạn",
        "Kiểm tra giúp đồ nào nên dùng trước",
        "Danh sách nguyên liệu cần mua bù",
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
        "Lên meal plan 7 ngày cho dân văn phòng",
        "Lập thực đơn 5 ngày đi làm mang cơm",
        "Kế hoạch ăn tối ít carb trong 1 tuần",
        "Tạo thực đơn tăng cơ với ngân sách 100k/ngày",
    ],
    "web_browsing": [
        "https://cookpad.com/vn/recipe/123456",
        "Tóm tắt link này https://giaoducyte.vn/dinh-duong",
        "Tom tat link nay https://giaoducyte.vn/dinh-duong",
        "Read this recipe: https://tasty.co/recipe/chicken-soup",
        "Check this article https://example.org/nutrition",
        "Đọc link này và tóm tắt giúp https://www.hsph.harvard.edu/nutritionsource/",
        "Mở bài viết này và rút ý chính https://www.who.int/news-room/fact-sheets",
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
        "Bánh mì ốp la khoảng bao nhiêu kcal",
        "100g ức gà có bao nhiêu protein",
        "Một tô bún bò trung bình bao nhiêu calo",
        "Cơm tấm sườn trứng có nhiều chất béo không",
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
        "Làm sao ăn healthy mà vẫn no lâu",
        "Thói quen ăn uống nào tốt cho giấc ngủ",
        "Mẹo giảm ăn vặt buổi tối",
        "Lịch ăn nào phù hợp người làm ca đêm",
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
        "Dự báo thời tiết cuối tuần",
        "Lịch thi đấu bóng đá tối nay",
        "Tỷ giá USD/VND hôm nay bao nhiêu",
        "Cách sửa lỗi C# trong Visual Studio",
    ],
}

FOOD_NOUNS = [
    "cơm tấm",
    "phở bò",
    "phở gà",
    "bún bò huế",
    "bún chả",
    "bún riêu",
    "bún thịt nướng",
    "bánh mì",
    "xôi gà",
    "xôi mặn",
    "cháo gà",
    "cháo vịt",
    "cháo yến mạch",
    "trứng luộc",
    "trứng ốp la",
    "ức gà áp chảo",
    "gà nướng",
    "cá hồi áp chảo",
    "cá hấp",
    "đậu hũ sốt cà",
    "rau luộc",
    "salad ức gà",
    "miến gà",
    "hủ tiếu",
    "mì xào",
    "cơm gà",
    "cơm chiên",
    "bánh cuốn",
    "gỏi cuốn",
    "nem cuốn",
    "canh chua",
    "canh rau",
    "súp bí đỏ",
    "súp gà",
    "cháo cá",
    "chả cá",
    "thịt bò xào",
    "thịt heo kho",
    "tôm rim",
    "đậu phụ non",
]

KB_DISHES = [
    "phở bò", "phở gà", "bún bò huế", "bún riêu", "hủ tiếu nam vang", "mì quảng", "bánh canh cua",
    "bún mắm", "bún cá", "bún mọc", "bún thang", "cháo gà", "cháo lòng", "cơm tấm", "cơm gà",
    "cơm chiên dương châu", "cơm bò lúc lắc", "cơm cá kho", "cơm thịt kho trứng", "cá kho tộ",
    "thịt kho tàu", "cá basa kho tiêu", "gà kho gừng", "rau muống xào tỏi", "bò xào cần tây",
    "mực xào chua ngọt", "tôm xào rau củ", "đậu hũ xào nấm", "gỏi cuốn", "bò bía", "chả giò",
    "bánh mì thịt", "bánh xèo", "bánh khọt", "bánh cuốn", "bánh bèo", "bánh bột lọc",
    "cao lầu", "cơm hến", "lẩu cá kèo", "bánh tằm bì", "bánh cống", "bánh đa cua",
    "nem nướng nha trang", "bún chả",
]

RECIPES_MODIFIERS = [
    "ít đậu",
    "nhiều đạm",
    "ít tinh bột",
    "ít dầu",
    "ít calo",
    "giàu protein",
    "nhanh",
    "dễ nấu",
    "ngon",
    "dễ làm",
    "rẻ",
    "healthy",
    "ăn kiêng",
    "cho bữa trưa",
    "cho bữa sáng",
    "cho bữa tối",
    "sau tập gym",
    "đi làm mang theo",
    "cho gia đình",
    "cho người mới tập bếp",
]

RECIPES_VERBS = [
    "công thức nấu",
    "cách nấu",
    "làm",
    "tìm món",
    "gợi ý món",
    "món",
    "mình muốn ăn",
    "cho tôi món",
    "chọn món",
    "đổi sang món",
]

RECIPES_CONTEXTS = [
    "bữa sáng",
    "bữa trưa",
    "bữa tối",
    "bữa phụ",
    "đi làm",
    "ở nhà",
    "mang đi",
    "ăn nhẹ",
    "ăn no",
    "giảm cân",
    "tăng cơ",
    "tiết kiệm",
    "nấu nhanh",
    "ít dầu mỡ",
    "ít tinh bột",
]

VAGUE_SWITCH_PHRASES = [
    "món khác",
    "đổi món",
    "có món khác không",
    "gợi ý món khác đi",
    "cho món khác",
    "đổi sang món khác",
    "món này chưa ổn",
    "thử món khác",
    "món khác nữa",
    "thêm lựa chọn khác",
    "cho món khác đi",
    "đổi sang món khác đi",
    "gợi ý thêm món khác",
    "thêm món khác cho tôi",
    "có lựa chọn nào khác không",
    "cho tôi lựa chọn khác",
    "món khác kiểu nhẹ hơn",
    "món khác kiểu no hơn",
    "món khác ít dầu hơn",
    "món khác nhiều đạm hơn",
    "món khác ít tinh bột hơn",
    "món khác rẻ hơn",
    "món khác nhanh hơn",
    "món khác dễ nấu hơn",
    "đổi qua món khác",
    "đổi sang món nhẹ hơn",
    "đổi sang món no hơn",
    "đổi sang món ít dầu hơn",
    "đổi sang món nhiều đạm hơn",
    "đổi sang món ít tinh bột hơn",
    "đổi sang món rẻ hơn",
    "đổi sang món nhanh hơn",
    "đổi sang món dễ nấu hơn",
    "không thích món này",
    "món này không hợp",
    "món này không ổn",
    "món này chưa hợp lắm",
    "món này hơi ngán",
    "món này hơi nặng",
    "món này hơi nhiều dầu",
    "món này hơi nhiều tinh bột",
    "món này hơi ít đạm",
    "món này hơi đắt",
    "món này hơi lâu",
    "có món nào khác ngon hơn không",
    "có món nào khác nhẹ hơn không",
    "có món nào khác ít dầu hơn không",
    "có món nào khác nhiều đạm hơn không",
    "có món nào khác ít tinh bột hơn không",
    "có món nào khác rẻ hơn không",
    "có món nào khác nhanh hơn không",
    "có món nào khác dễ nấu hơn không",
]


def build_recipe_search_seeds() -> list[str]:
    seeds: list[str] = []
    for noun in FOOD_NOUNS + KB_DISHES:
        seeds.extend(
            [
                f"công thức nấu {noun}",
                f"cách nấu {noun}",
                f"tìm món {noun}",
                f"gợi ý món {noun}",
                f"mình muốn ăn {noun}",
                f"cho tôi món {noun}",
                f"{noun} có công thức không",
            ]
        )
        for modifier in RECIPES_MODIFIERS:
            seeds.extend(
                [
                    f"{noun} {modifier}",
                    f"{noun} cho {modifier}",
                    f"món {noun} {modifier}",
                    f"công thức nấu {noun} {modifier}",
                    f"cách làm {noun} {modifier}",
                ]
            )
        for context in RECIPES_CONTEXTS:
            seeds.extend(
                [
                    f"{noun} cho {context}",
                    f"{noun} {context}",
                    f"món {noun} cho {context}",
                    f"gợi ý {noun} cho {context}",
                ]
            )
        seeds.extend(
            [
                f"{noun} kiểu quán",
                f"{noun} phiên bản gia đình",
                f"{noun} bản nhanh",
                f"{noun} bản healthy",
                f"{noun} ít dầu",
                f"{noun} nhiều đạm",
                f"{noun} ít tinh bột",
                f"{noun} cho bữa sáng",
                f"{noun} cho bữa trưa",
                f"{noun} cho bữa tối",
            ]
        )
    for phrase in VAGUE_SWITCH_PHRASES:
        seeds.extend(
            [
                phrase,
                f"cho tôi {phrase}",
                f"mình muốn {phrase}",
                f"có {phrase} không",
                f"tìm món khác",
                f"đề xuất món khác",
                f"đổi sang món khác",
                f"gợi ý lựa chọn khác",
                f"cho mình món khác",
                f"món này không hợp, cho món khác",
                f"món này hơi nặng, cho món khác",
                f"món này hơi đắt, cho món khác",
                f"món này hơi lâu, cho món khác",
                f"món này hơi ít đạm, cho món khác",
                f"món này hơi nhiều dầu, cho món khác",
            ]
        )
    # De-duplicate while preserving order.
    unique: list[str] = []
    seen: set[str] = set()
    for item in seeds:
        normalized = normalize_text(item)
        if normalized and normalized not in seen:
            seen.add(normalized)
            unique.append(normalized)
    return unique

PREFIXES = [
    "ban oi",
    "cho minh hoi",
    "tu van giup",
    "giup toi voi",
    "nhanh giup minh",
    "can gap",
    "please",
    "bro oi",
    "ad oi",
    "coach oi",
    "ai oi",
]

SUFFIXES = [
    "duoc khong",
    "nhe",
    "cam on",
    "hom nay",
    "trong ngay",
    "cho toi",
    "now",
    "gấp",
    "pls",
    "mình cảm ơn",
    "giúp mình nha",
]

QUESTION_STYLES = [
    "{}",
    "{}?",
    "{} ???",
    "{} !!",
    "xin {}",
    "toi can {}",
    "toi muon {}",
    "bạn có thể {}",
    "làm ơn {}",
    "gợi ý giúp mình: {}",
    "cho mình hỏi {}",
    "nhờ bạn {}",
]

CONTEXT_PREFIXES = [
    "Mình là dân văn phòng,",
    "Mình là sinh viên ở trọ,",
    "Mình đang giảm cân,",
    "Mình đang tăng cơ,",
    "Mình bị tiền tiểu đường,",
    "Mình bị mỡ máu nhẹ,",
    "Mình ăn chay linh hoạt,",
    "Mình hay ăn ngoài quán,",
    "Mình tập gym 5 buổi/tuần,",
    "Mình mới sinh em bé,",
    "Mình làm ca đêm,",
    "Mình có lịch họp dày đặc,",
]

CONTEXT_SUFFIXES = [
    "ngân sách dưới 60k nhé",
    "ưu tiên món nhanh dưới 20 phút",
    "tránh chiên dầu nhiều",
    "không ăn cay",
    "không dùng hải sản",
    "ưu tiên đồ Việt",
    "ưu tiên meal prep",
    "mình dị ứng đậu phộng",
    "mục tiêu khoảng 550 kcal/bữa",
    "ưu tiên nhiều protein",
    "ít carb buổi tối",
    "ăn nhẹ bụng để ngủ sớm",
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

    if rng.random() < 0.55:
        t = f"{rng.choice(CONTEXT_PREFIXES)} {t}"

    if rng.random() < 0.55:
        t = f"{t}, {rng.choice(CONTEXT_SUFFIXES)}"

    if rng.random() < 0.20:
        t = t.lower()
    elif rng.random() < 0.08:
        t = t.upper()

    if rng.random() < 0.25:
        t = typo_noise(t, rng)

    if rng.random() < 0.22:
        t = t.replace("món", rng.choice(["món", "món ăn", "dish"]))
    if rng.random() < 0.18:
        t = t.replace("công thức", rng.choice(["công thức", "recipe", "cách làm"]))

    t = normalize_text(t)
    return t


def build_balanced_samples(target_total: int, seed: int) -> list[dict]:
    rng = random.Random(seed)
    samples: list[dict] = []
    per_label = target_total // len(LABEL_ORDER)

    recipe_search_pool = build_recipe_search_seeds()

    for label in LABEL_ORDER:
        seeds = recipe_search_pool if label == "recipe_search" else SEED_DATASET[label]
        bucket: set[str] = set()
        # include seed lines first
        for s in seeds:
            bucket.add(normalize_text(s))

        attempts = 0
        while len(bucket) < per_label and attempts < per_label * 50:
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


def generate_dataset(output_path: str | None = None, target_total: int = 300_000, seed: int = 42):
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
    parser = argparse.ArgumentParser(description="Generate large intent dataset with augmentation.")
    parser.add_argument("--output", type=str, default=None)
    parser.add_argument("--target-total", type=int, default=300_000)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    os.makedirs(Path(__file__).resolve().parent, exist_ok=True)
    generate_dataset(output_path=args.output, target_total=args.target_total, seed=args.seed)
