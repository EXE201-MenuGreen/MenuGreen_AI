-- Add external user mapping so API can accept non-UUID user_id from client apps

BEGIN;

CREATE TABLE IF NOT EXISTS external_user_map (
    external_user_id TEXT PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE external_user_map ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS external_user_map_select_own ON external_user_map;
CREATE POLICY external_user_map_select_own ON external_user_map FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS external_user_map_insert_own ON external_user_map;
CREATE POLICY external_user_map_insert_own ON external_user_map FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS external_user_map_update_own ON external_user_map;
CREATE POLICY external_user_map_update_own ON external_user_map FOR UPDATE USING (auth.uid() = user_id);

COMMIT;
