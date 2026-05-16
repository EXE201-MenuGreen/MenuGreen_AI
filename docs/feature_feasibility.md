# Feature Feasibility - Viet Food Crawler + External Recommendation Dataset

## 1) Ket luan nhanh
- `viet_food_crawler.md`: PHU HOP cao voi MenuGreen AI (thuc pham, cong thuc, nguyen lieu, cach nau).
- `linh222/face_cleanser_recommendation_dataset`: KHONG phu hop truc tiep domain (my pham vs mon an),
  nhung co the tai su dung y tuong recommendation pipeline (interaction + content attributes).

## 2) Co the lam duoc voi du an hien tai khong?
Co. Kha thi va nen lam theo 2 lop:

### Lop A - Domain food (uu tien cao)
- Crawl du lieu mon Viet (ten mon, nguyen lieu, huong dan, image, category).
- Chuan hoa ingredient parser.
- Ingest vao `recipes`, `ingredients`, `recipe_ingredients`, `foods`, `food_aliases`.
- Dung du lieu nay cho:
  - AI Coach goi y bua an,
  - Macro estimation,
  - Tim cong thuc theo nguyen lieu.

### Lop B - Recommendation engine pattern (tai su dung ky thuat)
- Lay pattern tu repo face cleanser:
  - content-based
  - popularity score
  - attribute-based filtering
- Ap dung cho FOOD data cua minh thay vi cleanser data.

## 3) Diem can canh bao
- Khong nen dua cleanser dataset vao production answer cho user food.
- Neu dung cleanser repo, chi nen tai su dung code architecture/feature engineering pattern.
- Du lieu crawler can quy trinh quality gate (dedup + unit normalization + nutrition sanity checks).

## 4) To-do de trien khai an toan
1. Dung adapter crawler -> CSV/JSON schema thong nhat.
2. Ingest foods/recipes/aliases vao Supabase.
3. Tao optional interaction table cho recommendation (user_id, item_id, event_type, ts).
4. Build baseline recommenders cho FOOD:
   - content-only
   - content + popularity
   - attribute weighted
5. Danh gia offline (precision@k, recall@k) truoc khi mo trong app.

## 5) Pham vi code da them trong project
- `tools/data_pipeline/viet_food_crawler_adapter.py`
- `tools/data_pipeline/ingest_viecomrec_adapter.py` (adapter pattern, optional)
- `infra/sql/optional_reco_extension.sql`

