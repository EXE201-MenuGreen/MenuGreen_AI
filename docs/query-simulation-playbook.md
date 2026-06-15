# Query Simulation Playbook

## Mục tiêu

File này dùng để:
- gom câu hỏi user thật cho `MenuGreen AI Coach`
- giả lập thêm câu hỏi mới để test coverage
- phân loại câu nào dùng để test logic hiện tại
- phân loại câu nào nên đưa vào dataset nếu sau này retrain ONNX intent

## Khi nào dùng file này

Dùng khi team cần:
- test AI trước demo
- review quality sau khi thêm flow mới
- chuẩn bị bộ câu hỏi để QA
- thu thập dữ liệu user thật cho lần cải thiện tiếp theo
- quyết định có cần retrain hay chưa

## Nguyên tắc chung

1. Ưu tiên câu user thật trước câu tự bịa.
2. Giữ nguyên typo, tiếng Việt không dấu, slang sinh viên nếu có.
3. Một câu chỉ nên gán `1 intent chính`, nhưng có thể có nhiều `constraint`.
4. Nếu câu quá dài hoặc nhiều ý, vẫn giữ nguyên vì đó là hành vi user thật.
5. Luôn lưu cả câu thất bại, không chỉ câu chạy đúng.

## Các nhóm câu hỏi chính của project hiện tại

### 1. `meal_plan`

Các câu hỏi về:
- hôm nay ăn gì
- gợi ý món
- gợi ý bữa sáng/trưa/tối
- món theo ngân sách
- món theo thời gian nấu
- món theo thời tiết
- món theo sở thích như muốn ăn tôm, thích cá hồi

Ví dụ:
- Hôm nay ăn gì?
- Gợi ý bữa trưa nhanh dưới 60k
- Tối nay nên ăn gì ít béo
- Trời nắng nóng ăn gì cho mát
- Tôi muốn ăn tôm
- Có món nào no lâu mà rẻ không

### 2. `nutrition_calc`

Các câu hỏi về:
- đã ăn bao nhiêu kcal
- còn bao nhiêu kcal
- macro còn lại
- protein/carb/fat hiện tại

Ví dụ:
- Hôm nay tôi còn bao nhiêu kcal?
- Tôi đã ăn bao nhiêu protein rồi?
- Còn bao nhiêu carb cho hôm nay?

### 3. `recipe_search`

Các câu hỏi về:
- tìm món cụ thể
- công thức món
- cách nấu
- món liên quan đến nguyên liệu

Ví dụ:
- Công thức cá hồi áp chảo
- Cách làm salad bơ ức gà
- Có món nào với tôm không?

### 4. `general` hoặc ngoài phạm vi

Các câu:
- không liên quan đến món ăn
- quá mơ hồ
- hỏi chuyện ngoài domain hiện tại

Ví dụ:
- Kể chuyện vui đi
- Bạn là ai
- Hôm nay thời tiết thế nào

## Các nhóm constraint cần mô phỏng

Mỗi câu nên kiểm tra xem có constraint nào đi kèm không.

### Theo bữa
- bữa sáng
- bữa trưa
- bữa tối
- ăn khuya

### Theo ngân sách
- dưới 20k
- dưới 40k
- dưới 60k
- sinh viên ít tiền
- rẻ

### Theo thời gian
- nhanh
- dưới 10 phút
- dưới 20 phút
- nấu đơn giản
- không mất công

### Theo mục tiêu dinh dưỡng
- tăng cơ
- giảm cân
- ít béo
- nhiều đạm
- no lâu
- ít tinh bột

### Theo sở thích hoặc tránh né
- muốn ăn tôm
- thích cá hồi
- ghét rau
- dị ứng hải sản
- không ăn cay

### Theo thời tiết
- trời nóng
- nắng nóng
- trời mưa
- trời lạnh
- cần món mát
- cần món ấm

### Theo cách gõ thực tế
- có dấu
- không dấu
- viết tắt
- slang
- typo

Ví dụ:
- mon trua duoi 60k
- toi muon an tom
- an gi no lau ma re
- troi nong co mon gi mat hong

## Các luồng hội thoại cần giả lập

Đừng chỉ test câu đơn. Nên test cả chuỗi hội thoại.

### Luồng 1: hỏi chung rồi refine
1. Hôm nay ăn gì?
2. Có món nào rẻ hơn không?
3. Bữa trưa thôi
4. Dưới 60k nhé

### Luồng 2: nêu sở thích rồi follow-up
1. Tôi muốn ăn tôm
2. Có món khác không?
3. Món nào nhẹ hơn?
4. Món nào nhanh làm?

