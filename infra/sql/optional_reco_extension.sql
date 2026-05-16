-- Optional extension for recommendation experiments (food domain)
-- Keep this separate from core runtime schema.

BEGIN;

CREATE TABLE IF NOT EXISTS user_item_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    item_type TEXT NOT NULL DEFAULT 'recipe' CHECK (item_type IN ('recipe', 'food')),
    item_id UUID NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('view', 'click', 'save', 'consume', 'rate')),
    event_value NUMERIC,
    event_ts TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_user_item_interactions_user_ts
    ON user_item_interactions(user_id, event_ts DESC);

CREATE INDEX IF NOT EXISTS idx_user_item_interactions_item
    ON user_item_interactions(item_type, item_id);

ALTER TABLE user_item_interactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_item_interactions_select_own ON user_item_interactions;
CREATE POLICY user_item_interactions_select_own
    ON user_item_interactions FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_item_interactions_insert_own ON user_item_interactions;
CREATE POLICY user_item_interactions_insert_own
    ON user_item_interactions FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_item_interactions_update_own ON user_item_interactions;
CREATE POLICY user_item_interactions_update_own
    ON user_item_interactions FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_item_interactions_delete_own ON user_item_interactions;
CREATE POLICY user_item_interactions_delete_own
    ON user_item_interactions FOR DELETE USING (auth.uid() = user_id);

COMMIT;
