import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { ScheduleModule } from "@nestjs/schedule";
import { resolve } from "node:path";
import { AppController } from "./app.controller";
import { AiWriterService } from "./sync/ai-writer.service";
import { BeReaderService } from "./sync/be-reader.service";
import { SyncController } from "./sync/sync.controller";
import { SyncScheduler } from "./sync/sync.scheduler";
import { SyncService } from "./sync/sync.service";
import { SyncStateService } from "./sync/sync-state.service";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: [resolve(__dirname, "../../../.env")],
    }),
    ScheduleModule.forRoot(),
  ],
  controllers: [AppController, SyncController],
  providers: [
    BeReaderService,
    AiWriterService,
    SyncStateService,
    SyncService,
    SyncScheduler,
  ],
})
export class AppModule {}
