-- RAG_AI_MenuGreen database bootstrap (new project)
-- Date: 2026-05-15
-- Purpose:
-- 1) Clean runtime schema for AI Coach (profile + meal logs + chat sessions)
-- 2) Keep optional RAG/recipe capability separated but available
-- 3) Preserve compatibility by exposing legacy-style views where useful

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================================
-- CORE: USERS / PROFILE / SUBSCRIPTION
-- ============================================================================

CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    full_name TEXT,
    age INT,
    gender TEXT CHECK (gender IN ('male', 'female', 'other')),
    height_cm NUMERIC,
    weight_kg NUMERIC,
    activity_level TEXT CHECK (activity_level IN ('sedentary', 'light', 'moderate', 'active', 'very_active')),
    goal TEXT CHECK (goal IN ('lose_fat', 'maintain', 'gain_muscle')),
    tdee_kcal NUMERIC,
    target_calories NUMERIC,
    target_protein_g NUMERIC,
    target_carbs_g NUMERIC,
    target_fat_g NUMERIC,
    dietary_preferences TEXT[],
    allergies TEXT[]
);

CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    plan TEXT NOT NULL CHECK (plan IN ('free', 'saving', 'energy', 'performance')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'expired', 'cancelled')),
    started_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS external_user_map (
    external_user_id TEXT PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- CORE: LOGGING / COACH
-- ============================================================================

CREATE TABLE IF NOT EXISTS meal_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    logged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    meal_type TEXT CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    food_name TEXT,
    estimated_grams NUMERIC,
    calories_kcal NUMERIC DEFAULT 0,
    protein_g NUMERIC DEFAULT 0,
    carbs_g NUMERIC DEFAULT 0,
    fat_g NUMERIC DEFAULT 0,
    fiber_g NUMERIC DEFAULT 0,
    confidence NUMERIC,
    image_url TEXT,
    scan_request_id TEXT,
    source TEXT DEFAULT 'manual' CHECK (source IN ('manual', 'vision', 'import'))
);

CREATE TABLE IF NOT EXISTS ai_chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    thread_id TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    context_snapshot JSONB,
    tokens_used INT,
    model_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('alert', 'suggestion', 'weekly')),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- OPTIONAL: FOOD MASTER FOR VISION MAPPING
-- ============================================================================

CREATE TABLE IF NOT EXISTS foods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    calories_kcal_per_100g NUMERIC NOT NULL,
    protein_g_per_100g NUMERIC NOT NULL,
    carbs_g_per_100g NUMERIC NOT NULL,
    fat_g_per_100g NUMERIC NOT NULL,
    fiber_g_per_100g NUMERIC DEFAULT 0,
    default_serving_g NUMERIC,
    serving_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS food_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alias TEXT NOT NULL,
    food_id UUID NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_food_aliases_alias_search
    ON food_aliases USING gin (to_tsvector('simple', alias));

-- ============================================================================
-- OPTIONAL: PLANNING
-- ============================================================================

CREATE TABLE IF NOT EXISTS meal_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    plan_date DATE NOT NULL,
    meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    food_name TEXT,
    target_grams NUMERIC,
    mode TEXT DEFAULT 'balanced',
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- OPTIONAL: RAG / RECIPES (kept for separated project capabilities)
-- ============================================================================

CREATE TABLE IF NOT EXISTS ingredients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    calories_per_100g NUMERIC NOT NULL,
    protein_per_100g NUMERIC NOT NULL,
    carbs_per_100g NUMERIC NOT NULL,
    fat_per_100g NUMERIC NOT NULL,
    fiber_per_100g NUMERIC DEFAULT 0,
    category TEXT
);

CREATE TABLE IF NOT EXISTS recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    instructions TEXT,
    prep_time_minutes INT,
    cook_time_minutes INT,
    servings INT,
    image_url TEXT,
    dietary_tags TEXT[],
    calories_per_serving NUMERIC,
    protein_per_serving NUMERIC,
    carbs_per_serving NUMERIC,
    fat_per_serving NUMERIC,
    embedding VECTOR(3072)
);

CREATE TABLE IF NOT EXISTS recipe_ingredients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE,
    ingredient_id UUID REFERENCES ingredients(id) ON DELETE SET NULL,
    amount NUMERIC NOT NULL,
    unit TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    ingredient_id UUID REFERENCES ingredients(id) ON DELETE CASCADE,
    quantity NUMERIC NOT NULL,
    unit TEXT,
    expiry_date DATE,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, ingredient_id)
);

