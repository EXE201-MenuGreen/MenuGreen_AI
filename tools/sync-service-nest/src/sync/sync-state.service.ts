import { Injectable, OnModuleDestroy } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Pool } from "pg";

@Injectable()
export class SyncStateService implements OnModuleDestroy {
  private readonly pool: Pool;

  constructor(private readonly config: ConfigService) {
    const connectionString =
      this.config.get<string>("POSTGRES_URL") ||
      this.config.get<string>("AI_DATABASE_URL");
    if (!connectionString) {
      throw new Error("Missing POSTGRES_URL or AI_DATABASE_URL");
    }
    this.pool = new Pool({ connectionString });
  }

  async onModuleDestroy() {
    await this.pool.end();
  }

  async getCursor(table: string): Promise<string | null> {
    const res = await this.pool.query(
      "SELECT last_synced_at FROM sync_offsets WHERE source_table = $1 LIMIT 1",
      [table],
    );
    return res.rows[0]?.last_synced_at?.toISOString?.() ?? res.rows[0]?.last_synced_at ?? null;
  }

  async saveCursor(table: string, cursor: string): Promise<void> {
    await this.pool.query(
      `
        INSERT INTO sync_offsets (source_table, last_synced_at)
        VALUES ($1, $2)
        ON CONFLICT (source_table)
        DO UPDATE SET last_synced_at = EXCLUDED.last_synced_at
      `,
      [table, cursor],
    );
  }

  async addDeadLetter(input: {
    sourceTable: string;
    eventId?: string | null;
    payload: unknown;
    error: string;
    retryCount?: number;
  }): Promise<void> {
    await this.pool.query(
      `
        INSERT INTO sync_dead_letter (source_table, event_id, payload, error, retry_count)
        VALUES ($1, $2, $3, $4, $5)
      `,
      [
        input.sourceTable,
        input.eventId ?? null,
        JSON.stringify(input.payload),
        input.error,
        input.retryCount ?? 0,
      ],
    );
  }
}
