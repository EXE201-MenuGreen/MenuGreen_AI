import { Controller, Param, Post } from "@nestjs/common";
import { SyncService } from "./sync.service";

@Controller("sync")
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @Post("run")
  async runAll() {
    const results = await this.syncService.runAll();
    return { ok: true, results };
  }

  @Post("run/:table")
  async runOne(@Param("table") table: string) {
    const result = await this.syncService.runOne(table);
    return { ok: true, result };
  }
}
