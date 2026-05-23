export type SyncMode = "incremental" | "full";

export interface TableSyncConfig {
  table: string;
  mode: SyncMode;
  cursorColumn?: "updated_at" | "created_at";
  onConflict: string;
}

export interface SyncRunResult {
  table: string;
  mode: SyncMode;
  fetched: number;
  upserted: number;
  deadLettered: number;
  lastCursor?: string | null;
}
