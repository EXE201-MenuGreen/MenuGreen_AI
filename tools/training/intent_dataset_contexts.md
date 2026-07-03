# Tài liệu Ngữ cảnh Huấn luyện Phân loại Ý định (Intent Classification Contexts)

Tài liệu này tổng hợp toàn bộ các ngữ cảnh, mô tả ý định (intents), và các mẫu câu huấn luyện của mô hình phân loại ý định (Intent Classifier) cho MenuGreen AI. 

Dữ liệu này được tổng hợp từ file `intent_dataset.json` (đã được xóa để tối ưu hóa bộ nhớ kho lưu trữ).

---

## 1. Danh sách các Nhãn Ý định (Intent Labels)

| Tên Nhãn (Label Name) | Mã Nhãn (Label ID) | Mô tả Ý định |
| :--- | :---: | :--- |
| `recipe_search` | 0 | Tìm kiếm công thức nấu ăn, gợi ý món ăn nấu tại nhà. |
| `ai_search` | 1 | Tìm kiếm/tra cứu các nghiên cứu hoặc hướng dẫn dinh dưỡng/y khoa chuyên sâu qua AI. |
| `nutrition_calc` | 2 | Tính toán các chỉ số cơ thể (BMR, TDEE), nhu cầu calo/macro hàng ngày. |
| `inventory_check` | 3 | Kiểm tra tủ lạnh, quản lý nguyên liệu có sẵn. |
| `meal_plan` | 4 | Lên kế hoạch ăn uống hoặc thiết lập thực đơn/lịch ăn (hàng ngày/tuần). |
| `web_browsing` | 5 | Đọc, phân tích và trích xuất thông tin hoặc công thức từ link URL được cung cấp. |
| `calorie_lookup` | 6 | Tra cứu nhanh lượng calo/dinh dưỡng của một món ăn cụ thể có sẵn. |
| `general` | 7 | Hỏi đáp kiến thức thường thức về dinh dưỡng, sức khỏe, lối sống lành mạnh. |
| `unknown` | 8 | Các câu hỏi ngoài lề, không liên quan đến dinh dưỡng hoặc nấu ăn. |

---

## 2. Ngữ cảnh & Ví dụ chi tiết cho từng Ý định

### recipe_search (ID: 0)

**Mô tả:** Tìm kiếm công thức nấu ăn dựa trên nguyên liệu hoặc gợi ý các món ăn nấu tại nhà.

**Mẫu câu ví dụ:**
- *"Mình mới sinh em bé, bánh canh cua cho sau tập gym ??? pls"*
- *"thịt bò xào cho cho gia đình"*
- *"Mình ăn chay linh hoạt, thịt heo kho nhanh, mục tiêu khoảng 550 kcal/bữa"*
- *"phở bò cho giàu protein"*
- *"món gà nướng nhanh"*
- *"lẩu cá kèo cho nấu nhanh"*
- *"Mình đang tăng cơ, gợi ý giúp mình: công thức nấu cơm thịt kho trứng cho bữa trưa"*
- *"cho tôi có món nào khác rẻ hơn không"*
- *"tu van giup bánh khọt sau tập gym, ngân sách dưới 60k nhé"*
- *"cá kho tộ cho ít dầu mỡ"*

---

### ai_search (ID: 1)

**Mô tả:** Tra cứu các thông tin khoa học, nghiên cứu y khoa, chế độ dinh dưỡng đặc biệt từ nguồn đáng tin cậy.

