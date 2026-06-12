# Deploy Readiness Review

## Kết luận nhanh

Hiện tại app **chưa nên deploy public production**.

App có thể chạy để:
- demo nội bộ
- staging kín
- test với ít người dùng

App **không an toàn để mở public** vì đang có các rủi ro mức `Critical` và `High`, đặc biệt là:
- thiếu `auth/authorization` ở các API quan trọng
- đang mở public các endpoint `debug/admin`
- recommendation cho user mới dễ bị giống nhau
- một số luồng ghi dữ liệu có thể fail âm thầm nhưng API vẫn trả thành công

## Mức độ nghiêm trọng tổng quan

| Mức độ | Số lượng | Ý nghĩa |
| --- | --- | --- |
| Critical | 2 | Có thể gây lộ dữ liệu, bị gọi trái phép, hoặc phá hệ thống |
| High | 2 | Không chặn app chạy nhưng rủi ro sản phẩm/vận hành cao |
| Medium | 3 | Nên xử lý trước khi go-live để tránh lỗi khó debug |

## 1. `Critical` - Chưa có auth/authorization cho runtime API

### Vấn đề

Route chat chính đang public:
- `runtime/app/api/routes.py` dòng `106`

Schema request cho phép client tự gửi:
- `user_id`: `runtime/app/schemas/chat.py` dòng `14`
- `thread_id`: `runtime/app/schemas/chat.py` dòng `15`

Trong service, app lấy trực tiếp profile và meal logs từ `user_id` mà request gửi lên:
- `runtime/app/services/coach_service.py` dòng `256`
- `runtime/app/services/coach_service.py` dòng `258`

### Ảnh hưởng

- Người ngoài có thể giả danh `user_id` của user khác
- Có thể đọc ngữ cảnh dinh dưỡng, lịch sử ăn uống, subscription tier của user khác
- Có thể tạo chat history thay mặt user khác
- Đây là lỗi chặn deploy production

### Cách giải quyết

1. Bắt buộc xác thực ở API gateway hoặc ngay trong FastAPI.
2. Không nhận `user_id` từ body như nguồn sự thật nữa.
3. Lấy `user_id` từ access token hoặc từ backend trusted layer.
4. `thread_id` cũng nên được ràng buộc theo user hiện tại.
5. Nếu runtime chỉ dùng nội bộ giữa BE và AI runtime:
   - chỉ cho BE gọi runtime
   - dùng service token hoặc internal network
   - chặn public internet

### Ưu tiên sửa

Sửa đầu tiên trước khi deploy bất kỳ môi trường public nào.

## 2. `Critical` - Endpoint debug/admin đang public

### Vấn đề

Các route sau đang không có bảo vệ:
- `/debug/db`: `runtime/app/api/routes.py` dòng `42`
- `/debug/postgres`: `runtime/app/api/routes.py` dòng `58`
- `/admin/crawler/normalize`: `runtime/app/api/routes.py` dòng `111`
- `/admin/crawler/ingest`: `runtime/app/api/routes.py` dòng `121`
- `/api/ai/feedback`: `runtime/app/api/routes.py` dòng `139`
- `/api/ai/training-samples`: `runtime/app/api/routes.py` dòng `195`
- `/api/ai/curation/nightly`: `runtime/app/api/routes.py` dòng `233`
- `/api/ai/meal-plans/7d`: `runtime/app/api/routes.py` dòng `239`

### Ảnh hưởng

- Có thể lộ thông tin DB và tình trạng dữ liệu
- Có thể bị spam ingest crawler
- Có thể bị ghi dữ liệu training/feedback giả
- Có thể bị tạo meal plan hàng loạt gây rác DB
- Có thể bị lạm dụng tài nguyên AI và DB

### Cách giải quyết

1. Tắt hẳn các route `debug/*` ở production.
2. Chuyển `admin/*` sang internal-only hoặc bắt buộc role `admin`.
3. Thêm rate limiting cho các route ghi dữ liệu.
4. Gắn audit log cho các thao tác admin.
5. Nếu chưa làm auth kịp:
   - ít nhất chặn bằng reverse proxy
   - whitelist IP nội bộ
   - không expose public