### Luồng 3: hỏi theo goal
1. Tôi đang giảm cân
2. Gợi ý bữa tối ít béo
3. Có món nào nhiều đạm hơn không?

### Luồng 4: hỏi theo thời tiết
1. Trời nắng nóng ăn gì cho mát?
2. Có món nào nhẹ bụng hơn không?
3. Dưới 50k thôi

### Luồng 5: hỏi macro rồi xin món
1. Hôm nay tôi còn bao nhiêu kcal?
2. Gợi ý bữa trưa nhanh dưới 60k
3. Thêm 2 lựa chọn khác

### Luồng 6: lỗi hiểu ý user
1. Hôm nay nên ăn gì?
2. AI trả sai
3. User đổi cách hỏi: Gợi ý bữa trưa dưới 40k cho sinh viên

## Bộ câu hỏi mẫu để bắt đầu

### A. Câu tổng quát
- Hôm nay ăn gì?
- Hôm nay nên ăn gì?
- Gợi ý món cho hôm nay
- Có món nào ngon không?
- Ăn gì bây giờ?

### B. Theo ngân sách
- Gợi ý bữa trưa dưới 60k
- Có món nào dưới 40k không?
- Món rẻ cho sinh viên là gì?
- Ăn gì tiết kiệm mà vẫn no?
- Tối nay ăn gì tầm 30k

### C. Theo thời gian
- Có món nào làm nhanh không?
- Bữa sáng dưới 10 phút
- Gợi ý món nấu 15 phút
- Món nào tiện cho sinh viên bận?
- Ăn gì nhanh gọn mà không dầu mỡ

### D. Theo sở thích
- Tôi muốn ăn tôm
- Tôi thích cá hồi
- Hôm nay thèm bò
- Có món nào với ức gà không?
- Tôi muốn ăn món nước

### E. Theo thời tiết
- Trời nóng ăn gì cho mát?
- Nắng nóng cần đồ ăn nhẹ
- Trời mưa nên ăn gì?
- Hôm nay lạnh quá, gợi ý món ấm đi
- Thời tiết oi bức ăn gì dễ chịu?

### F. Theo mục tiêu sức khỏe
- Tôi đang giảm cân, ăn gì trưa nay?
- Gợi ý món nhiều đạm ít béo
- Có món nào no lâu không?
- Tôi muốn tăng cơ, nên ăn gì tối nay?
- Ăn gì ít tinh bột hơn?

### G. Theo macro
- Hôm nay tôi còn bao nhiêu kcal?
- Tôi còn bao nhiêu protein?
- Hôm nay tôi nạp bao nhiêu carb rồi?
- Còn bao nhiêu fat cho hôm nay?
- Nếu ăn món này thì vượt kcal không?

### H. Theo recipe
- Công thức cá hồi áp chảo
- Cách làm salad bơ ức gà
- Có món nào nấu với tôm không?
- Món nào giống cháo yến mạch trứng gà?
- Cách nấu món này sao cho nhanh?

### I. Typo, không dấu, slang
- hom nay an gi
- toi muon an tom
- bua trua duoi 60k
- troi nong an gi cho mat
- mon re cho sv
- co mon nao no lau hong
- toi dang giam can nen an gi

### J. Câu khó hoặc nhiều ràng buộc
- Hôm nay tôi còn bao nhiêu kcal và gợi ý bữa trưa nhanh dưới 60k?
- Tôi muốn ăn tôm nhưng ít béo và dưới 80k
- Trời nóng nên cần món mát, nhẹ, nhiều đạm
- Có món nào cho bữa tối no lâu mà không quá dầu không?
- Tôi thích cá hồi nhưng hôm nay muốn món rẻ hơn

## Bộ câu hỏi ngoài phạm vi để test fallback

- Hôm nay thời tiết thế nào?
- Viết giúp tôi email xin nghỉ học
- Kể chuyện cười đi
- Ai là tổng thống Mỹ?
- Tối nay xem phim gì?

Mục tiêu:
- AI không bịa
- AI từ chối đúng phạm vi
- không route nhầm sang gợi ý món

## Template để lưu câu hỏi

Gợi ý lưu trong CSV hoặc Google Sheets với các cột sau:

| Cột | Ý nghĩa |
| --- | --- |
| `id` | mã câu |
| `source` | `real`, `synthetic`, `qa`, `feedback` |
| `user_text` | nguyên văn câu user |
| `normalized_text` | bản normalize nếu cần |
| `intent_expected` | `meal_plan`, `nutrition_calc`, `recipe_search`, `general` |
| `constraints` | ví dụ `budget<=60000;meal=lunch;time<=20` |
| `difficulty` | `easy`, `medium`, `hard` |
| `expected_behavior` | AI nên làm gì |
| `expected_not_to_do` | AI không nên làm gì |
| `actual_behavior` | kết quả hiện tại |
| `status` | `pass`, `fail`, `partial` |
| `notes` | ghi chú |

