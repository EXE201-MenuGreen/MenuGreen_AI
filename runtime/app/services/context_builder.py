from __future__ import annotations

from datetime import date, datetime
import math


def _to_float(value) -> float:
    try:
        return float(value or 0)
    except Exception:
        return 0.0


def _first_value(data: dict, *keys: str):
    for key in keys:
        value = data.get(key)
        if value is not None and value != "":
            return value
    return None


def _round_away_from_zero(value: float) -> int:
    if value >= 0:
        return int(math.floor(value + 0.5))
    return int(math.ceil(value - 0.5))


def _calculate_age(raw_date) -> int:
    if not raw_date:
        return 25
    try:
        born = date.fromisoformat(str(raw_date)[:10])
        today = date.today()
        return today.year - born.year - ((today.month, today.day) < (born.month, born.day))
    except Exception:
        return 25


def apply_system_nutrition_metrics(profile: dict | None) -> tuple[dict, str]:
    """Fill missing metrics using the same formulas as MenuGreenSystem."""
    result = dict(profile or {})
    aliases = {
        "target_calories": ("target_calories_kcal", "TargetCalories"),
        "target_protein_g": ("TargetProteinG",),
        "target_carbs_g": ("TargetCarbsG",),
        "target_fat_g": ("TargetFatG",),
        "weight_kg": ("WeightKg",),
        "height_cm": ("HeightCm",),
        "date_of_birth": ("DateOfBirth",),
        "gender": ("Gender",),
        "activity_level": ("ActivityLevel",),
        "goal": ("goal_mode", "Goal"),
        "bmi": ("Bmi",),
        "bmr_kcal": ("BmrKcal",),
        "tdee_kcal": ("TdeeKcal",),
        "full_name": ("FullName",),
        "preferred_cuisine": ("PreferredCuisine",),
    }
    for canonical, candidate_keys in aliases.items():
        if result.get(canonical) is None:
            value = _first_value(result, *candidate_keys)
            if value is not None:
                result[canonical] = value

    target = _to_float(result.get("target_calories"))
    if target > 0:
        return result, "health_profile"

    weight = _to_float(_first_value(result, "weight_kg", "WeightKg"))
    height = _to_float(_first_value(result, "height_cm", "HeightCm"))
    bmr = _to_float(result.get("bmr_kcal"))
    tdee = _to_float(result.get("tdee_kcal"))
    if tdee <= 0:
        if weight <= 0 or height <= 0:
            return result, "missing"
        age = _calculate_age(result.get("date_of_birth"))
        gender = str(result.get("gender") or "").strip().lower()
        bmr = (10 * weight) + (6.25 * height) - (5 * age) + (5 if gender in {"male", "nam"} else -161)

        activity = str(result.get("activity_level") or "").strip().lower()
        multiplier = {
            "sedentary": 1.2,
            "light": 1.375,
            "lightlyactive": 1.375,
            "lightly active": 1.375,
            "moderate": 1.55,
            "moderatelyactive": 1.55,
            "moderately active": 1.55,
            "active": 1.725,
            "veryactive": 1.725,
            "very active": 1.725,
        }.get(activity, 1.2)
        tdee = max(_round_away_from_zero(bmr * multiplier), 1200)

    goal = str(_first_value(result, "goal", "goal_mode", "Goal") or "").strip().lower()
    adjustment = {
        "gain weight": 300,
        "gainweight": 300,
        "lose weight": -500,
        "loseweight": -500,
        "build muscle": 200,
        "buildmuscle": 200,
    }.get(goal, 0)
    target = tdee + adjustment

    if bmr > 0 and _to_float(result.get("bmr_kcal")) <= 0:
        result["bmr_kcal"] = _round_away_from_zero(bmr)
    result["tdee_kcal"] = _round_away_from_zero(tdee)
    result["target_calories"] = target

    protein_ratio = 0.35 if goal in {"build muscle", "buildmuscle"} else 0.30
    fat_ratio = 0.20 if goal in {"build muscle", "buildmuscle"} else 0.30
    carbs_ratio = 0.45 if goal in {"build muscle", "buildmuscle"} else 0.40
    protein_g = (target * protein_ratio) / 4
    if weight > 0:
        protein_g = min(max(protein_g, weight * 0.8), weight * 2.2)
    if _to_float(result.get("target_protein_g")) <= 0:
        result["target_protein_g"] = _round_away_from_zero(protein_g)
    if _to_float(result.get("target_carbs_g")) <= 0:
        result["target_carbs_g"] = _round_away_from_zero((target * carbs_ratio) / 4)
    if _to_float(result.get("target_fat_g")) <= 0:
        result["target_fat_g"] = _round_away_from_zero((target * fat_ratio) / 9)
    return result, "system_formula_v1"


