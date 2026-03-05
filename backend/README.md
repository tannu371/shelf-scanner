# ShelfScanner — Backend

FastAPI backend providing OCR-powered book search, pgvector-based recommendations, NLP personalisation, and HITL feedback logging.

## Feature Summary

| Feature | Implementation |
|---------|---------------|
| On-image OCR | PaddleOCR (server-side, bytes API) |
| Metadata retrieval | Google Books + Open Library + WorldCat (merged & cached) |
| Vector embeddings | SBERT `all-mpnet-base-v2` → `vector(768)` |
| Similarity search | PostgreSQL + pgvector HNSW index (cosine distance) |
| NLP personalisation | Mean taste vector → cosine fit score + "why you'd like it" explanation |
| HITL pipeline | `feedback_log` table → future retraining data |

## Setup

### Docker (recommended)

```bash
# From project root:
docker compose up --build
# → http://localhost:8000/docs
```

### Local

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # fill in GOOGLE_BOOKS_API_KEY
uvicorn app.api.main:app --reload --port 8000
# Requires a running PostgreSQL instance with pgvector extension
```

## Project Structure

```
backend/
├── app/
│   ├── api/
│   │   ├── main.py               # FastAPI app factory — mounts all routers
│   │   ├── schemas.py            # Shared Pydantic request/response models
│   │   ├── helpers.py            # Shared DB helpers + Google Books client
│   │   └── endpoints/
│   │       ├── scan.py           # POST /scan · POST /search
│   │       ├── recommend.py      # GET  /recommend  (pgvector KNN Top-K)
│   │       ├── match.py          # POST /match      (NLP personalisation)
│   │       ├── feedback.py       # POST /log_feedback (HITL confirm/like/skip)
│   │       └── books.py          # GET  /metadata/{isbn}
│   ├── services/
│   │   ├── embedding_service.py  # SBERT singleton (lazy load)
│   │   ├── text_recoginition.py  # PaddleOCR wrapper (bytes → text)
│   │   └── text_reconstruction.py# BookParser — title/author heuristics from OCR
│   ├── data_pipeline/
│   │   ├── api_clients.py        # Google Books · Open Library · WorldCat · Goodreads
│   │   └── database_generator.py # Bulk dataset ingestion scripts
│   └── main.py                  # uvicorn entrypoint
├── db/
│   ├── schema.sql               # Tables + HNSW index creation
│   └── database.py              # Async psycopg3 connection pool
├── Dockerfile
├── docker-entrypoint.sh         # Waits for DB ready → applies schema
├── requirements.txt
└── .env.example
```

## API Endpoints

| Method | Path | Body / Params | Description |
|--------|------|---------------|-------------|
| `GET` | `/` | — | Health check |
| `GET` | `/metadata/{isbn}` | — | Merged metadata from all sources |
| `POST` | `/scan` | `{ image_b64: str }` | Base64 spine image → OCR → candidates |
| `POST` | `/search` | `{ ocr_text: str }` | Text search → DB → Google Books fallback |
| `GET` | `/recommend` | `?isbn=&limit=&user_id=` | pgvector KNN Top-K similar books |
| `POST` | `/log_feedback` | `{ isbn, action, user_id? }` | HITL: confirm · like · skip |
| `POST` | `/match` | `{ isbn, liked_isbns[] }` | NLP fit score + "why you'd like it" |

### `/match` Response shape
```json
{
  "fit_score": 0.82,
  "confidence": "HIGH",
  "why_you_like_it": "Shares themes of identity and mystery with your liked books…",
  "theme_match": { "shared_categories": ["Mystery", "Thriller"], "overlap_score": 0.74 },
  "top_similar_liked": { /* BookResult */ }
}
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | `shelfscanner` | Database name |
| `DB_USER` | `postgres` | DB username |
| `DB_PASSWORD` | — | DB password |
| `GOOGLE_BOOKS_API_KEY` | — | Required for metadata fallback |
| `SBERT_MODEL` | `sentence-transformers/all-mpnet-base-v2` | HuggingFace model ID |

## Database Schema

```sql
-- books: one row per unique ISBN
books (isbn PK, title, authors[], categories[], description,
       avg_rating, rating_count, cover_url, publisher, year,
       embedding vector(768))   -- HNSW cosine index

-- users: taste profile per user
users (user_id PK, preferences text[], embedding vector(768))

-- feedback_log: HITL training data
feedback_log (id, isbn, action, user_id, ocr_raw_text,
              spine_image_b64, created_at)
```

## Notes

- **PaddleOCR first call** downloads model weights — allow 30–60 s on cold start.
- `/scan` has a **120 s timeout** to accommodate this.
- SBERT model is loaded **once at startup** as a singleton.
- pgvector HNSW index is created **at schema migration** (docker-entrypoint.sh).
