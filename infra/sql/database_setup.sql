-- RAG_AI_MenuGreen Supabase bootstrap (BE-aligned + AI-runtime compatible)
-- Date: 2026-05-23
-- Purpose:
-- 1) Align schema with Backend DBML for easier synchronization
-- 2) Keep compatibility for current AI runtime (legacy columns/table names)
-- 3) Add sync metadata tables for BE -> AI replication jobs

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================================
-- HELPERS
-- ============================================================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (auth.jwt() ->> 'role') = 'admin'
    OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin',
    false
  );
$$;

CREATE OR REPLACE FUNCTION normalize_slug(input_text TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  s TEXT;
BEGIN
  s := lower(COALESCE(input_text, ''));
  s := regexp_replace(s, '[^a-z0-9]+', '-', 'g');
  s := trim(both '-' from s);
  RETURN s;
END;
$$;

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

-- ============================================================================
-- USERS / AUTH SHADOW
-- Note: auth.users is still the auth source of truth in Supabase.
-- public.users exists for BE migration compatibility only.
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT,
  email_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_sign_in_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_token TEXT NOT NULL UNIQUE,
  user_agent TEXT,
  ip_address INET,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- PROFILE / SUBSCRIPTION
-- ============================================================================

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'user',
  age INT, -- legacy compatibility
  date_of_birth DATE,
  gender TEXT,
  height_cm NUMERIC,
  weight_kg NUMERIC,
  body_fat_percent NUMERIC,
  activity_level TEXT NOT NULL DEFAULT 'moderate',
  goal TEXT,
  tdee_kcal INT,
  bmr_kcal INT,
  target_calories INT,
  target_protein_g INT,
  target_carbs_g INT,
  target_fat_g INT,
  preferred_cuisine TEXT,
  dietary_preferences TEXT[] DEFAULT ARRAY[]::TEXT[],
  allergies TEXT[] DEFAULT ARRAY[]::TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS external_user_map (
  external_user_id TEXT PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  duration_days INT,
  price_vnd INT,
  feature_group TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  plan_id UUID REFERENCES subscription_plans(id) ON DELETE SET NULL,
  plan TEXT NOT NULL DEFAULT 'free', -- runtime compatibility
  status TEXT NOT NULL DEFAULT 'active',
  auto_renew BOOLEAN NOT NULL DEFAULT FALSE,
  payment_provider TEXT,
  payment_reference TEXT,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- FOOD KNOWLEDGE
-- ============================================================================

CREATE TABLE IF NOT EXISTS ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name_vi TEXT NOT NULL,
  name_en TEXT,
  category TEXT,
  image_url TEXT,
  calories_kcal NUMERIC,
  protein_g NUMERIC,
  carbs_g NUMERIC,
  fat_g NUMERIC,
  fiber_g NUMERIC,
  unit_default TEXT NOT NULL DEFAULT 'g',
  estimated_price_vnd INT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- legacy compatibility columns
  name TEXT,
  calories_per_100g NUMERIC,
  protein_per_100g NUMERIC,
  carbs_per_100g NUMERIC,
  fat_per_100g NUMERIC,
  fiber_per_100g NUMERIC
);

CREATE TABLE IF NOT EXISTS foods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name_vi TEXT NOT NULL,
  name_en TEXT,
  category TEXT NOT NULL DEFAULT 'general',
  description TEXT,
  image_url TEXT,
  calories_kcal NUMERIC NOT NULL DEFAULT 0,
  protein_g NUMERIC NOT NULL DEFAULT 0,
  carbs_g NUMERIC NOT NULL DEFAULT 0,
  fat_g NUMERIC NOT NULL DEFAULT 0,
  fiber_g NUMERIC,
  sugar_g NUMERIC,
  sodium_mg NUMERIC,
  estimated_price_vnd INT,
  default_serving_g INT NOT NULL DEFAULT 100,
  source TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- legacy compatibility columns
  name TEXT,
  calories_kcal_per_100g NUMERIC,
  protein_g_per_100g NUMERIC,
  carbs_g_per_100g NUMERIC,
  fat_g_per_100g NUMERIC,
  fiber_g_per_100g NUMERIC
);

