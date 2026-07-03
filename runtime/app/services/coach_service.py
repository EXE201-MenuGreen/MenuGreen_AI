from __future__ import annotations

from html import unescape
from html.parser import HTMLParser
import json
import re
import unicodedata
import uuid
from pathlib import Path
from urllib.parse import urlparse

import httpx

from app.core.config import get_settings
from app.core.gemini_pool import get_gemini_pool
from app.core.onnx_intent import OnnxIntentClassifier
from app.repositories.user_repository import UserRepository
from app.schemas.chat import ChatRequest, ChatResponse
from app.services.action_service import ActionService, context_summary_from_snapshot
from app.services.context_builder import build_context_snapshot
from app.services.safety_service import SafetyService


class _RecipePageTextExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.in_script = False
        self.in_style = False
        self.text_parts: list[str] = []
        self.title_parts: list[str] = []
        self.in_title = False

    def handle_starttag(self, tag: str, attrs) -> None:
        tag = (tag or "").lower()
        if tag == "script":
            self.in_script = True
        elif tag == "style":
            self.in_style = True
        elif tag == "title":
            self.in_title = True

    def handle_endtag(self, tag: str) -> None:
        tag = (tag or "").lower()
        if tag == "script":
            self.in_script = False
        elif tag == "style":
            self.in_style = False
        elif tag == "title":
            self.in_title = False

    def handle_data(self, data: str) -> None:
        if self.in_script or self.in_style:
            return
        text = re.sub(r"\s+", " ", unescape(data or "")).strip()
        if not text:
            return
        if self.in_title:
            self.title_parts.append(text)
        self.text_parts.append(text)


