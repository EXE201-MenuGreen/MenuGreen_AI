from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.api.routes import router as api_router


def create_app() -> FastAPI:
    app = FastAPI(title="MenuGreen AI Runtime", version="0.1.0")
    app.include_router(api_router)

    frontend_dir = Path(__file__).resolve().parents[1] / "frontend"
    if frontend_dir.exists():
        app.mount("/frontend", StaticFiles(directory=str(frontend_dir)), name="frontend")

        @app.get("/", include_in_schema=False)
        def root():
            return FileResponse(frontend_dir / "index.html")

    return app


app = create_app()
