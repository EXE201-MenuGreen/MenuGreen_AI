-- Non-destructive migration: current schema -> BE-aligned AI schema
-- Safe mode: no DROP SCHEMA / no data wipe
-- Date: 2026-05-23

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================================
-- Helpers
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
-- Ensure missing tables exist
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

CREATE TABLE IF NOT EXISTS external_user_map (
  external_user_id TEXT PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
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

CREATE TABLE IF NOT EXISTS notification_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  meal_reminder_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  water_reminder_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  workout_reminder_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  subscription_reminder_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  quiet_hours_start TIME,
  quiet_hours_end TIME,
  timezone TEXT NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS exercise_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  logged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  activity_type TEXT NOT NULL,
  duration_min INT,
  calories_burned_kcal NUMERIC,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payment_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
  plan_id UUID REFERENCES subscription_plans(id) ON DELETE SET NULL,
  provider TEXT NOT NULL,
  provider_transaction_id TEXT UNIQUE,
  amount_vnd INT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'VND',
  status TEXT NOT NULL DEFAULT 'pending',
  request_payload JSONB,
  callback_payload JSONB,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS meal_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  logged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  meal_type TEXT,
  food_id UUID REFERENCES foods(id) ON DELETE SET NULL,
  recipe_id UUID REFERENCES recipes(id) ON DELETE SET NULL,
  food_label TEXT,
  food_name TEXT,
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
  scan_request_id TEXT,
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
  food_name TEXT
);

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

CREATE TABLE IF NOT EXISTS ai_feedback_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES ai_conversations(id) ON DELETE SET NULL,
  message_id UUID REFERENCES ai_messages(id) ON DELETE SET NULL,
  thread_id TEXT,
  feedback_type TEXT NOT NULL CHECK (feedback_type IN ('thumbs_up', 'thumbs_down', 'correction', 'rating')),
  rating SMALLINT CHECK (rating BETWEEN 1 AND 5),
  user_note TEXT,
  assistant_response TEXT,
  corrected_response TEXT,
  feature_area TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_training_samples (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feedback_id UUID REFERENCES ai_feedback_events(id) ON DELETE SET NULL,
  source TEXT NOT NULL DEFAULT 'user_feedback',
  input_text TEXT NOT NULL,
  context_json JSONB,
  expected_output TEXT NOT NULL,
  labels TEXT[] DEFAULT ARRAY[]::TEXT[],
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'trained')),
  reviewed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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
-- Add missing columns to existing tables (non-breaking)
-- ============================================================================

ALTER TABLE IF EXISTS profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user';
ALTER TABLE IF EXISTS profiles ADD COLUMN IF NOT EXISTS age INT;
ALTER TABLE IF EXISTS profiles ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE IF EXISTS profiles ADD COLUMN IF NOT EXISTS body_fat_percent NUMERIC;
ALTER TABLE IF EXISTS profiles ADD COLUMN IF NOT EXISTS bmr_kcal INT;
ALTER TABLE IF EXISTS profiles ADD COLUMN IF NOT EXISTS preferred_cuisine TEXT;
ALTER TABLE IF EXISTS profiles ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE IF EXISTS profiles ADD COLUMN IF NOT EXISTS dietary_preferences TEXT[] DEFAULT ARRAY[]::TEXT[];
ALTER TABLE IF EXISTS profiles ADD COLUMN IF NOT EXISTS allergies TEXT[] DEFAULT ARRAY[]::TEXT[];

