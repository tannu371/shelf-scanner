# ShelfScanner 📚

> AI-powered book shelf scanner — point your camera at a shelf, get instant book details and personalised "books like X" recommendations.

## How It Works

```
📱 Live camera  →  YOLOv11 (on-device TFLite) detects book spines in real-time
                →  Tap capture (or import from gallery)
                →  Spine crop sent to backend (base64)
                →  PaddleOCR extracts title + author
                →  PostgreSQL full-text search (→ Google Books fallback)
                →  SBERT embeddings + pgvector KNN → personalised recommendations
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
├── backend/                  # FastAPI backend
│   ├── app/
│   │   ├── api/
│   │   │   ├── main.py       # App factory — wires all routers
│   │   │   ├── schemas.py    # Shared Pydantic models
│   │   │   ├── helpers.py    # Shared DB + API helpers
│   │   │   └── endpoints/
│   │   │       ├── scan.py       # POST /scan, POST /search
│   │   │       ├── recommend.py  # GET /recommend (pgvector KNN)
│   │   │       ├── feedback.py   # POST /log_feedback (HITL)
│   │   │       ├── books.py      # GET /metadata/{isbn}
│   │   │       └── match.py      # POST /match (NLP personalisation)
│   │   ├── services/         # OCR, embeddings, text parsing
│   │   ├── data_pipeline/    # External API clients (Google Books etc.)
│   │   └── db/               # Async psycopg3 connection pool
│   ├── db/schema.sql         # PostgreSQL + pgvector schema
│   ├── Dockerfile
│   ├── docker-entrypoint.sh
│   └── requirements.txt
│
├── frontend/                 # Flutter app
│   ├── lib/
│   │   ├── models/           # BookResult · SpineEntry · MatchResult / ThemeMatch
│   │   ├── api/              # ApiService (re-exports models for backward compat)
│   │   ├── services/         # YoloService · LikedBooksStore · ThemeProvider
│   │   ├── screen/           # Lean scaffold screens (HomeScreen, LiveDetection,
│   │   │                     #   Preview, BookSpineDetail, BookDetail)
│   │   └── widgets/
│   │       ├── home.dart · library.dart · profile.dart · settings.dart
│   │       ├── book_result_sheet.dart   # Quick-peek bottom sheet
│   │       ├── spine_detail/            # SpineAppBar · SpineImage · BookMetadata
│   │       │                            # ActionButtons · SimilarSection · SpineCard
│   │       └── book_detail/             # HeroCover · MetaRow · LikeButton
│   │                                    # PersonalisationCard · DecisionCard
│   │                                    # SimilarBookTile · SectionTitle
│   ├── assets/
│   │   ├── models/           # yolov11-2.tflite
│   │   ├── icons/            # gallery-import.svg (+ others)
│   │   └── sounds/           # shutter sound
│   └── ios/Runner/
│       ├── Info.plist              # Camera + privacy permissions
│       └── PrivacyInfo.xcprivacy  # iOS 17+ required reason APIs
│
├── docker-compose.yml        # One-command full stack
├── QUICKSTART.md
└── INTERVIEW-PREP.md         # Complete project knowledge doc
```

## Quick Start (Docker — recommended)

```bash
# 1. Environment variables
cp backend/.env.example backend/.env
# Edit backend/.env — add GOOGLE_BOOKS_API_KEY

# 2. Launch full stack
docker compose up --build
# API docs → http://localhost:8000/docs

# 3. Flutter app
cd frontend && flutter pub get

# Android emulator:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Physical iPhone (same Wi-Fi):
flutter run -d <device-udid> \
  --dart-define=API_BASE_URL=http://$(ipconfig getifaddr en0):8000
```

## iOS Setup

1. **Xcode** — install the iOS platform matching your device OS
2. **Developer Mode** — Settings → Privacy & Security → Developer Mode → On
3. **Trust Mac** — Settings → General → VPN & Device Management → Trust
4. **Apple Developer Team** — Xcode → Runner → Signing & Capabilities

> ⚠️ Use your Mac's LAN IP (e.g. `http://192.168.1.113:8000`), not `localhost`.

## Features

### 📱 Screens

| Screen | Description |
|---|---|
| **Home** | Hero card · How-it-works steps · "Start Scanning" CTA |
| **Live Detection** | Real-time YOLO spine boxes · capture photo · pick from gallery |
| **Preview** | Captured photo + YOLO overlays · "Get Recommendation" button |
| **Book Spine Detail** | **Tab-per-spine** layout · spine image · metadata · Like/Share · **Similar Books with List/Card toggle** |
| **Book Detail** | Hero cover · NLP fit score · "Should You Read It?" · description · genres |
| **Library** | 2-column grid of liked books |
| **Profile** | Stats · genre breakdown from liked books |
| **Settings** | Dark mode toggle · confidence threshold · API info |

### 📥 Gallery Import (AppBar)

Tap the **gallery icon** (top-right AppBar) to import an existing shelf photo instead of opening the live camera. The same YOLO → OCR → recommendation pipeline runs on the imported image.

### 📑 Tab-per-Spine

When multiple spines are detected the **Book Spine Detail** screen shows a **pill-style TabBar** (one tab per book, labelled with the first 2 words of the title). Swipe or tap between spines — no more scrolling past other results.

### 🔀 Similar Books — List / Card Toggle

The "Similar Books" section has two view modes, shared across all spine tabs:

| Mode | Layout |
|---|---|
| **Card** (default) | Horizontal scrollable 120px cover cards |
| **List** | Vertical tiles with cover · title · author · rating · match % |