class CoachService:
    """Single fallback policy lives here."""

    def __init__(self) -> None:
        self.settings = get_settings()
        self.repo = UserRepository()
        self.safety = SafetyService()
        self.action_service = ActionService()
        self.model_dir = Path(__file__).resolve().parents[2] / self.settings.intent_model_dir
        self.classifier = self._try_load_onnx()
        self.gemini_pool = get_gemini_pool()

    def _try_load_onnx(self) -> OnnxIntentClassifier | None:
        try:
            return OnnxIntentClassifier(self.model_dir)
        except Exception:
            return None

    @staticmethod
    def _heuristic_intent(message: str) -> str | None:
        text = (message or "").strip()
        normalized_text = CoachService._normalize_match_text(text)
        if not normalized_text:
            return None
        out_of_domain_keywords = [
            "viet giup",
            "viet email",
            "email xin nghi",
            "ke chuyen cuoi",
            "tong thong",
            "xem phim",
            "facebook",
            "flutter",
            "laptop gaming",
            "lich da bong",
            "tao anh",
            "dich doan",
            "thoi tiet the nao",
            "fps",
            "choi game",
            "game",
            "buon qua",
            "noi chuyen voi toi",
            "tarot",
            "emoji",
            "icon",
        ]
        product_capability_keywords = [
            "menugreen",
            "lich su kcal",
            "luu lich su",
            "co luu",
            "co tinh nang",
            "co ho tro",
            "tai khoan",
            "dang ky",
            "dang nhap",
            "app nay",
            "ung dung nay",
        ]
        search_keywords = [
            "search",
            "tra cuu",
            "tim thong tin",
            "nguon tham khao",
            "latest",
            "newest",
            "research",
        ]
        meal_keywords = [
            "an gi",
            "an j",
            "nen an gi",
            "mon gi",
            "recommend",
            "recommend mon",
            "recommend do an",
            "rcm",
            "rcm mon",
            "de xuat mon",
            "tu van mon",
            "muon an",
            "toi muon an",
            "thich an",
            "toi thich an",
            "goi y bua",
            "goi y bua an",
            "goi y mon",
            "goi y 3 mon",
            "co mon nao",
            "mon nao",
            "thuc don",
            "ke hoach bua an",
            "hom nay an gi",
            "hom nay nen an gi",
            "hom nay toi muon an",
            "hom nay toi thich an",
            "an nhe",
            "do an nhe",
            "mon mat",
            "mon nong",
            "giai nhiet",
            "doi mon",
            "eat clean",
            "healthy",
            "no lau",
            "nhanh",
            "nhe bung",
            "du chat",
            "it beo",
            "it dau",
            "re hon",
            "re re",
            "mon re cho sv",
            "cho sv",
            "it tien",
            "co mon khac",
            "khac khong",
            "bua trua thoi",
            "bua toi thoi",
            "bua sang thoi",
            "toi dang giam can",
            "giam can",
            "khong dung y toi",
        ]
        meal_fragment_keywords = [
            "di ung",
            "hai san",
            "khong an",
            "khong uong",
            "khong cay",
            "dung co",
            "dung goi y",
            "doi sang",
            "doi mon",
            "mon nuoc",
            "mon khac",
            "2 mon khac",
            "them 2 mon",
            "no toi chieu",
            "nhieu dam",
            "it carb",
            "it dau",
            "it beo",
            "du chat",
            "re nhat",
            "re hon",
            "bua trua",
            "bua toi",
            "bua sang",
            "30k",
            "40k",
            "50k",
            "60k",
            "70k",
            "80k",
            "90k",
            "100k",
        ]
        nutrition_keywords = [
            "bao nhieu carb",
            "bao nhieu protein",
            "bao nhieu fat",
            "con bao nhieu",
            "calo",
            "kcal",
            "protein",
            "carb",
            "fat",
            "macro",
            "vuot kcal",
            "du chua",
            "con lai",
            "tinh kcal",
            "tinh giup",
        ]
        nutrition_calc_keywords = [
            "tinh",
            "bao nhieu",
            "tong",
            "vuot",
            "thieu",
            "uoc luong",
            "log",
            "ghi nhan",
            "nhap nham",
            "sua lai",
            "tinh lai",
            "xoa",
            "con lai",
            "sai so",
            "gram",
            "g protein",
            "g carb",
            "g fat",
            "kcal",
            "calo",
        ]
        nutrition_log_keywords = [
            "toi vua an",
            "toi da an",
            "hom nay toi moi an",
            "nay an",
            "an roi",
            "vua uong",
            "vua an",
            "log giup",
            "log dum",
            "log mon",
        ]
        recipe_keywords = [
            "recipe",
            "cong thuc",
            "cach nau",
            "cach lam",
            "nguyen lieu",
            "nau sao",
            "co mon nao giong",
        ]
        recipe_followup_keywords = [
            "mat bao lau nau",
            "nau nhanh khong",
            "thay gi",
            "nguyen lieu",
            "co trung khong",
            "mon do",
            "mon dau",
        ]
        weather_keywords = [
            "troi nong",
            "nang nong",
            "nong buc",
            "troi lanh",
            "lanh",
            "mua",
            "oi buc",
            "thoi tiet",
            "mat troi",
        ]
        weather_food_keywords = [
            "an",
            "mon",
            "do an",
            "goi y",
            "danh sach",
            "nhe",
            "mat",
            "nong",
            "giai nhiet",
        ]
        meal_constraint_keywords = [
            "bua sang",
            "bua trua",
            "bua toi",
            "an sang",
            "an trua",
            "an toi",
            "duoi",
            "budget",
            "tam",
            "phut",
        ]
        meal_suggestion_keywords = [
            "goi y",
            "an gi",
            "nen an gi",
            "bua sang",
            "bua trua",
            "bua toi",
            "muon an",
            "thich an",
        ]
        if any(k in normalized_text for k in out_of_domain_keywords):
            return "general"
        if any(k in normalized_text for k in product_capability_keywords) and any(
            token in normalized_text for token in ("khong", "co", "luu", "tinh nang", "ho tro", "lich su")
        ):
            return "general"
        if any(k in normalized_text for k in search_keywords):
            return "ai_search"
        if normalized_text.startswith(("hom nay an j", "hom nay an gi", "toi nay an gi", "sang nay an gi")):
            return "meal_plan"
        if "eat clean" in normalized_text and any(token in normalized_text for token in ("salad", "mon", "nao")):
            return "recipe_search"
        if re.search(r"^lam\s+.+\b(cho nguoi moi bat dau|de khong|de nau)\b", normalized_text):
            return "recipe_search"

        has_recipe_signal = (
            any(k in normalized_text for k in recipe_keywords)
            or any(k in normalized_text for k in recipe_followup_keywords)
            or bool(re.search(r"^nau\s", normalized_text))
            or bool(
                re.search(
                    r"^lam\s+.+\b(sot|canh|cuon|chao|xao|hap|chien|nuong|salad|sup|bun|com|mi)\b",
                    normalized_text,
                )
            )
            or ("lam trong" in normalized_text and "phut" in normalized_text)
        )
        has_nutrition_signal = any(k in normalized_text for k in nutrition_keywords) or any(
            k in normalized_text for k in nutrition_calc_keywords
        )
        has_numeric_macro_signal = bool(
            re.search(r"\b\d+\s*(g|gram|kcal|calo)\b", normalized_text)
        ) and any(token in normalized_text for token in ("protein", "carb", "fat", "dam", "kcal", "calo"))
        has_log_signal = any(k in normalized_text for k in nutrition_log_keywords)
        has_budget_or_time = bool(re.search(r"\d+\s*(k|phut|p)\b", normalized_text))
        has_meal_signal = any(k in normalized_text for k in meal_keywords)
        has_meal_fragment = (
            any(k in normalized_text for k in meal_fragment_keywords)
            or bool(re.fullmatch(r"\d+\s*k", normalized_text))
            or normalized_text in {"toi", "trua", "sang", "bua toi", "bua trua", "bua sang"}
        )
        has_weather_food_signal = any(k in normalized_text for k in weather_keywords) and any(
            k in normalized_text for k in weather_food_keywords
        )
        has_macro_target_only = (
            any(token in normalized_text for token in ("protein", "carb", "fat", "kcal", "calo", "dam"))
            and not any(token in normalized_text for token in ("tinh", "bao nhieu", "tong", "vuot", "thieu", "log", "xoa", "sua"))
            and any(token in normalized_text for token in ("can", "muon", "con", "it", "nhieu"))
        )

        if has_recipe_signal:
            return "recipe_search"
        if has_weather_food_signal:
            return "meal_plan"
        if has_meal_signal and any(
            token in normalized_text
            for token in (
                "an gi",
                "nen an gi",
                "goi y",
                "co mon nao",
                "muon an",
                "thich an",
                "recommend",
                "rcm",
                "de xuat mon",
                "tu van mon",
            )
        ):
            return "meal_plan"
        has_suggestion_request = any(
            token in normalized_text
            for token in (
                "goi y", "de xuat", "recommend", "rcm", "an gi", "an j",
                "thuc don", "meal plan", "mon gi", "mon nao", "co mon", "nen an gi"
            )
        )
        if not has_suggestion_request:
            if has_log_signal:
                return "nutrition_calc"
            if (
                has_nutrition_signal
                and any(token in normalized_text for token in ("tinh", "bao nhieu", "tong", "vuot", "thieu", "uoc luong", "log", "xoa", "sua", "con lai"))
            ) or has_numeric_macro_signal:
                return "nutrition_calc"
            if re.search(r"\ban .+ duoc khong\b", normalized_text) and not any(
                token in normalized_text for token in ("an gi", "nen an gi")
            ):
                return "nutrition_calc"
        if has_meal_fragment or has_macro_target_only:
            return "meal_plan"
        if has_meal_signal:
            return "meal_plan"
        if has_nutrition_signal:
            return "nutrition_calc"
        if has_budget_or_time and any(k in normalized_text for k in meal_constraint_keywords + weather_food_keywords):
            return "meal_plan"
        if re.search(r"\bco mon .+ nao\b", normalized_text):
            return "meal_plan"
        if any(k in normalized_text for k in weather_keywords):
            return "general"
        return None

    @staticmethod
    def _normalize_match_text(message: str) -> str:
        text = (message or "").strip().lower()
        if not text:
            return ""
        text = unicodedata.normalize("NFKD", text)
        text = "".join(ch for ch in text if not unicodedata.combining(ch))
        text = text.replace("đ", "d")
        text = re.sub(r"[^a-z0-9\s]", " ", text)
        return re.sub(r"\s+", " ", text).strip()

    @staticmethod
    def _extract_urls(message: str) -> list[str]:
        text = (message or "").strip()
        if not text:
            return []
        matches = re.findall(r"https?://[^\s<>\"]+", text, flags=re.IGNORECASE)
        urls: list[str] = []
        seen: set[str] = set()
        for match in matches:
            url = match.rstrip(").,!?;:")
            if url in seen:
                continue
            seen.add(url)
            urls.append(url)
        return urls

    @staticmethod
    def _infer_contextual_intent(
        message: str,
        conversation_history=None,
        last_recommended_name: str = "",
    ) -> str | None:
        if not conversation_history:
            return None
        normalized_text = CoachService._normalize_match_text(message)
        if not normalized_text:
            return None

        recent_messages = conversation_history[-6:] if isinstance(conversation_history, list) else []
        recent_text = " ".join(
            CoachService._normalize_match_text(getattr(item, "content", "") or "")
            for item in recent_messages
        ).strip()
        has_recipe_context = any(
            token in recent_text
            for token in (
                "cong thuc",
                "cach nau",
                "nguyen lieu",
                "nau",
                "recipe",
            )
        ) or bool(last_recommended_name)
        has_meal_context = any(
            token in recent_text
            for token in (
                "goi y",
                "thuc don",
                "bua",
                "calo",
                "kcal",
                "p c f",
                "protein",
                "carb",
                "fat",
            )
        )

        has_suggestion_request = any(
            token in normalized_text
            for token in (
                "goi y", "de xuat", "recommend", "rcm", "an gi", "an j",
                "thuc don", "meal plan", "mon gi", "mon nao", "co mon", "nen an gi"
            )
        )
        if not has_suggestion_request:
            if any(
                token in normalized_text
                for token in ("tinh", "kcal", "calo", "protein", "carb", "fat", "macro", "log", "nhap nham", "xoa")
            ):
                return "nutrition_calc"

        if has_recipe_context and any(
            token in normalized_text
            for token in (
                "mon do",
                "mon dau",
                "nau",
                "thay",
                "nguyen lieu",
                "bao lau",
                "nhanh hon",
                "lam nhanh",
                "de hon",
                "noi com dien",
            )
        ):
            return "recipe_search"

        if has_meal_context and any(
            token in normalized_text
            for token in (
                "khong an",
                "khong uong",
                "di ung",
                "dung co",
                "goi y",
                "mon nuoc",
                "mon khac",
                "lua chon khac",
                "bua toi",
                "bua trua",
                "bua sang",
                "30k",
                "40k",
                "50k",
                "60k",
                "it carb",
                "nhieu dam",
                "re hon",
                "re nhat",
            )
        ):
            return "meal_plan"

        return None

    @staticmethod
    def _looks_like_recipe_url(message: str, url: str) -> bool:
        text = CoachService._normalize_match_text(message)
        parsed = urlparse(url)
        path = CoachService._normalize_match_text(parsed.path.replace("-", " ").replace("/", " "))
        recipe_hints = (
            "recipe",
            "recipes",
            "cong thuc",
            "cach nau",
            "mon an",
            "food",
            "cook",
            "kitchen",
            "allrecipes",
            "foodnetwork",
        )
        return any(hint in text for hint in ("link", "url", "cong thuc", "cach nau", "phan tich")) or any(
            hint in path or hint in parsed.netloc.lower() for hint in recipe_hints
        )

    @staticmethod
    def _extract_recipe_page_payload(html: str, url: str) -> dict:
        parser = _RecipePageTextExtractor()
        parser.feed(html or "")
        parser.close()
        title = " ".join(parser.title_parts).strip()
        text = " ".join(parser.text_parts)
        text = re.sub(r"\s+", " ", text).strip()
        return {
            "url": url,
            "title": title[:300],
            "content": text[:15000],
        }

    def _fetch_recipe_page_payload(self, url: str) -> dict | None:
        try:
            with httpx.Client(
                follow_redirects=True,
                timeout=20.0,
                headers={
                    "User-Agent": "MenuGreenAI/1.0 (+recipe-link-analysis)"
                },
            ) as client:
                response = client.get(url)
                response.raise_for_status()
                content_type = str(response.headers.get("content-type", "")).lower()
                if "text/html" not in content_type and "application/xhtml+xml" not in content_type:
                    page = None
                else:
                    page = self._extract_recipe_page_payload(response.text, str(response.url))
                if page and page.get("content"):
                    return page
        except Exception:
            pass

        try:
            sanitized_url = re.sub(r"^https?://", "", url.strip(), flags=re.IGNORECASE)
            reader_url = f"https://r.jina.ai/http://{sanitized_url}"
            with httpx.Client(
                follow_redirects=True,
                timeout=30.0,
                headers={
                    "User-Agent": "MenuGreenAI/1.0 (+recipe-link-analysis)"
                },
            ) as client:
                response = client.get(reader_url)
                response.raise_for_status()
                text = response.text or ""
                normalized = self._normalize_match_text(text[:1200])
                if any(
                    token in normalized
                    for token in (
                        "captcha",
                        "forbidden",
                        "verification successful",
                        "just a moment",
                    )
                ):
                    return None
                title_match = re.search(r"^Title:\s*(.+)$", text, flags=re.MULTILINE)
                title = title_match.group(1).strip() if title_match else url
                body = re.sub(r"\s+", " ", text).strip()
                return {
                    "url": url,
                    "title": title[:300],
                    "content": body[:15000],
                }
        except Exception:
            return None

    def _analyze_recipe_link(self, message: str, url: str) -> tuple[str, list[str]] | None:
        if self.gemini_pool.is_available():
            prompt = (
                "Bạn là AI Coach cho app món ăn MenuGreen.\n"
                "Hãy phân tích link recipe dưới đây và trả lời NGẮN bằng tiếng Việt.\n"
                "Yêu cầu:\n"
                "1. Xác định tên món.\n"
                "2. Tóm tắt món này là món gì.\n"
                "3. Liệt kê nguyên liệu chính tối đa 8 ý.\n"
                "4. Tóm tắt cách nấu tối đa 5 bước ngắn.\n"
                "5. Nếu thấy thời gian nấu hoặc khẩu phần thì nêu ra.\n"
                "6. Nếu link không phải recipe hoặc không đọc được, nói rõ điều đó.\n"
                "Không bịa thông tin.\n"
                f"User message: {message.strip()}\n"
                f"URL: {url}\n"
            )
            text = self.gemini_pool.invoke_url_context(
                prompt=prompt,
                url=url,
                model=self.settings.llm_model,
                temperature=0.2,
                cache_namespace="recipe-link-url-context",
            )
            if text:
                return text, ["recipe-link", "gemini-url-context"]

        page = self._fetch_recipe_page_payload(url)
        if not page:
            return (
                "Mình chưa đọc được nội dung từ link này. Bạn thử gửi link public của trang công thức hoặc dán thêm tên món để mình hỗ trợ tiếp.",
                ["url-fetch-failed"],
            )

        if not self.gemini_pool.is_available():
            title = page.get("title") or url
            return (
                f"Mình đã đọc được link recipe này: {title}. Hiện server chưa bật Gemini nên mình chưa phân tích sâu ingredient và steps tự động được.",
                ["url-fetched"],
            )

        prompt = (
            "Bạn là AI Coach cho app món ăn MenuGreen.\n"
            "Hãy phân tích nội dung trang web công thức nấu ăn dưới đây và trả lời NGẮN bằng tiếng Việt.\n"
            "Yêu cầu:\n"
            "1. Xác định tên món.\n"
            "2. Tóm tắt món này là món gì.\n"
            "3. Liệt kê nguyên liệu chính tối đa 8 ý.\n"
            "4. Tóm tắt cách nấu tối đa 5 bước ngắn.\n"
            "5. Nếu thấy thời gian nấu hoặc khẩu phần thì nêu ra.\n"
            "6. Nếu nội dung không giống trang recipe, nói rõ là link này không đủ dữ liệu công thức.\n"
            "Không bịa nếu trang không có thông tin.\n"
            f"User message: {message.strip()}\n"
            f"URL: {page.get('url')}\n"
            f"Page title: {page.get('title')}\n"
            f"Page content:\n{page.get('content')}\n"
        )
        text = self._invoke_gemini_text(prompt, cache_namespace="recipe-link-analysis")
        if not text:
            title = page.get("title") or url
            return (
                f"Mình đã mở được link này: {title}, nhưng Gemini chưa trả về phân tích lúc này. Bạn thử lại sau hoặc gửi thêm tên món giúp mình.",
                ["url-fetched", "gemini-fallback-failed"],
            )
        return text, ["recipe-link", "gemini-url-analysis"]

    @staticmethod
    def _extract_recipe_query(message: str) -> str:
        text = (message or "").strip()
        if not text:
            return ""

        cleaned = text
        prefixes = [
            r"^(công thức|cong thuc|cách nấu|cach nau|làm|lam|nấu|nau)\s+",
            r"^(tìm|tim|gợi ý|goi y|tra cứu|tra cuu)\s+(món|mon|công thức|cong thuc|recipe)\s+",
            r"^(recommend|rcm)\s+(món|mon|công thức|cong thuc|recipe)?\s*",
            r"^(gợi ý|goi y|tìm|tim)\s+",
        ]
        for pattern in prefixes:
            cleaned = re.sub(pattern, "", cleaned, flags=re.IGNORECASE).strip()

        cleaned = re.sub(
            r"\b(công thức|cong thuc|cách nấu|cach nau|recipe|món|mon|nấu|nau|làm|lam|tìm|tim|gợi ý|goi y|recommend|rcm|cho|của|cua|về|ve)\b",
            " ",
            cleaned,
            flags=re.IGNORECASE,
        )
        cleaned = re.sub(r"\s+", " ", cleaned).strip(" ,.-\t")
        return cleaned or text

    @staticmethod
    def _extract_preference_query(message: str) -> str:
        text = (message or "").strip()
        if not text:
            return ""
        patterns = [
            r"(?:hôm nay\s+)?(?:tôi\s+)?muốn ăn\s+(.+)",
            r"(?:hom nay\s+)?(?:toi\s+)?muon an\s+(.+)",
            r"(?:hôm nay\s+)?(?:tôi\s+)?thích ăn\s+(.+)",
            r"(?:hom nay\s+)?(?:toi\s+)?thich an\s+(.+)",
            r"(?:hôm nay\s+)?(?:tôi\s+)?thèm\s+(.+)",
            r"(?:hom nay\s+)?(?:toi\s+)?them\s+(.+)",
        ]
        for pattern in patterns:
            match = re.search(pattern, text, flags=re.IGNORECASE)
            if match:
                extracted = re.sub(r"[?.!,]+$", "", match.group(1).strip())
                return extracted
        return ""

    @staticmethod
    def _extract_weather_profile(message: str) -> dict:
        text = CoachService._normalize_match_text(message)
        if not text:
            return {}

        weather: str | None = None
        if any(token in text for token in ("nang nong", "troi nong", "oi buc", "nong buc", "mua he")):
            weather = "hot"
        elif any(token in text for token in ("troi lanh", "lanh", "ret")):
            weather = "cold"
        elif "mua" in text:
            weather = "rainy"
        elif "mat" in text:
            weather = "cool"

        wants_light = any(token in text for token in ("an nhe", "do an nhe", "nhe bung", "it dau", "it beo"))
        wants_refreshing = any(token in text for token in ("mat", "giai nhiet", "thanh mat", "de an"))
        wants_warm = any(token in text for token in ("am bung", "an nong", "mon nong", "am nong", "am"))
        wants_list = any(token in text for token in ("danh sach", "goi y", "mon nao", "an gi"))

        profile = {
            "weather": weather,
            "wants_light": wants_light,
            "wants_refreshing": wants_refreshing,
            "wants_warm": wants_warm,
            "wants_list": wants_list,
        }
        has_weather_signal = bool(weather or wants_light or wants_refreshing or wants_warm)
        return profile if has_weather_signal else {}

    @staticmethod
    def _is_vague_food_request(message: str) -> bool:
        text = (message or "").strip().lower()
        if not text:
            return True
        vague_phrases = [
            "món khác",
            "mon khac",
            "khác",
            "khac",
            "món khác nữa",
            "mon khac nua",
            "đổi món",
            "doi mon",
            "gợi ý khác",
            "goi y khac",
            "món khác đi",
            "mon khac di",
        ]
        return any(phrase in text for phrase in vague_phrases) or len(text.split()) <= 2

    @staticmethod
    def _extract_last_recommended_name(conversation_history) -> str:
        if not conversation_history:
            return ""
        pattern = re.compile(r"(?:gợi ý|goi y|mình gợi ý|theo món)\s+['\"]?([^'\".]+?)['\"]?(?:\s*\(|,|\.|$)", re.IGNORECASE)
        for item in reversed(conversation_history):
            role = getattr(item, "role", None) if not isinstance(item, dict) else item.get("role")
            content = getattr(item, "content", "") if not isinstance(item, dict) else item.get("content", "")
            if role != "assistant":
                continue
            match = pattern.search(content or "")
            if match:
                return match.group(1).strip()
        return ""

    @staticmethod
    def _clean_bullet_lines(text: str) -> list[str]:
        lines: list[str] = []
        for raw_line in (text or "").splitlines():
            line = raw_line.strip()
            if not line:
                continue
            line = re.sub(r"^[\-\*\d\.\)\s]+", "", line).strip()
            if line:
                lines.append(line)
        return lines

    def _invoke_gemini_text(self, prompt: str, cache_namespace: str) -> str | None:
        return self.gemini_pool.invoke_text(
            prompt=prompt,
            model=self.settings.llm_model,
            temperature=0.2,
            cache_namespace=cache_namespace,
        )

    @staticmethod
    def _is_hard_query(message: str, base_query: str = "") -> bool:
        text = (message or "").strip()
        query = (base_query or "").strip()
        if not text:
            return False
        if len(text) >= 18:
            return True
        if len(query.split()) >= 2:
            return True
        if "?" in text or "/" in text or "," in text:
            return True
        return len(text.split()) <= 2

    def _should_try_gemini_rewrite(
        self,
        message: str,
        query: str,
        recipe_candidates: list[dict],
        food_candidates: list[dict],
    ) -> bool:
        return (
            not recipe_candidates
            and not food_candidates
            and self.settings.gemini_query_rewrite_enabled
            and self.gemini_pool.is_available()
            and self._is_hard_query(message, query)
        )

    def _should_try_gemini_fallback(self, message: str, best_item: dict | None) -> bool:
        return (
            self.settings.gemini_response_fallback_enabled
            and self.gemini_pool.is_available()
            and best_item is None
            and self._is_hard_query(message, message)
        )

    def _score_meal_plan_candidate(
        self,
        row: dict,
        remaining_kcal: float,
        remaining_protein: float,
        remaining_carbs: float,
        remaining_fat: float,
    ) -> float:
        per_meal_kcal = max(float(remaining_kcal or 0) / 3.0, 350.0)
        per_meal_protein = max(float(remaining_protein or 0) / 3.0, 20.0)
        per_meal_carbs = max(float(remaining_carbs or 0) / 3.0, 30.0)
        per_meal_fat = max(float(remaining_fat or 0) / 3.0, 10.0)
        kcal = float(row.get("calories_kcal", 0) or 0)
        protein = float(row.get("protein_g", 0) or 0)
        carbs = float(row.get("carbs_g", 0) or 0)
        fat = float(row.get("fat_g", 0) or 0)
        if kcal <= 0:
            return 1e9
        return (
            abs(kcal - per_meal_kcal) * 0.45
            + abs(protein - per_meal_protein) * 1.25
            + abs(carbs - per_meal_carbs) * 0.75
            + abs(fat - per_meal_fat) * 0.95
        )

    def _rank_meal_plan_candidates(
        self,
        candidates: list[dict],
        remaining_kcal: float,
        remaining_protein: float,
        remaining_carbs: float,
        remaining_fat: float,
        limit: int = 3,
        exclude_names: set[str] | None = None,
    ) -> list[dict]:
        exclude_names = exclude_names or set()
        ranked = sorted(
            candidates,
            key=lambda row: self._score_meal_plan_candidate(
                row,
                remaining_kcal,
                remaining_protein,
                remaining_carbs,
                remaining_fat,
            ),
        )
        picked: list[dict] = []
        seen_names = set(exclude_names)
        for item in ranked:
            name = str(item.get("name", "")).strip().lower()
            if not name or name in seen_names:
                continue
            seen_names.add(name)
            picked.append(item)
            if len(picked) >= limit:
                break
        return picked

    def _find_related_meal_plan_items(
        self,
        message: str,
        preference_query: str,
        remaining_kcal: float,
        remaining_protein: float,
        remaining_carbs: float,
        remaining_fat: float,
        limit: int = 3,
    ) -> tuple[list[dict], list[str]]:
        if not preference_query:
            return [], []

        related_flags: list[str] = []
        candidate_pool: list[dict] = []
        seen_ids: set[str] = set()

        def add_candidates(rows: list[dict]) -> None:
            for row in rows:
                row_id = str(row.get("id") or "")
                if row_id and row_id in seen_ids:
                    continue
                if row_id:
                    seen_ids.add(row_id)
                candidate_pool.append(row)

        add_candidates(self.repo.search_recipes_by_name(preference_query, limit=12))
        add_candidates(self.repo.search_foods_by_name(preference_query, limit=12))

        if not candidate_pool and self._should_try_gemini_rewrite(message, preference_query, [], []):
            rewritten_queries = self._rewrite_recipe_queries_with_gemini(message, preference_query)
            for rewritten_query in rewritten_queries:
                before_count = len(candidate_pool)
                add_candidates(self.repo.search_recipes_by_name(rewritten_query, limit=12))
                add_candidates(self.repo.search_foods_by_name(rewritten_query, limit=12))
                if len(candidate_pool) > before_count:
                    related_flags.append("gemini-rewrite")
                    break

        if not candidate_pool:
            return [], related_flags

        ranked = self._rank_meal_plan_candidates(
            candidate_pool,
            remaining_kcal=remaining_kcal,
            remaining_protein=remaining_protein,
            remaining_carbs=remaining_carbs,
            remaining_fat=remaining_fat,
            limit=limit,
        )
        return ranked, related_flags

    def _rewrite_recipe_queries_with_gemini(self, message: str, base_query: str) -> list[str]:
        if not self.settings.gemini_query_rewrite_enabled or not self.gemini_pool.is_available():
            return []
        seed_query = (base_query or message or "").strip()
        if not seed_query:
            return []
        prompt = (
            "Bạn là bộ chuẩn hóa query search món ăn cho app dinh dưỡng.\n"
            "Nhiệm vụ: đổi câu user thành tối đa 3 query ngắn, dễ search trong DB món ăn.\n"
            "Giữ nguyên ý chính, sửa typo, chuyển từ Anh-Việt lẫn lộn thành từ khóa food tự nhiên.\n"
            "Không giải thích. Trả đúng JSON array string.\n"
            f"User message: {message.strip()}\n"
            f"Base query: {seed_query}\n"
            'Ví dụ output: ["pho bo", "phở bò", "món bò nước"]'
        )
        raw = self._invoke_gemini_text(prompt, cache_namespace="recipe-rewrite")
        if not raw:
            return []
        try:
            parsed = json.loads(raw)
            if not isinstance(parsed, list):
                return []
            candidates = [str(item).strip() for item in parsed if str(item).strip()]
        except Exception:
            candidates = self._clean_bullet_lines(raw)
        seen: set[str] = set()
        result: list[str] = []
        for item in [seed_query, *candidates]:
            key = item.lower()
            if key in seen:
                continue
            seen.add(key)
            result.append(item)
            if len(result) >= 4:
                break
        return result[1:]

    def _generate_recipe_fallback_with_gemini(self, message: str, context: dict) -> str | None:
        if not self.settings.gemini_response_fallback_enabled or not self.gemini_pool.is_available():
            return None
        remaining = context.get("remaining_totals", {})
        prompt = (
            "Bạn là AI Coach dinh dưỡng cho app MenuGreen.\n"
            "Hãy trả lời NGẮN bằng tiếng Việt, tối đa 4 câu.\n"
            "Mục tiêu: khi DB chưa có món khớp, vẫn gợi ý hướng ăn uống thực tế và nói rõ đây là gợi ý AI.\n"
            "Không bịa như thể có dữ liệu DB. Không chẩn đoán y khoa. Không nói quá chắc chắn.\n"
            f"User message: {message.strip()}\n"
            f"Remaining calories today: {remaining.get('calories_kcal', 0)}\n"
            f"Remaining protein/carbs/fat: {remaining.get('protein_g', 0)}/{remaining.get('carbs_g', 0)}/{remaining.get('fat_g', 0)}\n"
            "Hãy gợi ý 1-2 hướng món hoặc nhóm thực phẩm dễ áp dụng."
        )
        return self._invoke_gemini_text(prompt, cache_namespace="recipe-fallback")

    @staticmethod
    def _extract_budget_vnd(message: str) -> int | None:
        text = CoachService._normalize_match_text(message)
        if not text:
            return None
        patterns = [
            r"(?:duoi|khong qua|toi da|max)\s*(\d+(?:[.,]\d+)?)\s*(k|nghin|ngan|trieu|vnd|d)?",
            r"(\d+(?:[.,]\d+)?)\s*(k|nghin|ngan|trieu|vnd)\b",
        ]
        for pattern in patterns:
            match = re.search(pattern, text)
            if not match:
                continue
            raw_value = match.group(1).replace(",", ".")
            unit = (match.group(2) or "").strip()
            try:
                value = float(raw_value)
            except Exception:
                continue
            if unit in {"k", "nghin", "ngan"}:
                return int(value * 1000)
            if unit == "trieu":
                return int(value * 1_000_000)
            return int(value)
        return None

    @staticmethod
    def _extract_time_limit_min(message: str) -> int | None:
        text = CoachService._normalize_match_text(message)
        if not text:
            return None
        match = re.search(r"(\d+)\s*(phut|p)\b", text)
        if match:
            try:
                return max(int(match.group(1)), 1)
            except Exception:
                return None
        if "nhanh" in text or "gap" in text:
            return 20
        return None

    @staticmethod
    def _extract_meal_slot(message: str) -> str | None:
        text = CoachService._normalize_match_text(message)
        if not text:
            return None
        if any(token in text for token in ("bua trua", "an trua", "trua")):
            return "lunch"
        if any(token in text for token in ("bua sang", "an sang", "sang")):
            return "breakfast"
        if any(token in text for token in ("bua toi", "an toi", "toi nay", "buoi toi")):
            return "dinner"
        return None

    @staticmethod
    def _wants_remaining_kcal(message: str) -> bool:
        text = CoachService._normalize_match_text(message)
        if not text:
            return False
        phrases = (
            "con bao nhieu kcal",
            "con bao nhieu calo",
            "bao nhieu kcal con lai",
            "bao nhieu calo con lai",
            "con lai bao nhieu kcal",
            "con lai bao nhieu calo",
        )
        return any(phrase in text for phrase in phrases)

    @staticmethod
    def _meal_slot_label(slot: str | None) -> str:
        return {
            "breakfast": "bữa sáng",
            "lunch": "bữa trưa",
            "dinner": "bữa tối",
        }.get(slot or "", "bữa ăn")

    @staticmethod
    def _meal_slot_score(slot: str | None, row: dict) -> int:
        if not slot:
            return 0
        meal_type = CoachService._normalize_match_text(str(row.get("meal_type") or ""))
        name = CoachService._normalize_match_text(str(row.get("name") or ""))
        description = CoachService._normalize_match_text(str(row.get("description") or ""))
        haystack = " ".join(part for part in (meal_type, name, description) if part)
        if not haystack:
            return 1

        breakfast_tokens = ("sang", "yen mach", "sinh to", "smoothie", "oat", "chao")
        dinner_tokens = ("toi", "salad", "sup", "canh")

        if slot == "breakfast":
            if any(token in haystack for token in breakfast_tokens):
                return 0
            if "trua" in haystack or any(token in haystack for token in dinner_tokens):
                return 2
            return 1
        if slot == "lunch":
            if any(token in haystack for token in breakfast_tokens):
                return 2
            return 0
        if slot == "dinner":
            if any(token in haystack for token in dinner_tokens):
                return 0
            if any(token in haystack for token in breakfast_tokens):
                return 2
            return 1
        return 0

    @staticmethod
    def _weather_keyword_score(profile: dict, row: dict) -> int:
        weather = profile.get("weather")
        wants_light = bool(profile.get("wants_light"))
        wants_refreshing = bool(profile.get("wants_refreshing"))
        wants_warm = bool(profile.get("wants_warm"))

        name = CoachService._normalize_match_text(str(row.get("name") or ""))
        description = CoachService._normalize_match_text(str(row.get("description") or ""))
        meal_type = CoachService._normalize_match_text(str(row.get("meal_type") or ""))
        haystack = " ".join(part for part in (name, description, meal_type) if part)

        cool_tokens = ("salad", "sinh to", "smoothie", "sua chua", "chanh", "rau", "trai cay", "bo", "mang tay")
        warm_tokens = ("pho", "bun", "sup", "canh", "chao", "nuoc", "nong", "ham")

        score = 0
        if weather in ("hot", "cool"):
            if any(token in haystack for token in cool_tokens):
                score -= 3
            if any(token in haystack for token in warm_tokens):
                score += 3
        if weather in ("cold", "rainy"):
            if any(token in haystack for token in warm_tokens):
                score -= 3
            if any(token in haystack for token in cool_tokens):
                score += 2
        if wants_refreshing and any(token in haystack for token in cool_tokens):
            score -= 2
        if wants_warm and any(token in haystack for token in warm_tokens):
            score -= 2
        if wants_light:
            if "salad" in haystack or "rau" in haystack or "sinh to" in haystack:
                score -= 1
            if "chien" in haystack or "xao" in haystack:
                score += 2
        return score

    def _find_weather_meal_items(
        self,
        context: dict,
        message: str,
        limit: int = 4,
    ) -> tuple[list[dict], dict]:
        profile = self._extract_weather_profile(message)
        if not profile:
            return [], {}

        remaining = context.get("remaining_totals", {})
        candidates = self.repo.list_active_recipes(limit=80) + self.repo.list_active_foods(limit=120)
        if not candidates:
            return [], profile

        if profile.get("weather") == "hot":
            target_kcal = 320.0
        elif profile.get("weather") in ("cold", "rainy"):
            target_kcal = 430.0
        else:
            target_kcal = max(float(remaining.get("calories_kcal", 0) or 0) / 3.0, 350.0)

        ranked = sorted(
            candidates,
            key=lambda row: (
                self._weather_keyword_score(profile, row),
                abs(float(row.get("calories_kcal", 0) or 0) - target_kcal),
                float(row.get("fat_g", 0) or 0) if profile.get("wants_light") or profile.get("weather") == "hot" else 0.0,
                float(row.get("estimated_price_vnd", 0) or 0),
            ),
        )

        picked: list[dict] = []
        seen_names: set[str] = set()
        for row in ranked:
            name = str(row.get("name") or "").strip().lower()
            if not name or name in seen_names:
                continue
            kcal = float(row.get("calories_kcal", 0) or 0)
            if kcal <= 0:
                continue
            seen_names.add(name)
            picked.append(row)
            if len(picked) >= limit:
                break
        return picked, profile

    def _find_constrained_meal_items(
        self,
        context: dict,
        message: str,
        limit: int = 3,
    ) -> tuple[list[dict], dict]:
        meal_slot = self._extract_meal_slot(message)
        budget_vnd = self._extract_budget_vnd(message)
        time_limit_min = self._extract_time_limit_min(message)
        wants_remaining = self._wants_remaining_kcal(message)

        if not any([meal_slot, budget_vnd, time_limit_min, wants_remaining]):
            return [], {}

        remaining = context.get("remaining_totals", {})
        max_price_vnd = budget_vnd if budget_vnd is not None else 250000
        max_total_time_min = time_limit_min if time_limit_min is not None else 240
        candidates = self.repo.list_meal_candidates_by_constraints(
            max_price_vnd=max_price_vnd,
            max_total_time_min=max_total_time_min,
            max_items=200,
        )
        if not candidates:
            return [], {
                "meal_slot": meal_slot,
                "budget_vnd": budget_vnd,
                "time_limit_min": time_limit_min,
                "wants_remaining": wants_remaining,
            }

        per_meal_target = max(float(remaining.get("calories_kcal", 0) or 0) / 3.0, 350.0)
        if meal_slot == "breakfast":
            per_meal_target = min(per_meal_target, 400.0)
        elif meal_slot == "dinner":
            per_meal_target = max(per_meal_target, 400.0)

        ranked = sorted(
            candidates,
            key=lambda row: (
                self._meal_slot_score(meal_slot, row),
                abs(float(row.get("calories_kcal", 0) or 0) - per_meal_target),
                0 if row.get("source") == "recipe" else 1,
                float(row.get("estimated_price_vnd", 0) or 0),
                float((row.get("prep_time_min", 0) or 0) + (row.get("cook_time_min", 0) or 0)),
            ),
        )
        picked: list[dict] = []
        seen_names: set[str] = set()
        for row in ranked:
            name = str(row.get("name") or "").strip().lower()
            if not name or name in seen_names:
                continue
            seen_names.add(name)
            picked.append(row)
            if len(picked) >= limit:
                break
        return picked, {
            "meal_slot": meal_slot,
            "budget_vnd": budget_vnd,
            "time_limit_min": time_limit_min,
            "wants_remaining": wants_remaining,
        }

    @staticmethod
    def _score_recipe_row(row: dict, query: str, exclude_name: str = "") -> tuple[int, float, int]:
        name = str(row.get("name", "")).lower()
        query_text = (query or "").lower().strip()
        similarity = float(row.get("similarity", 0) or 0)
        exact_match = 0 if query_text and query_text == name else 1
        variant_penalty = 1 if any(
            token in name
            for token in [
                "ít đậu",
                "nhiều đạm",
                "ít tinh bột",
                "ít dầu",
                "healthy",
                "giảm cân",
                "protein",
            ]
        ) else 0
        exclude_penalty = 1 if exclude_name and exclude_name.lower() in name else 0
        return (exact_match + variant_penalty + exclude_penalty, -similarity, len(name))

    async def reply(self, request: ChatRequest) -> ChatResponse:
        request_id = request.request_id or str(uuid.uuid4())
        thread_id = request.thread_id or request.user_id or request_id

        profile = self.repo.get_profile(request.user_id) if request.user_id else None
        plan = self.repo.get_subscription_plan(request.user_id) if request.user_id else "free"
        logs_7d = self.repo.get_meal_logs_7d(request.user_id) if request.user_id else []
        context = build_context_snapshot(profile, logs_7d)
        last_recommended_name = self._extract_last_recommended_name(request.conversation_history)
        urls = self._extract_urls(request.message)
        contextual_intent = self._infer_contextual_intent(
            request.message,
            request.conversation_history,
            last_recommended_name,
        )
        is_short_followup = len(self._normalize_match_text(request.message).split()) <= 8

        if urls and self._looks_like_recipe_url(request.message, urls[0]):
            analyzed = self._analyze_recipe_link(request.message, urls[0])
            if analyzed:
                response_text, route_flags = analyzed
                intent = "recipe_search"
                source = (
                    "gemini"
                    if "gemini-url-analysis" in route_flags or "gemini-url-context" in route_flags
                    else "fallback"
                )
                confidence = None
            else:
                intent = self._heuristic_intent(request.message) or "general"
                response_text, route_flags = self._compose_contextual_response(
                    intent,
                    context,
                    request.message,
                    request.conversation_history,
                    last_recommended_name,
                )
                source = "fallback"
                confidence = None
        elif self.classifier is not None:
            intent, score = self.classifier.predict(request.message)
            threshold = float(getattr(self.settings, "intent_confidence_threshold", 0.45))
            heuristic_intent = self._heuristic_intent(request.message)
            if score < threshold:
                intent = contextual_intent or heuristic_intent or "general"
            elif intent in ("unknown", ""):
                intent = contextual_intent or heuristic_intent or "general"
            elif contextual_intent and is_short_followup:
                intent = contextual_intent
            elif heuristic_intent == "meal_plan" and intent in ("general", "recipe_search", "nutrition_calc"):
                intent = "meal_plan"
            elif heuristic_intent == "recipe_search" and intent in ("general", "meal_plan", "nutrition_calc"):
                intent = "recipe_search"
            response_text, route_flags = self._compose_contextual_response(
                intent,
                context,
                request.message,
                request.conversation_history,
                last_recommended_name,
            )
            source = "onnx"
            confidence = round(score, 4)
        else:
            intent = contextual_intent or self._heuristic_intent(request.message) or "general"
            response_text, route_flags = self._compose_contextual_response(
                intent,
                context,
                request.message,
                request.conversation_history,
                last_recommended_name,
            )
            source = "fallback"
            confidence = None

        if not request.skip_save:
            self.repo.save_chat_session(
                user_id=request.user_id,
                thread_id=thread_id,
                role="user",
                content=request.message,
                context_snapshot=context,
                model_name=self.settings.llm_model,
            )
        safe_response, safety_flags = self.safety.apply(
            user_message=request.message,
            response_text=response_text,
            context=context,
        )

        if not request.skip_save:
            self.repo.save_chat_session(
                user_id=request.user_id,
                thread_id=thread_id,
                role="assistant",
                content=safe_response,
                context_snapshot=context,
                model_name=self.settings.llm_model,
            )
        source_parts = [source, *route_flags]
        if safety_flags:
            source_parts.append("safety")
        final_source = "+".join(dict.fromkeys(part for part in source_parts if part))

        return ChatResponse(
            response=safe_response,
            intent=intent,
            source=final_source,
            request_id=request_id,
            thread_id=thread_id,
            intent_confidence=confidence,
            subscription_tier=plan if plan in ("free", "saving", "energy", "performance") else "free",
            actions=self.action_service.suggest_for_chat(intent, request.message, context),
            suggested_prompts=self.action_service.suggested_prompts(context, intent),
            safety_flags=safety_flags,
            context_summary=context_summary_from_snapshot(context),
            recommendation_refs=[],
        )

    def _compose_contextual_response(
        self,
        intent: str,
        context: dict,
        message: str,
        conversation_history=None,
        last_recommended_name: str = "",
    ) -> tuple[str, list[str]]:
        totals = context.get("today_totals", {})
        remaining = context.get("remaining_totals", {})
        targets = context.get("targets", {})
        profile = context.get("profile", {})
        goal = profile.get("goal", "maintain")
        normalized_text = CoachService._normalize_match_text(message)

        if intent == "nutrition_calc":
            is_status_check = any(
                phrase in normalized_text
                for phrase in (
                    "con lai", "con bao nhieu", "hom nay nap", "da nap", "lich su an"
                )
            )
            if not is_status_check and self.gemini_pool.is_available():
                prompt = (
                    "Bạn là AI Coach dinh dưỡng cho ứng dụng MenuGreen.\n"
                    "Hãy trả lời câu hỏi tính toán calo hoặc tư vấn dinh dưỡng của người dùng bằng tiếng Việt, một cách NGẮN GỌN, dễ hiểu và chuyên nghiệp.\n"
                    "Hãy áp dụng các quy tắc/công thức tính toán dưới đây khi người dùng hỏi các vấn đề liên quan:\n"
                    "1. Chỉ số BMI: BMI = Cân nặng (kg) / [Chiều cao (m)]^2. Phân loại theo chuẩn WHO:\n"
                    "   - < 18.5: Gầy\n"
                    "   - 18.5 - 24.9: Bình thường\n"
                    "   - 25.0 - 29.9: Thừa cân\n"
                    "   - >= 30.0: Béo phì\n"
                    "2. Giảm cân & Thâm hụt Calo: 1kg mỡ thừa tương đương khoảng 7700 kcal. Mức thâm hụt calo hằng ngày khuyến nghị là 500-1000 kcal so với TDEE (tuyệt đối không để lượng calo nạp hằng ngày thấp dưới mức BMR của họ).\n"
                    "3. Phân bổ Macro theo chế độ ăn kiêng cụ thể:\n"
                    "   - Keto: 5% Carbs, 25% Protein, 70% Fat.\n"
                    "   - Low-Carb: 20% Carbs, 40% Protein, 40% Fat.\n"
                    "   - Tăng cơ (High-Protein): 40% Carbs, 30% Protein, 30% Fat.\n"
                    "   - Cân bằng (Balanced): 50% Carbs, 20% Protein, 30% Fat.\n"
                    "Tính toán số liệu cụ thể dựa trên chỉ số của người dùng dưới đây nếu họ yêu cầu thiết lập chế độ.\n\n"
                    "Dưới đây là thông tin hiện tại của người dùng trong hệ thống (sử dụng nếu liên quan):\n"
                    f"- Mục tiêu: {goal}\n"
                    f"- Chiều cao/Cân nặng: {profile.get('height_cm', profile.get('HeightCm', '?'))} cm, {profile.get('weight_kg', profile.get('WeightKg', '?'))} kg\n"
                    f"- BMI: {profile.get('bmi', '?')}\n"
                    f"- BMR/TDEE: {profile.get('bmr_kcal', '?')} kcal / {profile.get('tdee_kcal', '?')} kcal\n"
                    f"- Dinh dưỡng hôm nay đã nạp: {totals.get('calories_kcal', 0)} kcal (P/C/F = {totals.get('protein_g', 0)}/{totals.get('carbs_g', 0)}/{totals.get('fat_g', 0)}g)\n"
                    f"- Mục tiêu ngày: {targets.get('calories_kcal', 0)} kcal\n\n"
                    f"Câu hỏi của user: {message.strip()}\n"
                )
                response_text = self._invoke_gemini_text(prompt, cache_namespace="nutrition-calc")
                if response_text:
                    return response_text, ["gemini-calc"]

            return (
                f"Hôm nay (mục tiêu: {goal}) bạn đã nạp {totals.get('calories_kcal', 0)} kcal, "
                f"P/C/F = {totals.get('protein_g', 0)}/{totals.get('carbs_g', 0)}/{totals.get('fat_g', 0)}g. "
                f"Còn lại: {remaining.get('calories_kcal', 0)} kcal, "
                f"P/C/F = {remaining.get('protein_g', 0)}/{remaining.get('carbs_g', 0)}/{remaining.get('fat_g', 0)}g "
                f"(target: {targets.get('calories_kcal', 0)} kcal).",
                [],
            )

        if intent == "recipe_search":
            query = self._extract_recipe_query(message)
            if self._is_vague_food_request(message) and conversation_history:
                query = last_recommended_name or query

            hybrid_flags: list[str] = ["recipe-detail"]
            display_query = query if query else (message or "").strip()
            recipe_candidates = self.repo.search_recipes_by_name(query, limit=5)
            food_candidates = self.repo.search_foods_by_name(query, limit=5)

            if self._should_try_gemini_rewrite(message, query, recipe_candidates, food_candidates):
                rewritten_queries = self._rewrite_recipe_queries_with_gemini(message, query)
                for rewritten_query in rewritten_queries:
                    recipe_candidates = self.repo.search_recipes_by_name(rewritten_query, limit=5)
                    food_candidates = self.repo.search_foods_by_name(rewritten_query, limit=5)
                    if recipe_candidates or food_candidates:
                        query = rewritten_query
                        display_query = rewritten_query
                        hybrid_flags.append("gemini-rewrite")
                        break

            best_item = None
            if recipe_candidates:
                best_item = sorted(recipe_candidates, key=lambda row: self._score_recipe_row(row, query, last_recommended_name))[0]
            elif food_candidates:
                best_item = sorted(food_candidates, key=lambda row: self._score_recipe_row(row, query, last_recommended_name))[0]
            if not best_item:
                fallback_items = self.repo.suggest_meal_plan_items(
                    remaining_kcal=float(remaining.get("calories_kcal", 0) or 0),
                    remaining_protein=float(remaining.get("protein_g", 0) or 0),
                    remaining_carbs=float(remaining.get("carbs_g", 0) or 0),
                    remaining_fat=float(remaining.get("fat_g", 0) or 0),
                    limit=1,
                )
                best_item = fallback_items[0] if fallback_items else None
            if not best_item:
                active_pool = self.repo.list_active_recipes(limit=5) + self.repo.list_active_foods(limit=5)
                if active_pool:
                    best_item = sorted(active_pool, key=lambda row: self._score_recipe_row(row, query, last_recommended_name))[0]

            if best_item:
                name = best_item.get("name", "unknown")
                kcal = best_item.get("calories_kcal", "?")
                detail = self._format_recipe_detail(best_item) if best_item.get("instructions") else ""
                suggestion_text = f"{name} ({kcal} kcal{detail})"
                return (
                    f"Theo món '{display_query}', mình gợi ý 1 món chính: {suggestion_text}. "
                    f"Hôm nay bạn đang ở mức {totals.get('calories_kcal', 0)} kcal "
                    f"và còn {remaining.get('calories_kcal', 0)} kcal cho ngày hôm nay.",
                    hybrid_flags,
                )

            gemini_fallback = None
            if self._should_try_gemini_fallback(message, best_item):
                gemini_fallback = self._generate_recipe_fallback_with_gemini(message, context)
            if gemini_fallback:
                hybrid_flags.append("gemini-fallback")
                return gemini_fallback, hybrid_flags

            return (
                f"Theo món '{display_query}', mình tạm gợi ý mặc định: trứng luộc + rau luộc. "
                f"Hôm nay bạn đang ở mức {totals.get('calories_kcal', 0)} kcal "
                f"và còn {remaining.get('calories_kcal', 0)} kcal cho ngày hôm nay.",
                hybrid_flags,
            )

        if intent == "ai_search":
            q = (message or "").strip()
            return (
                f"Mình đã nhận yêu cầu AI search cho: '{q}'. "
                "Hiện runtime này đang trả câu trả lời dạng định hướng để BE tích hợp search provider "
                "(web/search API) ở bước tiếp theo. "
                "Bạn có thể bật pipeline search để mình trả kết quả có nguồn trích dẫn.",
                [],
            )

        if intent in ("general", "unknown"):
            return (
                "Xin lỗi, câu hỏi này nằm ngoài phạm vi hỗ trợ hiện tại của AI Coach. "
                "Mình đang tập trung vào món ăn, dinh dưỡng, thực đơn và truy vấn công thức. "
                "Bạn có thể hỏi lại theo hướng đó, hoặc đổi sang câu hỏi về calo, món ăn, hay kế hoạch bữa ăn.",
                [],
            )

        if intent == "meal_plan":
            remain_kcal = remaining.get("calories_kcal", 0)
            remain_protein = remaining.get("protein_g", 0)
            remain_carbs = remaining.get("carbs_g", 0)
            remain_fat = remaining.get("fat_g", 0)
            dish_only_request = self._is_dish_only_recommendation(message)
            has_daily_target = any(
                float(remaining.get(field, 0) or 0) > 0
                for field in ("calories_kcal", "protein_g", "carbs_g", "fat_g")
            )
            preference_query = self._extract_preference_query(message)
            route_flags: list[str] = []
            weather_items, weather_profile = self._find_weather_meal_items(context, message, limit=4)

            if weather_items and weather_profile:
                if dish_only_request:
                    return self._dish_only_response(weather_items), ["dish-only"]
                weather = weather_profile.get("weather")
                weather_label = {
                    "hot": "trời nắng nóng",
                    "cold": "trời lạnh",
                    "rainy": "trời mưa",
                    "cool": "thời tiết mát",
                }.get(weather, "thời tiết hiện tại")
                style_bits: list[str] = []
                if weather_profile.get("wants_light"):
                    style_bits.append("nhẹ")
                if weather_profile.get("wants_refreshing"):
                    style_bits.append("mát")
                if weather_profile.get("wants_warm"):
                    style_bits.append("ấm nóng")

                item_lines: list[str] = []
                for item in weather_items:
                    name = item.get("name", "unknown")
                    kcal = float(item.get("calories_kcal", 0) or 0)
                    price = int(float(item.get("estimated_price_vnd", 0) or 0))
                    detail_parts = [f"{kcal:.1f} kcal"]
                    if price > 0:
                        detail_parts.append(f"~{price:,}đ".replace(",", "."))
                    item_lines.append(f"{name} ({', '.join(detail_parts)})")

                style_text = f" kiểu {'/'.join(style_bits)}" if style_bits else ""
                return (
                    f"Với {weather_label}{style_text}, mình gợi ý {len(item_lines)} món phù hợp: {'; '.join(item_lines)}.",
                    route_flags,
                )
            constrained_items, constraints = self._find_constrained_meal_items(context, message, limit=3)

            remaining_text = ""
            if constraints.get("wants_remaining"):
                if has_daily_target:
                    remaining_text = (
                        f"Hôm nay bạn đã nạp {totals.get('calories_kcal', 0)} kcal "
                        f"và còn khoảng {remain_kcal} kcal cho ngày hôm nay. "
                    )
                else:
                    remaining_text = (
                        f"Hôm nay bạn đã nạp khoảng {totals.get('calories_kcal', 0)} kcal. "
                        "Mình chưa tính chính xác phần còn lại vì bạn chưa thiết lập mục tiêu ngày. "
                    )

            if constrained_items:
                if dish_only_request:
                    resp = self._dish_only_response(constrained_items)
                    if remaining_text:
                        resp = f"{remaining_text}{resp}"
                    return resp, ["dish-only"]
                slot_label = self._meal_slot_label(constraints.get("meal_slot"))
                budget_vnd = constraints.get("budget_vnd")
                time_limit_min = constraints.get("time_limit_min")
                condition_parts: list[str] = []
                if constraints.get("meal_slot"):
                    condition_parts.append(slot_label)
                if budget_vnd:
                    condition_parts.append(f"dưới {budget_vnd:,}đ".replace(",", "."))
                if time_limit_min:
                    condition_parts.append(f"trong khoảng {time_limit_min} phút")

                option_lines: list[str] = []
                for item in constrained_items:
                    name = item.get("name", "unknown")
                    kcal = float(item.get("calories_kcal", 0) or 0)
                    price = int(float(item.get("estimated_price_vnd", 0) or 0))
                    total_time = int(
                        float(item.get("total_time_min", 0) or 0)
                        or float(item.get("prep_time_min", 0) or 0) + float(item.get("cook_time_min", 0) or 0)
                    )
                    detail_parts = [f"{kcal:.1f} kcal"]
                    if price > 0:
                        detail_parts.append(f"~{price:,}đ".replace(",", "."))
                    if total_time > 0:
                        detail_parts.append(f"{total_time} phút")
                    option_lines.append(f"{name} ({', '.join(detail_parts)})")

                intro = "Mình gợi ý vài món phù hợp như sau"
                if condition_parts:
                    intro = f"Với yêu cầu {' '.join(condition_parts)}, mình gợi ý {len(option_lines)} lựa chọn"
                return (
                    f"{remaining_text}{intro}: {'; '.join(option_lines)}.",
                    route_flags,
                )
            if constraints and any(
                constraints.get(key) for key in ("meal_slot", "budget_vnd", "time_limit_min")
            ):
                condition_parts: list[str] = []
                if constraints.get("meal_slot"):
                    condition_parts.append(self._meal_slot_label(constraints.get("meal_slot")))
                if constraints.get("budget_vnd"):
                    condition_parts.append(f"dưới {int(constraints['budget_vnd']):,}đ".replace(",", "."))
                if constraints.get("time_limit_min"):
                    condition_parts.append(f"trong khoảng {int(constraints['time_limit_min'])} phút")
                condition_text = " ".join(condition_parts) if condition_parts else "theo ràng buộc bạn đưa ra"
                return (
                    f"{remaining_text}Mình chưa tìm thấy món nào khớp {condition_text} trong DB hiện tại.",
                    route_flags,
                )

            suggestions: list[dict] = []
            if preference_query:
                suggestions, related_flags = self._find_related_meal_plan_items(
                    message=message,
                    preference_query=preference_query,
                    remaining_kcal=float(remain_kcal or 0),
                    remaining_protein=float(remain_protein or 0),
                    remaining_carbs=float(remain_carbs or 0),
                    remaining_fat=float(remain_fat or 0),
                    limit=3,
                )
                route_flags.extend(related_flags)

            if len(suggestions) < 3:
                general_suggestions = self.repo.suggest_meal_plan_items(
                    remaining_kcal=float(remain_kcal or 0),
                    remaining_protein=float(remain_protein or 0),
                    remaining_carbs=float(remain_carbs or 0),
                    remaining_fat=float(remain_fat or 0),
                    limit=6,
                )
                existing_names = {
                    str(item.get("name", "")).strip().lower()
                    for item in suggestions
                    if str(item.get("name", "")).strip()
                }
                for item in general_suggestions:
                    name = str(item.get("name", "")).strip().lower()
                    if not name or name in existing_names:
                        continue
                    existing_names.add(name)
                    suggestions.append(item)
                    if len(suggestions) >= 3:
                        break

            if not suggestions:
                suggestions = self.repo.suggest_meal_plan_items(
                    remaining_kcal=float(remain_kcal or 0),
                    remaining_protein=float(remain_protein or 0),
                    remaining_carbs=float(remain_carbs or 0),
                    remaining_fat=float(remain_fat or 0),
                    limit=3,
                )
            if suggestions:
                if dish_only_request:
                    resp = self._dish_only_response(suggestions)
                    if constraints.get("wants_remaining") and remaining_text:
                        resp = f"{remaining_text}{resp}"
                    return resp, [*route_flags, "dish-only"]
                meal_slots = ("Sáng", "Trưa", "Tối")
                lines: list[str] = []
                total_kcal = 0.0
                total_protein = 0.0
                total_carbs = 0.0
                total_fat = 0.0
                for idx, item in enumerate(suggestions):
                    name = item.get("name", "unknown")
                    kcal = float(item.get("calories_kcal", 0) or 0)
                    p = float(item.get("protein_g", 0) or 0)
                    c = float(item.get("carbs_g", 0) or 0)
                    f = float(item.get("fat_g", 0) or 0)
                    total_kcal += kcal
                    total_protein += p
                    total_carbs += c
                    total_fat += f
                    meal_label = meal_slots[idx] if idx < len(meal_slots) else f"Bữa {idx + 1}"
                    lines.append(f"{meal_label}: {name} ({kcal:.1f} kcal, P/C/F {p:.1f}/{c:.1f}/{f:.1f})")
                intro = "Hôm nay bạn có thể ăn 3 bữa như sau:"
                if preference_query:
                    intro = f"Vì bạn muốn ăn {preference_query}, mình gợi ý 3 bữa liên quan như sau:"
                target_text = (
                    f"Mục tiêu còn lại trong ngày hiện là {remain_kcal} kcal, "
                    f"P/C/F = {remain_protein}/{remain_carbs}/{remain_fat}g."
                    if has_daily_target
                    else "Bạn chưa thiết lập mục tiêu dinh dưỡng trong ngày, nên mình đang gợi ý theo dữ liệu món hiện có."
                )
                return (
                    f"{intro} {'; '.join(lines)}. "
                    f"Tổng 3 bữa khoảng {total_kcal:.1f} kcal, "
                    f"P/C/F = {total_protein:.1f}/{total_carbs:.1f}/{total_fat:.1f}g. "
                    f"{target_text}",
                    route_flags,
                )

            gemini_fallback = None
            if not dish_only_request and self._should_try_gemini_fallback(message, None):
                gemini_fallback = self._generate_recipe_fallback_with_gemini(message, context)
            if gemini_fallback:
                return gemini_fallback, ["gemini-fallback"]
            return (
                f"Mình chưa tìm thấy đủ món có dữ liệu macro trong DB hiện tại. "
                "Chưa đủ dữ liệu món trong DB để gợi ý 3 món cụ thể. "
                f"Phần còn lại trong ngày: {remain_kcal} kcal, "
                f"P/C/F = {remain_protein}/{remain_carbs}/{remain_fat}g.",
                [],
            )

        return (
            "Xin lỗi, câu hỏi này nằm ngoài phạm vi hỗ trợ hiện tại của AI Coach. "
            "Mình đang tập trung vào món ăn, dinh dưỡng, thực đơn và truy vấn công thức.",
            [],
        )

    @staticmethod
    def _is_dish_only_recommendation(message: str) -> bool:
        text = CoachService._normalize_match_text(message)
        if not text:
            return False

        recipe_signals = (
            "cong thuc",
            "cach nau",
            "cach lam",
            "nguyen lieu",
            "nau sao",
            "recipe",
        )
        plan_signals = (
            "thuc don",
            "meal plan",
            "ke hoach bua an",
            "3 bua",
            "ba bua",
            "7 ngay",
            "mot tuan",
            "hang tuan",
        )
        recommendation_signals = (
            "recommend",
            "rcm",
            "goi y mon",
            "goi y bua",
            "de xuat mon",
            "tu van mon",
            "an gi",
            "nen an gi",
            "mon nao",
            "co mon nao",
            "muon an",
            "thich an",
        )
        return (
            any(signal in text for signal in recommendation_signals)
            and not any(signal in text for signal in recipe_signals)
            and not any(signal in text for signal in plan_signals)
        )

    @staticmethod
    def _dish_only_response(items: list[dict]) -> str:
        options: list[str] = []
        for item in items[:3]:
            name = str(item.get("name") or "").strip()
            if not name:
                continue
            raw_kcal = item.get("calories_kcal")
            try:
                kcal_value = float(raw_kcal)
                kcal = f"{kcal_value:.1f}".rstrip("0").rstrip(".")
            except (TypeError, ValueError):
                kcal = "chưa rõ"
            options.append(f"{name} ({kcal} kcal)")

        if not options:
            return "Mình chưa tìm thấy món phù hợp trong dữ liệu hiện tại."
        return f"Mình gợi ý {len(options)} món: {'; '.join(options)}."

    @staticmethod
    def _format_recipe_detail(row: dict) -> str:
        details: list[str] = []
        total_time = row.get("total_time_min")
        if total_time:
            details.append(f"{total_time} phút")
        price = row.get("estimated_price_vnd")
        if price:
            details.append(f"~{price:,}đ".replace(",", "."))
        instructions = row.get("instructions")
        if isinstance(instructions, list) and instructions:
            steps = " → ".join(str(x).strip() for x in instructions[:3] if str(x).strip())
            if steps:
                details.append(f"cách làm: {steps}")
        return ", " + ", ".join(details) if details else ""