ALTER TABLE IF EXISTS subscriptions ADD COLUMN IF NOT EXISTS plan_id UUID;
ALTER TABLE IF EXISTS subscriptions ADD COLUMN IF NOT EXISTS plan TEXT DEFAULT 'free';
ALTER TABLE IF EXISTS subscriptions ADD COLUMN IF NOT EXISTS auto_renew BOOLEAN DEFAULT FALSE;
ALTER TABLE IF EXISTS subscriptions ADD COLUMN IF NOT EXISTS payment_provider TEXT;
ALTER TABLE IF EXISTS subscriptions ADD COLUMN IF NOT EXISTS payment_reference TEXT;
ALTER TABLE IF EXISTS subscriptions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS subscriptions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS slug TEXT;
ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS name_vi TEXT;
ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS name_en TEXT;
ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS calories_kcal NUMERIC;
ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS protein_g NUMERIC;
ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS carbs_g NUMERIC;
ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS fat_g NUMERIC;
ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS fiber_g NUMERIC;
ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS unit_default TEXT DEFAULT 'g';
ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS estimated_price_vnd INT;
ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS ingredients ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS slug TEXT;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS name_vi TEXT;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS name_en TEXT;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'general';
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS calories_kcal NUMERIC DEFAULT 0;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS protein_g NUMERIC DEFAULT 0;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS carbs_g NUMERIC DEFAULT 0;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS fat_g NUMERIC DEFAULT 0;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS fiber_g NUMERIC;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS sugar_g NUMERIC;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS sodium_mg NUMERIC;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS estimated_price_vnd INT;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS default_serving_g INT DEFAULT 100;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS source TEXT;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS calories_kcal_per_100g NUMERIC;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS protein_g_per_100g NUMERIC;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS carbs_g_per_100g NUMERIC;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS fat_g_per_100g NUMERIC;
ALTER TABLE IF EXISTS foods ADD COLUMN IF NOT EXISTS fiber_g_per_100g NUMERIC;

ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS food_id UUID;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS slug TEXT;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS prep_time_min INT;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS cook_time_min INT;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS total_time_min INT;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS difficulty TEXT;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS meal_type TEXT;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS estimated_price_vnd INT;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS video_url TEXT;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS calories_kcal NUMERIC;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS protein_g NUMERIC;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS carbs_g NUMERIC;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS fat_g NUMERIC;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS fiber_g NUMERIC;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS sugar_g NUMERIC;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS sodium_mg NUMERIC;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS instructions_text TEXT;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS prep_time_minutes INT;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS cook_time_minutes INT;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS dietary_tags TEXT[] DEFAULT ARRAY[]::TEXT[];
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS calories_per_serving NUMERIC;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS protein_per_serving NUMERIC;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS carbs_per_serving NUMERIC;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS fat_per_serving NUMERIC;
ALTER TABLE IF EXISTS recipes ADD COLUMN IF NOT EXISTS embedding VECTOR(3072);

ALTER TABLE IF EXISTS recipe_ingredients ADD COLUMN IF NOT EXISTS quantity NUMERIC;
ALTER TABLE IF EXISTS recipe_ingredients ADD COLUMN IF NOT EXISTS amount NUMERIC;
ALTER TABLE IF EXISTS recipe_ingredients ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE IF EXISTS meal_logs ADD COLUMN IF NOT EXISTS food_id UUID;
ALTER TABLE IF EXISTS meal_logs ADD COLUMN IF NOT EXISTS recipe_id UUID;
ALTER TABLE IF EXISTS meal_logs ADD COLUMN IF NOT EXISTS food_label TEXT;
ALTER TABLE IF EXISTS meal_logs ADD COLUMN IF NOT EXISTS food_name TEXT;
ALTER TABLE IF EXISTS meal_logs ADD COLUMN IF NOT EXISTS sugar_g NUMERIC;
ALTER TABLE IF EXISTS meal_logs ADD COLUMN IF NOT EXISTS is_manual BOOLEAN DEFAULT TRUE;
ALTER TABLE IF EXISTS meal_logs ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS meal_plans ADD COLUMN IF NOT EXISTS food_id UUID;
ALTER TABLE IF EXISTS meal_plans ADD COLUMN IF NOT EXISTS recipe_id UUID;
ALTER TABLE IF EXISTS meal_plans ADD COLUMN IF NOT EXISTS target_calories INT;
ALTER TABLE IF EXISTS meal_plans ADD COLUMN IF NOT EXISTS target_grams INT;
ALTER TABLE IF EXISTS meal_plans ADD COLUMN IF NOT EXISTS food_name TEXT;
ALTER TABLE IF EXISTS meal_plans ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================================================
-- Backfill and compat sync
-- ============================================================================

UPDATE ingredients
SET name_vi = COALESCE(NULLIF(name_vi, ''), NULLIF(name, ''))
WHERE name_vi IS NULL;

UPDATE foods
SET name_vi = COALESCE(NULLIF(name_vi, ''), NULLIF(name, ''))
WHERE name_vi IS NULL;

UPDATE recipes
SET title = COALESCE(NULLIF(title, ''), NULLIF(name, ''))
WHERE title IS NULL;

UPDATE foods
SET slug = normalize_slug(COALESCE(name_vi, name_en, name))
WHERE slug IS NULL;

UPDATE ingredients
SET slug = normalize_slug(COALESCE(name_vi, name_en, name))
WHERE slug IS NULL;

UPDATE recipes
SET slug = normalize_slug(COALESCE(title, name))
WHERE slug IS NULL;

