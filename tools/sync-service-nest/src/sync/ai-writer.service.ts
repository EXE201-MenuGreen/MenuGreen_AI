import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { TableSyncConfig } from "./sync.types";

@Injectable()
export class AiWriterService {
  private readonly logger = new Logger(AiWriterService.name);
  private readonly client: SupabaseClient;

  constructor(private readonly config: ConfigService) {
    const url = this.config.get<string>("SUPABASE_URL");
    const key = this.config.get<string>("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !key) {
      throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    }
    this.client = createClient(url, key, { auth: { persistSession: false } });
  }

  async upsertBatch(
    cfg: TableSyncConfig,
    rows: Record<string, unknown>[],
  ): Promise<number> {
    if (!rows.length) return 0;
    const { error } = await this.client
      .from(cfg.table)
      .upsert(rows, { onConflict: cfg.onConflict, ignoreDuplicates: false });
    if (error) {
      this.logger.error(`Upsert failed for ${cfg.table}: ${error.message}`);
      throw error;
    }
    return rows.length;
  }
}
