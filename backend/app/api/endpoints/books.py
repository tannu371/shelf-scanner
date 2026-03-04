"""
ShelfScanner — /metadata endpoint

GET /metadata/{isbn}
  Fetch, merge, and return book metadata. Upserts into DB with embedding.
"""
import asyncio
import logging

from fastapi import APIRouter, HTTPException

from ..schemas import BookResult
from ..helpers import fetch_and_merge_metadata, upsert_book

logger = logging.getLogger(__name__)

router = APIRouter(prefix="", tags=["Books"])


@router.get("/metadata/{isbn}", response_model=BookResult)
async def get_metadata(isbn: str):
    """
    Fetch and merge book metadata for a given ISBN from multiple external APIs
    (Google Books, Open Library, WorldCat, Goodreads).

    - Upserts the result (with embedding) into the database in the background.
    - Returns merged metadata with best-available values from all sources.
    """
    meta = await fetch_and_merge_metadata(isbn)
    if not meta["title"]:
        raise HTTPException(404, f"No metadata found for ISBN {isbn}")

    # Persist in background — don't block the response
    asyncio.create_task(upsert_book(meta))
    return meta
