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

## Next Steps
- Port working endpoints from old project into `runtime/app` modules.
- Add Supabase repositories for profile + meal logs context.
- Add contract tests before replacing old service.