**Mẫu câu ví dụ:**
- *"mình bị tiền tiểu đường, can gap cho mình hỏi tìm thông tin cập nhật về carb cycling hom nay"*
- *"ban oi xin tim giup thong tin moi nhat ve Mediterranean diet, mục tiêu khoảng 550 kcal/bữa"*
- *"AD OI LÀM ƠN CHO TÔI NGUỒN THAM KHẢO VỀ PROTEIN CHO NGƯỜI TẬP GYM, ÍT CARB BUỔI TỐI"*
- *"nhanh giup minh search giúp bài viết về meal timing cho gym"*
- *"Search giúp bài viiết về meal timing cho gym, không ăn cay"*
- *"cho minh hoi Cho tôi nguồn tham khảo về protein cho người tập gym cam on, ưu tiên meal prep"*
- *"Mình đang tăng cơ, can gap tim giup thong tin moi nhat ve Mediterranean diet now, ăn nhẹ bụng để ngủ sớm"*
- *"toi muon tìm giúp thực đơn eat clean cho dân văn phòng, ưu tiên món nhanh dưới 20 phút"*
- *"GỢI Ý GIÚP MÌNH: CHO TÔI NGUỒN THAM KHẢO VỀ PROTEIN CHO NGƯỜI TẬP GYM"*
- *"Mình là dân văn phòng, làm ơn Tìm giúp thực đơn eat clean cho dân văn phng, mình dị ứng đậu phộng"*

---

### nutrition_calc (ID: 2)

**Mô tả:** Tính toán nhu cầu dinh dưỡng hàng ngày (BMR, TDEE, lượng macro carbs/protein/fat cần thiết).

**Mẫu câu ví dụ:**
- *"Mình là sinh viên ở trọ, Tính lượng calo cần thiết gấp, ưu tiên meal prep"*
- *"Mình tập gym 5 buổi/tuần, Tôi nặng 68kg cao 170cm, tính nhanh TDEE giúp cam on, tránh chiên dầu nhiều"*
- *"mình làm ca đêm, tính proteinc ần ăn cho nam 75kg tập tạ? mình cảm ơn"*
- *"cho minh hoi Tinh BMR cho toi ??? now, ưu tiên đồ Việt"*
- *"Mình ăn chay linh hoạt, please Macro của tôi nên như thế nào gấp"*
- *"Mình làm ca đêm, Ăn Keto thì chia mmacro thế nào pls, mục tiêu khoảng 550 kcal/bữa"*
- *"mình có lịch họp dày đặc, nhờ bạn toi can bao nhieu protein moi ngay"*
- *"Mình bị mỡ máu nhẹ, làm ơn Tính nhu cầu dinh dưỡng hằng ngày cam on"*
- *"cho minh hoi tính lượng calo và carb chế độ low-carb, ưu tiên đồ việt"*
- *"MÌNH LÀM CA ĐÊM, CAN GAP TÔI NẶNG 65KG MUỐN TĂNG CÂN CẦN NẠP BAO NHIÊU PROTEIN CAM ON, MÌNH DỊ ỨNG ĐẬU PHỘNG"*

---

### inventory_check (ID: 3)

**Mô tả:** Quản lý và kiểm tra các nguyên liệu hiện có trong tủ lạnh hoặc kho thực phẩm của người dùng.

**Mẫu câu ví dụ:**
- *"Mình là sinh viên ở trọ, Danh sách nguyên liệu cần mua bù !! nhe, mục tiêu khoảng 550 kcal/bữa"*
- *"toi can Nguyên liệu nào cần mua thêm, không dùng hải sản"*
- *"Mình mới sinh em bé, bạn có thể Rau củ nào sắp hỏng, ăn nhẹ bụng để ngủ sớm"*
- *"mình đang giảm cân, kiem tra tu lanh cua toi trong ngay"*
- *"PLEASE KIỂM TRA GIÚP ĐỒ NÀO NÊN DÙNG TRƯỚC, ĂN NHẸ BỤNG ĐỂ NGỦ SỚM"*
- *"coach oig ợi ý giúp mình: Nguyên liệu nào cần mua thêm, mình dị ứng đậu phộng"*
- *"toi can Kiểm tra giúp đồ nào nên dùng trước, không dùng hải sản"*
- *"ai oi toi muon Rau cu nao sap hong giúp mình nha, ngâân sách dưới 60k nhé"*
- *"Mình là sinh viên ở trọ, ad oi Kiểm tra tủ lạnh của tôi ???, tránh chiên dầu nhiều"*
- *"Mình hay ăn ngoài quán, What is in my fridge !! now, ngân sách dưới 60k nhé"*