CREATE TABLE IF NOT EXISTS recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  food_id UUID REFERENCES foods(id) ON DELETE SET NULL,
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  prep_time_min INT,
  cook_time_min INT,
  total_time_min INT,
  servings INT NOT NULL DEFAULT 1,
  difficulty TEXT,
  meal_type TEXT,
  estimated_price_vnd INT,
  instructions JSONB,
  video_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  calories_kcal NUMERIC,
  protein_g NUMERIC,
  carbs_g NUMERIC,
  fat_g NUMERIC,
  fiber_g NUMERIC,
  sugar_g NUMERIC,
  sodium_mg NUMERIC,
  -- legacy compatibility columns
  name TEXT,
  instructions_text TEXT,
  prep_time_minutes INT,
  cook_time_minutes INT,
  dietary_tags TEXT[] DEFAULT ARRAY[]::TEXT[],
  calories_per_serving NUMERIC,
  protein_per_serving NUMERIC,
  carbs_per_serving NUMERIC,
  fat_per_serving NUMERIC,
  embedding VECTOR(3072)
);

CREATE TABLE IF NOT EXISTS recipe_ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
  quantity NUMERIC,
  amount NUMERIC, -- legacy compatibility
  unit TEXT,
  notes TEXT
);

-- ============================================================================
-- USER CONTEXT TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS meal_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  logged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  meal_type TEXT,
  food_id UUID REFERENCES foods(id) ON DELETE SET NULL,
  recipe_id UUID REFERENCES recipes(id) ON DELETE SET NULL,
  food_label TEXT,
  food_name TEXT, -- legacy compatibility
  estimated_grams NUMERIC,
  calories_kcal NUMERIC,
  protein_g NUMERIC,
  carbs_g NUMERIC,
  fat_g NUMERIC,
  fiber_g NUMERIC,
  sugar_g NUMERIC,
  image_url TEXT,
  confidence NUMERIC,
  notes TEXT,
  is_manual BOOLEAN NOT NULL DEFAULT TRUE,
  scan_request_id TEXT, -- legacy compatibility
  source TEXT DEFAULT 'manual',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fridge_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  ingredient_id UUID REFERENCES ingredients(id) ON DELETE SET NULL,
  custom_name TEXT,
  quantity NUMERIC,
  unit TEXT,
  minimum_quantity NUMERIC,
  purchase_date DATE,
  expires_at DATE,
  is_expired BOOLEAN NOT NULL DEFAULT FALSE,
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS meal_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  plan_date DATE NOT NULL,
  meal_type TEXT NOT NULL,
  food_id UUID REFERENCES foods(id) ON DELETE SET NULL,
  recipe_id UUID REFERENCES recipes(id) ON DELETE SET NULL,
  target_calories INT,
  target_grams INT,
  mode TEXT,
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  food_name TEXT -- legacy compatibility
);

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- AI CONVERSATION TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS ai_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  tokens_used INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Runtime table used by current repository.save_chat_session()
CREATE TABLE IF NOT EXISTS ai_chat_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  thread_id TEXT NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  context_snapshot JSONB,
  tokens_used INT,
  model_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_recommendations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Legacy table still referenced by optional SQL / older runtime modules
CREATE TABLE IF NOT EXISTS user_inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  ingredient_id UUID REFERENCES ingredients(id) ON DELETE CASCADE,
  quantity NUMERIC NOT NULL,
  unit TEXT,
  expiry_date DATE,
  added_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, ingredient_id)
);