### Ưu tiên sửa

Sửa cùng đợt với auth.

## 3. `High` - Recommendation cho user mới dễ giống nhau

### Vấn đề

Khi user không có profile đủ sâu, app dùng logic xếp hạng khá deterministic.

Default cho external user:
- `goal = maintain`: `runtime/app/repositories/user_repository.py` dòng `475`
- `target_calories = 2000`: dòng `476`
- `target_protein_g = 120`: dòng `477`
- `target_carbs_g = 220`: dòng `478`
- `target_fat_g = 60`: dòng `479`

Ranking món:
- `ranked = sorted(pool, key=score)`: `runtime/app/repositories/user_repository.py` dòng `646`

Meal plan 7 ngày:
- `top = ranked[:20]`: `runtime/app/services/meal_plan_service.py` dòng `47`
- xoay vòng bằng `idx % len(top)`: `runtime/app/services/meal_plan_service.py` dòng `56`

UUID user thật hiện được trả về ngay, không có bootstrap default profile riêng trong nhánh này:
- `runtime/app/repositories/user_repository.py` dòng `395`

### Ảnh hưởng

- User mới vẫn nhận được recommendation
- Nhưng nhiều user mới có thể thấy gần như cùng 1 bộ món
- Cảm giác cá nhân hóa thấp
- Nếu đi production consumer thì đây là vấn đề sản phẩm lớn

### Cách giải quyết

1. Bổ sung onboarding tối thiểu khi đăng ký:
   - goal
   - chiều cao/cân nặng
   - dị ứng
   - món ghét
   - ngân sách
   - thời gian nấu
2. Với cold-start, thêm cơ chế đa dạng hóa:
   - random có seed theo `user_id`
   - ưu tiên khác nhau theo bữa
   - tránh lặp món trong 3-7 ngày gần nhất
3. Tách ranking thành 2 bước:
   - lọc món phù hợp
   - sau đó diversity re-rank
4. Với user UUID mới, đảm bảo BE hoặc runtime luôn có một bước bootstrap profile ban đầu.

### Ưu tiên sửa

Sửa trước khi mở cho nhiều user thật.

## 4. `High` - Meal plan có thể trả thành công dù ghi DB fail

### Vấn đề

Trong `MealPlanService`, app gọi insert xong là trả response:
- `runtime/app/services/meal_plan_service.py` dòng `82`

Nhưng trong repository, khi insert từng row bị lỗi thì code `continue` luôn:
- `runtime/app/repositories/user_repository.py` dòng `921`
- `runtime/app/repositories/user_repository.py` dòng `954`

### Ảnh hưởng

- API có thể báo tạo meal plan thành công
- Nhưng DB chỉ lưu một phần hoặc không lưu gì
- Frontend và DB bị lệch trạng thái
- Rất khó debug khi user báo “thấy trả ra plan nhưng load lại không có”

### Cách giải quyết

1. `insert_meal_plan_rows()` phải trả về số dòng đã ghi thật.
2. `generate_7d_plan()` phải kiểm tra kết quả ghi DB.
3. Nếu insert thiếu:
   - rollback toàn bộ
   - hoặc trả lỗi rõ ràng
4. Nên insert theo transaction thay vì từng row độc lập.
5. Thêm logging khi số row insert không khớp kỳ vọng.

### Ưu tiên sửa

Sửa trước production vì đây là lỗi integrity dữ liệu.

## 5. `Medium` - Healthcheck chưa phản ánh readiness thật

### Vấn đề

`/health` hiện chỉ trả:
- `runtime/app/api/routes.py` dòng `37`

Trong khi:
- ONNX có thể load fail và rơi sang fallback: `runtime/app/services/coach_service.py` dòng `24`, `279`
- DB có thể không kết nối được
- Gemini có thể không cấu hình

### Ảnh hưởng

- Hệ thống monitoring có thể thấy app “healthy”
- Nhưng thực tế model, DB, hoặc fallback không sẵn sàng
- Khi deploy lên cloud sẽ khó phân biệt app sống với app sẵn sàng phục vụ

