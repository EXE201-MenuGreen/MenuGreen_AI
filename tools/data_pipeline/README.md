# Data Pipeline V1 (gon)

Khong framework ruom ra. Chi co 3 script ingest core + adapter mo rong:

Core:
- `ingest_foods.py`
- `ingest_recipes.py`

Adapters:
- `viet_food_crawler_adapter.py` (chuan hoa du lieu crawler mon Viet)
- `ingest_crawler_normalized.py` (import normalized crawler vao PostgreSQL)
- `ingest_viecomrec_adapter.py` (pattern mapper interaction dataset)

## Chuan bi
1. Dam bao da tao DB bang `infra/sql/database_setup.sql`.
2. Tuy chon bat recommendation extension: `infra/sql/optional_reco_extension.sql`.
3. Tao `.env` o root project co:
   - `POSTGRES_URL=postgresql://USER:PASSWORD@HOST:5432/DB`

## Chay core ingest
```powershell
cd D:\EXE\RAG_AI_MenuGreen
python tools\data_pipeline\ingest_foods.py --csv tools\data_pipeline\foods.sample.csv
python tools\data_pipeline\ingest_recipes.py --csv tools\data_pipeline\recipes.sample.csv
```

## Crawler flow (end-to-end)
```powershell
# 1) Convert raw crawler JSON -> normalized JSON
python tools\data_pipeline\viet_food_crawler_adapter.py --input data\crawler_raw.json --output data\crawler_normalized.json

# 2) Import normalized JSON -> PostgreSQL tables
python tools\data_pipeline\ingest_crawler_normalized.py --input data\crawler_normalized.json
```

## Interaction adapter (pattern tu external repo)
```powershell
python tools\data_pipeline\ingest_viecomrec_adapter.py --input data\interactions.csv --output data\interactions_normalized.json
```

## Dinh dang CSV
- `foods`: `name_vi,name_en,category,calories_kcal,protein_g,carbs_g,fat_g,fiber_g,estimated_price_vnd,default_serving_g,image_url`
- `recipes`: `title,description,instructions,prep_time_min,cook_time_min,total_time_min,servings,difficulty,meal_type,estimated_price_vnd,image_url,calories_kcal,protein_g,carbs_g,fat_g`
- Schema moi khong co `food_aliases`, nen `ingest_aliases.py` se bao loi chu dong neu chay.
