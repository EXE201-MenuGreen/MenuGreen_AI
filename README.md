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

## Demo User Seed (Supabase)
- Runtime currently reads/writes user context only when `user_id` is a valid UUID.
- To avoid `Goal=unknown` and `0.0 kcal` during demo, seed a fixed user:
  - SQL file: `infra/sql/seed_demo_user.sql`
  - Demo `user_id`: `11111111-1111-1111-1111-111111111111`
- Run in Supabase SQL Editor, then call `/worker/chat` with that UUID.

## External User ID Support
- If client sends non-UUID user id (e.g. `user_abc_123`), runtime can auto-map to internal UUID.
- Run migration once in Supabase SQL Editor:
  - `infra/sql/migration_external_user_map.sql`
- Runtime will auto-create:
  - `profiles` row (default target values)
  - `external_user_map` row (`external_user_id -> profiles.id`)

## Next Steps
- Port working endpoints from old project into `runtime/app` modules.
- Add Supabase repositories for profile + meal logs context.
- Add contract tests before replacing old service.
