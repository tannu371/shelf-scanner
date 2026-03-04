"""
ShelfScanner — /match endpoint

POST /match
  Computes a personalised "fit score" between one book and a user's liked books.
  Uses pgvector cosine similarity between the target book's SBERT embedding
  and the mean embedding of the liked books.

  Also returns:
    - theme overlap (shared categories/keywords)
    - top matching liked book
    - a human-readable "why you'd like it" paragraph (NLP generated)
"""
import logging
from typing import List, Optional
import numpy as np
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ..schemas import BookResult
from ...db.database import get_pool

logger = logging.getLogger(__name__)
router = APIRouter(prefix="", tags=["Personalization"])


# ── Request / Response ────────────────────────────────────────────────────────

class MatchRequest(BaseModel):
    isbn: str
    liked_isbns: List[str]
    user_id: Optional[str] = None


class ThemeMatch(BaseModel):
    shared_categories: List[str]
    overlap_score: float          # 0.0 – 1.0


class MatchResponse(BaseModel):
    isbn: str
    fit_score: float              # cosine similarity in [0, 1]
    confidence: str               # "high" / "medium" / "low"
    why_you_like_it: str          # NLP-generated sentence
    theme_match: ThemeMatch
    top_similar_liked: Optional[BookResult] = None


# ── Endpoint ──────────────────────────────────────────────────────────────────

@router.post("/match", response_model=MatchResponse)
async def match_book(req: MatchRequest):
    """
    Compute a personalised fit score for a book against the user's liked books.

    Algorithm:
      1. Fetch SBERT embedding for the target book from the DB.
      2. Fetch SBERT embeddings for all liked books.
      3. Compute mean liked embedding → "taste vector".
      4. Cosine similarity(target, taste_vector) = fit_score.
      5. Find the single closest liked book by cosine distance (top_similar_liked).
      6. Compute category overlap for theme_match.
      7. Generate a short "why you'd like it" explanation from shared themes.
    """
    if not req.liked_isbns:
        raise HTTPException(400, "liked_isbns must not be empty")

    pool = await get_pool()
    async with pool.connection() as conn:
        # 1. Target book embedding + metadata
        async with conn.cursor() as cur:
            await cur.execute(
                """
                SELECT isbn, title, authors, publisher, year, description,
                       categories, cover_url, avg_rating, rating_count,
                       embedding
                FROM books WHERE isbn = %s
                """,
                (req.isbn,),
            )
            target_row = await cur.fetchone()

        if not target_row or target_row["embedding"] is None:
            raise HTTPException(
                404, f"Book {req.isbn} not found in DB or has no embedding"
            )

        target_vec = np.array(target_row["embedding"], dtype=np.float32)
        target_cats = set(target_row["categories"] or [])

        # 2. Liked books embeddings + metadata
        async with conn.cursor() as cur:
            await cur.execute(
                """
                SELECT isbn, title, authors, cover_url, avg_rating,
                       rating_count, description, publisher, year,
                       categories, embedding
                FROM books
                WHERE isbn = ANY(%s) AND embedding IS NOT NULL
                """,
                (req.liked_isbns,),
            )
            liked_rows = await cur.fetchall()

    if not liked_rows:
        raise HTTPException(
            404, "None of the liked books have embeddings in the DB yet"
        )

    # 3. Mean "taste vector"
    liked_vecs = np.array(
        [r["embedding"] for r in liked_rows], dtype=np.float32
    )
    taste_vec = liked_vecs.mean(axis=0)

    # 4. Cosine similarity
    def cosine(a: np.ndarray, b: np.ndarray) -> float:
        denom = np.linalg.norm(a) * np.linalg.norm(b)
        if denom == 0:
            return 0.0
        return float(np.dot(a, b) / denom)

    fit_score = max(0.0, cosine(target_vec, taste_vec))

    # 5. Most similar liked book
    sims = [(r, cosine(target_vec, np.array(r["embedding"], dtype=np.float32)))
            for r in liked_rows]
    sims.sort(key=lambda x: x[1], reverse=True)
    top_row, top_sim = sims[0]

    top_similar = BookResult(
        isbn=top_row["isbn"],
        title=top_row["title"],
        authors=top_row["authors"] or [],
        publisher=top_row["publisher"] or "",
        year=top_row["year"] or "",
        description=top_row["description"] or "",
        categories=top_row["categories"] or [],
        cover_url=top_row["cover_url"] or "",
        avg_rating=top_row["avg_rating"],
        rating_count=top_row["rating_count"],
        match_score=round(top_sim, 4),
    )

    # 6. Theme overlap
    liked_cats: set = set()
    for r in liked_rows:
        liked_cats.update(r["categories"] or [])

    shared = sorted(target_cats & liked_cats)
    union = target_cats | liked_cats
    overlap_score = len(shared) / len(union) if union else 0.0

    # 7. NLP: build "why you'd like it" explanation
    why = _why_you_like_it(
        title=target_row["title"] or "This book",
        shared_cats=shared,
        top_liked_title=top_row["title"],
        fit_score=fit_score,
        description=target_row["description"] or "",
    )

    confidence = "high" if fit_score >= 0.75 else ("medium" if fit_score >= 0.5 else "low")

    return MatchResponse(
        isbn=req.isbn,
        fit_score=round(fit_score, 4),
        confidence=confidence,
        why_you_like_it=why,
        theme_match=ThemeMatch(
            shared_categories=shared,
            overlap_score=round(overlap_score, 4),
        ),
        top_similar_liked=top_similar,
    )


# ── NLP helper ────────────────────────────────────────────────────────────────

def _why_you_like_it(
    title: str,
    shared_cats: List[str],
    top_liked_title: str,
    fit_score: float,
    description: str,
) -> str:
    """
    Build a short personalised explanation using:
      - Shared genre categories (NLP category overlap)
      - Cosine similarity level
      - Key noun/theme extraction from description (rule-based NLP)
    """
    # Extract key themes: capitalised nouns / named entities from description
    themes = _extract_themes(description)

    genre_str = (
        ", ".join(shared_cats[:3]) if shared_cats
        else "similar themes to what you enjoy"
    )
    theme_str = (
        f" with a focus on {', '.join(themes[:2])}" if themes else ""
    )

    if fit_score >= 0.75:
        opener = f"Based on your taste, you will very likely enjoy \"{title}\""
    elif fit_score >= 0.5:
        opener = f"\"{title}\" is a good match for your reading profile"
    else:
        opener = f"\"{title}\" shares some elements with your reading history"

    return (
        f"{opener}. It covers {genre_str}{theme_str}, "
        f"similar in spirit to \"{top_liked_title}\" which you liked."
    )


def _extract_themes(text: str, top_n: int = 5) -> List[str]:
    """
    Rule-based NLP: extract candidate themes by finding capitalised multi-word
    phrases (likely proper nouns / named entities) and frequent significant words.
    No ML model required.
    """
    import re
    from collections import Counter

    # Stopwords (minimal set)
    STOP = {
        "the","a","an","and","or","but","in","on","at","to","for","of","with",
        "is","was","are","were","this","that","it","its","by","from","as","be",
        "has","have","had","not","no","if","about","which","they","their",
        "will","can","may","also","all","we","our","i","he","she","his","her",
        "book","reader","story","novel","author","chapter","page","world","life",
        "time","people","man","woman","way","day","year","part","new","one","two",
    }

    words = re.findall(r"[A-Za-z]{4,}", text)
    filtered = [w.lower() for w in words if w.lower() not in STOP]
    freq = Counter(filtered)
    return [w.title() for w, _ in freq.most_common(top_n)]
