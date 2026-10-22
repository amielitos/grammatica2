"""
Grammatica AI Backend - Main Entry Point

A standalone FastAPI service that provides AI-powered lesson summarization
and quiz generation from uploaded PDF files, powered by Google Gemini.
"""

import os
import sys

# Ensure UTF-8 stdout/stderr on Windows to avoid UnicodeEncodeError
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

import warnings
# Suppress harmless pydub ffmpeg runtime warning triggered by markitdown
warnings.filterwarnings("ignore", category=RuntimeWarning, module="pydub")

# Ensure the ai_backend directory is in sys.path so modules like config, routes, etc. can be resolved
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from contextlib import asynccontextmanager
from fastapi import FastAPI
# pyrefly: ignore [missing-import]
from fastapi.middleware.cors import CORSMiddleware
# pyrefly: ignore [missing-import]
from fastapi.staticfiles import StaticFiles
# pyrefly: ignore [missing-import]
import uvicorn

try:
    from config import settings
    from routes.lesson import router as lesson_router
    from routes.quiz import router as quiz_router
    from routes.convert import router as convert_router
    from routes.email import router as email_router
    from routes.payment import router as payment_router
    from routes.notebook import router as notebook_router
    from middleware.idempotency import IdempotencyMiddleware
except ImportError:
    from ai_backend.config import settings
    from ai_backend.routes.lesson import router as lesson_router
    from ai_backend.routes.quiz import router as quiz_router
    from ai_backend.routes.convert import router as convert_router
    from ai_backend.routes.email import router as email_router
    from ai_backend.routes.payment import router as payment_router
    from ai_backend.routes.notebook import router as notebook_router
    from ai_backend.middleware.idempotency import IdempotencyMiddleware


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events."""
    # Validate configuration
    settings.validate()

    # Ensure static directories exist
    os.makedirs(settings.IMAGES_DIR, exist_ok=True)

    print("=" * 60, flush=True)
    print("[*] Grammatica AI Backend starting up...", flush=True)
    print(f"   Model:  {settings.GEMINI_MODEL}", flush=True)
    print(f"   Port:   {settings.PORT}", flush=True)
    print(f"   Images: {settings.IMAGES_DIR}", flush=True)
    print("=" * 60, flush=True)

    yield

    print("[*] Grammatica AI Backend shutting down...", flush=True)


app = FastAPI(
    title="Grammatica AI Backend",
    description="AI-powered lesson summarization and quiz generation service.",
    version="1.0.0",
    lifespan=lifespan,
)

# -- CORS & Idempotency Middlewares --------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*", "Idempotency-Key", "X-Idempotency-Key"],
    expose_headers=["Idempotent-Replay", "X-Idempotency-Key", "Retry-After"],
)
app.add_middleware(IdempotencyMiddleware)

# -- Static Files (for serving generated images) ------------------------------
os.makedirs(settings.STATIC_DIR, exist_ok=True)
os.makedirs(settings.IMAGES_DIR, exist_ok=True)
app.mount("/static", StaticFiles(directory=settings.STATIC_DIR), name="static")

# -- Routes -------------------------------------------------------------------
app.include_router(lesson_router)
app.include_router(quiz_router)
app.include_router(convert_router)
app.include_router(email_router)
app.include_router(payment_router)
app.include_router(notebook_router)


@app.get("/health")
async def health_check():
    """Simple health check endpoint (no auth required)."""
    return {"status": "ok", "service": "grammatica-ai-backend"}


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=True,
        app_dir=BASE_DIR,
        reload_dirs=[BASE_DIR],
    )

