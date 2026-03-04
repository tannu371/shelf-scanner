"""
ShelfScanner — Shared API Helpers
Utilities shared across multiple endpoint routers.
All DB access uses psycopg3 (AsyncConnectionPool + dict_row + %s placeholders).
"""
import asyncio
import logging
import os
from typing import Any, Dict, List

import httpx

from ..data_pipeline.api_clients import (
    fetch_google_books_data,
    fetch_open_library_data,
    fetch_worldcat_data,
    fetch_goodreads_data,
)
from ..services.embedding_service import generate_book_embedding
from ..db.database import get_pool
from .schemas import BookResult

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Metadata fetching
# ---------------------------------------------------------------------------

async def fetch_and_merge_metadata(isbn: str) -> Dict[str, Any]:
    """Fetch book metadata from all external APIs and merge into one dict."""
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


# ---------------------------------------------------------------------------
# DB upsert  (psycopg3: %(name)s placeholders, conn.execute)
# ---------------------------------------------------------------------------

async def upsert_book(meta: Dict[str, Any]) -> None:
    """Insert or update a book row with a freshly generated embedding."""
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
# Search helpers  (psycopg3: %s placeholders, cursor.fetchall / fetchone)
# ---------------------------------------------------------------------------

async def db_text_search(query: str, limit: int = 5) -> List[BookResult]:
    """Fast path — PostgreSQL full-text search against the books table."""
    pool = await get_pool()
    async with pool.connection() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                """
                SELECT isbn, title, authors, publisher, year, description,
                       categories, cover_url, avg_rating, rating_count
                FROM books
                WHERE to_tsvector('english', title || ' ' || array_to_string(authors, ' '))
                      @@ plainto_tsquery('english', %s)
                LIMIT %s
                """,
                (query, limit),
            )
            rows = await cur.fetchall()
    return [BookResult(**r, match_score=None) for r in rows]


async def google_text_search(query: str) -> List[BookResult]:
    """Slow path — Google Books API search; upserts results into the DB."""
    api_key = os.getenv("GOOGLE_BOOKS_API_KEY", "")
    url = "https://www.googleapis.com/books/v1/volumes"
    params = {"q": query, "maxResults": 5, "key": api_key}

    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(url, params=params)
    if resp.status_code != 200:
        return []

    results: List[BookResult] = []
    for item in resp.json().get("items", []):
        info = item.get("volumeInfo", {})
        isbns = [
            i["identifier"]
            for i in info.get("industryIdentifiers", [])
            if i["type"] in ("ISBN_13", "ISBN_10")
        ]
        if not isbns:
            continue
        meta = {
            "isbn": isbns[0],
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
        asyncio.create_task(upsert_book(meta))
        results.append(BookResult(**meta, match_score=None))
    return results
