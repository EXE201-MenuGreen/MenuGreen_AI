# RAG Worker Basic Implementation Report

Updated: 2026-06-23

## What was implemented

This pass implements the worker-first foundation for MenuGreen AI runtime before linking more deeply into MenuGreenSystem.

### Runtime auth

- Added optional env setting `AI_RUNTIME_INTERNAL_KEY`.
- `/health` stays open.
- All other routes require `X-AI-Runtime-Key` only when `AI_RUNTIME_INTERNAL_KEY` is configured.
- If the key is empty, local development remains unchanged.

### Worker context contract

- Added `GET /worker/context?user_id={id}&date=YYYY-MM-DD`.
- Response includes:
  - `user_profile`
  - `nutritional_target`
  - `actual_intake_today`
  - `remaining_budget_today`
  - `safety_and_allergies`
  - `preferences`
  - `current_meal_plan`
  - `subscription`
  - `data_quality`
- Context reads PostgreSQL through best-effort repository methods and degrades with `data_quality` instead of crashing when optional tables/columns are missing.

### Chat contract extension

- Kept existing `/worker/chat` request and legacy response fields.
- Added backward-compatible response fields:
  - `actions`
  - `suggested_prompts`
  - `safety_flags`
  - `context_summary`
  - `recommendation_refs`

### Streaming chat

- Added `POST /worker/chat/stream`.
- Uses SSE `text/event-stream`.
- Basic event flow:
  - `start`
  - `delta`
  - `actions`
  - `safety`
  - `final`
  - `done`
  - `error`
- Current basic implementation chunks the full rule/DB response. True provider token streaming is reserved for advanced phase.

### Action/function-calling schema

- Added `ActionSuggestion` contract with:
  - `id`
  - `type`
  - `title`
  - `description`
  - `requires_confirmation`
  - `payload`
  - `safety_notes`
- Basic action types:
  - `generate_meal_plan`
  - `replace_food`
  - `budget_optimize`
  - `schedule_meal`
  - `show_recipe`
  - `log_meal`
  - `ask_followup`
- Added `POST /api/ai/actions/execute` as a basic safe stub. Non-read actions require confirmation and deeper execution remains for the fill/advanced phase.

### Recommendation worker endpoints

Added worker-compatible recommendation endpoints:

- `POST /api/ai/recommendations/generate`
- `POST /api/ai/recommendations/safe`
- `POST /api/ai/recommendations/daily-menu`
- `POST /api/ai/recommendations/weekly-plan`
- `POST /api/ai/recommendations/budget-aware`
- `POST /api/ai/recommendations/smart-schedule`

The shared response returns:

- `items`
- `reasons`
- `scores`
- `safety_flags`
- `excluded_items`
- `actions`
- `context_summary`

### Allergy filtering

- Added `AllergySafetyService`.
- Filters candidates using context allergy keys/names, blocked ingredients, disliked ingredients, and candidate ingredient/allergen/tag fields.
- Unsafe excluded items are returned with reasons.

### Contract tests

- Added FastAPI contract tests with fake services/repo.
- Covered:
  - `/health` open under auth key
  - optional auth key behavior
  - `/worker/context` response shape
  - allergy filtering in `/safe`
  - budget-aware, daily-menu, weekly-plan, smart-schedule
  - `/worker/chat` backward-compatible extended fields
  - `/worker/chat/stream` event order
  - existing `/api/ai/meal-plans/7d` still works

## Verification

Commands run:

```powershell
python -m compileall runtime/app
.\.venv\Scripts\python.exe -m pip install pytest==8.3.4
.\.venv\Scripts\python.exe -m pytest tests -q
```

Result:

- Compile passed.
- Tests passed: `8 passed`.

Note: global Python did not have `pytest`; tests were run with the repo-local `.venv`.

## Deferred work

- Link MenuGreenSystem public APIs to these new worker endpoints.
- Add true LLM planner/function-calling execution.
- Add true provider token streaming.
- Add production metrics/logging for recommendation/context/safety failures.
- Add DB integration tests behind an env flag.
- Add stronger allergy matching from normalized ingredient/allergen join tables if the production schema exposes those relationships consistently.