-- ============================================================================
-- SYNC METADATA TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS sync_offsets (
  source_table TEXT PRIMARY KEY,
  last_synced_at TIMESTAMPTZ,
  last_event_id TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sync_dead_letter (
  id BIGSERIAL PRIMARY KEY,
  source_table TEXT NOT NULL,
  event_id TEXT,
  payload JSONB,
  error TEXT NOT NULL,
  retry_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- COMPATIBILITY TRIGGERS (legacy <-> BE columns)
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_food_compat_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.name_vi IS NULL OR btrim(NEW.name_vi) = '' THEN
    NEW.name_vi := COALESCE(NULLIF(btrim(NEW.name), ''), NULLIF(btrim(NEW.name_en), ''), 'food');
  END IF;
  IF NEW.name IS NULL OR btrim(NEW.name) = '' THEN
    NEW.name := COALESCE(NULLIF(btrim(NEW.name_vi), ''), NULLIF(btrim(NEW.name_en), ''));
  END IF;
  IF NEW.slug IS NULL OR btrim(NEW.slug) = '' THEN
    NEW.slug := normalize_slug(COALESCE(NEW.name_vi, NEW.name, ''));
    IF NEW.slug IS NULL OR NEW.slug = '' THEN
      NEW.slug := 'food-' || replace(gen_random_uuid()::TEXT, '-', '');
    END IF;
  END IF;

  NEW.calories_kcal := COALESCE(NEW.calories_kcal, NEW.calories_kcal_per_100g, 0);
  NEW.protein_g := COALESCE(NEW.protein_g, NEW.protein_g_per_100g, 0);
  NEW.carbs_g := COALESCE(NEW.carbs_g, NEW.carbs_g_per_100g, 0);
  NEW.fat_g := COALESCE(NEW.fat_g, NEW.fat_g_per_100g, 0);
  NEW.fiber_g := COALESCE(NEW.fiber_g, NEW.fiber_g_per_100g);

  NEW.calories_kcal_per_100g := COALESCE(NEW.calories_kcal_per_100g, NEW.calories_kcal);
  NEW.protein_g_per_100g := COALESCE(NEW.protein_g_per_100g, NEW.protein_g);
  NEW.carbs_g_per_100g := COALESCE(NEW.carbs_g_per_100g, NEW.carbs_g);
  NEW.fat_g_per_100g := COALESCE(NEW.fat_g_per_100g, NEW.fat_g);
  NEW.fiber_g_per_100g := COALESCE(NEW.fiber_g_per_100g, NEW.fiber_g);

  NEW.default_serving_g := COALESCE(NEW.default_serving_g, 100);
  NEW.category := COALESCE(NEW.category, 'general');
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION sync_ingredient_compat_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.name_vi IS NULL OR btrim(NEW.name_vi) = '' THEN
    NEW.name_vi := COALESCE(NULLIF(btrim(NEW.name), ''), NULLIF(btrim(NEW.name_en), ''), 'ingredient');
  END IF;
  IF NEW.name IS NULL OR btrim(NEW.name) = '' THEN
    NEW.name := COALESCE(NULLIF(btrim(NEW.name_vi), ''), NULLIF(btrim(NEW.name_en), ''));
  END IF;
  IF NEW.slug IS NULL OR btrim(NEW.slug) = '' THEN
    NEW.slug := normalize_slug(COALESCE(NEW.name_vi, NEW.name, ''));
    IF NEW.slug IS NULL OR NEW.slug = '' THEN
      NEW.slug := 'ingredient-' || replace(gen_random_uuid()::TEXT, '-', '');
    END IF;
  END IF;

  NEW.calories_kcal := COALESCE(NEW.calories_kcal, NEW.calories_per_100g, 0);
  NEW.protein_g := COALESCE(NEW.protein_g, NEW.protein_per_100g, 0);
  NEW.carbs_g := COALESCE(NEW.carbs_g, NEW.carbs_per_100g, 0);
  NEW.fat_g := COALESCE(NEW.fat_g, NEW.fat_per_100g, 0);
  NEW.fiber_g := COALESCE(NEW.fiber_g, NEW.fiber_per_100g, 0);

  NEW.calories_per_100g := COALESCE(NEW.calories_per_100g, NEW.calories_kcal);
  NEW.protein_per_100g := COALESCE(NEW.protein_per_100g, NEW.protein_g);
  NEW.carbs_per_100g := COALESCE(NEW.carbs_per_100g, NEW.carbs_g);
  NEW.fat_per_100g := COALESCE(NEW.fat_per_100g, NEW.fat_g);
  NEW.fiber_per_100g := COALESCE(NEW.fiber_per_100g, NEW.fiber_g);
  NEW.unit_default := COALESCE(NULLIF(NEW.unit_default, ''), 'g');
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION sync_recipe_compat_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.title IS NULL OR btrim(NEW.title) = '' THEN
    NEW.title := COALESCE(NULLIF(btrim(NEW.name), ''), 'recipe');
  END IF;
  IF NEW.name IS NULL OR btrim(NEW.name) = '' THEN
    NEW.name := NEW.title;
  END IF;
  IF NEW.slug IS NULL OR btrim(NEW.slug) = '' THEN
    NEW.slug := normalize_slug(COALESCE(NEW.title, NEW.name, ''));
    IF NEW.slug IS NULL OR NEW.slug = '' THEN
      NEW.slug := 'recipe-' || replace(gen_random_uuid()::TEXT, '-', '');
    END IF;
  END IF;

  NEW.prep_time_min := COALESCE(NEW.prep_time_min, NEW.prep_time_minutes);
  NEW.cook_time_min := COALESCE(NEW.cook_time_min, NEW.cook_time_minutes);
  NEW.prep_time_minutes := COALESCE(NEW.prep_time_minutes, NEW.prep_time_min);
  NEW.cook_time_minutes := COALESCE(NEW.cook_time_minutes, NEW.cook_time_min);

  NEW.instructions_text := COALESCE(NEW.instructions_text, NEW.instructions #>> '{}');

  NEW.calories_per_serving := COALESCE(NEW.calories_per_serving, NEW.calories_kcal);
  NEW.protein_per_serving := COALESCE(NEW.protein_per_serving, NEW.protein_g);
  NEW.carbs_per_serving := COALESCE(NEW.carbs_per_serving, NEW.carbs_g);
  NEW.fat_per_serving := COALESCE(NEW.fat_per_serving, NEW.fat_g);

  NEW.calories_kcal := COALESCE(NEW.calories_kcal, NEW.calories_per_serving);
  NEW.protein_g := COALESCE(NEW.protein_g, NEW.protein_per_serving);
  NEW.carbs_g := COALESCE(NEW.carbs_g, NEW.carbs_per_serving);
  NEW.fat_g := COALESCE(NEW.fat_g, NEW.fat_per_serving);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION sync_recipe_ingredient_compat_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.quantity := COALESCE(NEW.quantity, NEW.amount);
  NEW.amount := COALESCE(NEW.amount, NEW.quantity);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION sync_meal_log_compat_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.food_label := COALESCE(NULLIF(NEW.food_label, ''), NULLIF(NEW.food_name, ''));
  NEW.food_name := COALESCE(NULLIF(NEW.food_name, ''), NULLIF(NEW.food_label, ''));
  NEW.source := COALESCE(NULLIF(NEW.source, ''), CASE WHEN NEW.is_manual THEN 'manual' ELSE 'import' END);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_food_compat_columns ON foods;
CREATE TRIGGER trg_sync_food_compat_columns
BEFORE INSERT OR UPDATE ON foods
FOR EACH ROW
EXECUTE FUNCTION sync_food_compat_columns();

DROP TRIGGER IF EXISTS trg_sync_ingredient_compat_columns ON ingredients;
CREATE TRIGGER trg_sync_ingredient_compat_columns
BEFORE INSERT OR UPDATE ON ingredients
FOR EACH ROW
EXECUTE FUNCTION sync_ingredient_compat_columns();

DROP TRIGGER IF EXISTS trg_sync_recipe_compat_columns ON recipes;
CREATE TRIGGER trg_sync_recipe_compat_columns
BEFORE INSERT OR UPDATE ON recipes
FOR EACH ROW
EXECUTE FUNCTION sync_recipe_compat_columns();

DROP TRIGGER IF EXISTS trg_sync_recipe_ingredient_compat_columns ON recipe_ingredients;
CREATE TRIGGER trg_sync_recipe_ingredient_compat_columns
BEFORE INSERT OR UPDATE ON recipe_ingredients
FOR EACH ROW
EXECUTE FUNCTION sync_recipe_ingredient_compat_columns();

DROP TRIGGER IF EXISTS trg_sync_meal_log_compat_columns ON meal_logs;
CREATE TRIGGER trg_sync_meal_log_compat_columns
BEFORE INSERT OR UPDATE ON meal_logs
FOR EACH ROW
EXECUTE FUNCTION sync_meal_log_compat_columns();

-- ============================================================================
-- INDEXES / RAG RPC
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status ON subscriptions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_meal_logs_user_logged_at ON meal_logs(user_id, logged_at);
CREATE INDEX IF NOT EXISTS idx_fridge_items_user_updated ON fridge_items(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_meal_plans_user_plan_date ON meal_plans(user_id, plan_date);
CREATE INDEX IF NOT EXISTS idx_ai_chat_sessions_user_thread_created ON ai_chat_sessions(user_id, thread_id, created_at);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_user_created ON ai_conversations(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_messages_conversation_created ON ai_messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_sync_dead_letter_source_created ON sync_dead_letter(source_table, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_foods_name_search
ON foods USING gin(to_tsvector('simple', COALESCE(name_vi, '') || ' ' || COALESCE(name_en, '') || ' ' || COALESCE(name, '')));

CREATE INDEX IF NOT EXISTS idx_recipes_name_search
ON recipes USING gin(to_tsvector('simple', COALESCE(title, '') || ' ' || COALESCE(name, '')));

CREATE INDEX IF NOT EXISTS idx_ingredients_name_search
ON ingredients USING gin(to_tsvector('simple', COALESCE(name_vi, '') || ' ' || COALESCE(name_en, '') || ' ' || COALESCE(name, '')));

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
    COALESCE(r.name, r.title) AS name,
    r.description,
    COALESCE(r.prep_time_minutes, r.prep_time_min) AS prep_time_minutes,
    COALESCE(r.cook_time_minutes, r.cook_time_min) AS cook_time_minutes,
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
-- COMPAT VIEWS
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
  COALESCE(plan, 'free') AS tier,
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
  logged_at::DATE AS date,
  calories_kcal AS calories_consumed,
  protein_g AS protein_consumed,
  carbs_g AS carbs_consumed,
  fat_g AS fat_consumed,
  NULL::INT AS water_ml,
  NULL::TEXT AS mood,
  NULL::INT AS energy_level,
  NULL::INT AS health_score,
  notes
FROM meal_logs;

-- ============================================================================
-- RLS
-- ============================================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE external_user_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE fridge_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_offsets ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_dead_letter ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_select_own ON profiles;
CREATE POLICY profiles_select_own ON profiles FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS profiles_insert_own ON profiles;
CREATE POLICY profiles_insert_own ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS profiles_update_own ON profiles;
CREATE POLICY profiles_update_own ON profiles FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS external_user_map_select_own ON external_user_map;
CREATE POLICY external_user_map_select_own ON external_user_map FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS external_user_map_insert_own ON external_user_map;
CREATE POLICY external_user_map_insert_own ON external_user_map FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS external_user_map_update_own ON external_user_map;
CREATE POLICY external_user_map_update_own ON external_user_map FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS subscriptions_select_own ON subscriptions;
CREATE POLICY subscriptions_select_own ON subscriptions FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS subscriptions_insert_own ON subscriptions;
CREATE POLICY subscriptions_insert_own ON subscriptions FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS subscriptions_update_own ON subscriptions;
CREATE POLICY subscriptions_update_own ON subscriptions FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS meal_logs_select_own ON meal_logs;
CREATE POLICY meal_logs_select_own ON meal_logs FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS meal_logs_insert_own ON meal_logs;
CREATE POLICY meal_logs_insert_own ON meal_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS meal_logs_update_own ON meal_logs;
CREATE POLICY meal_logs_update_own ON meal_logs FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS meal_logs_delete_own ON meal_logs;
CREATE POLICY meal_logs_delete_own ON meal_logs FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS fridge_items_select_own ON fridge_items;
CREATE POLICY fridge_items_select_own ON fridge_items FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS fridge_items_insert_own ON fridge_items;
CREATE POLICY fridge_items_insert_own ON fridge_items FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS fridge_items_update_own ON fridge_items;
CREATE POLICY fridge_items_update_own ON fridge_items FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS fridge_items_delete_own ON fridge_items;
CREATE POLICY fridge_items_delete_own ON fridge_items FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS meal_plans_select_own ON meal_plans;
CREATE POLICY meal_plans_select_own ON meal_plans FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS meal_plans_insert_own ON meal_plans;
CREATE POLICY meal_plans_insert_own ON meal_plans FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS meal_plans_update_own ON meal_plans;
CREATE POLICY meal_plans_update_own ON meal_plans FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS meal_plans_delete_own ON meal_plans;
CREATE POLICY meal_plans_delete_own ON meal_plans FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS notifications_select_own ON notifications;
CREATE POLICY notifications_select_own ON notifications FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS notifications_insert_own ON notifications;
CREATE POLICY notifications_insert_own ON notifications FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS notifications_update_own ON notifications;
CREATE POLICY notifications_update_own ON notifications FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_conversations_select_own ON ai_conversations;
CREATE POLICY ai_conversations_select_own ON ai_conversations FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS ai_conversations_insert_own ON ai_conversations;
CREATE POLICY ai_conversations_insert_own ON ai_conversations FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS ai_conversations_update_own ON ai_conversations;
CREATE POLICY ai_conversations_update_own ON ai_conversations FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS ai_conversations_delete_own ON ai_conversations;
CREATE POLICY ai_conversations_delete_own ON ai_conversations FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_messages_select_own ON ai_messages;
CREATE POLICY ai_messages_select_own ON ai_messages
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM ai_conversations c
    WHERE c.id = ai_messages.conversation_id
      AND c.user_id = auth.uid()
  )
);
DROP POLICY IF EXISTS ai_messages_insert_own ON ai_messages;
CREATE POLICY ai_messages_insert_own ON ai_messages
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM ai_conversations c
    WHERE c.id = ai_messages.conversation_id
      AND c.user_id = auth.uid()
  )
);
DROP POLICY IF EXISTS ai_messages_update_own ON ai_messages;
CREATE POLICY ai_messages_update_own ON ai_messages
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM ai_conversations c
    WHERE c.id = ai_messages.conversation_id
      AND c.user_id = auth.uid()
  )
);
DROP POLICY IF EXISTS ai_messages_delete_own ON ai_messages;
CREATE POLICY ai_messages_delete_own ON ai_messages
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM ai_conversations c
    WHERE c.id = ai_messages.conversation_id
      AND c.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS ai_chat_sessions_select_own ON ai_chat_sessions;
