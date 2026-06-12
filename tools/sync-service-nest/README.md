# Sync Service (NestJS Skeleton)

BE database -> AI PostgreSQL synchronization worker with:
- cron scheduler
- upsert by table
- dead-letter logging into `sync_dead_letter`

Cron is set to `*/2 * * * *` (every 2 minutes) in code.

## Quick start

```powershell
cd D:\EXE\RAG_AI_MenuGreen\tools\sync-service-nest
npm install
npm run build
npm run start:dev
```

This service reads the shared root env file:
- [`.env`](/D:/EXE/RAG_AI_MenuGreen/.env)

## Install Notes

Expected local requirements:
- Node.js `20+`
- npm
- Access to both source BE database and target AI PostgreSQL

Important Git note:
- Commit `package-lock.json`
- Do not commit `node_modules/`
- Do not commit `dist/`

After clone, each teammate should run:

```powershell
cd D:\EXE\RAG_AI_MenuGreen\tools\sync-service-nest
npm install
npm run build
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