## Nguồn để kiếm câu hỏi user thật

### Trong app hiện tại
- chat history nội bộ
- feedback thumbs up/down
- câu user nhập ở demo
- câu bị fail hoặc bị hỏi lại

### Từ người dùng mục tiêu
- sinh viên đại học
- người ở ký túc xá
- người đi làm nhưng ngân sách thấp
- người đang giảm cân hoặc tập gym

### Từ môi trường thực tế
- group sinh viên
- group nấu ăn tiết kiệm
- group gym/dinh dưỡng
- bạn bè dùng thử app

## Cách xin dữ liệu user thật

Không cần hỏi quá học thuật. Có thể hỏi trực tiếp:
- Nếu dùng app này bạn sẽ hỏi gì?
- Khi bí món ăn bạn thường gõ như thế nào?
- Nếu muốn món rẻ, bạn sẽ nhắn sao?
- Nếu trời nóng/lạnh, bạn sẽ hỏi app kiểu gì?
- Nếu đang giảm cân, bạn sẽ yêu cầu thế nào?

## Cách sinh dữ liệu giả lập

### Quy tắc sinh
- thay đổi cách diễn đạt cùng một ý
- đổi có dấu và không dấu
- thêm typo nhẹ
- thêm slang sinh viên
- thêm nhiều constraint cùng lúc

### Ví dụ sinh biến thể cho một ý

Ý gốc:
- Gợi ý bữa trưa dưới 60k

Biến thể:
- Bữa trưa nào dưới 60k vậy
- Mon trua duoi 60k
- Ăn trưa gì tầm 60k đổ lại
- Có món trưa nào rẻ rẻ không
- Trưa nay ăn gì budget 60k

## Mục tiêu số lượng câu hỏi ban đầu

Gợi ý tối thiểu:

| Nhóm | Số câu tối thiểu |
| --- | ---: |
| `meal_plan` tổng quát | 40 |
| theo ngân sách/thời gian | 40 |
| theo sở thích/nguyên liệu | 30 |
| theo thời tiết | 20 |
| theo macro/kcal | 25 |
| `recipe_search` | 25 |
| typo/không dấu/slang | 30 |
| ngoài phạm vi | 20 |

Tổng gợi ý ban đầu: `230` câu.

## Tiêu chí đánh giá một câu test là đạt

Một câu được xem là pass nếu:
- route đúng intent chính
- không trả lời lạc đề
- có dùng đúng constraint nếu user nêu ra
- không bịa món không có trong DB nếu flow đó yêu cầu DB grounding
- nếu ngoài phạm vi thì từ chối đúng

## Dấu hiệu nên thêm vào bộ retrain sau này

Nếu gặp nhiều câu như sau thì nên đánh dấu để huấn luyện vòng sau:
- ONNX hay route sai sang `general`
- câu nhiều ràng buộc nhưng thường bị hiểu thành câu đơn giản
- câu theo thời tiết bị lạc sang flow khác
- follow-up như `có món khác không` bị mất ngữ cảnh
- typo nặng hoặc slang khiến parser hiện tại fail

## Ưu tiên thu thập đầu tiên

Nếu thời gian ít, thu theo thứ tự:
1. `meal_plan` theo ngân sách/thời gian
2. câu theo sở thích như `muốn ăn tôm`, `thích cá hồi`
3. câu theo thời tiết
4. câu macro + follow-up
5. typo/không dấu/slang

## Gợi ý vận hành thực tế

- Mỗi lần thêm flow mới, thêm ngay `10-20` câu test tương ứng.
- Mỗi bug user report, thêm ít nhất `1` câu regression test.
- Mỗi tuần gom lại các câu fail và phân nhóm.
- Khi số lượng câu fail cùng pattern tăng lên, mới cân nhắc retrain.

## Kết luận

Hiện tại project này vẫn nên ưu tiên:
- gom dữ liệu user thật
- mở rộng rule/ranking/service layer
- tạo bộ regression test bằng câu hỏi tự nhiên

Chưa cần retrain chỉ vì thêm vài flow mới.
Nhưng nên chuẩn bị bộ câu hỏi từ bây giờ để:
- đo chất lượng ổn định
- biết chính xác khi nào retrain là đáng
- giảm tình trạng vá logic mà không có bộ test thực tế
