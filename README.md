# RAG AI MenuGreen (Clean Rebuild)

Clean, runtime-first rebuild for MenuGreen AI Coach.

## Goals
- Keep runtime stable and minimal.
- Keep ONNX inference as primary path.
- Isolate training/data-discovery scripts from production runtime.
- Remove overlapping fallback logic and centralize fallback policy.

## Project Layout
- `runtime/`: production API service (FastAPI) for chat/coach.
- `tools/`: training/export/data scripts (not required for prod startup).
- `research/`: experiments, notebooks, ad-hoc validation.
- `infra/`: local/devops scripts.
- `docs/`: architecture, migration, and contracts.
- `tests/`: API + service tests.

## Runtime Principles
1. Runtime loads prebuilt ONNX from `runtime/models/intent_onnx`.
2. If ONNX unavailable, fallback occurs in one place only.
3. No training/export scripts imported by runtime.
4. Runtime dependencies are pinned and separated from dev/training deps.

## Quick Start (runtime)
```powershell
cd runtime
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements-runtime.txt
uvicorn app.main:app --reload --port 8000
```

## Setup For Teammates
Recommended local prerequisites:
- Python `3.11+` for runtime work
- Node.js `20+` for `tools/sync-service-nest`
- PostgreSQL connection string for the runtime DB
- Gemini API key if you want hybrid rewrite/fallback enabled

Runtime setup from a clean clone:
```powershell
cd D:\EXE\RAG_AI_MenuGreen\runtime
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements-runtime.txt
```

Minimal runtime `.env`:
```env
POSTGRES_URL=postgresql://username:password@host:5432/dbname
GOOGLE_API_KEY=your_gemini_api_key
```

Run the runtime:
```powershell
cd D:\EXE\RAG_AI_MenuGreen\runtime
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --port 8000
```

Sync service setup:
```powershell
cd D:\EXE\RAG_AI_MenuGreen\tools\sync-service-nest
copy .env.example .env
npm install
npm run build
npm run start:dev
```

Repository hygiene:
- Commit `package-lock.json` files.
- Do not commit `.venv`, `.venv311`, `node_modules`, or `dist`.
- These local/build folders are already covered by `.gitignore`.

## Demo User Seed (PostgreSQL)
- Runtime connects with `POSTGRES_URL`.
- Runtime can auto-create a local PostgreSQL demo user for non-UUID IDs.
- For fixed demo data, seed PostgreSQL and call `/worker/chat` with that UUID.

## External User ID Support
- If client sends non-UUID user id (e.g. `user_abc_123`), runtime derives a stable internal UUID.
- Runtime will auto-create:
  - `roles` default row when needed
  - `users` row
  - `profiles` row
  - `health_profiles` row with default target values

## Next Steps
- Port working endpoints from old project into `runtime/app` modules.
- Add PostgreSQL repositories for profile + meal logs context.
- Add contract tests before replacing old service.
