-- Seed 1 demo user for runtime testing (Supabase SQL Editor)
-- Safe to run multiple times.

BEGIN;

-- Fixed UUID for stable FE demo
-- Use this user_id in /worker/chat:
-- 11111111-1111-1111-1111-111111111111

INSERT INTO profiles (
    id,
    full_name,
    age,
    gender,
    height_cm,
    weight_kg,
    activity_level,
    goal,
    tdee_kcal,
    target_calories,
    target_protein_g,
    target_carbs_g,
    target_fat_g,
    dietary_preferences,
    allergies
)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    'Demo User',
    27,
    'male',
    172,
    70,
    'moderate',
    'maintain',
    2300,
    2100,
    140,
    240,
    65,
    ARRAY['high_protein'],
    ARRAY[]::text[]
)
ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    age = EXCLUDED.age,
    gender = EXCLUDED.gender,
    height_cm = EXCLUDED.height_cm,
    weight_kg = EXCLUDED.weight_kg,
    activity_level = EXCLUDED.activity_level,
    goal = EXCLUDED.goal,
    tdee_kcal = EXCLUDED.tdee_kcal,
    target_calories = EXCLUDED.target_calories,
    target_protein_g = EXCLUDED.target_protein_g,
    target_carbs_g = EXCLUDED.target_carbs_g,
    target_fat_g = EXCLUDED.target_fat_g,
    dietary_preferences = EXCLUDED.dietary_preferences,
    allergies = EXCLUDED.allergies,
    updated_at = NOW();

INSERT INTO subscriptions (
    user_id,
    plan,
    status
)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    'performance',
    'active'
)
ON CONFLICT (user_id) DO UPDATE SET
    plan = EXCLUDED.plan,
    status = EXCLUDED.status,
    updated_at = NOW();

-- Clear old demo meal logs for today to avoid duplicate stacking
DELETE FROM meal_logs
WHERE user_id = '11111111-1111-1111-1111-111111111111'
  AND logged_at::date = CURRENT_DATE;

INSERT INTO meal_logs (
    user_id,
    logged_at,
    meal_type,
    food_name,
    estimated_grams,
    calories_kcal,
    protein_g,
    carbs_g,
    fat_g,
    fiber_g,
    confidence,
    source
)
VALUES
(
    '11111111-1111-1111-1111-111111111111',
    NOW() - INTERVAL '8 hours',
    'breakfast',
    'Pho bo',
    450,
    520,
    32,
    62,
    14,
    3,
    0.92,
    'manual'
),
(
    '11111111-1111-1111-1111-111111111111',
    NOW() - INTERVAL '4 hours',
    'lunch',
    'Com ga nuong',
    380,
    610,
    40,
    70,
    18,
    4,
    0.90,
    'manual'
),
(
    '11111111-1111-1111-1111-111111111111',
    NOW() - INTERVAL '1 hours',
    'snack',
    'Sua chua Hy Lap',
    170,
    150,
    13,
    10,
    6,
    0,
    0.96,
    'manual'
);

-- ---------------------------------------------------------------------------
-- AI chat demo rows (so thread_id is visible immediately)
-- ---------------------------------------------------------------------------
DELETE FROM ai_chat_sessions
WHERE user_id = '11111111-1111-1111-1111-111111111111'
  AND thread_id IN ('thread-001', 'thread-002');

INSERT INTO ai_chat_sessions (
    user_id,
    thread_id,
    role,
    content,
    context_snapshot,
    tokens_used,
    model_name
)
VALUES
(
    '11111111-1111-1111-1111-111111111111',
    'thread-001',
    'user',
    'Toi con bao nhieu carb hom nay?',
    '{"source":"seed"}'::jsonb,
    42,
    'gemini-2.5-flash'
),
(
    '11111111-1111-1111-1111-111111111111',
    'thread-001',
    'assistant',
    'Hom nay ban da nap 1280 kcal. Con lai khoang 820 kcal, carbs con lai ~98g.',
    '{"source":"seed"}'::jsonb,
    96,
    'gemini-2.5-flash'
),
(
    '11111111-1111-1111-1111-111111111111',
    'thread-002',
    'user',
    'Hom nay an gi de du protein?',
    '{"source":"seed"}'::jsonb,
    39,
    'gemini-2.5-flash'
),
(
    '11111111-1111-1111-1111-111111111111',
    'thread-002',
    'assistant',
    'Goi y: uc ga ap chao, sua chua Hy Lap, va dau hu non. Muc tieu protein con lai ~55g.',
    '{"source":"seed"}'::jsonb,
    110,
    'gemini-2.5-flash'
);

