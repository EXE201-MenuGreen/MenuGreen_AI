# Weekly AI Training Runbook (MenuGreen)

Updated: 2026-05-23

## 1) Goal

Run incremental retraining for AI intent + response quality using curated user feedback.

## 2) Data Gate (must pass before training)

Use these thresholds for weekly run:

- `approved` training samples >= 120
- Per-priority feature coverage:
  - `nutrition_chat` >= 40
  - `meal_recommendation` >= 40
  - `meal_plan_generation` >= 20
- Rejection rate in reviewed samples <= 35%
- Safety-critical feedback ratio <= 10%

If gate fails, skip training and continue curation/review.

## 3) Endpoints used in the loop

- Collect feedback: `POST /api/ai/feedback`
- Curate nightly: `POST /api/ai/curation/nightly`
- Review dataset: `PATCH /api/ai/training-samples/{sampleId}/review`
- List dataset: `GET /api/ai/training-samples?status=approved&limit=500`

## 4) Weekly execution steps

1. Run curation:
   - `POST /api/ai/curation/nightly?limit=2000`
2. Reviewer approves/rejects pending samples.
3. Validate data gate.
4. Retrain intent model.
5. Export ONNX.
6. Deploy ONNX bundle to runtime.
7. Smoke test runtime and FE capability console.

## 5) Training commands

```powershell
cd D:\EXE\RAG_AI_MenuGreen

# dataset refresh
python -X utf8 tools\training\generate_dataset.py

# train
python -X utf8 tools\training\train_intent_classifier.py

# export + quantize + package
python -X utf8 tools\training\export_onnx.py
```

Output expected:

- Trained model: `tools/training/menu_green_intent_model/best`
- ONNX runtime: `runtime/models/intent_onnx`
- Zip bundle: `tools/training/dist/intent_onnx_runtime.zip`

## 6) Pass/Fail criteria

Pass if all conditions meet:

- Intent eval:
  - Macro F1 >= 0.90
  - No class with F1 < 0.82 in `recipe_search`, `nutrition_calc`, `meal_plan`
- Runtime functional checks:
  - `/worker/chat` works for 10/10 smoke prompts
  - `/api/ai/meal-plans/7d` returns 21 items (7 days x 3 meals)
  - Safety layer triggers correctly on risky prompts
- Operational:
  - No new 5xx regression on AI endpoints in smoke test

Fail if any gate above is broken; rollback ONNX to previous bundle.

## 7) Rollback

1. Keep previous `runtime/models/intent_onnx` backup as `intent_onnx_prev`.
2. If regression found:
   - Stop runtime
   - Restore `intent_onnx_prev` -> `intent_onnx`
   - Start runtime and re-run smoke tests

## 8) Definition of done (weekly)

- Nightly curation executed.
- Enough approved samples for next cycle.
- New ONNX deployed or explicit skip reason logged.
- Short weekly note published:
  - sample counts
  - model metrics
  - issues and next actions
