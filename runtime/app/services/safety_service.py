from __future__ import annotations

from app.core.config import get_settings


class SafetyService:
    def __init__(self) -> None:
        self.settings = get_settings()
        self.medical_block_keywords = [
            "ngừng thuốc",
            "bo thuoc",
            "thay thế thuốc",
            "thay the thuoc",
            "dùng quá liều",
            "tu sat",
            "tự sát",
        ]

    def apply(self, user_message: str, response_text: str, context: dict | None = None) -> tuple[str, list[str]]:
        flags: list[str] = []
        safe_text = response_text or ""
        lower = safe_text.lower()

        if self.settings.safety_block_medical_keywords:
            if any(k in lower for k in self.medical_block_keywords):
                flags.append("medical-risk-keyword")
                safe_text = (
                    "Mình không thể hỗ trợ nội dung có rủi ro y tế nguy hiểm. "
                    "Bạn nên tham khảo bác sĩ hoặc chuyên gia y tế được cấp phép."
                )

        max_chars = int(self.settings.safety_max_response_chars or 1200)
        if len(safe_text) > max_chars:
            flags.append("response-truncated")
            safe_text = safe_text[:max_chars].rstrip() + "..."

        msg = (user_message or "").lower()
        if any(x in msg for x in ["ăn kiêng cực đoan", "nhịn ăn", "bo bua", "bỏ bữa"]):
            flags.append("extreme-diet-risk")
            safe_text += (
                " Lưu ý an toàn: tránh cắt giảm cực đoan; nên duy trì mức năng lượng và protein phù hợp."
            )

        return safe_text, flags

