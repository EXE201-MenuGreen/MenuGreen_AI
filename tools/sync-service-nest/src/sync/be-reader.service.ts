import { Injectable, Logger, OnModuleDestroy } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Pool } from "pg";
import { TableSyncConfig } from "./sync.types";

@Injectable()
export class BeReaderService implements OnModuleDestroy {
  private readonly logger = new Logger(BeReaderService.name);
  private readonly pool: Pool;

  constructor(private readonly config: ConfigService) {
    const connectionString = this.config.get<string>("BE_DATABASE_URL");
    if (!connectionString) {
      throw new Error("Missing BE_DATABASE_URL");
    }
    this.pool = new Pool({ connectionString });
  }

  async onModuleDestroy() {
    await this.pool.end();
  }

  async fetchIncremental(
    cfg: TableSyncConfig,
    cursor: string | null,
    batchSize: number,
  ): Promise<Record<string, unknown>[]> {
    if (!cfg.cursorColumn) {
      throw new Error(`Table ${cfg.table} missing cursorColumn for incremental mode`);
    }
    const table = quoteIdent(cfg.table);
    const cursorColumn = quoteIdent(cfg.cursorColumn);
    const sql = `SELECT * FROM ${table} WHERE ${cursorColumn} > $1 ORDER BY ${cursorColumn} ASC LIMIT $2`;
    const params = [cursor ?? "1970-01-01T00:00:00Z", batchSize];
    const res = await this.pool.query(sql, params);
    return res.rows;
  }

  async fetchFull(
    cfg: TableSyncConfig,
    batchSize: number,
    offset: number,
  ): Promise<Record<string, unknown>[]> {
    const sql = `SELECT * FROM ${quoteIdent(cfg.table)} ORDER BY 1 LIMIT $1 OFFSET $2`;
    const res = await this.pool.query(sql, [batchSize, offset]);
    return res.rows;
  }

  async ping(): Promise<void> {
    await this.pool.query("SELECT 1");
    this.logger.log("Connected to BE database");
  }
}

function quoteIdent(value: string): string {
  if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(value)) {
    throw new Error(`Unsafe SQL identifier: ${value}`);
  }
  return `"${value}"`;
}