### 🧠 NLP Personalisation (`POST /match`)

1. **Taste vector** — mean SBERT embedding of all liked books
2. **Cosine similarity** (pgvector) → **Fit Score %** (`HIGH` ≥ 75 %, `MEDIUM` ≥ 50 %, `LOW`)
3. **"Why You'd Like It"** — shared genres + keyword extraction from description
4. Returns the **most similar liked book** + **shared category chips**

### 🎨 Dark Mode

Controlled by `ThemeProvider` (`ValueNotifier<ThemeMode>` in `lib/services/`). Toggle in **Settings → Dark Mode** — instant app-wide switch.

### ❤️ Library

`LikedBooksStore` (`ChangeNotifier` singleton) persists likes in memory. The Library grid rebuilds automatically.

---

## Deployment

### 📱 Android APK (Free)

Build a release APK directly on macOS — no paid account needed:

```bash
cd frontend
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Or split by CPU architecture (smaller files):
flutter build apk --split-per-abi
# Use app-arm64-v8a-release.apk for modern Android phones
```

**Install on device:** transfer the `.apk` to an Android phone, enable **Settings → Security → Install unknown apps**, then open the file.

> The APK includes the bundled TFLite model (`yolov11-2.tflite`) and runs on-device inference with no internet required for detection.

> **App Icon:** Custom bookshelf + magnifying glass icon (flat design, orange shelf with colourful spines). Configured via `flutter_launcher_icons` in `pubspec.yaml` — run `dart run flutter_launcher_icons` to regenerate all mipmap sizes from `assets/icons/app_icon.png`.

---

### 🍎 iOS — Free Sideload (Your Own Device Only)

A free Apple ID is enough to install the app on **your own iPhone** via Xcode (certificate valid for 7 days):

```bash
cd frontend
open ios/Runner.xcworkspace
```

In Xcode:
1. **Signing & Capabilities → Team** → sign in with your free Apple ID
2. Select your iPhone as the run target
3. Press **▶ Run** — Xcode builds and installs on your device

> ⚠️ Distributing to other iOS users requires a paid Apple Developer account ($99/year) for App Store or TestFlight. There is no free alternative for distributing `.ipa` files to arbitrary devices.

---

### 🌐 Flutter Web — Not Supported

`flutter build web` fails because `tflite_flutter` uses `dart:ffi` (Foreign Function Interface) to call native TFLite C libraries. Web browsers do not support FFI. The same limitation applies to `camera`, `permission_handler`, and `gal`. Supporting web would require moving model inference to the backend and replacing all native APIs with browser equivalents — a significant refactor.

---

### ☁️ Cloud Deployment (Free) — Render + Neon

Deploy the backend so the APK works anywhere (no LAN / same-WiFi requirement).

**Why Render + Neon?** Render's free PostgreSQL doesn't support the `pgvector` extension. [Neon](https://neon.tech) provides free PostgreSQL **with pgvector built-in**.

#### 1. Create a Neon Database (free)
1. Sign up at [neon.tech](https://neon.tech) → create a project
2. Create a database called `shelfscanner`
3. Note your connection details: host, user, password
4. Apply the schema:
   ```bash
   psql "postgresql://USER:PASS@HOST/shelfscanner?sslmode=require" -f backend/db/schema.sql
   ```

#### 2. Deploy Backend on Render (free)
1. Push your repo to GitHub
2. On [render.com](https://render.com) → **New → Web Service** → connect your repo
3. Set **Root Directory** to `backend`
4. **Build Command:** `pip install -r requirements.txt`
5. **Start Command:** `uvicorn app.api.main:app --host 0.0.0.0 --port $PORT --workers 1`
6. Add **Environment Variables:**
   ```
   DB_HOST=ep-xxx.us-east-2.aws.neon.tech
   DB_PORT=5432
   DB_NAME=shelfscanner
   DB_USER=your_neon_user
   DB_PASSWORD=your_neon_password
   DB_SSLMODE=require
   GOOGLE_BOOKS_API_KEY=your_key
   SBERT_MODEL=sentence-transformers/all-mpnet-base-v2
   ```

#### 3. Rebuild the APK with the Render URL
```bash
cd frontend
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-app.onrender.com
```

> ⚠️ Render free tier spins down after 15 min of inactivity. The first request after spin-up takes ~30–60s (cold start + SBERT model load).

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Health check |
| `GET` | `/metadata/{isbn}` | Fetch merged book metadata |
| `POST` | `/scan` | Base64 spine image → OCR → book candidates |
| `POST` | `/search` | OCR text → book candidates |
| `GET` | `/recommend?isbn=` | Top-K similar books (pgvector KNN) |
| `POST` | `/log_feedback` | HITL feedback (confirm / like / skip) |
| `POST` | `/match` | NLP personalisation — fit score + "why you'd like it" |

## Database Schema

```
books        — isbn, title, authors, embedding vector(768)  [HNSW cosine index]
book_users   — user_id, preferences, embedding vector(768)
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
flutter analyze --no-pub   # must be clean before running
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

---

### Common Docker commands

```bash
docker compose up --build api          # Rebuild after backend changes
docker compose logs -f api             # Tail live logs
docker compose exec api bash           # Shell into API container
docker compose down -v && docker compose up --build  # Fresh start
```

### Common Flutter commands

```bash
cd frontend && flutter analyze --no-pub   # Pre-flight lint check

# Run on physical iPhone with correct API URL
flutter run -d <iphone-udid> \
  --dart-define=API_BASE_URL=http://$(ipconfig getifaddr en0):8000

# Hot reload (r) · hot restart (R) · quit (q)
```
