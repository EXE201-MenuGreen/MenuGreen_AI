from __future__ import annotations

from datetime import datetime


def _to_float(value) -> float:
    try:
        return float(value or 0)
    except Exception:
        return 0.0


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


def build_context_snapshot(profile: dict | None, logs_7d: list[dict]) -> dict:
    today_totals = summarize_today_macros(logs_7d)
    profile_data = profile or {}
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
    }
