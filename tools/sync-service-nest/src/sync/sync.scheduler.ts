import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Cron } from "@nestjs/schedule";
import { SyncService } from "./sync.service";

@Injectable()
export class SyncScheduler {
  private readonly logger = new Logger(SyncScheduler.name);

  constructor(
    private readonly config: ConfigService,
    private readonly syncService: SyncService,
  ) {}

  @Cron("*/2 * * * *")
  async handleCron() {
    const enabled = (this.config.get<string>("SYNC_ENABLED") || "true").toLowerCase() === "true";
    if (!enabled) return;

    this.logger.log("Cron sync started");
    try {
      await this.syncService.runAll();
    } catch (err) {
      this.logger.error(`Cron sync failed: ${String(err)}`);
    }
  }
}
