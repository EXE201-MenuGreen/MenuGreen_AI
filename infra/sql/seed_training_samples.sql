-- Seed approved/pending training samples for weekly training gate.
-- Safe to run multiple times; each run adds a new batch.

BEGIN;

INSERT INTO ai_training_samples (
  source,
  input_text,
  context_json,
  expected_output,
  labels,
  status
)
SELECT
  'sql_seed_bootstrap',
  'Yeu cau #' || gs::text || ': goi y bua an duoi 60k va nhanh',
  jsonb_build_object(
    'feature_area',
    CASE
      WHEN gs % 3 = 0 THEN 'meal_plan_generation'
      WHEN gs % 2 = 0 THEN 'meal_recommendation'
      ELSE 'nutrition_chat'
    END,
    'seed_batch', '2026-05-23'
  ),
  CASE
    WHEN gs % 5 = 0 THEN 'Goi y: ca hap + rau luoc + com gao lut, ~550 kcal.'
    WHEN gs % 2 = 0 THEN 'Goi y: uc ga ap chao + salad + khoai lang, ~600 kcal.'
    ELSE 'Goi y: dau hu sot ca + trung + canh rau, ~520 kcal.'
  END,
  ARRAY[
    'seed',
    CASE
      WHEN gs % 3 = 0 THEN 'meal_plan_generation'
      WHEN gs % 2 = 0 THEN 'meal_recommendation'
      ELSE 'nutrition_chat'
    END
  ]::text[],
  CASE
    WHEN gs <= 130 THEN 'approved'
    ELSE 'pending'
  END
FROM generate_series(1, 150) gs;

COMMIT;

