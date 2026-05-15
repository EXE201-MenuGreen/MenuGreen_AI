# Fallback Policy

## Rule
Runtime may fallback in one place only: `app/services/coach_service.py`.

## Allowed flow
1. Try ONNX intent model from `runtime/models/intent_onnx`.
2. If load or inference fails, return one fallback source (`source=fallback`) and log reason.

## Forbidden
- Module-level hidden fallbacks inside multiple files.
- Auto-calling training/export from runtime path.
- Duplicated fallback branches in API router and orchestrator simultaneously.
