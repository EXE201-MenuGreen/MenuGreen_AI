# Data Pipeline V1 (gọn)

Không framework rườm rà. Chỉ có 3 script ingest:

- `ingest_foods.py`
- `ingest_aliases.py`
- `ingest_recipes.py`

## Chuẩn bị
1. Đảm bảo đã tạo DB bằng `infra/sql/database_setup.sql`.
2. Tạo `.env` ở root project có:
   - `SUPABASE_URL=...`
   - `SUPABASE_KEY=...` (service role cho batch ingest)

## Chạy
```powershell
cd D:\EXE\RAG_AI_MenuGreen
python tools\data_pipeline\ingest_foods.py --csv tools\data_pipeline\foods.sample.csv
python tools\data_pipeline\ingest_aliases.py --csv tools\data_pipeline\aliases.sample.csv
python tools\data_pipeline\ingest_recipes.py --csv tools\data_pipeline\recipes.sample.csv
```

## Định dạng CSV
- `foods`: `name, calories_kcal_per_100g, protein_g_per_100g, carbs_g_per_100g, fat_g_per_100g, fiber_g_per_100g, default_serving_g, serving_notes`
- `aliases`: `alias, food_name` (food_name phải khớp `foods.name`)
- `recipes`: các cột sample, `dietary_tags` ngăn cách bằng `|`