---

### meal_plan (ID: 4)

**Mô tả:** Thiết lập thực đơn, lịch trình ăn uống cá nhân hóa cho một ngày hoặc một tuần.

**Mẫu câu ví dụ:**
- *"Mình bị mỡ máu nhẹ, Hôm nay còn bao nhiêu kcal và nên ăn món gì tiếp"*
- *"mình là sinh viên ở trọ, can gap toi can ke hoach an 7 ngay giam can pls, tránh chiên dầu nhiều"*
- *"Mình làm ca đêm, bro oi Xem lượng calo còn lại hôm nay và gợi ý 3 món ăn ít béo !! giúp mình nha, ăn nhẹ bụng để ngủ sớm"*
- *"Calo còn lại hôm nay là bao nhiêu, rcm giùm món gì ăn nhanh, ngân sách dưới 60k nhé"*
- *"mình là dân văn phòng, giup toi voi hôm nay còn bao nhiêu kcal và nên ăn món gì tiếp !!"*
- *"can gap gợi ý giúp mình: Kế hoạch ăn 7 ngày giảm cân mình cảm ơn"*
- *"giup toi voi Ke hoach an 7 ngay giam can"*
- *"mình đang giảm cân, cho mình hỏi hôm nay tôi còn bao nhiêu kcal và gợi ý bữa trưa nhanh dưới 60k?"*
- *"nhanh giup minh toi can gợi ý món ăn trưa dưới 50k phù hợp với lượng calo còn lại, tránh chiên dầu nhiều"*
- *"ai oi gợi ý giúp mình: Create a 7-day meal plan cam on, không ăn cay"*

---

### web_browsing (ID: 5)

**Mô tả:** Phân tích nội dung và trích xuất thành phần dinh dưỡng hoặc hướng dẫn nấu ăn từ các đường dẫn (URL).

**Mẫu câu ví dụ:**
- *"Check this article https://example.org/nutrition, ngân sách dưới 60k nhé"*
- *"nhờ bạn mở bài viết này và rút ý chính https://www.who.int/news-room/fact-sheets giúp mình nha"*
- *"Mình là dân văn phòng, toi can Read this recipe: https://tasty.co/recipe/chicken-soup nhe"*
- *"MÌNH LÀM CA ĐÊM, LÀM ƠN ĐỌC LINK NÀY VÀ TÓM TẮT GIÚP HTTPS://WWW.HSPH.HARVARD.EDU/NUTRITIONSOURCE/"*
- *"Mình là dân văn phòng, Tóm tắt link này https://giaoducyte.vn/dinh-duong, ưu tiên nhiều protein"*
- *"nhờ bạn Mở bài viết này và rút ý chính https://www.who.int/news-room/fact-sheets cam on, ngân sách dưới 60k nhé"*
- *"Mình có lịch họp dày đặc, tu van giup cho mình hỏi Đọc link này và tóm tắt giúp https://www.hsph.harvard.edu/nutritionsource/, tránh chiên dầu nhiều"*
- *"Mình có lịch họp dày đặc, coach oi Mở bài viết này và rút ý chính https://www.who.int/news-room/fact-sheets?, ít carb buổi tối"*
- *"Mình mới sinh em bé, Tóm tắt link này https://giaoducyte.vn/dinh-duong nhe, không ăn cay"*
- *"coach oi bạn có thể https://cookpad.com/vn/recipe/123456 cam on, ưu tiên món ăn nhanh dưiớ 20 phút"*

---

### calorie_lookup (ID: 6)

**Mô tả:** Tra cứu hàm lượng calo và thành phần dinh dưỡng của một món ăn cụ thể trong ngày.

