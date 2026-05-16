# Data Pipeline V1 (gon)

Khong framework ruom ra. Chi co 3 script ingest core + adapter mo rong:

Core:
- `ingest_foods.py`
- `ingest_aliases.py`
- `ingest_recipes.py`

Adapters:
- `viet_food_crawler_adapter.py` (chuan hoa du lieu crawler mon Viet)
- `ingest_crawler_normalized.py` (import normalized crawler vao Supabase)
- `ingest_viecomrec_adapter.py` (pattern mapper interaction dataset)

## Chuan bi
1. Dam bao da tao DB bang `infra/sql/database_setup.sql`.
2. Tuy chon bat recommendation extension: `infra/sql/optional_reco_extension.sql`.
3. Tao `.env` o root project co:
   - `SUPABASE_URL=...`
   - `SUPABASE_KEY=...` (service role cho batch ingest)

## Chay core ingest
```powershell
cd D:\EXE\RAG_AI_MenuGreen
python tools\data_pipeline\ingest_foods.py --csv tools\data_pipeline\foods.sample.csv
python tools\data_pipeline\ingest_aliases.py --csv tools\data_pipeline\aliases.sample.csv
python tools\data_pipeline\ingest_recipes.py --csv tools\data_pipeline\recipes.sample.csv
```

## Crawler flow (end-to-end)
```powershell
# 1) Convert raw crawler JSON -> normalized JSON
python tools\data_pipeline\viet_food_crawler_adapter.py --input data\crawler_raw.json --output data\crawler_normalized.json

# 2) Import normalized JSON -> Supabase tables
python tools\data_pipeline\ingest_crawler_normalized.py --input data\crawler_normalized.json
```

## Interaction adapter (pattern tu external repo)
```powershell
python tools\data_pipeline\ingest_viecomrec_adapter.py --input data\interactions.csv --output data\interactions_normalized.json
```

## Dinh dang CSV
- `foods`: `name, calories_kcal_per_100g, protein_g_per_100g, carbs_g_per_100g, fat_g_per_100g, fiber_g_per_100g, default_serving_g, serving_notes`
- `aliases`: `alias, food_name` (food_name phai khop `foods.name`)
- `recipes`: cac cot sample, `dietary_tags` ngan cach bang `|`