### Cách giải quyết

1. Tách thành:
   - `/health` cho liveness
   - `/ready` cho readiness
2. Readiness nên kiểm tra:
   - DB kết nối được
   - model ONNX load được hoặc fallback được bật hợp lệ
   - bảng bắt buộc tồn tại
3. Trả thêm trạng thái chi tiết:
   - `db_ok`
   - `onnx_ok`
   - `gemini_ok`
   - `degraded_mode`

### Ưu tiên sửa

Sửa trước khi đưa lên môi trường có autoscaling/monitoring chuẩn.

## 6. `Medium` - Không có test nghiệp vụ đủ để tự tin go-live

### Vấn đề

Thư mục `tests` hiện chưa có test thực tế cho runtime:
- `D:\EXE\RAG_AI_MenuGreen\tests` hiện không có file test

Trong khi runtime có nhiều luồng quan trọng:
- chat
- recommendation
- meal plan
- feedback/training sample
- schema mapping PascalCase

### Ảnh hưởng

- Mỗi lần sửa schema hoặc logic recommendation đều có nguy cơ gãy ngầm
- Rất dễ “chạy local được nhưng deploy lỗi”
- Khó refactor tiếp

### Cách giải quyết

1. Thêm smoke tests tối thiểu:
   - `/health`
   - `/worker/chat`
   - `/api/ai/meal-plans/7d`
2. Thêm test repository cho:
   - resolve user
   - đọc profile
   - suggest meal items
3. Thêm test cho cold-start:
   - 1 user mới có recommendation
   - 10 user mới không bị cùng 1 kết quả cứng hoàn toàn
4. Thêm test cho schema mới PascalCase.

### Ưu tiên sửa

Nên làm ngay sau khi khóa auth và route admin.

## 7. `Medium` - Nhiều chỗ nuốt lỗi âm thầm, khó quan sát production

### Vấn đề

Nhiều `except Exception` đang return rỗng hoặc `False`, ví dụ:
- lưu chat session: `runtime/app/repositories/user_repository.py` dòng `156`
- nhiều repository method khác cũng đang fallback im lặng

Chat service vẫn tiếp tục dù save history fail:
- `runtime/app/services/coach_service.py` dòng `291`
- `runtime/app/services/coach_service.py` dòng `305`

### Ảnh hưởng

- App có thể “trả lời được” nhưng mất history
- DB lỗi nhưng không lộ ra ngoài
- Log không đủ để truy nguyên nguyên nhân
- Production dễ sinh bug kiểu “thỉnh thoảng mất dữ liệu”

### Cách giải quyết

1. Không nuốt lỗi hoàn toàn ở các luồng quan trọng.
2. Ghi log có cấu trúc cho:
   - save chat fail
   - insert meal plan fail
   - query profile fail
3. Phân loại lỗi:
   - lỗi chấp nhận degrade
   - lỗi phải fail request
4. Đưa metric Prometheus cho:
   - chat_success_total
   - chat_persist_fail_total
   - meal_plan_insert_fail_total
   - db_query_fail_total

### Ưu tiên sửa

Sửa trước production để vận hành đỡ mù.

## Thứ tự xử lý đề xuất

### Giai đoạn 1 - Chặn rủi ro lớn nhất

1. Thêm auth/authorization cho runtime
2. Tắt hoặc khóa toàn bộ `debug/admin`
3. Chặn public internet nếu runtime chỉ dành cho BE gọi nội bộ

### Giai đoạn 2 - Ổn định dữ liệu và hành vi

1. Sửa meal plan ghi DB theo transaction
2. Bổ sung readiness check
3. Thêm logging và metrics cho các lỗi quan trọng

### Giai đoạn 3 - Nâng chất lượng recommendation

1. Bootstrap profile cho user mới
2. Thêm onboarding preference
3. Thêm diversity re-ranking để tránh món giống nhau giữa user mới

### Giai đoạn 4 - Tăng độ tin cậy

1. Viết smoke tests
2. Viết integration tests cho runtime + DB schema mới
3. Thiết lập CI chạy test trước deploy

