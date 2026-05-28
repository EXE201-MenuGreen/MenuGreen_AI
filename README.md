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
