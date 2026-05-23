import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createClient, SupabaseClient } from "@supabase/supabase-js";

@Injectable()
export class SyncStateService {
  private readonly client: SupabaseClient;

  constructor(private readonly config: ConfigService) {
    const url = this.config.get<string>("SUPABASE_URL");
    const key = this.config.get<string>("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !key) {
      throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    }
    this.client = createClient(url, key, { auth: { persistSession: false } });
  }

  async getCursor(table: string): Promise<string | null> {
    const { data, error } = await this.client
      .from("sync_offsets")
      .select("last_synced_at")
      .eq("source_table", table)
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    return data?.last_synced_at ?? null;
  }

  async saveCursor(table: string, cursor: string): Promise<void> {
    const { error } = await this.client.from("sync_offsets").upsert(
      {
        source_table: table,
        last_synced_at: cursor,
      },
      { onConflict: "source_table" },
    );
    if (error) throw error;
  }

  async addDeadLetter(input: {
    sourceTable: string;
    eventId?: string | null;
    payload: unknown;
    error: string;
    retryCount?: number;
  }): Promise<void> {
    const { error } = await this.client.from("sync_dead_letter").insert({
      source_table: input.sourceTable,
      event_id: input.eventId ?? null,
      payload: input.payload,
      error: input.error,
      retry_count: input.retryCount ?? 0,
    });
    if (error) throw error;
  }
}
