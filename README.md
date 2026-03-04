# ShelfScanner 📚

> AI-powered book shelf scanner — point your camera at a shelf, get instant book details and personalised "books like X" recommendations.

## How It Works

```
📱 Camera Scan
    → YOLOv11 (on-device TFLite) detects book spines in real-time
    → Captured spine image sent to backend (base64)
    → PaddleOCR extracts title + author text
    → PostgreSQL fast-path full-text search (or Google Books fallback)
    → SBERT embeddings + pgvector KNN → personalised recommendations
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile app | Flutter (Dart) |
| On-device detection | YOLOv11 TFLite (CPU-only, iOS + Android) |
| Backend API | FastAPI (Python 3.10) |
| OCR | PaddleOCR |
| Embeddings | SentenceTransformer `all-mpnet-base-v2` (768-dim) |
| Vector search | PostgreSQL + pgvector (HNSW index, cosine similarity) |
| Containerisation | Docker + Docker Compose |

## Project Structure

```
shelf-scanner/
├── backend/                 # FastAPI backend
│   ├── app/
│   │   ├── api/
│   │   │   ├── main.py      # App factory — wires all routers
│   │   │   ├── schemas.py   # Shared Pydantic models
│   │   │   ├── helpers.py   # Shared DB + API helpers
│   │   │   └── endpoints/
│   │   │       ├── scan.py      # POST /scan, POST /search
│   │   │       ├── recommend.py # GET /recommend (pgvector KNN)
│   │   │       ├── feedback.py  # POST /log_feedback (HITL)
│   │   │       ├── books.py     # GET /metadata/{isbn}
│   │   │       └── match.py     # POST /match (NLP personalisation)
│   │   ├── services/        # OCR, embeddings, text parsing
│   │   ├── data_pipeline/   # External API clients (Google Books etc.)
│   │   └── db/              # Async psycopg3 connection pool
│   ├── db/schema.sql        # PostgreSQL + pgvector schema
│   ├── Dockerfile
│   ├── docker-entrypoint.sh
│   └── requirements.txt
├── frontend/                # Flutter app
│   ├── lib/
│   │   ├── api/             # HTTP client (ApiService + MatchResult models)
│   │   ├── screen/          # Home, LiveDetection, Preview, BookDetail screens
│   │   ├── services/        # YoloService · LikedBooksStore · ThemeProvider
│   │   └── widgets/         # Home · Library · Profile · Settings · BookResultSheet
│   ├── assets/models/       # TFLite model (.tflite)
│   └── ios/Runner/
│       ├── Info.plist           # Camera + mic + privacy permissions
│       └── PrivacyInfo.xcprivacy # iOS 17+ required reason APIs
├── docker-compose.yml       # One-command full stack
└── INTERVIEW-PREP.md        # Complete project knowledge doc
```

## Quick Start (Docker — recommended)

```bash
# 1. Set up environment variables
cp backend/.env.example backend/.env
# Edit backend/.env — add your GOOGLE_BOOKS_API_KEY

# 2. Launch the full stack
docker compose up --build
# API docs → http://localhost:8000/docs

# 3. Run the Flutter app
cd frontend
flutter pub get

# Android emulator:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Physical iPhone (same WiFi as Mac):
flutter run -d <device-udid> \
  --dart-define=API_BASE_URL=http://<mac-lan-ip>:8000
# Get your Mac's LAN IP: ipconfig getifaddr en0
```

## iOS Setup Notes

Running on a **physical iPhone** requires a few extra steps:

1. **Xcode** — install the iOS platform SDK matching your device's iOS version
2. **Developer Mode** — Settings → Privacy & Security → Developer Mode → On
3. **Trust Mac** — Settings → General → VPN & Device Management → Trust
4. **Apple Developer Team** — Xcode → Runner target → Signing & Capabilities
5. **Keep phone unlocked** during first install

> ⚠️ `localhost` in the API URL resolves to the **phone itself**, not your Mac.  
> Use your Mac's LAN IP (e.g. `http://192.168.1.113:8000`) instead.

## Features

### 📱 Flutter Screens

| Screen | Description |
|---|---|
| **Home** | Gradient hero card, how-it-works steps, quick-scan CTA |
| **Live Detection** | Real-time YOLO spine detection with labelled bounding boxes |
| **Preview** | Captured photo + YOLO overlays + "Get Recommendation" button |
| **Book Detail** | Hero cover, NLP fit score, "Should You Read It?" signals, expandable description, genre chips, most-similar liked book |
| **Library** | 2-column grid of liked books — live-synced via `LikedBooksStore` |
| **Profile** | Stats (liked count, scans), genre chips derived from liked books |
| **Settings** | Dark mode toggle, confidence threshold slider, API info, About |

### 🧠 NLP Personalisation (`POST /match`)

1. **Taste vector** — mean SBERT embedding of all liked books
2. **Cosine similarity** (pgvector) → **Fit Score %** (`HIGH` ≥ 75%, `MEDIUM` ≥ 50%, `LOW`)
3. **"Why You'd Like It"** — shared genres + rule-based keyword extraction from description
4. Returns the **most similar liked book** and **shared category chips**

### 🎨 Dark Mode

Controlled by `ThemeProvider` (`ValueNotifier<ThemeMode>` singleton in `lib/services/`).  
Toggle in **Settings → Dark Mode** — instant app-wide switch, no restart needed.

### ❤️ Library (liked books)

`LikedBooksStore` (`ChangeNotifier` singleton in `lib/services/`) persists likes in memory across all screens. The Library grid rebuilds automatically via `addListener`.

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Health check |
| `GET` | `/metadata/{isbn}` | Fetch merged book metadata from all sources |
| `POST` | `/scan` | Base64 spine image → OCR → book candidates |
| `POST` | `/search` | OCR text string → book candidates |
| `GET` | `/recommend?isbn=` | Top-K similar books via pgvector KNN |
| `POST` | `/log_feedback` | HITL feedback (confirm / like / skip) |
| `POST` | `/match` | NLP personalisation — cosine fit score + "why you'd like it" |


## Database Schema

```
books        — isbn, title, authors, embedding vector(768)  [HNSW cosine index]
users        — user_id, preferences, embedding vector(768)
feedback_log — isbn, action, ocr_raw_text, spine_image_b64  [HITL pipeline]
```

## Development (without Docker)

```bash
# Backend
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.api.main:app --reload --port 8000

# Frontend
cd frontend
flutter pub get
dart analyze lib/   # pre-flight check — must show "No issues found"
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

## License

[Add your license here]

---

### Common Docker commands

```bash
# Rebuild after any backend source change
docker compose up --build api

# Tail live logs
docker compose logs -f api

# Shell into running API container
docker compose exec api bash

# Nuke volumes and start fresh (redownloads PaddleOCR models)
docker compose down -v && docker compose up --build
```

### Common Flutter commands

```bash
# Pre-flight check (run before every flutter run)
cd frontend && dart analyze lib/

# Run on physical iPhone with correct API URL
flutter run -d <iphone-udid> \
  --dart-define=API_BASE_URL=http://$(ipconfig getifaddr en0):8000

# Hot reload (r), hot restart (R), quit (q)
```