## Điều kiện tối thiểu để được phép deploy production

Nên chỉ deploy public khi đạt đủ các điều kiện sau:

- `worker/chat` không còn nhận `user_id` tự do từ client public
- route `debug/*` và `admin/*` đã bị khóa hoặc tắt
- meal-plan không còn trả success giả khi ghi DB fail
- có smoke test cơ bản
- có readiness check thật
- có logging/metrics cho lỗi DB và persist

## Điều kiện nếu chỉ deploy staging/demo nội bộ

Có thể chấp nhận deploy nếu:

- không mở public internet
- chỉ team nội bộ dùng
- DB là dữ liệu test
- chấp nhận recommendation còn chưa đủ cá nhân hóa
- chấp nhận chưa có test đầy đủ

## Ghi chú cuối

Về mặt kỹ thuật, app hiện **chạy được**.
Về mặt production readiness, app hiện **chưa đạt mức an toàn để mở public**.

Nếu cần, bước tiếp theo nên là:
- tạo checklist fix theo thứ tự ưu tiên
- hoặc sửa trực tiếp nhóm lỗi `Critical` trước

## Chuẩn Bị Triển Khai AI

### Định hướng AI hiện tại

Hướng AI hiện tại là hợp lý cho app sinh viên:

- `ONNX` lo phần `intent classification` và routing
- `DB + service logic` lo dữ liệu thật và business rules
- `Gemini` chỉ nên dùng cho fallback, rewrite, hoặc câu quá khó

Không cần đổi ngay sang mô hình conversational AI full-time.
Thay vào đó, nên phát triển thêm theo hướng nâng chất lượng recommendation, retrieval, và personalization.

### 1. Cá nhân hóa recommendation

#### Nên bổ sung tín hiệu

- món ghét
- dị ứng
- ngân sách
- thời gian nấu
- mục tiêu tăng cân / giảm cân / giữ cân

#### Nên làm gì

- dùng các tín hiệu trên để `re-rank` món
- ưu tiên món phù hợp hồ sơ user thay vì chỉ dựa vào macro gần đúng
- giảm các món user từng bỏ qua hoặc từng phản hồi xấu

#### Lý do nên ưu tiên

Đây là phần đáng làm nhất vì cải thiện chất lượng cảm nhận rất rõ mà không cần tăng chi phí model.

### 2. Cold-start thông minh cho user mới

#### Vấn đề hiện tại

User mới có thể nhận recommendation khá giống nhau nếu chưa có đủ profile.

#### Nên làm gì

- seed theo `user_id`
- chia nhóm user theo `goal`, `budget`, `cook time`
- thêm `diversity re-rank` để tránh lặp món

#### Kết quả mong đợi

- user mới vẫn có recommendation ngay
- nhưng không bị cùng một bộ món cứng cho nhiều người
- trải nghiệm onboarding tốt hơn mà không tốn nhiều tiền

### 3. Semantic search cho món ăn và công thức

#### Nên hỗ trợ các kiểu query

- câu gõ sai
- từ lóng
- tên món không chính xác
- mô tả kiểu như `món nước ít béo nhiều đạm`

#### Nên làm gì

- mở rộng embedding search cho foods/recipes
- ưu tiên search theo ý nghĩa thay vì chỉ `ILIKE`
- kết hợp semantic search với DB filtering theo macro / giá / thời gian

#### Lợi ích

Giúp AI hiểu ý user tốt hơn mà không cần biến app thành chatbot full LLM.

### 4. Query rewrite tiếng Việt

#### Nên xử lý tốt hơn các dạng

- typo
- viết tắt
- tiếng Việt không dấu
- slang sinh viên

Ví dụ:

- `com ga giam can`
- `an gi it beo no lau`
- `mon re cho sv`

#### Nên làm gì

- chuẩn hóa query trước khi search DB
- rewrite ra 1-3 truy vấn ngắn dễ match hơn
- chỉ gọi Gemini ở bước này khi thật sự cần

#### Lợi ích

Phần này rất hợp với hybrid hiện tại vì tăng khả năng hiểu truy vấn nhưng vẫn giữ chi phí thấp.