CREATE INDEX IF NOT EXISTS idx_recipes_name_search ON recipes USING gin(to_tsvector('simple', name));
CREATE INDEX IF NOT EXISTS idx_recipes_embedding
    ON recipes USING hnsw ((embedding::halfvec(3072)) halfvec_cosine_ops);

DROP FUNCTION IF EXISTS match_recipes(vector, double precision, integer);

CREATE OR REPLACE FUNCTION match_recipes(
    query_embedding VECTOR(3072),
    match_threshold DOUBLE PRECISION DEFAULT 0.5,
    match_count INT DEFAULT 5
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    prep_time_minutes INT,
    cook_time_minutes INT,
    servings INT,
    dietary_tags TEXT[],
    similarity DOUBLE PRECISION
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        r.name,
        r.description,
        r.prep_time_minutes,
        r.cook_time_minutes,
        r.servings,
        r.dietary_tags,
        1 - ((r.embedding::halfvec(3072)) <=> (query_embedding::halfvec(3072))) AS similarity
    FROM recipes r
    WHERE r.embedding IS NOT NULL
      AND 1 - ((r.embedding::halfvec(3072)) <=> (query_embedding::halfvec(3072))) > match_threshold
    ORDER BY (r.embedding::halfvec(3072)) <=> (query_embedding::halfvec(3072))
    LIMIT match_count;
END;
$$;

-- ============================================================================
-- COMPAT VIEWS (for easier migration from old service naming)
-- ============================================================================

CREATE OR REPLACE VIEW user_profiles AS
SELECT
    id,
    created_at,
    updated_at,
    COALESCE(full_name, '') AS name,
    age,
    gender,
    height_cm,
    weight_kg,
    activity_level,
    goal,
    dietary_preferences,
    allergies
FROM profiles;

CREATE OR REPLACE VIEW user_subscriptions AS
SELECT
    id,
    user_id,
    plan AS tier,
    started_at,
    expires_at,
    (status = 'active') AS is_active,
    created_at,
    updated_at
FROM subscriptions;

CREATE OR REPLACE VIEW daily_logs AS
SELECT
    id,
    user_id,
    logged_at::date AS date,
    calories_kcal AS calories_consumed,
    protein_g AS protein_consumed,
    carbs_g AS carbs_consumed,
    fat_g AS fat_consumed,
    NULL::INT AS water_ml,
    NULL::TEXT AS mood,
    NULL::INT AS energy_level,
    NULL::INT AS health_score,
    NULL::TEXT AS notes
FROM meal_logs;

-- ============================================================================
-- INDEXES FOR RUNTIME QUERIES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_meal_logs_user_logged_at ON meal_logs(user_id, logged_at);
CREATE INDEX IF NOT EXISTS idx_ai_chat_sessions_user_thread_created ON ai_chat_sessions(user_id, thread_id, created_at);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status ON subscriptions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_meal_plans_user_plan_date ON meal_plans(user_id, plan_date);

-- ============================================================================
-- RLS
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE external_user_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_aliases ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_inventory ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_select_own ON profiles;
CREATE POLICY profiles_select_own ON profiles FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS profiles_update_own ON profiles;
CREATE POLICY profiles_update_own ON profiles FOR UPDATE USING (auth.uid() = id);
DROP POLICY IF EXISTS profiles_insert_own ON profiles;
CREATE POLICY profiles_insert_own ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS subscriptions_select_own ON subscriptions;
CREATE POLICY subscriptions_select_own ON subscriptions FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS subscriptions_insert_own ON subscriptions;
CREATE POLICY subscriptions_insert_own ON subscriptions FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS subscriptions_update_own ON subscriptions;
CREATE POLICY subscriptions_update_own ON subscriptions FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS external_user_map_select_own ON external_user_map;
CREATE POLICY external_user_map_select_own ON external_user_map FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS external_user_map_insert_own ON external_user_map;
CREATE POLICY external_user_map_insert_own ON external_user_map FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS external_user_map_update_own ON external_user_map;
CREATE POLICY external_user_map_update_own ON external_user_map FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS meal_logs_select_own ON meal_logs;
CREATE POLICY meal_logs_select_own ON meal_logs FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS meal_logs_insert_own ON meal_logs;
CREATE POLICY meal_logs_insert_own ON meal_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS meal_logs_update_own ON meal_logs;
CREATE POLICY meal_logs_update_own ON meal_logs FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS meal_logs_delete_own ON meal_logs;
CREATE POLICY meal_logs_delete_own ON meal_logs FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_chat_sessions_select_own ON ai_chat_sessions;
CREATE POLICY ai_chat_sessions_select_own ON ai_chat_sessions FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS ai_chat_sessions_insert_own ON ai_chat_sessions;
CREATE POLICY ai_chat_sessions_insert_own ON ai_chat_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_recommendations_select_own ON ai_recommendations;
CREATE POLICY ai_recommendations_select_own ON ai_recommendations FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS ai_recommendations_insert_own ON ai_recommendations;
CREATE POLICY ai_recommendations_insert_own ON ai_recommendations FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS ai_recommendations_update_own ON ai_recommendations;
CREATE POLICY ai_recommendations_update_own ON ai_recommendations FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS meal_plans_select_own ON meal_plans;
CREATE POLICY meal_plans_select_own ON meal_plans FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS meal_plans_insert_own ON meal_plans;
CREATE POLICY meal_plans_insert_own ON meal_plans FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS meal_plans_update_own ON meal_plans;
CREATE POLICY meal_plans_update_own ON meal_plans FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS meal_plans_delete_own ON meal_plans;
CREATE POLICY meal_plans_delete_own ON meal_plans FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS foods_select_all ON foods;
CREATE POLICY foods_select_all ON foods FOR SELECT USING (true);
DROP POLICY IF EXISTS foods_admin_all ON foods;
CREATE POLICY foods_admin_all ON foods
    FOR ALL USING (
        (auth.jwt() ->> 'role')::text = 'admin'
        OR (auth.jwt() -> 'user_metadata' ->> 'role')::text = 'admin'
    );

DROP POLICY IF EXISTS food_aliases_select_all ON food_aliases;
CREATE POLICY food_aliases_select_all ON food_aliases FOR SELECT USING (true);
DROP POLICY IF EXISTS food_aliases_admin_all ON food_aliases;
CREATE POLICY food_aliases_admin_all ON food_aliases
    FOR ALL USING (
        (auth.jwt() ->> 'role')::text = 'admin'
        OR (auth.jwt() -> 'user_metadata' ->> 'role')::text = 'admin'
    );

DROP POLICY IF EXISTS ingredients_select_all ON ingredients;
CREATE POLICY ingredients_select_all ON ingredients FOR SELECT USING (true);
DROP POLICY IF EXISTS ingredients_admin_all ON ingredients;
CREATE POLICY ingredients_admin_all ON ingredients
    FOR ALL USING (
        (auth.jwt() ->> 'role')::text = 'admin'
        OR (auth.jwt() -> 'user_metadata' ->> 'role')::text = 'admin'
    );

DROP POLICY IF EXISTS recipes_select_all ON recipes;
CREATE POLICY recipes_select_all ON recipes FOR SELECT USING (true);
DROP POLICY IF EXISTS recipes_admin_all ON recipes;
CREATE POLICY recipes_admin_all ON recipes
    FOR ALL USING (
        (auth.jwt() ->> 'role')::text = 'admin'
        OR (auth.jwt() -> 'user_metadata' ->> 'role')::text = 'admin'
    );

DROP POLICY IF EXISTS recipe_ingredients_select_all ON recipe_ingredients;
CREATE POLICY recipe_ingredients_select_all ON recipe_ingredients FOR SELECT USING (true);
DROP POLICY IF EXISTS recipe_ingredients_admin_all ON recipe_ingredients;
CREATE POLICY recipe_ingredients_admin_all ON recipe_ingredients
    FOR ALL USING (
        (auth.jwt() ->> 'role')::text = 'admin'
        OR (auth.jwt() -> 'user_metadata' ->> 'role')::text = 'admin'
    );

DROP POLICY IF EXISTS user_inventory_select_own ON user_inventory;
CREATE POLICY user_inventory_select_own ON user_inventory FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS user_inventory_insert_own ON user_inventory;
CREATE POLICY user_inventory_insert_own ON user_inventory FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_inventory_update_own ON user_inventory;
CREATE POLICY user_inventory_update_own ON user_inventory FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS user_inventory_delete_own ON user_inventory;
CREATE POLICY user_inventory_delete_own ON user_inventory FOR DELETE USING (auth.uid() = user_id);

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON subscriptions;
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_foods_updated_at ON foods;
CREATE TRIGGER update_foods_updated_at
    BEFORE UPDATE ON foods
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_meal_plans_updated_at ON meal_plans;
CREATE TRIGGER update_meal_plans_updated_at
    BEFORE UPDATE ON meal_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMIT;
