"""
ShelfScanner — Shared Pydantic schemas used across all routers.
"""
from typing import List, Optional
from pydantic import BaseModel


class BookResult(BaseModel):
    isbn: str
    title: str
    authors: List[str]
    publisher: str
    year: str
    description: str
    categories: List[str]
    cover_url: str
    avg_rating: Optional[float] = None
    rating_count: Optional[int] = None
    match_score: Optional[float] = None   # cosine similarity for recommendations


class ScanRequest(BaseModel):
    """Payload sent from Flutter after YOLO crops a book spine."""
    image_b64: str        # Base64-encoded image of the cropped spine
    user_id: Optional[str] = None


class SearchRequest(BaseModel):
    """Direct text search (title / author query from on-device OCR)."""
    ocr_text: str
    user_id: Optional[str] = None


class FeedbackRequest(BaseModel):
    isbn: str
    action: str           # 'confirm' | 'like' | 'skip'
    user_id: Optional[str] = None
    ocr_raw_text: Optional[str] = None
    spine_image_b64: Optional[str] = None
