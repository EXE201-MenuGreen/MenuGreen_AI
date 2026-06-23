from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from app.api.routes import router as api_router
from app.core.config import get_settings


def create_app() -> FastAPI:
    app = FastAPI(title="MenuGreen AI Runtime", version="0.1.0")

    @app.middleware("http")
    async def internal_key_middleware(request: Request, call_next):
        expected_key = (get_settings().ai_runtime_internal_key or "").strip()
        if expected_key and request.url.path != "/health":
            supplied_key = request.headers.get("X-AI-Runtime-Key", "")
            if supplied_key != expected_key:
                return JSONResponse(
                    status_code=401,
                    content={"detail": "Invalid or missing AI runtime key."},
                )
        return await call_next(request)

    app.include_router(api_router)

    frontend_dir = Path(__file__).resolve().parents[1] / "frontend"
    if frontend_dir.exists():
        app.mount("/frontend", StaticFiles(directory=str(frontend_dir)), name="frontend")

        @app.get("/", include_in_schema=False)
        def root():
            return FileResponse(frontend_dir / "index.html")

    return app


app = create_app()