### 5. Memory nhẹ theo user

#### Không cần memory quá nặng

Chỉ cần nhớ những thứ quan trọng như:

- món vừa gợi ý
- món user từng thích hoặc chê
- pattern ăn uống gần đây

#### Nên làm gì

- tránh gợi ý lặp lại món vừa nói
- ưu tiên món gần với lịch sử user thích
- điều chỉnh câu trả lời theo tình trạng dinh dưỡng trong ngày

#### Lợi ích

AI sẽ đỡ nói lặp, đỡ “máy móc”, và cá nhân hóa tốt hơn mà không cần chatbot memory lớn.

### 6. Feedback loop để tự cải thiện

#### Nguồn dữ liệu nên tận dụng

- `thumbs up / thumbs down`
- corrected response
- feedback text
- hành vi chọn hoặc bỏ qua món gợi ý

#### Nên làm gì

- cải thiện ranking
- tạo training samples
- refine intent/rule
- điều chỉnh các heuristic đang dùng

#### Lợi ích

Đây là cách rẻ để AI ngày càng khôn hơn theo dữ liệu thật của app.

### 7. Confidence-based routing

#### Ý tưởng

- ONNX tự tin cao thì đi `rule/DB` luôn
- ONNX tự tin thấp hoặc query mơ hồ thì mới gọi Gemini

#### Nên làm gì

- dùng `intent_confidence_threshold` rõ ràng
- log lại các case confidence thấp
- gom các query confidence thấp để review và cải thiện intent/routing

#### Lợi ích

Giữ được chi phí thấp vì phần lớn request không cần gọi LLM ngoài.

### 8. Giải thích recommendation

#### Không chỉ gợi ý món

AI nên nói thêm:

- vì sao chọn món này
- món này hợp goal nào
- còn bao nhiêu calo / protein / carb / fat

#### Lợi ích

User sẽ thấy AI thông minh hơn, minh bạch hơn, và tin tưởng recommendation hơn dù backend logic không quá phức tạp.

### Có cần train lại ONNX không

#### Không cần train lại nếu chỉ:

- thêm bảng
- thêm cột
- thêm thuộc tính hồ sơ user
- thêm logic ranking

#### Cần train lại nếu:

- thêm intent mới
- đổi label intent
- muốn model hiểu loại câu hỏi mới

### Thứ tự triển khai AI nên làm

1. cá nhân hóa recommendation
2. cold-start cho user mới
3. semantic search + query rewrite
4. memory nhẹ theo user
5. feedback loop
6. confidence-based routing tốt hơn
7. giải thích recommendation rõ hơn

### Kết luận phần AI

AI hiện tại hoàn toàn có thể phát triển tiếp rất tốt.
Hướng đúng không phải là đổi sang conversational ONNX ngay, mà là:

- làm recommendation thông minh hơn
- làm retrieval tốt hơn
- làm personalization tốt hơn
- chỉ dùng Gemini ở đúng các ca khó để giữ chi phí thấp

## AI Roadmap 3 Phase

### Mục tiêu chung

Roadmap này ưu tiên theo thứ tự:

1. tăng chất lượng thấy rõ
2. giữ chi phí thấp
3. không bắt team phải train lại model liên tục
4. tận dụng tối đa kiến trúc hiện tại

### Phase 1 - Tối ưu nhanh, ít tốn tiền, nên làm ngay

#### Mục tiêu

- cải thiện trải nghiệm user mới
- giảm việc recommendation bị giống nhau
- tăng khả năng hiểu query tiếng Việt đời thường
- giữ Gemini ở mức tối thiểu

#### Hạng mục nên làm

- thêm `cold-start diversification`
- thêm `seed theo user_id`
- thêm `goal/budget/cook-time grouping`
- cải thiện `query rewrite`
- chuẩn hóa typo, không dấu, slang
- thêm `confidence-based routing`
- log các case ONNX confidence thấp
- thêm giải thích ngắn cho recommendation

#### Kết quả kỳ vọng

