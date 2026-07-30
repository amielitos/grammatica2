"""
Grammatica AI Backend — Main Entry Point

A standalone FastAPI service that provides AI-powered lesson summarization
and quiz generation from uploaded PDF files, powered by Google Gemini.
"""

import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import uvicorn

from config import settings
from routes.lesson import router as lesson_router
from routes.quiz import router as quiz_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events."""
    # Validate configuration
    settings.validate()

    # Ensure static directories exist
    os.makedirs(settings.IMAGES_DIR, exist_ok=True)

    print("=" * 60)
    print("🚀 Grammatica AI Backend starting up...")
    print(f"   Model:  {settings.GEMINI_MODEL}")
    print(f"   Port:   {settings.PORT}")
    print(f"   Images: {settings.IMAGES_DIR}")
    print("=" * 60)

    yield

    print("🛑 Grammatica AI Backend shutting down...")


app = FastAPI(
    title="Grammatica AI Backend",
    description="AI-powered lesson summarization and quiz generation service.",
    version="1.0.0",
    lifespan=lifespan,
)

# ── CORS ─────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Static Files (for serving generated images) ─────────────────────────────
app.mount("/static", StaticFiles(directory=settings.STATIC_DIR), name="static")

# ── Routes ───────────────────────────────────────────────────────────────────
app.include_router(lesson_router)
app.include_router(quiz_router)


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
    )