-- ---------------------------------------------------------------------------
-- Meal plan demo rows
-- ---------------------------------------------------------------------------
DELETE FROM meal_plans
WHERE user_id = '11111111-1111-1111-1111-111111111111'
  AND plan_date = CURRENT_DATE;

INSERT INTO meal_plans (
    user_id,
    plan_date,
    meal_type,
    food_name,
    target_grams,
    mode,
    is_completed
)
VALUES
(
    '11111111-1111-1111-1111-111111111111',
    CURRENT_DATE,
    'breakfast',
    'Pho bo',
    450,
    'balanced',
    TRUE
),
(
    '11111111-1111-1111-1111-111111111111',
    CURRENT_DATE,
    'lunch',
    'Com ga nuong',
    380,
    'balanced',
    TRUE
),
(
    '11111111-1111-1111-1111-111111111111',
    CURRENT_DATE,
    'dinner',
    'Ca hoi ap chao + rau luoc',
    320,
    'balanced',
    FALSE
),
(
    '11111111-1111-1111-1111-111111111111',
    CURRENT_DATE,
    'snack',
    'Sua chua Hy Lap',
    170,
    'balanced',
    TRUE
);

-- ---------------------------------------------------------------------------
-- AI recommendation demo rows
-- ---------------------------------------------------------------------------
DELETE FROM ai_recommendations
WHERE user_id = '11111111-1111-1111-1111-111111111111';

INSERT INTO ai_recommendations (
    user_id,
    type,
    title,
    body,
    data,
    is_read
)
VALUES
(
    '11111111-1111-1111-1111-111111111111',
    'suggestion',
    'Tang protein bua toi',
    'Ban dang thieu protein trong ngay, uu tien mon co ca/ga/tofu cho bua toi.',
    '{"remaining_protein_g":55}'::jsonb,
    FALSE
),
(
    '11111111-1111-1111-1111-111111111111',
    'alert',
    'Can bang carbs',
    'Carbs da dung muc trung binh, tranh them do ngot truoc khi ngu.',
    '{"remaining_carbs_g":98}'::jsonb,
    FALSE
);

-- ---------------------------------------------------------------------------
-- Optional inventory + interaction demo (only if seed ingredients exist)
-- ---------------------------------------------------------------------------
INSERT INTO user_inventory (user_id, ingredient_id, quantity, unit, expiry_date)
SELECT
    '11111111-1111-1111-1111-111111111111',
    i.id,
    500,
    'g',
    CURRENT_DATE + INTERVAL '5 days'
FROM ingredients i
WHERE lower(i.name) IN ('uc ga', 'gao', 'ca hoi')
ON CONFLICT (user_id, ingredient_id) DO UPDATE SET
    quantity = EXCLUDED.quantity,
    unit = EXCLUDED.unit,
    expiry_date = EXCLUDED.expiry_date;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'user_item_interactions'
    ) THEN
        BEGIN
            INSERT INTO user_item_interactions (user_id, item_type, item_id, action, metadata)
            SELECT
                '11111111-1111-1111-1111-111111111111',
                'recipe',
                r.id::text,
                'view',
                '{"source":"seed"}'::jsonb
            FROM recipes r
            LIMIT 2;
        EXCEPTION WHEN OTHERS THEN
            -- Keep seed idempotent across schema variants.
            NULL;
        END;
    END IF;
END
$$;

COMMIT;