- user mới vẫn được gợi ý ngay
- recommendation bớt lặp
- app hiểu câu nhập tự nhiên tốt hơn
- không tăng đáng kể chi phí vận hành

#### Có cần train lại ONNX không

Không.

### Phase 2 - Nâng chất lượng recommendation và personalization

#### Mục tiêu

- recommendation sát từng user hơn
- giảm cảm giác app trả lời chung chung
- tận dụng dữ liệu user thực tế để cải thiện AI

#### Hạng mục nên làm

- thêm tín hiệu hồ sơ:
  - món ghét
  - dị ứng
  - ngân sách
  - thời gian nấu
  - goal dinh dưỡng
- thêm memory nhẹ theo user
- lưu lịch sử món đã gợi ý
- tránh gợi ý lặp trong nhiều ngày
- thêm feedback loop từ:
  - thumbs up/down
  - corrected response
  - hành vi chọn món
- re-rank món bằng nhiều tín hiệu hơn macro

#### Kết quả kỳ vọng

- recommendation cá nhân hóa rõ hơn
- user quay lại sẽ thấy app “nhớ” mình hơn
- chất lượng tăng mà vẫn chưa cần chuyển sang conversational LLM-first

#### Có cần train lại ONNX không

Không, trừ khi bạn thêm intent mới.

### Phase 3 - Mở rộng hybrid AI dài hạn

#### Mục tiêu

- tăng độ thông minh ở các câu khó
- nâng retrieval và semantic understanding
- chuẩn bị cho giai đoạn có nhiều dữ liệu thật hơn

#### Hạng mục nên làm

- mở rộng `semantic search` cho foods/recipes
- kết hợp `embedding + filtering + ranking`
- gom các query fail / confidence thấp để tạo training set
- review lại taxonomy intent
- chỉ train lại ONNX khi:
  - xuất hiện loại câu hỏi mới
  - intent cũ không còn đủ
  - có đủ dữ liệu sạch để train
- tối ưu hybrid policy:
  - query nào luôn đi DB
  - query nào được gọi Gemini
  - query nào cần fallback nhiều bước

#### Kết quả kỳ vọng

- app xử lý tốt hơn các câu mơ hồ hoặc diễn đạt khó
- tăng độ “thông minh” mà vẫn không biến hệ thống thành app phụ thuộc hoàn toàn vào API ngoài
- giữ được chi phí ở mức kiểm soát được

#### Có cần train lại ONNX không

Chỉ khi business thật sự đổi nhu cầu intent hoặc có dữ liệu mới đủ giá trị.

## Thứ tự ưu tiên đề xuất

Nếu phải chọn đúng thứ tự làm để hiệu quả nhất, nên đi như sau:

1. `Phase 1` toàn bộ
2. personalization trong `Phase 2`
3. feedback loop + memory nhẹ
4. semantic search trong `Phase 3`
5. chỉ sau đó mới cân nhắc train lại ONNX

## Gợi ý triển khai thực tế cho team

### Nếu thời gian ngắn

Chỉ cần làm:

- cold-start diversification
- query rewrite tốt hơn
- confidence-based routing
- explanation cho recommendation

Đây là gói cải thiện rẻ nhất nhưng hiệu quả thấy ngay.

### Nếu có thêm thời gian

Làm tiếp:

- personalization
- memory nhẹ
- feedback loop

Đây là phần tạo khác biệt thật sự cho sản phẩm.

### Nếu làm đồ án hoặc phát triển dài hạn

Khi đã có nhiều dữ liệu thật hơn, mới nên làm sâu thêm:

- semantic retrieval tốt hơn
- review lại intent taxonomy
- cân nhắc retrain ONNX

## Kết luận roadmap

Roadmap phù hợp nhất cho MenuGreen là:

- ngắn hạn: cải thiện recommendation và query understanding
- trung hạn: tăng personalization theo user
- dài hạn: mở rộng semantic retrieval và chỉ retrain model khi thật sự cần

Đây là hướng phát triển vừa hợp chi phí sinh viên, vừa giữ được kiến trúc AI hiện tại, vừa dễ mở rộng theo dữ liệu thật sau này.