CREATE POLICY ai_chat_sessions_select_own ON ai_chat_sessions FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS ai_chat_sessions_insert_own ON ai_chat_sessions;
CREATE POLICY ai_chat_sessions_insert_own ON ai_chat_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS ai_chat_sessions_update_own ON ai_chat_sessions;
CREATE POLICY ai_chat_sessions_update_own ON ai_chat_sessions FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_recommendations_select_own ON ai_recommendations;
CREATE POLICY ai_recommendations_select_own ON ai_recommendations FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS ai_recommendations_insert_own ON ai_recommendations;
CREATE POLICY ai_recommendations_insert_own ON ai_recommendations FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS ai_recommendations_update_own ON ai_recommendations;
CREATE POLICY ai_recommendations_update_own ON ai_recommendations FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS foods_select_all ON foods;
CREATE POLICY foods_select_all ON foods FOR SELECT USING (true);
DROP POLICY IF EXISTS foods_admin_all ON foods;
CREATE POLICY foods_admin_all ON foods FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS ingredients_select_all ON ingredients;
CREATE POLICY ingredients_select_all ON ingredients FOR SELECT USING (true);
DROP POLICY IF EXISTS ingredients_admin_all ON ingredients;
CREATE POLICY ingredients_admin_all ON ingredients FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS recipes_select_all ON recipes;
CREATE POLICY recipes_select_all ON recipes FOR SELECT USING (true);
DROP POLICY IF EXISTS recipes_admin_all ON recipes;
CREATE POLICY recipes_admin_all ON recipes FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS recipe_ingredients_select_all ON recipe_ingredients;
CREATE POLICY recipe_ingredients_select_all ON recipe_ingredients FOR SELECT USING (true);
DROP POLICY IF EXISTS recipe_ingredients_admin_all ON recipe_ingredients;
CREATE POLICY recipe_ingredients_admin_all ON recipe_ingredients FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS subscription_plans_select_all ON subscription_plans;
CREATE POLICY subscription_plans_select_all ON subscription_plans FOR SELECT USING (true);
DROP POLICY IF EXISTS subscription_plans_admin_all ON subscription_plans;
CREATE POLICY subscription_plans_admin_all ON subscription_plans FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS user_inventory_select_own ON user_inventory;
CREATE POLICY user_inventory_select_own ON user_inventory FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS user_inventory_insert_own ON user_inventory;
CREATE POLICY user_inventory_insert_own ON user_inventory FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_inventory_update_own ON user_inventory;
CREATE POLICY user_inventory_update_own ON user_inventory FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS user_inventory_delete_own ON user_inventory;
CREATE POLICY user_inventory_delete_own ON user_inventory FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS sync_offsets_admin_all ON sync_offsets;
CREATE POLICY sync_offsets_admin_all ON sync_offsets FOR ALL USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS sync_dead_letter_admin_all ON sync_dead_letter;
CREATE POLICY sync_dead_letter_admin_all ON sync_dead_letter FOR ALL USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS users_admin_all ON users;
CREATE POLICY users_admin_all ON users FOR ALL USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS sessions_admin_all ON sessions;
CREATE POLICY sessions_admin_all ON sessions FOR ALL USING (is_admin()) WITH CHECK (is_admin());

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================================
-- UPDATED_AT TRIGGERS
-- ============================================================================

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_subscription_plans_updated_at ON subscription_plans;
CREATE TRIGGER update_subscription_plans_updated_at
BEFORE UPDATE ON subscription_plans
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON subscriptions;
CREATE TRIGGER update_subscriptions_updated_at
BEFORE UPDATE ON subscriptions
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_ingredients_updated_at ON ingredients;
CREATE TRIGGER update_ingredients_updated_at
BEFORE UPDATE ON ingredients
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_foods_updated_at ON foods;
CREATE TRIGGER update_foods_updated_at
BEFORE UPDATE ON foods
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_recipes_updated_at ON recipes;
CREATE TRIGGER update_recipes_updated_at
BEFORE UPDATE ON recipes
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_fridge_items_updated_at ON fridge_items;
CREATE TRIGGER update_fridge_items_updated_at
BEFORE UPDATE ON fridge_items
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_meal_plans_updated_at ON meal_plans;
CREATE TRIGGER update_meal_plans_updated_at
BEFORE UPDATE ON meal_plans
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_sync_offsets_updated_at ON sync_offsets;
CREATE TRIGGER update_sync_offsets_updated_at
BEFORE UPDATE ON sync_offsets
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

COMMIT;