def _merge_supplied_context(profile: dict, totals: dict, supplied_context: dict | None) -> tuple[dict, dict]:
    supplied = supplied_context if isinstance(supplied_context, dict) else {}
    supplied_profile = supplied.get("profile") if isinstance(supplied.get("profile"), dict) else {}
    user_profile = supplied.get("user_profile") if isinstance(supplied.get("user_profile"), dict) else {}
    health_profile = supplied.get("health_profile") if isinstance(supplied.get("health_profile"), dict) else {}

    merged_profile = dict(profile)
    for source in (supplied_profile, user_profile, health_profile):
        merged_profile.update({key: value for key, value in source.items() if value is not None})

    recent = supplied.get("recent_nutrition") if isinstance(supplied.get("recent_nutrition"), dict) else {}
    actual_today = (
        supplied.get("actual_intake_today")
        if isinstance(supplied.get("actual_intake_today"), dict)
        else {}
    )
    if actual_today:
        totals = {
            "calories_kcal": _to_float(_first_value(actual_today, "calories_kcal", "calories", "total_calories")),
            "protein_g": _to_float(_first_value(actual_today, "protein_g", "protein", "total_protein_g")),
            "carbs_g": _to_float(_first_value(actual_today, "carbs_g", "carbs", "total_carbs_g")),
            "fat_g": _to_float(_first_value(actual_today, "fat_g", "fat", "total_fat_g")),
            "fiber_g": _to_float(_first_value(actual_today, "fiber_g", "fiber", "total_fiber_g")),
        }
    snapshot_date = str(_first_value(recent, "snapshot_date", "date") or "")[:10]
    if recent and snapshot_date == date.today().isoformat():
        totals = {
            "calories_kcal": _to_float(_first_value(recent, "total_calories", "total_calories_kcal")),
            "protein_g": _to_float(recent.get("total_protein_g")),
            "carbs_g": _to_float(recent.get("total_carbs_g")),
            "fat_g": _to_float(recent.get("total_fat_g")),
            "fiber_g": _to_float(recent.get("total_fiber_g")),
        }
    return merged_profile, totals


def summarize_today_macros(logs: list[dict]) -> dict:
    today = datetime.now().date().isoformat()
    totals = {
        "calories_kcal": 0.0,
        "protein_g": 0.0,
        "carbs_g": 0.0,
        "fat_g": 0.0,
        "fiber_g": 0.0,
    }

    for row in logs:
        # Support both schemas:
        # - MVP-style meal_logs.logged_at + calories_kcal/protein_g/...
        # - legacy daily_logs.date + calories_consumed/protein_consumed/...
        logged_date = str(row.get("date", ""))
        logged_at = str(row.get("logged_at", ""))
        if logged_date != today and not logged_at.startswith(today):
            continue

        totals["calories_kcal"] += _to_float(
            row.get("calories_kcal", row.get("calories_consumed"))
        )
        totals["protein_g"] += _to_float(
            row.get("protein_g", row.get("protein_consumed"))
        )
        totals["carbs_g"] += _to_float(
            row.get("carbs_g", row.get("carbs_consumed"))
        )
        totals["fat_g"] += _to_float(
            row.get("fat_g", row.get("fat_consumed"))
        )
        totals["fiber_g"] += _to_float(row.get("fiber_g"))

    return {k: round(v, 1) for k, v in totals.items()}


def build_context_snapshot(
    profile: dict | None,
    logs_7d: list[dict],
    supplied_context: dict | None = None,
) -> dict:
    today_totals = summarize_today_macros(logs_7d)
    profile_data = profile or {}
    profile_data, today_totals = _merge_supplied_context(profile_data, today_totals, supplied_context)
    profile_data, target_source = apply_system_nutrition_metrics(profile_data)
    targets = {
        "calories_kcal": _to_float(
            profile_data.get("target_calories", profile_data.get("target_calories_kcal"))
        ),
        "protein_g": _to_float(profile_data.get("target_protein_g")),
        "carbs_g": _to_float(profile_data.get("target_carbs_g")),
        "fat_g": _to_float(profile_data.get("target_fat_g")),
    }
    remaining = {
        "calories_kcal": round(max(targets["calories_kcal"] - today_totals["calories_kcal"], 0.0), 1),
        "protein_g": round(max(targets["protein_g"] - today_totals["protein_g"], 0.0), 1),
        "carbs_g": round(max(targets["carbs_g"] - today_totals["carbs_g"], 0.0), 1),
        "fat_g": round(max(targets["fat_g"] - today_totals["fat_g"], 0.0), 1),
    }
    return {
        "profile": profile_data,
        "meal_logs_7d_count": len(logs_7d),
        "today_totals": today_totals,
        "targets": targets,
        "remaining_totals": remaining,
        "target_source": target_source,
    }
