# ShelfScanner — Quick Start

## Prerequisites

| Requirement | Version |
|---|---|
| Flutter SDK | Latest stable (`flutter --version`) |
| Python | 3.10+ |
| Docker + Docker Compose | Latest |
| Xcode (iOS) | 15+ |
| Android Studio (Android) | Latest stable |

---

## Recommended: Full Stack with Docker

```bash
# 1. Clone and enter the project
git clone <repo-url> && cd shelf-scanner

# 2. Configure environment
cp backend/.env.example backend/.env
# Open backend/.env and set GOOGLE_BOOKS_API_KEY

# 3. Start everything (API + PostgreSQL + pgvector)
docker compose up --build
# → API docs: http://localhost:8000/docs

# 4. Install Flutter deps
cd frontend && flutter pub get

# 5a. Run on Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# 5b. Run on physical iPhone (replace <udid> and <mac-ip>)
flutter run -d <udid> --dart-define=API_BASE_URL=http://<mac-ip>:8000
# Get your Mac's IP: ipconfig getifaddr en0
```

---

## Local Backend (no Docker)

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env              # fill in GOOGLE_BOOKS_API_KEY
uvicorn app.api.main:app --reload --port 8000
# Requires PostgreSQL with pgvector extension
```

---

## iOS Physical Device Checklist

1. **Developer Mode** — iPhone Settings → Privacy & Security → Developer Mode → On
2. **Trust Mac** — Settings → General → VPN & Device Management → Trust
3. **Signing** — Xcode → Runner target → Signing & Capabilities → set your Apple ID team
4. **API URL** — use your Mac's LAN IP, not `localhost` (the phone can't resolve Mac's localhost)

---

## Project Layout

```
shelf-scanner/
├── backend/                # FastAPI · PaddleOCR · pgvector
│   ├── app/api/endpoints/  # scan · recommend · match · feedback · books
│   ├── db/schema.sql
│   ├── Dockerfile
│   └── requirements.txt
└── frontend/               # Flutter (iOS + Android)
    └── lib/
        ├── models/         # BookResult · SpineEntry · MatchResult
        ├── api/            # ApiService (HTTP client + model re-exports)
        ├── services/       # YoloService · LikedBooksStore · ThemeProvider
        ├── screen/         # HomeScreen · LiveDetection · Preview
        │                   # BookSpineDetail (tabs) · BookDetail
        └── widgets/
            ├── spine_detail/  # SpineCard · SimilarSection (card/list toggle)
            └── book_detail/   # HeroCover · PersonalisationCard · DecisionCard …
```

---

## Useful Commands

```bash
# Backend
docker compose logs -f api                    # Live API logs
docker compose exec api bash                  # Shell into container
docker compose down -v && docker compose up --build  # Nuke & rebuild

# Frontend
flutter analyze --no-pub                      # Lint check (run before every flutter run)
flutter pub get                               # After pubspec changes
flutter clean && flutter pub get              # Nuclear option for build issues
```

---

## Common Issues

| Symptom | Fix |
|---|---|
| `API_BASE_URL` not set | Pass `--dart-define=API_BASE_URL=http://<ip>:8000` to `flutter run` |
| iOS build fails — pods | `cd ios && pod install && cd ..` |
| PaddleOCR slow on first request | First call downloads model weights; subsequent calls are fast |
| YOLO model not found | Ensure `assets/models/yolov11-2.tflite` is declared in `pubspec.yaml` |
| Camera permission denied | iOS: check `Info.plist` has `NSCameraUsageDescription` |
