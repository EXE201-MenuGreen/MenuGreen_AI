# syntax=docker/dockerfile:1.7

FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8000 \
    INTENT_MODEL_DIR=models/intent_onnx

WORKDIR /app/runtime

# onnxruntime CPU wheels need libgomp at runtime.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY runtime/requirements-runtime.txt ./requirements-runtime.txt
RUN pip install --upgrade pip \
    && pip install -r requirements-runtime.txt

COPY runtime/app ./app
COPY runtime/frontend ./frontend
COPY runtime/models ./models

RUN test -f models/intent_onnx/model.int8.onnx \
    && test -f models/intent_onnx/label_config.json \
    && test -f models/intent_onnx/tokenizer.json

RUN addgroup --system menugreen \
    && adduser --system --ingroup menugreen --home /app --disabled-password appuser \
    && chown -R appuser:menugreen /app

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen(f'http://127.0.0.1:{os.environ.get(\"PORT\", \"8000\")}/health', timeout=3).read()" || exit 1

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
