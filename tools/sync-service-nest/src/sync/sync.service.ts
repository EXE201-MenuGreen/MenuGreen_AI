import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { AiWriterService } from "./ai-writer.service";
import { BeReaderService } from "./be-reader.service";
import { DEFAULT_TABLE_ORDER, TABLE_CONFIGS } from "./table-config";
import { SyncRunResult } from "./sync.types";
import { SyncStateService } from "./sync-state.service";

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);
  private running = false;

  constructor(
    private readonly config: ConfigService,
    private readonly reader: BeReaderService,
    private readonly writer: AiWriterService,
    private readonly state: SyncStateService,
  ) {}

  resolveTables(): string[] {
    const envTables = (this.config.get<string>("SYNC_TABLES") || "").trim();
    if (!envTables) return DEFAULT_TABLE_ORDER;
    return envTables
      .split(",")
      .map((x) => x.trim())
      .filter((x) => !!x && !!TABLE_CONFIGS[x]);
  }

  async runAll(): Promise<SyncRunResult[]> {
    if (this.running) {
      this.logger.warn("Skip runAll because previous run is still active");
      return [];
    }
    this.running = true;
    const results: SyncRunResult[] = [];
    try {
      for (const table of this.resolveTables()) {
        const result = await this.runOne(table);
        results.push(result);
      }
      return results;
    } finally {
      this.running = false;
    }
  }

  async runOne(table: string): Promise<SyncRunResult> {
    const cfg = TABLE_CONFIGS[table];
    if (!cfg) {
      throw new Error(`Unknown table config: ${table}`);
    }

    const batchSize = Number(this.config.get<string>("SYNC_BATCH_SIZE") || 500);
    let fetched = 0;
    let upserted = 0;
    let deadLettered = 0;
    let lastCursor: string | null = null;

    if (cfg.mode === "incremental") {
      lastCursor = await this.state.getCursor(cfg.table);
      while (true) {
        const rows = await this.reader.fetchIncremental(cfg, lastCursor, batchSize);
        if (!rows.length) break;
        fetched += rows.length;

        try {
          upserted += await this.writer.upsertBatch(cfg, rows);
        } catch (err) {
          deadLettered += rows.length;
          await this.state.addDeadLetter({
            sourceTable: cfg.table,
            payload: rows,
            error: String(err),
          });
          break;
        }

        const cursorCol = cfg.cursorColumn as string;
        const tail = rows[rows.length - 1]?.[cursorCol];
        if (!tail) break;
        lastCursor = tail instanceof Date ? tail.toISOString() : String(tail);
        await this.state.saveCursor(cfg.table, lastCursor);
      }
    } else {
      let offset = 0;
      while (true) {
        const rows = await this.reader.fetchFull(cfg, batchSize, offset);
        if (!rows.length) break;
        fetched += rows.length;

        try {
          upserted += await this.writer.upsertBatch(cfg, rows);
        } catch (err) {
          deadLettered += rows.length;
          await this.state.addDeadLetter({
            sourceTable: cfg.table,
            payload: rows,
            error: String(err),
          });
          break;
        }

        offset += rows.length;
        if (rows.length < batchSize) break;
      }
    }

    const result: SyncRunResult = {
      table: cfg.table,
      mode: cfg.mode,
      fetched,
      upserted,
      deadLettered,
      lastCursor,
    };

    this.logger.log(
      `Sync ${cfg.table} done. mode=${cfg.mode} fetched=${fetched} upserted=${upserted} dead=${deadLettered}`,
    );
    return result;
  }
}
