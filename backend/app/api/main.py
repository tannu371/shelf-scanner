"""
ShelfScanner Backend — FastAPI Application Factory

This file only:
  1. Creates the FastAPI app instance
  2. Registers middleware
  3. Wires in the lifecycle hooks (DB pool)
  4. Includes all endpoint routers

Business logic lives in:
  app/api/endpoints/  — route handlers
  app/api/helpers.py  — shared DB / API helpers
  app/api/schemas.py  — shared Pydantic models
  app/services/       — OCR, embedding, text parsing
  app/data_pipeline/  — external API clients
  app/db/             — database pool management
"""
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from ..db.database import init_db, close_db
from .endpoints import scan, recommend, feedback, books, match

load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------
app = FastAPI(
    title="ShelfScanner API",
    description=(
        "Book detection, OCR-based identification, metadata retrieval, "
        "and personalised pgvector recommendations."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Lifecycle — DB connection pool
# ---------------------------------------------------------------------------
@app.on_event("startup")
async def startup() -> None:
    await init_db()
    logger.info("✅ Database pool initialised.")


@app.on_event("shutdown")
async def shutdown() -> None:
    await close_db()
    logger.info("Database pool closed.")


# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------
app.include_router(scan.router)        # POST /scan, POST /search
app.include_router(recommend.router)   # GET  /recommend
app.include_router(feedback.router)    # POST /log_feedback
app.include_router(books.router)       # GET  /metadata/{isbn}
app.include_router(match.router)       # POST /match (personalisation)


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------
@app.get("/", tags=["Health"])
async def root():
    return {"status": "ok", "message": "ShelfScanner API — see /docs"}