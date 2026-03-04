"""
ShelfScanner — /scan and /search endpoints

POST /scan   — accept a base64 book-spine image, run PaddleOCR, return book candidates
POST /search — text-based book search (OCR text already extracted on-device)
"""
import base64
import logging
from typing import List

from fastapi import APIRouter, HTTPException

from ..schemas import BookResult, ScanRequest, SearchRequest
from ..helpers import db_text_search, google_text_search

logger = logging.getLogger(__name__)

router = APIRouter(prefix="", tags=["Books"])


@router.post("/scan", response_model=List[BookResult])
async def scan_spine(req: ScanRequest):
    """
    Accept a base64-encoded book spine image, run OCR, parse title/author,
    and return the best-matching book candidates.

    Flutter flow:
        YOLO detects spine → crop → POST here → receive BookResult list
    """
    try:
        image_bytes = base64.b64decode(req.image_b64)
    except Exception:
        raise HTTPException(400, "Invalid base64 image data")

    # Lazy import — PaddleOCR takes ~10 s to load; skip at startup
    from ...services.text_recoginition import extract_text_from_bytes  # noqa: PLC0415
    from ...services.text_reconstruction import BookParser              # noqa: PLC0415

    ocr_data = extract_text_from_bytes(image_bytes)
    parser = BookParser()
    parsed = parser.parse_spine(ocr_data)
    combined = parsed["combined_query"]

    if not combined.strip():
        raise HTTPException(422, "OCR returned no readable text from the image")

    # 1. Fast path — DB full-text search
    results = await db_text_search(combined, limit=5)

    # 2. Slow path — Google Books API
    if not results:
        results = await google_text_search(combined)

    if not results:
        raise HTTPException(404, "No matching books found for the scanned spine")

    return results


@router.post("/search", response_model=List[BookResult])
async def search_books(req: SearchRequest):
    """
    Text-based book search.
    Used when OCR text is already extracted on-device (e.g. Tesseract / CRAFT).
    """
    if not req.ocr_text.strip():
        raise HTTPException(400, "ocr_text must not be empty")

    results = await db_text_search(req.ocr_text, limit=5)
    if not results:
        results = await google_text_search(req.ocr_text)
    if not results:
        raise HTTPException(404, "No matching books found")
    return results