**Mẫu câu ví dụ:**
- *"mình là dân văn phòng, nhờ bạn bun bo co bao nhieu protein giúp mình nha"*
- *"bạn có thể cơm tấm sườn trứng có nhiều chất béo không gấp, ưu tiên đồ việt"*
- *"mìình là sinh viên ở trọ, tu van giup gợi ý giúp mình: how many calories are in pho giúp mình nha"*
- *"Mình đang tăng cơ, ad oi Tinh calo com tam now, không ăn cay"*
- *"BAN OI XIN NUTRITION FACTS FOR BANH MI DUOC KHONG, ƯU TIÊN NHIỀU PROTEIN"*
- *"mình đang giảm cân, tính calo cơm tấm ls, mục tiêu khoảng 550 kcal/bữa"*
- *"Mình bị tiền tiểu đường, cho minh hoi Bun bo co bao nhieu protein?, mụ ctiêu khoảng 550 kcal/bữa"*
- *"Mình làm ca đêm, nhanh giup minh làm ơn Pho bo bao nhieu calo, ăn nhẹ bụng để ngủ sớm"*
- *"ban oi Bánh ìm ốp la khoảng bao nhiêu kcal, mục tiêu khoảng 550 kcal/bữa"*
- *"mình đang giảm cân, nhanh giup minh mot qua trung bao nhieu calo !!"*

---

### general (ID: 7)

**Mô tả:** Các câu hỏi xã giao hoặc thảo luận kiến thức dinh dưỡng thường thức, mẹo ăn uống lành mạnh.

**Mẫu câu ví dụ:**
- *"Mình mới sinh em bé, please toi can Tai sao nen an sang gấp"*
- *"Mình đang giảm cân, Tai sao nen an sang ??? duoc khong, ưu tiên đồ Việt"*
- *"Mình mới sinh em bé, ai oi Tips for healthy eating !!, ưu tiên món nhanh dưới 20 phút"*
- *"Mìnnh có lịch họp dày đặc, Ăn gì để tăng cơ, ăn nhẹ bụng để ngủ sớm"*
- *"coach oi cho mình hỏi Ăn gì để tăng cơ pls"*
- *"mình đang tăng cơ, bro oi foods that boost immune system? nhe, tránh chiên dầu nhiều"*
- *"mình bị mỡ máu nhẹ, toi muon lịch ăn nào phù hợp người làm ca đêm, mình dị ứng đậu phộng"*
- *"Mình mới sinh em bé, ai oi Làm sao ăn healthy mà vẫn no lâu, ưu tiên món nhhanh dưới 20 phút"*
- *"làm ơn làm sao ăn healthy mà vẫn no lâu trong ngay"*
- *"bro oi toi muon Thói quen ăn uống nào tốt cho giấc gủ, tránh chiên dầu nhiều"*

---

### unknown (ID: 8)

**Mô tả:** Các câu hỏi ngoài phạm vi hỗ trợ của trợ lý dinh dưỡng (chính trị, lập trình, thời tiết, giải trí, v.v.).

**Mẫu câu ví dụ:**
- *"Mình có lịch họp dày đặc, coach oi Gia vang hom nay"*
- *"Mình là sinh viên ở trọ, ad oi How to center a div in CSS hom nay"*
- *"Mình ăn chay linh hoạt, toi can Code Python lam sao"*
- *"cho mình hỏi Code Python làm sao hom nay, ăn nhẹ bụng để ngủ sớm"*
- *"Thời tiết hôm nay thế nào !! pls, ngân sách dưới 60k nhé"*
- *"ai oi Giá USD hôm nay"*
- *"bro oi bang gia chung khoan, ăn nhẹ bụng để ngủ sớm"*
- *"tu van giup who won the last election !!, ngân sách dưới 60k nhé"*
- *"Mình là dân văn phòng, xin Code Python lam sao pls"*
- *"Mình bị tiền tiểu đường, Dự báo thời tiết cuối tuần? giúp mình nha, ưu tiên đồ Việt"*

---

