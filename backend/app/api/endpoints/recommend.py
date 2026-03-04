"""
ShelfScanner — /recommend endpoint

GET /recommend?isbn=<isbn>&limit=<n>
  Returns Top-K books similar to the given ISBN using pgvector KNN cosine search.
  All DB access uses psycopg3 (cursor API, %s placeholders).
"""
import logging
from typing import List, Optional

from fastapi import APIRouter, HTTPException, Query

from ..schemas import BookResult
from ..helpers import fetch_and_merge_metadata, upsert_book
from ...db.database import get_pool

logger = logging.getLogger(__name__)

router = APIRouter(prefix="", tags=["Recommendations"])


@router.get("/recommend", response_model=List[BookResult])
async def get_recommendations(
    isbn: str = Query(..., description="ISBN of the seed book"),
    user_id: Optional[str] = Query(None, description="Optional user ID for personalisation"),
    limit: int = Query(10, ge=1, le=50, description="Number of recommendations to return"),
):
    """
    Return Top-K books similar to the given ISBN using pgvector KNN cosine search.

    - Looks up the seed book's embedding in the database.
    - If not found, fetches metadata from external APIs and upserts it first.
    - Returns similar books ordered by cosine similarity (highest first).
    """
    pool = await get_pool()
    async with pool.connection() as conn:
        # 1. Get the source book's embedding
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT embedding FROM books WHERE isbn = %s", (isbn,)
            )
            row = await cur.fetchone()

        if not row or row["embedding"] is None:
            # Seed book not in DB yet — fetch and store it
            try:
                meta = await fetch_and_merge_metadata(isbn)
                await upsert_book(meta)
            except Exception as exc:
                logger.exception("Failed to fetch metadata for ISBN %s", isbn)
                raise HTTPException(
                    404, f"Book {isbn} not found and could not be fetched"
                ) from exc

            async with conn.cursor() as cur:
                await cur.execute(
                    "SELECT embedding FROM books WHERE isbn = %s", (isbn,)
                )
                row = await cur.fetchone()
            if not row:
                raise HTTPException(
                    404, f"Could not generate embedding for ISBN {isbn}"
                )

        embedding = row["embedding"]

        # 2. pgvector KNN — cosine similarity, exclude the seed book itself
        async with conn.cursor() as cur:
            await cur.execute(
                """
                SELECT isbn, title, authors, publisher, year, description,
                       categories, cover_url, avg_rating, rating_count,
                       1 - (embedding <=> %s::vector) AS similarity
                FROM books
                WHERE isbn != %s
                  AND embedding IS NOT NULL
                ORDER BY embedding <=> %s::vector
                LIMIT %s
                """,
                (embedding, isbn, embedding, limit),
            )
            rows = await cur.fetchall()

    return [
        BookResult(
            isbn=r["isbn"],
            title=r["title"],
            authors=r["authors"],
            publisher=r["publisher"],
            year=r["year"],
            description=r["description"],
            categories=r["categories"],
            cover_url=r["cover_url"],
            avg_rating=r["avg_rating"],
            rating_count=r["rating_count"],
            match_score=round(float(r["similarity"]), 4),
        )
        for r in rows
    ]
