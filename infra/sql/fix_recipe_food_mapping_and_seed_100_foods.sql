BEGIN;

-- Clone linked foods into recipe-specific food rows when recipe title and food name diverge.
INSERT INTO foods (
  "Id",
  "NameVi",
  "NameEn",
  "Category",
  "Description",
  "CaloriesKcal",
  "ProteinG",
  "CarbsG",
  "FatG",
  "FiberG",
  "EstimatedPriceVnd",
  "DefaultServingG",
  "ImageUrl",
  "IsActive",
  "CreatedAt"
)
SELECT
  cloned_food_id,
  recipe_title,
  linked_name_en,
  linked_category,
  COALESCE(linked_description, recipe_title),
  linked_calories_kcal,
  linked_protein_g,
  linked_carbs_g,
  linked_fat_g,
  linked_fiber_g,
  linked_estimated_price_vnd,
  linked_default_serving_g,
  linked_image_url,
  COALESCE(linked_is_active, TRUE),
  NOW()
FROM (
  VALUES
    (
      'ed000001-0000-0000-0000-000000000001'::uuid,
      'ec000001-0000-0000-0000-000000000001'::uuid,
      'Ức gà áp chảo sốt chanh',
      'fd000001-0000-0000-0000-000000000001'::uuid
    ),
    (
      'ed000002-0000-0000-0000-000000000002'::uuid,
      'ec000002-0000-0000-0000-000000000002'::uuid,
      'Salad bơ ức gà giảm cân',
      'fd000003-0000-0000-0000-000000000003'::uuid
    ),
    (
      'ed000003-0000-0000-0000-000000000003'::uuid,
      'ec000003-0000-0000-0000-000000000003'::uuid,
      'Cá hồi áp chảo sốt măng tây',
      'fd000007-0000-0000-0000-000000000007'::uuid
    ),
    (
      'ed000004-0000-0000-0000-000000000004'::uuid,
      'ec000004-0000-0000-0000-000000000004'::uuid,
      'Cháo yến mạch trứng gà ăn sáng',
      'fd000008-0000-0000-0000-000000000008'::uuid
    )
) AS mapping(cloned_food_id, recipe_id, recipe_title, source_food_id)
JOIN LATERAL (
  SELECT
    f."NameEn" AS linked_name_en,
    f."Category" AS linked_category,
    f."Description" AS linked_description,
    f."CaloriesKcal" AS linked_calories_kcal,
    f."ProteinG" AS linked_protein_g,
    f."CarbsG" AS linked_carbs_g,
    f."FatG" AS linked_fat_g,
    f."FiberG" AS linked_fiber_g,
    f."EstimatedPriceVnd" AS linked_estimated_price_vnd,
    f."DefaultServingG" AS linked_default_serving_g,
    f."ImageUrl" AS linked_image_url,
    f."IsActive" AS linked_is_active
  FROM foods f
  WHERE f."Id" = mapping.source_food_id
) AS linked ON TRUE
ON CONFLICT ("Id") DO UPDATE SET
  "NameVi" = EXCLUDED."NameVi",
  "NameEn" = EXCLUDED."NameEn",
  "Category" = EXCLUDED."Category",
  "Description" = EXCLUDED."Description",
  "CaloriesKcal" = EXCLUDED."CaloriesKcal",
  "ProteinG" = EXCLUDED."ProteinG",
  "CarbsG" = EXCLUDED."CarbsG",
  "FatG" = EXCLUDED."FatG",
  "FiberG" = EXCLUDED."FiberG",
  "EstimatedPriceVnd" = EXCLUDED."EstimatedPriceVnd",
  "DefaultServingG" = EXCLUDED."DefaultServingG",
  "ImageUrl" = EXCLUDED."ImageUrl",
  "IsActive" = EXCLUDED."IsActive";

UPDATE recipes
SET "FoodId" = mapped.cloned_food_id
FROM (
  VALUES
    ('ec000001-0000-0000-0000-000000000001'::uuid, 'ed000001-0000-0000-0000-000000000001'::uuid),
    ('ec000002-0000-0000-0000-000000000002'::uuid, 'ed000002-0000-0000-0000-000000000002'::uuid),
    ('ec000003-0000-0000-0000-000000000003'::uuid, 'ed000003-0000-0000-0000-000000000003'::uuid),
    ('ec000004-0000-0000-0000-000000000004'::uuid, 'ed000004-0000-0000-0000-000000000004'::uuid)
) AS mapped(recipe_id, cloned_food_id)
WHERE recipes."Id" = mapped.recipe_id
  AND recipes."FoodId" IS DISTINCT FROM mapped.cloned_food_id;

