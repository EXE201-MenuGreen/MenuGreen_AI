# Sync Service (NestJS Skeleton)

BE database -> AI Supabase synchronization worker with:
- cron scheduler
- upsert by table
- dead-letter logging into `sync_dead_letter`

Cron is set to `*/2 * * * *` (every 2 minutes) in code.

## Quick start

```powershell
cd D:\EXE\RAG_AI_MenuGreen\tools\sync-service-nest
copy .env.example .env
npm install
npm run start:dev
```

## Endpoints

- `GET /health`
- `POST /sync/run` (run all configured tables once)
- `POST /sync/run/:table` (run one table once)

## Required target tables

- `sync_offsets`
- `sync_dead_letter`

These are created by:
- [database_setup.sql](/D:/EXE/RAG_AI_MenuGreen/infra/sql/database_setup.sql)
- [migration_from_current.sql](/D:/EXE/RAG_AI_MenuGreen/infra/sql/migration_from_current.sql)
