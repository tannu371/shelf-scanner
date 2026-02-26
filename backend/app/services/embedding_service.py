"""
ShelfScanner — Embedding Service
Loads SentenceTransformer once at startup for efficient inference.
Generates 768-dim vectors for books (description + categories)
and users (preference text).
"""
import os
import logging
import numpy as np
from typing import Optional
from sentence_transformers import SentenceTransformer

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Model — loaded once as a module-level singleton
# ---------------------------------------------------------------------------
_MODEL_NAME = os.getenv("SBERT_MODEL", "sentence-transformers/all-mpnet-base-v2")
_model: Optional[SentenceTransformer] = None


def get_model() -> SentenceTransformer:
    global _model
    if _model is None:
        logger.info(f"Loading SentenceTransformer model: {_MODEL_NAME} …")
        _model = SentenceTransformer(_MODEL_NAME)
        logger.info("Model loaded.")
    return _model


# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

def generate_book_embedding(description: str, categories: list[str]) -> list[float]:
    """
    Create a single embedding vector for a book by encoding a
    combined representation of its description and genre tags.
    Returns a Python list of floats (ready to insert into pgvector).
    """
    model = get_model()
    text = _build_book_text(description, categories)
    vector = model.encode(text, normalize_embeddings=True)
    return vector.tolist()


def generate_user_embedding(preference_text: str) -> list[float]:
    """
    Encode a free-text user preference description into a vector.
    Used by the User Embedding Builder to enable personalised search.
    """
    model = get_model()
    vector = model.encode(preference_text, normalize_embeddings=True)
    return vector.tolist()


def batch_generate_book_embeddings(
    descriptions: list[str],
    categories_list: list[list[str]],
    batch_size: int = 64,
) -> list[list[float]]:
    """
    Efficiently generate book embeddings in bulk (for dataset ingestion).
    """
    model = get_model()
    texts = [
        _build_book_text(desc, cats)
        for desc, cats in zip(descriptions, categories_list)
    ]
    vectors = model.encode(
        texts,
        batch_size=batch_size,
        normalize_embeddings=True,
        show_progress_bar=True,
    )
    return [v.tolist() for v in vectors]


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

def _build_book_text(description: str, categories: list[str]) -> str:
    """
    Combine description and genre tags into a single string for embedding.
    Genre tags are prepended so the model weights them more heavily.
    """
    genre_prefix = ", ".join(categories) if categories else ""
    parts = [p for p in [genre_prefix, description] if p.strip()]
    return " | ".join(parts) if parts else "unknown"