-- Seed 100 additional foods for broader recommendation coverage.
WITH protein_pool AS (
  SELECT *
  FROM (
    VALUES
      (1, 'Ức gà', 'Chicken breast', 31.0, 0.0, 3.6, 'Món mặn', 42000),
      (2, 'Cá hồi', 'Salmon', 25.0, 0.0, 24.0, 'Món mặn', 125000),
      (3, 'Bò nạc', 'Lean beef', 29.0, 0.0, 12.0, 'Món mặn', 98000),
      (4, 'Tôm', 'Shrimp', 24.0, 1.5, 1.0, 'Hải sản', 76000),
      (5, 'Đậu hũ', 'Tofu', 12.0, 8.5, 10.0, 'Chay', 24000),
      (6, 'Cá ngừ', 'Tuna', 27.0, 0.0, 8.0, 'Hải sản', 82000),
      (7, 'Thịt heo nạc', 'Lean pork', 26.0, 1.0, 11.0, 'Món mặn', 65000),
      (8, 'Ức vịt', 'Duck breast', 23.0, 0.0, 14.0, 'Món mặn', 88000),
      (9, 'Trứng gà', 'Egg', 13.0, 1.1, 11.0, 'Bữa sáng', 18000),
      (10, 'Nấm đùi gà', 'King oyster mushroom', 8.0, 10.0, 2.0, 'Chay', 26000)
  ) AS t(protein_idx, protein_vi, protein_en, protein_g, base_carbs_g, fat_g, category, base_price)
),
side_pool AS (
  SELECT *
  FROM (
    VALUES
      (1, 'cơm gạo lứt', 'brown rice', 23.0, 1.8, 100, 9000),
      (2, 'khoai lang hấp', 'steamed sweet potato', 20.0, 3.0, 100, 8000),
      (3, 'yến mạch', 'oats', 28.0, 4.0, 80, 11000),
      (4, 'bông cải xanh', 'broccoli', 8.0, 3.5, 120, 12000),
      (5, 'bí đỏ', 'pumpkin', 12.0, 2.5, 120, 10000),
      (6, 'salad rau xanh', 'green salad', 9.0, 3.2, 130, 13000),
      (7, 'bún gạo lứt', 'brown rice noodles', 30.0, 2.1, 110, 12000),
      (8, 'quinoa', 'quinoa', 21.0, 2.8, 90, 17000),
      (9, 'ngô ngọt', 'sweet corn', 19.0, 2.6, 100, 9000),
      (10, 'mì nguyên cám', 'whole wheat pasta', 27.0, 3.0, 100, 14000)
  ) AS t(side_idx, side_vi, side_en, carbs_g, fiber_g, serving_g, side_price)
)
INSERT INTO foods (
  "Id",
  "NameVi",
  "NameEn",
  "Category",
  "Description",
  "CaloriesKcal",
  "ProteinG",
  "CarbsG",
  "FatG",
  "FiberG",
  "EstimatedPriceVnd",
  "DefaultServingG",
  "ImageUrl",
  "IsActive",
  "CreatedAt"
)
SELECT
  (
    substr(md5('menugreen-seed-food-' || protein_idx || '-' || side_idx), 1, 8) || '-' ||
    substr(md5('menugreen-seed-food-' || protein_idx || '-' || side_idx), 9, 4) || '-' ||
    substr(md5('menugreen-seed-food-' || protein_idx || '-' || side_idx), 13, 4) || '-' ||
    substr(md5('menugreen-seed-food-' || protein_idx || '-' || side_idx), 17, 4) || '-' ||
    substr(md5('menugreen-seed-food-' || protein_idx || '-' || side_idx), 21, 12)
  )::uuid AS id,
  initcap(protein_vi || ' ăn cùng ' || side_vi) AS name_vi,
  initcap(protein_en || ' with ' || side_en) AS name_en,
  CASE
    WHEN protein_idx IN (5, 10) THEN 'Chay'
    WHEN protein_idx IN (4, 6) THEN 'Hải sản'
    WHEN protein_idx = 9 THEN 'Bữa sáng'
    ELSE 'Món mặn'
  END AS category,
  initcap('Phần ăn seed mở rộng với ' || protein_vi || ' và ' || side_vi || ' cho hệ thống recommend.') AS description,
  ROUND((120 + protein_g * 6.5 + carbs_g * 3.8 + fat_g * 8.5 + side_idx * 4 + protein_idx * 3)::numeric, 1) AS calories_kcal,
  ROUND((protein_g + (side_idx % 3) * 0.7)::numeric, 1) AS protein_g,
  ROUND((base_carbs_g + carbs_g)::numeric, 1) AS carbs_g,
  ROUND((fat_g + ((protein_idx + side_idx) % 4) * 0.8)::numeric, 1) AS fat_g,
  ROUND((fiber_g + (side_idx % 4) * 0.6)::numeric, 1) AS fiber_g,
  (base_price + side_price + protein_idx * 1500 + side_idx * 600) AS estimated_price_vnd,
  GREATEST(serving_g + protein_idx * 5, 120) AS default_serving_g,
  NULL AS image_url,
  TRUE AS is_active,
  NOW() AS created_at
FROM protein_pool
CROSS JOIN side_pool
ON CONFLICT ("Id") DO UPDATE SET
  "NameVi" = EXCLUDED."NameVi",
  "NameEn" = EXCLUDED."NameEn",
  "Category" = EXCLUDED."Category",
  "Description" = EXCLUDED."Description",
  "CaloriesKcal" = EXCLUDED."CaloriesKcal",
  "ProteinG" = EXCLUDED."ProteinG",
  "CarbsG" = EXCLUDED."CarbsG",
  "FatG" = EXCLUDED."FatG",
  "FiberG" = EXCLUDED."FiberG",
  "EstimatedPriceVnd" = EXCLUDED."EstimatedPriceVnd",
  "DefaultServingG" = EXCLUDED."DefaultServingG",
  "ImageUrl" = EXCLUDED."ImageUrl",
  "IsActive" = EXCLUDED."IsActive";

COMMIT;
