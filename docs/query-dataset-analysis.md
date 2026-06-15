# Query Dataset Analysis

## File đã phân tích

- `menugreen_query_simulation_400.xlsx`

## Cấu trúc workbook

Workbook có `3` sheet:
- `Dataset_400`
- `Summary`
- `Sources`

Sheet chính để dùng cho runtime analysis là `Dataset_400`.

## Cấu trúc dữ liệu chính

Sheet `Dataset_400` có `400` dòng và `17` cột:

- `id`
- `source`
- `collection_method`
- `user_text`
- `normalized_text`
- `intent_expected`
- `constraints`
- `difficulty`
- `category`
- `expected_behavior`
- `expected_not_to_do`
- `actual_behavior`
- `status`
- `notes`
- `conversation_id`
- `turn_id`
- `source_url`

## Phân bố intent

- `meal_plan`: `263`
- `recipe_search`: `62`
- `nutrition_calc`: `50`
- `general`: `25`

Kết luận:
- dataset nghiêng mạnh về `meal_plan`
- đây là hợp lý với sản phẩm hiện tại vì phần recommendation là flow chính

## Phân bố category nổi bật

- `budget_time`: `55`
- `recipe_search`: `50`
- `typo_slang`: `47`
- `preference_ingredient`: `42`
- `nutrition_calc`: `40`
- `meal_plan_general`: `39`
- `dialog_flow`: `36`
- `multi_constraint`: `31`
- `weather`: `29`
- `general_fallback`: `25`

Kết luận:
- dataset không chỉ test intent đơn
- nó test mạnh các pattern thực tế như typo, follow-up, nhiều constraint, weather, sở thích nguyên liệu

## Constraint xuất hiện nhiều nhất

Các constraint phổ biến:

- `meal=dinner`
- `meal=lunch`
- `meal=breakfast`
- `metric=kcal_remaining`
- `nutrition=high_protein`
- `budget<=50000`
- `budget<=60000`
- `time<=20`
- `time<=30`
- `ingredient=shrimp`
- `ingredient=salmon`
- `ingredient=tofu`
- `weather=hot`
- `digestion=light`
- `goal=weight_loss`
- `avoid=oily`
- `inherit_context=true`

Kết luận:
- runtime nên ưu tiên hỗ trợ tốt:
  - bữa sáng/trưa/tối
  - budget
  - thời gian nấu
  - ingredient preference
  - weather
  - low-fat/light digestion
  - follow-up có ngữ cảnh

## Điểm yếu runtime trước khi vá

Khi đo nhanh bằng `CoachService._heuristic_intent(...)` trên toàn bộ `400` câu:

- đúng: `219 / 400`
- accuracy xấp xỉ: `54.75%`

Các nhóm miss lớn nhất:

- `recipe_search`
- `budget_time`
- `preference_ingredient`
- `multi_constraint`
- `dialog_flow`
- `typo_slang`
- `nutrition_calc`

Nguyên nhân chính:

1. keyword `recipe_search` quá rộng
   - từ như `món`, `cơm`, `bún` làm nhiều câu recommendation bị route sai sang recipe

2. thiếu rule cho budget/time
   - các câu như `bữa tối dưới 30k`, `dưới 20 phút` chưa được coi là meal-plan rõ ràng

3. thiếu support typo/slang
   - ví dụ `an j`, `mon re cho sv`

4. thiếu support dialog follow-up
   - ví dụ `bữa trưa thôi`, `có món khác không`, `tôi đang giảm cân`

5. thiếu phân biệt `nutrition_calc` và `meal_plan` trong câu hỗn hợp

## Các thay đổi code đã bổ sung từ dataset này

Đã cập nhật tại:

- [coach_service.py](/D:/EXE/RAG_AI_MenuGreen/runtime/app/services/coach_service.py)

### 1. Mở rộng heuristic routing

Đã thêm nhiều pattern cho:

