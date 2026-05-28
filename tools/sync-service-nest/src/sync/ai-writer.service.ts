import { Injectable, Logger, OnModuleDestroy } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Pool } from "pg";
import { TableSyncConfig } from "./sync.types";

@Injectable()
export class AiWriterService implements OnModuleDestroy {
  private readonly logger = new Logger(AiWriterService.name);
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

  async upsertBatch(
    cfg: TableSyncConfig,
    rows: Record<string, unknown>[],
  ): Promise<number> {
    if (!rows.length) return 0;

    const columns = Object.keys(rows[0]);
    if (!columns.length) return 0;

    const params: unknown[] = [];
    const valuesSql = rows
      .map((row, rowIndex) => {
        const placeholders = columns.map((column, colIndex) => {
          params.push(row[column]);
          return `$${rowIndex * columns.length + colIndex + 1}`;
        });
        return `(${placeholders.join(", ")})`;
      })
      .join(", ");

    const updateSql = columns
      .filter((column) => column !== cfg.onConflict)
      .map((column) => `${quoteIdent(column)} = EXCLUDED.${quoteIdent(column)}`)
      .join(", ");

    const sql = `
      INSERT INTO ${quoteIdent(cfg.table)} (${columns.map(quoteIdent).join(", ")})
      VALUES ${valuesSql}
      ON CONFLICT (${quoteIdent(cfg.onConflict)})
      DO UPDATE SET ${updateSql || `${quoteIdent(cfg.onConflict)} = EXCLUDED.${quoteIdent(cfg.onConflict)}`}
    `;

    try {
      await this.pool.query(sql, params);
      return rows.length;
    } catch (error) {
      this.logger.error(`Upsert failed for ${cfg.table}: ${String(error)}`);
      throw error;
    }
  }
}

function quoteIdent(value: string): string {
  if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(value)) {
    throw new Error(`Unsafe SQL identifier: ${value}`);
  }
  return `"${value}"`;
}