-- ============================================================================
-- Compatibility trigger refresh (safe for old + new shape)
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_recipe_compat_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.title := COALESCE(NULLIF(NEW.title, ''), NULLIF(NEW.name, ''), 'recipe');
  NEW.name := COALESCE(NULLIF(NEW.name, ''), NEW.title);
  NEW.slug := COALESCE(NULLIF(NEW.slug, ''), normalize_slug(COALESCE(NEW.title, NEW.name)));
  NEW.instructions_text := COALESCE(NEW.instructions_text, to_jsonb(NEW) ->> 'instructions');
  NEW.prep_time_min := COALESCE(NEW.prep_time_min, NEW.prep_time_minutes);
  NEW.cook_time_min := COALESCE(NEW.cook_time_min, NEW.cook_time_minutes);
  NEW.prep_time_minutes := COALESCE(NEW.prep_time_minutes, NEW.prep_time_min);
  NEW.cook_time_minutes := COALESCE(NEW.cook_time_minutes, NEW.cook_time_min);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_recipe_compat_columns ON recipes;
CREATE TRIGGER trg_sync_recipe_compat_columns
BEFORE INSERT OR UPDATE ON recipes
FOR EACH ROW EXECUTE FUNCTION sync_recipe_compat_columns();

-- ============================================================================
-- Indexes and RLS for newly added tables
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_exercise_logs_user_logged_at ON exercise_logs(user_id, logged_at);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_user_created ON payment_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_feedback_events_user_created ON ai_feedback_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_training_samples_status_created ON ai_training_samples(status, created_at DESC);

ALTER TABLE notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE external_user_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_feedback_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_training_samples ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_offsets ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_dead_letter ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS external_user_map_select_own ON external_user_map;
CREATE POLICY external_user_map_select_own ON external_user_map FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS external_user_map_insert_own ON external_user_map;
CREATE POLICY external_user_map_insert_own ON external_user_map FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS external_user_map_update_own ON external_user_map;
CREATE POLICY external_user_map_update_own ON external_user_map FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS notification_settings_select_own ON notification_settings;
CREATE POLICY notification_settings_select_own ON notification_settings FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS notification_settings_insert_own ON notification_settings;
CREATE POLICY notification_settings_insert_own ON notification_settings FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS notification_settings_update_own ON notification_settings;
CREATE POLICY notification_settings_update_own ON notification_settings FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS exercise_logs_select_own ON exercise_logs;
CREATE POLICY exercise_logs_select_own ON exercise_logs FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS exercise_logs_insert_own ON exercise_logs;
CREATE POLICY exercise_logs_insert_own ON exercise_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS exercise_logs_update_own ON exercise_logs;
CREATE POLICY exercise_logs_update_own ON exercise_logs FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS exercise_logs_delete_own ON exercise_logs;
CREATE POLICY exercise_logs_delete_own ON exercise_logs FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS payment_transactions_select_own ON payment_transactions;
CREATE POLICY payment_transactions_select_own ON payment_transactions FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_feedback_events_select_own ON ai_feedback_events;
CREATE POLICY ai_feedback_events_select_own ON ai_feedback_events FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS ai_feedback_events_insert_own ON ai_feedback_events;
CREATE POLICY ai_feedback_events_insert_own ON ai_feedback_events FOR INSERT WITH CHECK (auth.uid() = user_id);

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

DROP POLICY IF EXISTS ai_training_samples_admin_all ON ai_training_samples;
CREATE POLICY ai_training_samples_admin_all ON ai_training_samples FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS sync_offsets_admin_all ON sync_offsets;
CREATE POLICY sync_offsets_admin_all ON sync_offsets FOR ALL USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS sync_dead_letter_admin_all ON sync_dead_letter;
CREATE POLICY sync_dead_letter_admin_all ON sync_dead_letter FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP TRIGGER IF EXISTS update_notification_settings_updated_at ON notification_settings;
CREATE TRIGGER update_notification_settings_updated_at
BEFORE UPDATE ON notification_settings
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_exercise_logs_updated_at ON exercise_logs;
CREATE TRIGGER update_exercise_logs_updated_at
BEFORE UPDATE ON exercise_logs
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_payment_transactions_updated_at ON payment_transactions;
CREATE TRIGGER update_payment_transactions_updated_at
BEFORE UPDATE ON payment_transactions
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_ai_training_samples_updated_at ON ai_training_samples;
CREATE TRIGGER update_ai_training_samples_updated_at
BEFORE UPDATE ON ai_training_samples
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_sync_offsets_updated_at ON sync_offsets;
CREATE TRIGGER update_sync_offsets_updated_at
BEFORE UPDATE ON sync_offsets
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMIT;
