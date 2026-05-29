-- PostgreSQL demo seed for the current MenuGreen schema.
-- Safe to run multiple times.

BEGIN;

INSERT INTO roles (id, name, description, created_at, updated_at) VALUES
  ('00000000-0000-0000-0000-000000000001', 'user', 'Default application user', NOW(), NOW()),
  ('00000000-0000-0000-0000-000000000002', 'admin', 'System administrator', NOW(), NOW())
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  updated_at = NOW();

INSERT INTO profiles (
  user_id,
  full_name,
  avatar_url,
  date_of_birth,
  gender,
  preferred_cuisine,
  created_at,
  updated_at
) VALUES
  (
    '11111111-1111-1111-1111-111111111111',
    'Demo User',
    'https://example.com/avatar-demo.png',
    '1998-05-15',
    'male',
    'Vietnamese',
    NOW(),
    NOW()
  )
ON CONFLICT (user_id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  avatar_url = EXCLUDED.avatar_url,
  date_of_birth = EXCLUDED.date_of_birth,
  gender = EXCLUDED.gender,
  preferred_cuisine = EXCLUDED.preferred_cuisine,
  updated_at = NOW();

INSERT INTO health_profiles (
  user_id,
  height_cm,
  weight_kg,
  body_fat_percent,
  activity_level,
  goal,
  bmi,
  bmr_kcal,
  tdee_kcal,
  target_calories,
  target_protein_g,
  target_carbs_g,
  target_fat_g,
  created_at,
  updated_at
) VALUES
  (
    '11111111-1111-1111-1111-111111111111',
    170,
    68,
    18,
    'moderate',
    'maintain',
    23.53,
    1580,
    2450,
    2200,
    130,
    250,
    70,
    NOW(),
    NOW()
  )
ON CONFLICT (user_id) DO UPDATE SET
  height_cm = EXCLUDED.height_cm,
  weight_kg = EXCLUDED.weight_kg,
  body_fat_percent = EXCLUDED.body_fat_percent,
  activity_level = EXCLUDED.activity_level,
  goal = EXCLUDED.goal,
  bmi = EXCLUDED.bmi,
  bmr_kcal = EXCLUDED.bmr_kcal,
  tdee_kcal = EXCLUDED.tdee_kcal,
  target_calories = EXCLUDED.target_calories,
  target_protein_g = EXCLUDED.target_protein_g,
  target_carbs_g = EXCLUDED.target_carbs_g,
  target_fat_g = EXCLUDED.target_fat_g,
  updated_at = NOW();

INSERT INTO user_ai_profiles (
  user_id,
  preferences,
  disliked_foods,
  eating_pattern,
  favorite_cuisines,
  calorie_preference,
  updated_at,
  created_at
) VALUES
  (
    '11111111-1111-1111-1111-111111111111',
    '{"budget":"medium","protein_priority":true,"spicy":"medium"}'::json,
    '["nội tạng"]'::json,
    '{"meals_per_day":3,"snacks":1,"breakfast_time":"07:30","lunch_time":"12:00","dinner_time":"19:00"}'::json,
    '["Vietnamese","Korean","Japanese"]'::json,
    '{"daily_target":2200,"mode":"maintain"}'::json,
    NOW(),
    NOW()
  )
ON CONFLICT (user_id) DO UPDATE SET
  preferences = EXCLUDED.preferences,
  disliked_foods = EXCLUDED.disliked_foods,
  eating_pattern = EXCLUDED.eating_pattern,
  favorite_cuisines = EXCLUDED.favorite_cuisines,
  calorie_preference = EXCLUDED.calorie_preference,
  updated_at = NOW();

INSERT INTO users (
  id,
  role_id,
  email,
  password_hash,
  email_confirmed,
  is_active,
  last_sign_in_at,
  created_at,
  updated_at
) VALUES
  (
    '11111111-1111-1111-1111-111111111111',
    '00000000-0000-0000-0000-000000000001',
    'demo@menugreen.local',
    'demo-password-hash',
    TRUE,
    TRUE,
    NOW(),
    NOW(),
    NOW()
  )
ON CONFLICT (id) DO UPDATE SET
  role_id = EXCLUDED.role_id,
  email = EXCLUDED.email,
  email_confirmed = TRUE,
  is_active = TRUE,
  last_sign_in_at = NOW(),
  updated_at = NOW();

INSERT INTO sessions (
  id,
  user_id,
  refresh_token,
  user_agent,
  ip_address,
  expires_at,
  created_at
) VALUES
  (
    '11111111-1111-1111-1111-111111111112',
    '11111111-1111-1111-1111-111111111111',
    'demo-refresh-token',
    'MenuGreen Demo Client',
    '127.0.0.1',
    NOW() + INTERVAL '30 days',
    NOW()
  )
ON CONFLICT (refresh_token) DO UPDATE SET
  user_agent = EXCLUDED.user_agent,
  ip_address = EXCLUDED.ip_address,
  expires_at = EXCLUDED.expires_at;

INSERT INTO email_verifications (
  id,
  user_id,
  otp_code,
  expires_at,
  verified_at,
  created_at
) VALUES
  (
    '11111111-1111-1111-1111-111111111113',
    '11111111-1111-1111-1111-111111111111',
    '123456',
    NOW() + INTERVAL '10 minutes',
    NOW(),
    NOW()
  )
ON CONFLICT (id) DO UPDATE SET
  expires_at = EXCLUDED.expires_at,
  verified_at = EXCLUDED.verified_at;

INSERT INTO password_reset_tokens (
  id,
  user_id,
  token,
  expires_at,
  used_at,
  created_at
) VALUES
  (
    '11111111-1111-1111-1111-111111111114',
    '11111111-1111-1111-1111-111111111111',
    'demo-password-reset-token',
    NOW() + INTERVAL '15 minutes',
    NULL,
    NOW()
  )
ON CONFLICT (id) DO UPDATE SET
  token = EXCLUDED.token,
  expires_at = EXCLUDED.expires_at,
  used_at = EXCLUDED.used_at;

INSERT INTO allergies (id, name, description, created_at) VALUES
  ('22222222-2222-2222-2222-222222222201', 'Hải sản', 'Dị ứng tôm, cua, mực, nghêu, sò.', NOW()),
  ('22222222-2222-2222-2222-222222222202', 'Đậu phộng', 'Dị ứng đậu phộng và sản phẩm liên quan.', NOW()),
  ('22222222-2222-2222-2222-222222222203', 'Sữa', 'Không dung nạp lactose hoặc dị ứng sữa.', NOW())
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description;

INSERT INTO user_allergies (user_id, allergy_id, created_at) VALUES
  ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222202', NOW())
ON CONFLICT (user_id, allergy_id) DO NOTHING;

INSERT INTO ingredients (
  id,
  name_vi,
  name_en,
  category,
  calories_kcal,
  protein_g,
  carbs_g,
  fat_g,
  estimated_price_vnd,
  unit_default,
  image_url,
  is_active,
  created_at,
  updated_at
) VALUES
  ('33333333-3333-3333-3333-333333333301', 'Ức gà', 'Chicken breast', 'protein', 165, 31, 0, 3.6, 25000, 'g', NULL, TRUE, NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333302', 'Gạo trắng', 'White rice', 'carb', 130, 2.7, 28, 0.3, 18000, 'g', NULL, TRUE, NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333303', 'Rau xà lách', 'Lettuce', 'vegetable', 15, 1.4, 2.9, 0.2, 12000, 'g', NULL, TRUE, NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333304', 'Trứng gà', 'Chicken egg', 'protein', 155, 13, 1.1, 11, 30000, 'quả', NULL, TRUE, NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333305', 'Cá hồi', 'Salmon', 'protein', 208, 20, 0, 13, 180000, 'g', NULL, TRUE, NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333306', 'Khoai lang', 'Sweet potato', 'carb', 86, 1.6, 20, 0.1, 22000, 'g', NULL, TRUE, NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  name_vi = EXCLUDED.name_vi,
  name_en = EXCLUDED.name_en,
  category = EXCLUDED.category,
  calories_kcal = EXCLUDED.calories_kcal,
  protein_g = EXCLUDED.protein_g,
  carbs_g = EXCLUDED.carbs_g,
  fat_g = EXCLUDED.fat_g,
  estimated_price_vnd = EXCLUDED.estimated_price_vnd,
  unit_default = EXCLUDED.unit_default,
  image_url = EXCLUDED.image_url,
  is_active = TRUE,
  updated_at = NOW();

INSERT INTO foods (
  id,
  name_vi,
  name_en,
  category,
  description,
  calories_kcal,
  protein_g,
  carbs_g,
  fat_g,
  fiber_g,
  estimated_price_vnd,
  default_serving_g,
  image_url,
  is_active,
  created_at,
  updated_at
) VALUES
  ('44444444-4444-4444-4444-444444444401', 'Cơm ức gà luộc', 'Boiled chicken rice', 'main', 'Bữa chính nhiều protein, dễ chuẩn bị.', 520, 42, 58, 9, 3, 45000, 420, NULL, TRUE, NOW(), NOW()),
  ('44444444-4444-4444-4444-444444444402', 'Salad ức gà', 'Chicken salad', 'salad', 'Salad nhẹ, giàu đạm, phù hợp bữa tối.', 320, 35, 12, 14, 5, 35000, 300, NULL, TRUE, NOW(), NOW()),
  ('44444444-4444-4444-4444-444444444403', 'Trứng luộc khoai lang', 'Boiled eggs with sweet potato', 'breakfast', 'Bữa sáng nhanh, no lâu.', 410, 22, 48, 13, 6, 28000, 350, NULL, TRUE, NOW(), NOW()),
  ('44444444-4444-4444-4444-444444444404', 'Cá hồi áp chảo', 'Pan-seared salmon', 'main', 'Món giàu omega-3 và protein.', 560, 39, 35, 27, 4, 95000, 380, NULL, TRUE, NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  name_vi = EXCLUDED.name_vi,
  name_en = EXCLUDED.name_en,
  category = EXCLUDED.category,
  description = EXCLUDED.description,
  calories_kcal = EXCLUDED.calories_kcal,
  protein_g = EXCLUDED.protein_g,
  carbs_g = EXCLUDED.carbs_g,
  fat_g = EXCLUDED.fat_g,
  fiber_g = EXCLUDED.fiber_g,
  estimated_price_vnd = EXCLUDED.estimated_price_vnd,
  default_serving_g = EXCLUDED.default_serving_g,
  image_url = EXCLUDED.image_url,
  is_active = TRUE,
  updated_at = NOW();

INSERT INTO food_allergies (food_id, allergy_id) VALUES
  ('44444444-4444-4444-4444-444444444404', '22222222-2222-2222-2222-222222222201')
ON CONFLICT (food_id, allergy_id) DO NOTHING;

INSERT INTO recipes (
  id,
  food_id,
  title,
  description,
  prep_time_min,
  cook_time_min,
  total_time_min,
  servings,
  difficulty,
  meal_type,
  estimated_price_vnd,
  instructions,
  image_url,
  video_url,
  is_active,
  created_at,
  updated_at
) VALUES
  (
    '55555555-5555-5555-5555-555555555501',
    '44444444-4444-4444-4444-444444444402',
    'Salad ức gà nhanh',
    'Recipe salad ức gà cho bữa tối nhẹ bụng.',
    15,
    10,
    25,
    2,
    'easy',
    'dinner',
    35000,
    '["Luộc ức gà với ít muối.", "Xé gà thành sợi.", "Rửa rau xà lách.", "Trộn gà, rau và sốt ít béo."]'::json,
    NULL,
    NULL,
    TRUE,
    NOW(),
    NOW()
  ),
  (
    '55555555-5555-5555-5555-555555555502',
    '44444444-4444-4444-4444-444444444403',
    'Trứng luộc khoai lang',
    'Bữa sáng dễ nấu, phù hợp người bận.',
    5,
    20,
    25,
    1,
    'easy',
    'breakfast',
    28000,
    '["Luộc trứng 8 đến 10 phút.", "Hấp hoặc luộc khoai lang.", "Ăn cùng rau xanh nếu cần thêm chất xơ."]'::json,
    NULL,
    NULL,
    TRUE,
    NOW(),
    NOW()
  )
ON CONFLICT (id) DO UPDATE SET
  food_id = EXCLUDED.food_id,
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  prep_time_min = EXCLUDED.prep_time_min,
  cook_time_min = EXCLUDED.cook_time_min,
  total_time_min = EXCLUDED.total_time_min,
  servings = EXCLUDED.servings,
  difficulty = EXCLUDED.difficulty,
  meal_type = EXCLUDED.meal_type,
  estimated_price_vnd = EXCLUDED.estimated_price_vnd,
  instructions = EXCLUDED.instructions,
  image_url = EXCLUDED.image_url,
  video_url = EXCLUDED.video_url,
  is_active = TRUE,
  updated_at = NOW();

INSERT INTO recipe_ingredients (
  id,
  recipe_id,
  ingredient_id,
  quantity,
  unit,
  notes
) VALUES
  ('66666666-6666-6666-6666-666666666601', '55555555-5555-5555-5555-555555555501', '33333333-3333-3333-3333-333333333301', 200, 'g', 'Luộc chín rồi xé sợi'),
  ('66666666-6666-6666-6666-666666666602', '55555555-5555-5555-5555-555555555501', '33333333-3333-3333-3333-333333333303', 150, 'g', 'Rửa sạch'),
  ('66666666-6666-6666-6666-666666666603', '55555555-5555-5555-5555-555555555502', '33333333-3333-3333-3333-333333333304', 2, 'quả', 'Luộc chín'),
  ('66666666-6666-6666-6666-666666666604', '55555555-5555-5555-5555-555555555502', '33333333-3333-3333-3333-333333333306', 250, 'g', 'Hấp hoặc luộc')
ON CONFLICT (id) DO UPDATE SET
  recipe_id = EXCLUDED.recipe_id,
  ingredient_id = EXCLUDED.ingredient_id,
  quantity = EXCLUDED.quantity,
  unit = EXCLUDED.unit,
  notes = EXCLUDED.notes;

INSERT INTO favorite_foods (user_id, food_id, created_at) VALUES
  ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444402', NOW()),
  ('11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444403', NOW())
ON CONFLICT (user_id, food_id) DO NOTHING;

INSERT INTO meal_logs (
  id,
  user_id,
  food_id,
  recipe_id,
  meal_type,
  quantity_g,
  calories_kcal,
  protein_g,
  carbs_g,
  fat_g,
  source_type,
  notes,
  logged_at
) VALUES
  ('77777777-7777-7777-7777-777777777701', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444403', '55555555-5555-5555-5555-555555555502', 'breakfast', 350, 410, 22, 48, 13, 'seed', 'Bữa sáng demo', NOW() - INTERVAL '2 hours'),
  ('77777777-7777-7777-7777-777777777702', '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444401', NULL, 'lunch', 420, 520, 42, 58, 9, 'seed', 'Bữa trưa demo', NOW() - INTERVAL '1 hour')
ON CONFLICT (id) DO UPDATE SET
  meal_type = EXCLUDED.meal_type,
  quantity_g = EXCLUDED.quantity_g,
  calories_kcal = EXCLUDED.calories_kcal,
  protein_g = EXCLUDED.protein_g,
  carbs_g = EXCLUDED.carbs_g,
  fat_g = EXCLUDED.fat_g,
  source_type = EXCLUDED.source_type,
  notes = EXCLUDED.notes,
  logged_at = EXCLUDED.logged_at;

INSERT INTO water_logs (id, user_id, amount_ml, logged_at) VALUES
  ('77777777-7777-7777-7777-777777777703', '11111111-1111-1111-1111-111111111111', 500, NOW() - INTERVAL '3 hours'),
  ('77777777-7777-7777-7777-777777777704', '11111111-1111-1111-1111-111111111111', 350, NOW() - INTERVAL '1 hour')
ON CONFLICT (id) DO UPDATE SET
  amount_ml = EXCLUDED.amount_ml,
  logged_at = EXCLUDED.logged_at;

INSERT INTO weight_logs (id, user_id, weight_kg, body_fat_percent, recorded_at) VALUES
  ('77777777-7777-7777-7777-777777777705', '11111111-1111-1111-1111-111111111111', 68, 18, CURRENT_DATE - INTERVAL '7 days'),
  ('77777777-7777-7777-7777-777777777706', '11111111-1111-1111-1111-111111111111', 67.6, 17.8, NOW())
ON CONFLICT (id) DO UPDATE SET
  weight_kg = EXCLUDED.weight_kg,
  body_fat_percent = EXCLUDED.body_fat_percent,
  recorded_at = EXCLUDED.recorded_at;

INSERT INTO nutrition_snapshots (
  id,
  user_id,
  snapshot_date,
  total_calories,
  total_protein_g,
  total_carbs_g,
  total_fat_g,
  goal_completion_percent,
  created_at
) VALUES
  ('77777777-7777-7777-7777-777777777707', '11111111-1111-1111-1111-111111111111', CURRENT_DATE, 930, 64, 106, 22, 42.27, NOW())
ON CONFLICT (id) DO UPDATE SET
  total_calories = EXCLUDED.total_calories,
  total_protein_g = EXCLUDED.total_protein_g,
  total_carbs_g = EXCLUDED.total_carbs_g,
  total_fat_g = EXCLUDED.total_fat_g,
  goal_completion_percent = EXCLUDED.goal_completion_percent,
  created_at = EXCLUDED.created_at;

INSERT INTO fridge_items (
  id,
  user_id,
  ingredient_id,
  custom_name,
  quantity,
  unit,
  minimum_quantity,
  purchase_date,
  expires_at,
  is_expired,
  added_at,
  updated_at
) VALUES
  ('88888888-8888-8888-8888-888888888801', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333301', NULL, 600, 'g', 200, CURRENT_DATE - INTERVAL '1 day', CURRENT_DATE + INTERVAL '3 days', FALSE, NOW(), NOW()),
  ('88888888-8888-8888-8888-888888888802', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333304', NULL, 8, 'quả', 2, CURRENT_DATE - INTERVAL '2 days', CURRENT_DATE + INTERVAL '10 days', FALSE, NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  quantity = EXCLUDED.quantity,
  unit = EXCLUDED.unit,
  minimum_quantity = EXCLUDED.minimum_quantity,
  purchase_date = EXCLUDED.purchase_date,
  expires_at = EXCLUDED.expires_at,
  is_expired = EXCLUDED.is_expired,
  updated_at = NOW();

INSERT INTO meal_plan_headers (
  id,
  user_id,
  title,
  plan_type,
  start_date,
  end_date,
  target_calories,
  generated_by,
  is_active,
  created_at,
  updated_at
) VALUES
  ('99999999-9999-9999-9999-999999999901', '11111111-1111-1111-1111-111111111111', 'Demo meal plan hôm nay', 'daily', CURRENT_DATE, CURRENT_DATE, 2200, 'seed', TRUE, NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  plan_type = EXCLUDED.plan_type,
  start_date = EXCLUDED.start_date,
  end_date = EXCLUDED.end_date,
  target_calories = EXCLUDED.target_calories,
  generated_by = EXCLUDED.generated_by,
  is_active = TRUE,
  updated_at = NOW();

INSERT INTO meal_plan_items (
  id,
  meal_plan_id,
  meal_type,
  food_id,
  recipe_id,
  planned_date,
  target_calories,
  is_completed,
  created_at
) VALUES
  ('99999999-9999-9999-9999-999999999902', '99999999-9999-9999-9999-999999999901', 'breakfast', '44444444-4444-4444-4444-444444444403', '55555555-5555-5555-5555-555555555502', CURRENT_DATE, 450, TRUE, NOW()),
  ('99999999-9999-9999-9999-999999999903', '99999999-9999-9999-9999-999999999901', 'lunch', '44444444-4444-4444-4444-444444444401', NULL, CURRENT_DATE, 650, TRUE, NOW()),
  ('99999999-9999-9999-9999-999999999904', '99999999-9999-9999-9999-999999999901', 'dinner', '44444444-4444-4444-4444-444444444402', '55555555-5555-5555-5555-555555555501', CURRENT_DATE, 550, FALSE, NOW())
ON CONFLICT (id) DO UPDATE SET
  meal_type = EXCLUDED.meal_type,
  food_id = EXCLUDED.food_id,
  recipe_id = EXCLUDED.recipe_id,
  planned_date = EXCLUDED.planned_date,
  target_calories = EXCLUDED.target_calories,
  is_completed = EXCLUDED.is_completed;

INSERT INTO ai_conversations (id, user_id, title, created_at) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '11111111-1111-1111-1111-111111111111', 'Demo nutrition chat', NOW())
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title;

INSERT INTO ai_messages (
  id,
  conversation_id,
  role,
  content,
  tokens_used,
  created_at
) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'user', 'Hôm nay tôi còn bao nhiêu calo?', 12, NOW() - INTERVAL '5 minutes'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'assistant', 'Bạn đã ăn khoảng 930 kcal, còn khoảng 1270 kcal so với mục tiêu 2200 kcal.', 38, NOW() - INTERVAL '4 minutes')
ON CONFLICT (id) DO UPDATE SET
  role = EXCLUDED.role,
  content = EXCLUDED.content,
  tokens_used = EXCLUDED.tokens_used,
  created_at = EXCLUDED.created_at;

INSERT INTO recommendation_history (
  id,
  user_id,
  type,
  input,
  output,
  confidence,
  created_at
) VALUES
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
    '11111111-1111-1111-1111-111111111111',
    'meal_suggestion',
    '{"remaining_calories":1270,"priority":"high_protein"}'::json,
    '{"items":["Salad ức gà","Cá hồi áp chảo"],"reason":"Giàu protein, phù hợp mục tiêu duy trì."}'::json,
    0.86,
    NOW()
  )
ON CONFLICT (id) DO UPDATE SET
  type = EXCLUDED.type,
  input = EXCLUDED.input,
  output = EXCLUDED.output,
  confidence = EXCLUDED.confidence,
  created_at = EXCLUDED.created_at;

INSERT INTO recommendation_feedbacks (
  id,
  recommendation_id,
  rating,
  feedback,
  created_at
) VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 5, 'Gợi ý hợp khẩu vị.', NOW())
ON CONFLICT (id) DO UPDATE SET
  rating = EXCLUDED.rating,
  feedback = EXCLUDED.feedback,
  created_at = EXCLUDED.created_at;

INSERT INTO notifications (
  id,
  user_id,
  title,
  body,
  type,
  is_read,
  scheduled_at,
  sent_at,
  created_at
) VALUES
  ('cccccccc-cccc-cccc-cccc-ccccccccccc1', '11111111-1111-1111-1111-111111111111', 'Nhắc uống nước', 'Bạn nhớ uống thêm 350ml nước nhé.', 'water_reminder', FALSE, NOW() + INTERVAL '30 minutes', NULL, NOW())
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  body = EXCLUDED.body,
  type = EXCLUDED.type,
  is_read = EXCLUDED.is_read,
  scheduled_at = EXCLUDED.scheduled_at,
  sent_at = EXCLUDED.sent_at,
  created_at = EXCLUDED.created_at;

INSERT INTO subscription_plans (
  id,
  name,
  description,
  duration_days,
  price_vnd,
  feature_group,
  is_active,
  created_at
) VALUES
  ('dddddddd-dddd-dddd-dddd-ddddddddddd1', 'Free', 'Gói miễn phí cho người dùng mới.', 30, 0, 'free', TRUE, NOW()),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd2', 'Performance', 'Gói tối ưu meal plan và macro cá nhân.', 30, 99000, 'performance', TRUE, NOW())
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  duration_days = EXCLUDED.duration_days,
  price_vnd = EXCLUDED.price_vnd,
  feature_group = EXCLUDED.feature_group,
  is_active = EXCLUDED.is_active,
  created_at = EXCLUDED.created_at;

INSERT INTO subscriptions (
  id,
  user_id,
  plan_id,
  status,
  auto_renew,
  started_at,
  expires_at,
  created_at
) VALUES
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1', '11111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-ddddddddddd2', 'active', TRUE, NOW(), NOW() + INTERVAL '30 days', NOW())
ON CONFLICT (id) DO UPDATE SET
  plan_id = EXCLUDED.plan_id,
  status = EXCLUDED.status,
  auto_renew = EXCLUDED.auto_renew,
  started_at = EXCLUDED.started_at,
  expires_at = EXCLUDED.expires_at,
  created_at = EXCLUDED.created_at;

INSERT INTO payments (
  id,
  user_id,
  subscription_id,
  amount_vnd,
  status,
  payment_method,
  created_at
) VALUES
  ('ffffffff-ffff-ffff-ffff-fffffffffff1', '11111111-1111-1111-1111-111111111111', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeee1', 99000, 'paid', 'sepay', NOW())
ON CONFLICT (id) DO UPDATE SET
  amount_vnd = EXCLUDED.amount_vnd,
  status = EXCLUDED.status,
  payment_method = EXCLUDED.payment_method,
  created_at = EXCLUDED.created_at;

INSERT INTO sepay_transactions (
  id,
  payment_id,
  transaction_code,
  bank_account,
  transfer_amount,
  transfer_content,
  transaction_time,
  status,
  created_at
) VALUES
  ('ffffffff-ffff-ffff-ffff-fffffffffff2', 'ffffffff-ffff-ffff-ffff-fffffffffff1', 'SEPAY-DEMO-001', '970422-DEMO', 99000, 'MENUGREEN DEMO USER PERFORMANCE', NOW(), 'matched', NOW())
ON CONFLICT (id) DO UPDATE SET
  transaction_code = EXCLUDED.transaction_code,
  bank_account = EXCLUDED.bank_account,
  transfer_amount = EXCLUDED.transfer_amount,
  transfer_content = EXCLUDED.transfer_content,
  transaction_time = EXCLUDED.transaction_time,
  status = EXCLUDED.status,
  created_at = EXCLUDED.created_at;

INSERT INTO activity_logs (
  id,
  user_id,
  action,
  entity_type,
  entity_id,
  metadata,
  created_at
) VALUES
  (
    'abababab-abab-abab-abab-ababababab01',
    '11111111-1111-1111-1111-111111111111',
    'ai_feedback',
    'ai_message',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
    '{"feedback_type":"thumbs_up","rating":5,"feature_area":"nutrition_chat","source":"seed"}'::json,
    NOW()
  ),
  (
    'abababab-abab-abab-abab-ababababab02',
    '11111111-1111-1111-1111-111111111111',
    'ai_training_sample',
    'ai_feedback',
    'abababab-abab-abab-abab-ababababab01',
    '{"feedback_id":"abababab-abab-abab-abab-ababababab01","source":"seed","input_text":"Hôm nay tôi còn bao nhiêu calo?","expected_output":"Bạn còn khoảng 1270 kcal.","labels":["nutrition_chat"],"status":"pending"}'::json,
    NOW()
  )
ON CONFLICT (id) DO UPDATE SET
  action = EXCLUDED.action,
  entity_type = EXCLUDED.entity_type,
  entity_id = EXCLUDED.entity_id,
  metadata = EXCLUDED.metadata,
  created_at = EXCLUDED.created_at;

INSERT INTO budget_requests (
  id,
  user_id,
  budget_vnd,
  time_limit_min,
  result,
  created_at
) VALUES
  (
    'cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcd01',
    '11111111-1111-1111-1111-111111111111',
    70000,
    30,
    '{"suggestions":["Trứng luộc khoai lang","Salad ức gà"],"estimated_total_vnd":63000}'::json,
    NOW()
  )
ON CONFLICT (id) DO UPDATE SET
  budget_vnd = EXCLUDED.budget_vnd,
  time_limit_min = EXCLUDED.time_limit_min,
  result = EXCLUDED.result,
  created_at = EXCLUDED.created_at;

COMMIT;
