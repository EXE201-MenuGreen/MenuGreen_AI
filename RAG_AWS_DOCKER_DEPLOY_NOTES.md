# RAG AWS Docker Deploy Notes

## Runtime Shape

The deployable service is the FastAPI runtime under `runtime/`.

Container entrypoint:

```bash
uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
```

The container workdir is `/app/runtime` so the default model path works:

```env
INTENT_MODEL_DIR=models/intent_onnx
```

## Required Runtime Files

The Docker image copies only:

- `runtime/app`
- `runtime/frontend`
- `runtime/models`
- `runtime/requirements-runtime.txt`

The `.dockerignore` excludes dev folders, virtualenvs, logs, `.env`, training assets, and the large fp32 `runtime/models/intent_onnx/model.onnx`.

The runtime still includes `model.int8.onnx`, tokenizer files, and configs. `OnnxIntentClassifier` prefers `model.int8.onnx` before `model.onnx`, so this is enough for production intent routing.

The Dockerfile intentionally fails the build if these required runtime files are missing:

- `runtime/models/intent_onnx/model.int8.onnx`
- `runtime/models/intent_onnx/label_config.json`
- `runtime/models/intent_onnx/tokenizer.json`

If fp32 fallback is required, remove this line from `.dockerignore`:

```text
runtime/models/intent_onnx/model.onnx
```

## Build Locally

Run from repository root:

```powershell
docker build -t menugreen-rag-runtime:local .
```

Run locally:

```powershell
docker run --rm -p 8000:8000 `
  -e POSTGRES_URL="postgresql://postgres:password@host.docker.internal:5432/MenuGreen" `
  -e GOOGLE_API_KEY="your-key" `
  -e AI_RUNTIME_INTERNAL_KEY="local-dev-key" `
  menugreen-rag-runtime:local
```

Health check:

```powershell
curl http://localhost:8000/health
```

## AWS Environment Variables

Set these in ECS/App Runner/EC2 environment or Secrets Manager/SSM Parameter Store:

```env
PORT=8000
POSTGRES_URL=postgresql://user:password@rds-host:5432/dbname
GOOGLE_API_KEY=...
GOOGLE_API_KEYS=...
AI_RUNTIME_INTERNAL_KEY=...
INTENT_MODEL_DIR=models/intent_onnx
GEMINI_QUERY_REWRITE_ENABLED=true
GEMINI_RESPONSE_FALLBACK_ENABLED=true
```

Do not bake `.env` into the image.

## AWS Health Check

Use:

```http
GET /health
```

Expected response:

```json
{"status":"ok","service":"runtime"}
```

## Deployment Notes

- Recommended target: ECS Fargate + ECR + RDS PostgreSQL.
- App Runner is also fine for a quick first deploy.
- Keep RAG private/internal if possible; MenuGreenSystem should call it server-to-server.
- Enable `AI_RUNTIME_INTERNAL_KEY` in AWS and send it from System as `X-AI-Runtime-Key`.
- The ONNX model folder is gitignored, so CI/CD must either build from a workspace that already has `runtime/models/intent_onnx` or download the model bundle before `docker build`.