- `meal_plan`
  - `goi y mon`
  - `co mon nao`
  - `mon nao`
  - `doi mon`
  - `eat clean`
  - `healthy`
  - `no lau`
  - `nhanh`
  - `it beo`
  - `it dau`
  - `mon re cho sv`
  - `co mon khac`
  - `bua trua thoi`
  - `toi dang giam can`

- `nutrition_calc`
  - `protein`
  - `carb`
  - `fat`
  - `macro`
  - `vuot kcal`
  - `du chua`
  - `tinh kcal`

- `recipe_search`
  - `cong thuc`
  - `cach nau`
  - `cach lam`
  - `nguyen lieu`
  - pattern kiểu `nau ...`
  - pattern kiểu `lam trong 20 phut`

- `general`
  - thêm chặn sớm cho các câu ngoài domain như:
    - email
    - facebook
    - laptop gaming
    - lịch đá bóng
    - tạo ảnh
    - tổng thống

### 2. Cải thiện nhóm weather

Đã có flow nhận biết:

- `trời nóng`
- `nắng nóng`
- `trời lạnh`
- `trời mưa`
- `nhẹ`
- `mát`
- `ấm nóng`

và rank món theo kiểu thời tiết thay vì rơi về `general`.

### 3. Cải thiện meal-plan có constraint

Đã có flow riêng cho:

- `bữa sáng / trưa / tối`
- `dưới 60k`
- `nhanh`
- `20 phút`
- kết hợp với câu kiểu `còn bao nhiêu kcal`

### 4. Tách tốt hơn giữa `nutrition_calc` và `meal_plan`

Nếu câu có cả:
- `gợi ý`
- `bữa`
- `ăn gì`

thì đi `meal_plan`.

Nếu câu chủ yếu là:
- kiểm tra macro
- còn bao nhiêu kcal
- vượt kcal không

thì vẫn giữ `nutrition_calc`.

## Kết quả sau khi vá

Đo lại bằng `CoachService._heuristic_intent(...)` trên cùng `400` câu:

- đúng: `383 / 400`
- accuracy xấp xỉ: `95.75%`

## Các nhóm còn chưa phủ hết hoàn toàn

Sau khi vá, các nhóm còn miss ít nhưng vẫn đáng theo dõi:

- `nutrition_calc`
- `dialog_flow`
- `general_fallback`
- `recipe_search`

### Cụ thể

1. `nutrition_calc`
- một số câu kiểm tra kcal có chữ `ăn` hoặc có ngữ cảnh món vẫn dễ bị hiểu là recommendation

2. `dialog_flow`
- các câu follow-up rất ngắn vẫn phụ thuộc ngữ cảnh trước đó
- ví dụ:
  - `không đúng ý tôi`
  - `có món khác không`

3. `general_fallback`
- vẫn còn vài câu ngoài domain có thể chứa động từ kiểu `làm` làm router nghiêng sai

4. `recipe_search`
- vẫn còn một vài câu kiểu:
  - `Có món salad eat clean nào...`
  - ranh giới giữa `recipe search` và `meal recommendation` hơi mờ

## Kết luận

Dataset này rất hữu ích vì nó phản ánh đúng các luồng user thực tế hơn là chỉ câu ngắn chuẩn textbook.

Kết luận quan trọng:

1. Chưa cần retrain ngay chỉ vì có thêm flow mới.
2. Rule/routing/service-layer hiện tại vẫn cải thiện được rất nhiều nếu dựa trên dataset thật.
3. Bộ 400 câu này đủ tốt để làm regression set ban đầu.
4. Nếu sau này muốn retrain, nên ưu tiên lấy thêm mẫu ở các nhóm còn miss:
   - `nutrition_calc`
   - `dialog_flow`
   - ranh giới `meal_plan` vs `recipe_search`

## Đề xuất bước tiếp theo

1. Gắn dataset này vào test tự động cho router intent.
2. Thêm `actual_behavior` và `status` sau mỗi lần test regression.
3. Tạo một file CSV chuẩn hóa từ sheet `Dataset_400` để dễ chạy test CI hơn.
4. Khi số câu fail tăng lại ở cùng một pattern, mới cân nhắc retrain ONNX.
