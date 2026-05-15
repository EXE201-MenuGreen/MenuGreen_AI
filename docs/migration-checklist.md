# Migration Checklist (Old -> Clean Rebuild)

## Phase 1: Runtime bootstrap
- [ ] Port `/worker/chat` request/response contract.
- [ ] Port `profile + meal_logs` context builder only.
- [ ] Keep ONNX intent classifier load from local models.

## Phase 2: Data layer
- [ ] Implement `profiles` repository.
- [ ] Implement `meal_logs` (7-day + today totals) repository.
- [ ] Add integration tests with Supabase staging.

## Phase 3: Coach behavior
- [ ] Build prompt with explicit user context snapshot.
- [ ] Add response guardrails for missing data.
- [ ] Save chat session + tokens used.

## Phase 4: Cleanup
- [ ] Move old training/discovery scripts into `tools/`.
- [ ] Move experiments/notebooks into `research/`.
- [ ] Remove runtime imports that reference training scripts.

## Done criteria
- Runtime starts with only `requirements-runtime.txt`.
- No `ModuleNotFoundError` on clean machine.
- ONNX available -> source=onnx; unavailable -> source=fallback.
- Contract tests pass for `/health` and `/worker/chat`.
