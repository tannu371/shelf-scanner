# ShelfScanner/app/api/main.py
import asyncio
import base64
import logging
import os
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

from ..data_pipeline.api_clients import (
    fetch_google_books_data,
    fetch_open_library_data,
    fetch_worldcat_data,
    fetch_goodreads_data,
)
from ..services.text_recoginition import extract_text_from_bytes, extract_raw_text
from ..services.text_reconstruction import BookParser
from ..services.embedding_service import generate_book_embedding, generate_user_embedding
from ...db.database import init_db, close_db, get_pool

load_dotenv()
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------
app = FastAPI(
    title="ShelfScanner API",
    description="Book detection, metadata retrieval, and personalised recommendations.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Lifecycle — DB pool + model warm-up
# ---------------------------------------------------------------------------
@app.on_event("startup")
async def startup():
    await init_db()
    logger.info("Startup complete.")

@app.on_event("shutdown")
async def shutdown():
    await close_db()

# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------
class ScanRequest(BaseModel):
    """Payload sent from Flutter after on-device YOLO detection crops a spine."""
    image_b64: str           # Base64-encoded image of the cropped book spine
    user_id: Optional[str] = None

class SearchRequest(BaseModel):
    """Direct text search (title / author query from OCR)."""
    ocr_text: str
    user_id: Optional[str] = None

class FeedbackRequest(BaseModel):
    isbn: str
    action: str              # 'confirm' | 'like' | 'skip'
    user_id: Optional[str] = None
    ocr_raw_text: Optional[str] = None
    spine_image_b64: Optional[str] = None

class BookResult(BaseModel):
    isbn: str
    title: str
    authors: List[str]
    publisher: str
    year: str
    description: str
    categories: List[str]
    cover_url: str
    avg_rating: Optional[float]
    rating_count: Optional[int]
    match_score: Optional[float] = None   # similarity score for recommendations

# ---------------------------------------------------------------------------
# Helper — merge + normalise external API data
# ---------------------------------------------------------------------------
async def _fetch_and_merge_metadata(isbn: str) -> Dict[str, Any]:
    google, openlib, worldcat, goodreads = await asyncio.gather(
        fetch_google_books_data(isbn),
        fetch_open_library_data(isbn),
        fetch_worldcat_data(isbn),
        fetch_goodreads_data(isbn),
    )
    title = google.get("title") or openlib.get("title") or worldcat.get("title", "")
    authors = sorted(set(
        google.get("authors", []) + openlib.get("authors", []) + worldcat.get("authors", [])
    ))
    publisher = google.get("publisher") or (openlib.get("publishers") or [""])[0]
    description = google.get("description") or openlib.get("description", "")
    year = str(
        worldcat.get("year") or google.get("publishedDate") or openlib.get("publishDate", "")
    ).split("-")[0]
    categories = sorted(set(google.get("categories", []) + openlib.get("categories", [])))
    cover_url = google.get("coverURL") or openlib.get("coverURL", "")

    return {
        "isbn": isbn, "title": title, "authors": authors,
        "publisher": publisher, "year": year, "description": description,
        "categories": categories, "cover_url": cover_url,
        "avg_rating": openlib.get("ol_average_rating") or goodreads.get("goodreads_rating"),
        "rating_count": openlib.get("ol_rating_count") or goodreads.get("goodreads_rating_count"),
    }


async def _upsert_book(meta: Dict[str, Any]) -> None:
    """Insert (or update) a book row and generate its embedding."""
    pool = await get_pool()
    embedding = generate_book_embedding(meta["description"], meta["categories"])
    async with pool.connection() as conn:
        await conn.execute(
            """
            INSERT INTO books
                (isbn, title, authors, publisher, year, description,
                 categories, cover_url, avg_rating, rating_count, embedding)
            VALUES
                (%(isbn)s, %(title)s, %(authors)s, %(publisher)s, %(year)s,
                 %(description)s, %(categories)s, %(cover_url)s,
                 %(avg_rating)s, %(rating_count)s, %(embedding)s)
            ON CONFLICT (isbn) DO UPDATE SET
                title        = EXCLUDED.title,
                authors      = EXCLUDED.authors,
                publisher    = EXCLUDED.publisher,
                year         = EXCLUDED.year,
                description  = EXCLUDED.description,
                categories   = EXCLUDED.categories,
                cover_url    = EXCLUDED.cover_url,
                avg_rating   = EXCLUDED.avg_rating,
                rating_count = EXCLUDED.rating_count,
                embedding    = EXCLUDED.embedding,
                updated_at   = NOW()
            """,
            {**meta, "embedding": embedding},
        )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@app.get("/", tags=["Health"])
async def root():
    return {"status": "ok", "message": "ShelfScanner API — see /docs"}


@app.get("/metadata/{isbn}", response_model=BookResult, tags=["Books"])
async def get_metadata(isbn: str):
    """
    Fetch and merge book metadata for a given ISBN.
    Upserts the result (with embedding) into the database.
    """
    meta = await _fetch_and_merge_metadata(isbn)
    if not meta["title"]:
        raise HTTPException(404, f"No metadata found for ISBN {isbn}")
    asyncio.create_task(_upsert_book(meta))   # persist in background
    return meta


@app.post("/scan", response_model=List[BookResult], tags=["Books"])
async def scan_spine(req: ScanRequest):
    """
    Accept a base64-encoded book spine image, run OCR,
    parse title/author, and return the best-matching book candidates.

    Flutter flow:
        YOLO detects spine → crop → send here → receive book candidates
    """
    try:
        image_bytes = base64.b64decode(req.image_b64)
    except Exception:
        raise HTTPException(400, "Invalid base64 image data")

    # 1. OCR
    ocr_data = extract_text_from_bytes(image_bytes)
    parser = BookParser()
    parsed = parser.parse_spine(ocr_data)
    combined = parsed["combined_query"]

    if not combined.strip():
        raise HTTPException(422, "OCR returned no readable text from the image")

    # 2. DB fuzzy search first (fast path)
    results = await _db_text_search(combined, limit=5)

    # 3. Fallback to Google Books if DB miss (slow path)
    if not results:
        results = await _google_text_search(combined)

    if not results:
        raise HTTPException(404, "No matching books found for the scanned spine")

    return results


@app.post("/search", response_model=List[BookResult], tags=["Books"])
async def search_books(req: SearchRequest):
    """
    Text-based book search.
    Used when OCR text is already extracted on-device (e.g. CRAFT + Tesseract).
    """
    if not req.ocr_text.strip():
        raise HTTPException(400, "ocr_text must not be empty")

    results = await _db_text_search(req.ocr_text, limit=5)
    if not results:
        results = await _google_text_search(req.ocr_text)
    if not results:
        raise HTTPException(404, "No matching books found")
    return results


@app.get("/recommend", response_model=List[BookResult], tags=["Recommendations"])
async def get_recommendations(
    isbn: str = Query(..., description="ISBN of the seed book"),
    user_id: Optional[str] = Query(None),
    limit: int = Query(10, ge=1, le=50),
):
    """
    Return Top-K books similar to the given ISBN using pgvector KNN cosine search.
    """
    pool = await get_pool()
    async with pool.connection() as conn:
        # Get the source book's embedding
        row = await conn.fetchrow(
            "SELECT embedding FROM books WHERE isbn = $1", isbn
        )
        if not row or row["embedding"] is None:
            # Try to fetch + store first
            try:
                meta = await _fetch_and_merge_metadata(isbn)
                await _upsert_book(meta)
            except Exception:
                raise HTTPException(404, f"Book {isbn} not found and could not be fetched")
            row = await conn.fetchrow(
                "SELECT embedding FROM books WHERE isbn = $1", isbn
            )
            if not row:
                raise HTTPException(404, f"Could not generate embedding for ISBN {isbn}")

        embedding = row["embedding"]

        # pgvector KNN — cosine similarity, exclude the seed book itself
        rows = await conn.fetch(
            """
            SELECT isbn, title, authors, publisher, year, description,
                   categories, cover_url, avg_rating, rating_count,
                   1 - (embedding <=> $1::vector) AS similarity
            FROM books
            WHERE isbn != $2
              AND embedding IS NOT NULL
            ORDER BY embedding <=> $1::vector
            LIMIT $3
            """,
            embedding, isbn, limit,
        )

    return [
        BookResult(
            isbn=r["isbn"], title=r["title"], authors=r["authors"],
            publisher=r["publisher"], year=r["year"],
            description=r["description"], categories=r["categories"],
            cover_url=r["cover_url"], avg_rating=r["avg_rating"],
            rating_count=r["rating_count"],
            match_score=round(float(r["similarity"]), 4),
        )
        for r in rows
    ]


@app.post("/log_feedback", tags=["Feedback"])
async def log_feedback(req: FeedbackRequest):
    """
    Log a user action (confirm / like / skip) for HITL model retraining.
    """
    if req.action not in ("confirm", "like", "skip"):
        raise HTTPException(400, "action must be 'confirm', 'like', or 'skip'")

    pool = await get_pool()
    async with pool.connection() as conn:
        await conn.execute(
            """
            INSERT INTO feedback_log
                (user_id, isbn, action, ocr_raw_text, spine_image_b64)
            VALUES ($1, $2, $3, $4, $5)
            """,
            req.user_id, req.isbn, req.action,
            req.ocr_raw_text, req.spine_image_b64,
        )
    return {"status": "ok"}


# ---------------------------------------------------------------------------
# Internal search helpers
# ---------------------------------------------------------------------------

async def _db_text_search(query: str, limit: int = 5) -> List[BookResult]:
    """Fast path — PostgreSQL full-text search."""
    pool = await get_pool()
    async with pool.connection() as conn:
        rows = await conn.fetch(
            """
            SELECT isbn, title, authors, publisher, year, description,
                   categories, cover_url, avg_rating, rating_count
            FROM books
            WHERE to_tsvector('english', title || ' ' || array_to_string(authors, ' '))
                  @@ plainto_tsquery('english', $1)
            LIMIT $2
            """,
            query, limit,
        )
    return [BookResult(**dict(r), match_score=None) for r in rows]


async def _google_text_search(query: str) -> List[BookResult]:
    """Slow path — Google Books API text search, upserts results into DB."""
    import httpx
    api_key = os.getenv("GOOGLE_BOOKS_API_KEY", "")
    url = "https://www.googleapis.com/books/v1/volumes"
    params = {"q": query, "maxResults": 5, "key": api_key}
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(url, params=params)
    if resp.status_code != 200:
        return []

    items = resp.json().get("items", [])
    results = []
    for item in items:
        info = item.get("volumeInfo", {})
        isbns = [i["identifier"] for i in info.get("industryIdentifiers", [])
                 if i["type"] in ("ISBN_13", "ISBN_10")]
        if not isbns:
            continue
        isbn = isbns[0]
        meta = {
            "isbn": isbn,
            "title": info.get("title", ""),
            "authors": info.get("authors", []),
            "publisher": info.get("publisher", ""),
            "year": (info.get("publishedDate") or "").split("-")[0],
            "description": info.get("description", ""),
            "categories": info.get("categories", []),
            "cover_url": (info.get("imageLinks") or {}).get("thumbnail", ""),
            "avg_rating": info.get("averageRating"),
            "rating_count": info.get("ratingsCount"),
        }
        asyncio.create_task(_upsert_book(meta))
        results.append(BookResult(**meta, match_score=None))
    return results