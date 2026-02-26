# ShelfScanner 📚

> AI-powered book shelf scanner — point your camera at a shelf, get instant book details and personalised "books like X" recommendations.

## How It Works

```
📱 Camera Scan
    → YOLOv11 (on-device TFLite) detects book spines
    → Cropped spine image sent to backend
    → PaddleOCR extracts title + author text
    → PostgreSQL fast-path search (or Google Books fallback)
    → SBERT embeddings + pgvector KNN → recommendations
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile app | Flutter (Dart) |
| On-device detection | YOLOv11 TFLite |
| Backend API | FastAPI (Python 3.10) |
| OCR | PaddleOCR |
| Embeddings | SentenceTransformer `all-mpnet-base-v2` |
| Vector search | PostgreSQL + pgvector (HNSW index) |
| Containerisation | Docker + Docker Compose |

## Project Structure

```
shelf-scanner/
├── backend/                # FastAPI backend
│   ├── app/
│   │   ├── api/main.py     # All API endpoints
│   │   ├── services/       # OCR, embeddings, text parsing
│   │   └── data_pipeline/  # External API clients (Google Books etc.)
│   ├── db/
│   │   ├── schema.sql      # PostgreSQL + pgvector schema
│   │   └── database.py     # Async connection pool
│   ├── Dockerfile
│   ├── docker-entrypoint.sh
│   └── requirements.txt
├── frontend/               # Flutter app
│   ├── lib/
│   │   ├── api/            # HTTP client (ApiService)
│   │   ├── screen/         # Home, LiveDetection, Preview screens
│   │   └── widgets/        # BookResultSheet + nav widgets
│   └── assets/models/      # TFLite model + labels
├── docker-compose.yml      # One-command stack
└── QUICKSTART.md
```

## Quick Start (Docker — recommended)

```bash
# 1. Set up environment
cp backend/.env.example backend/.env
# Edit backend/.env and add your GOOGLE_BOOKS_API_KEY

# 2. Launch the full stack
docker compose up --build
# API docs → http://localhost:8000/docs

# 3. Run the Flutter app
cd frontend && flutter pub get
flutter run                                       # Android emulator
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000   # physical device
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Health check |
| `GET` | `/metadata/{isbn}` | Fetch merged book metadata |
| `POST` | `/scan` | Base64 spine image → book candidates |
| `POST` | `/search` | OCR text → book candidates |
| `GET` | `/recommend?isbn=` | Top-K similar books (pgvector KNN) |
| `POST` | `/log_feedback` | HITL feedback (confirm/like/skip) |

## Database Schema

```
books        — isbn, title, authors, embedding vector(768)  [HNSW index]
users        — user_id, preferences, embedding vector(768)
feedback_log — isbn, action, ocr_raw_text, spine_image_b64  [HITL pipeline]
```

## Development (without Docker)

See [QUICKSTART.md](QUICKSTART.md) for local setup instructions.

## License

[Add your license here]
