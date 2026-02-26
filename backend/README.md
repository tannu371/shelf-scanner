# ShelfScanner Backend

FastAPI backend providing OCR-powered book search, pgvector-based recommendations, and HITL feedback logging.

## Features

| Feature | Implementation |
|---------|---------------|
| On-image OCR | PaddleOCR (server-side) |
| Metadata retrieval | Google Books + Open Library + WorldCat (merged & cached) |
| Vector embeddings | SBERT `all-mpnet-base-v2` → `vector(768)` |
| Similarity search | PostgreSQL + pgvector HNSW index (cosine) |
| HITL pipeline | `feedback_log` table → future CRAFT/Tesseract retraining |

## Setup (Local)

```bash
conda create -n shelfscanner python=3.10 -y
conda activate shelfscanner
pip install -r requirements.txt

cp .env.example .env        # fill in GOOGLE_BOOKS_API_KEY
python app/main.py          # → http://localhost:8000/docs
```

> Requires PostgreSQL with pgvector. For Docker setup see root `README.md`.

## Setup (Docker)

```bash
# From project root:
docker compose up --build
```

## Project Structure

```
backend/
├── app/
│   ├── api/
│   │   └── main.py             # All FastAPI endpoints
│   ├── services/
│   │   ├── embedding_service.py  # SBERT singleton
│   │   ├── text_recoginition.py  # PaddleOCR (bytes API)
│   │   └── text_reconstruction.py # BookParser (title/author heuristics)
│   ├── data_pipeline/
│   │   ├── api_clients.py        # Google Books, Open Library, WorldCat, Goodreads
│   │   └── database_generator.py # Bulk dataset ingestion
│   └── main.py                  # uvicorn entrypoint
├── db/
│   ├── schema.sql               # PostgreSQL + pgvector tables + HNSW index
│   └── database.py              # Async psycopg3 connection pool
├── input/                       # Raw shelf images for processing
├── output/                      # Cropped spines + OCR results
├── runs/                        # YOLO training runs
├── Dockerfile
├── docker-entrypoint.sh         # Wait-for-DB + schema migration
├── requirements.txt
└── .env.example
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Health check |
| `GET` | `/metadata/{isbn}` | Fetch + merge metadata from all external APIs |
| `POST` | `/scan` | `{ image_b64 }` → OCR → candidates |
| `POST` | `/search` | `{ ocr_text }` → DB search → Google Books fallback |
| `GET` | `/recommend` | `?isbn=&limit=` → pgvector KNN Top-K |
| `POST` | `/log_feedback` | `{ isbn, action: confirm\|like\|skip }` |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DB_HOST` | PostgreSQL host (default: `localhost`) |
| `DB_PORT` | PostgreSQL port (default: `5432`) |
| `DB_NAME` | Database name (default: `shelfscanner`) |
| `DB_USER` | DB user (default: `postgres`) |
| `DB_PASSWORD` | DB password |
| `GOOGLE_BOOKS_API_KEY` | Google Books API key |
| `SBERT_MODEL` | HuggingFace model ID (default: `sentence-transformers/all-mpnet-base-v2`) |
