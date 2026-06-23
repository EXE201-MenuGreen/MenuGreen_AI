from __future__ import annotations

from typing import Any

from app.schemas.actions import ActionSuggestion, ExecuteActionRequest, ExecuteActionResponse


class ActionService:
    def suggest_for_chat(self, intent: str | None, message: str, context: dict | None = None) -> list[ActionSuggestion]:
        intent_key = (intent or "general").strip().lower()
        context = context or {}
        remaining = context.get("remaining_totals") or {}
        actions: list[ActionSuggestion] = []

        if intent_key == "meal_plan":
            actions.append(
                ActionSuggestion(
                    type="generate_meal_plan",
                    title="Tạo meal plan",
                    description="Tạo kế hoạch ăn uống dựa trên macro còn lại, ngân sách và thời gian nấu.",
                    payload={"target_calories": remaining.get("calories_kcal"), "source": "chat"},
                    safety_notes=["Cần lọc dị ứng trước khi tạo plan."],
                )
            )
            actions.append(
                ActionSuggestion(
                    type="budget_optimize",
                    title="Tối ưu ngân sách",
                    description="Tìm các món phù hợp mục tiêu dinh dưỡng với chi phí thấp hơn.",
                    payload={"source": "chat"},
                    safety_notes=["Không chọn món nằm trong danh sách dị ứng hoặc không thích."],
                )
            )
        elif intent_key == "recipe_search":
            actions.append(
                ActionSuggestion(
                    type="show_recipe",
                    title="Xem công thức",
                    description="Mở chi tiết công thức hoặc món ăn liên quan.",
                    requires_confirmation=False,
                    payload={"query": message},
                )
            )
            actions.append(
                ActionSuggestion(
                    type="replace_food",
                    title="Đổi món tương tự",
                    description="Tìm món thay thế an toàn hơn hoặc hợp ngân sách hơn.",
                    payload={"query": message},
                    safety_notes=["Món thay thế vẫn phải qua allergy filter."],
                )
            )
        elif intent_key == "nutrition_calc":
            actions.append(
                ActionSuggestion(
                    type="log_meal",
                    title="Ghi lại bữa ăn",
                    description="Ghi nhận món vừa hỏi vào nhật ký dinh dưỡng nếu user xác nhận.",
                    payload={"source": "chat"},
                )
            )

        if not actions:
            actions.append(
                ActionSuggestion(
                    type="ask_followup",
                    title="Hỏi thêm ngữ cảnh",
                    description="Hỏi thêm mục tiêu, ngân sách, bữa ăn hoặc dị ứng để cá nhân hóa tốt hơn.",
                    requires_confirmation=False,
                    payload={"source": "chat"},
                )
            )

        return actions

    def suggested_prompts(self, context: dict | None = None, intent: str | None = None) -> list[str]:
        context = context or {}
        remaining = context.get("remaining_totals") or {}
        prompts = [
            "Hôm nay tôi còn bao nhiêu kcal và nên ăn gì tiếp?",
            "Gợi ý bữa tối ít calo nhưng đủ protein.",
            "Tạo thực đơn 7 ngày theo ngân sách của tôi.",
        ]
        if float(remaining.get("calories_kcal") or 0) > 0:
            prompts.insert(0, f"Tôi còn {remaining.get('calories_kcal')} kcal, nên ăn món nào?")
        return prompts[:5]

    def execute_basic(self, request: ExecuteActionRequest) -> ExecuteActionResponse:
        if request.type in {"ask_followup", "show_recipe"}:
            return ExecuteActionResponse(
                status="completed",
                action=request.type,
                result={"payload": request.payload},
            )
        if not request.confirmed:
            return ExecuteActionResponse(
                status="needs_confirmation",
                action=request.type,
                result={"message": "Action requires user confirmation."},
                safety_notes=["Confirm before writing data or generating a plan."],
            )
        return ExecuteActionResponse(
            status="unsupported",
            action=request.type,
            result={"message": "This action type is reserved for the next implementation phase."},
        )


def context_summary_from_snapshot(context: dict[str, Any] | None) -> dict[str, Any]:
    context = context or {}
    return {
        "targets": context.get("targets") or {},
        "today_totals": context.get("today_totals") or {},
        "remaining_totals": context.get("remaining_totals") or {},
        "meal_logs_7d_count": context.get("meal_logs_7d_count", 0),
    }
