# ShelfScanner — Frontend

Flutter mobile app (iOS + Android) for real-time book shelf scanning, OCR-powered book lookup, and personalised recommendations.

## Setup

```bash
flutter pub get
flutter analyze --no-pub          # must be clean
flutter run --dart-define=API_BASE_URL=http://<backend-ip>:8000
```

See root `QUICKSTART.md` for full device setup instructions.

## Architecture

```
lib/
├── models/                   # Pure data classes (no Flutter deps)
│   ├── book_result.dart      # BookResult — all book metadata fields
│   ├── spine_entry.dart      # SpineEntry — BookResult + raw spine image bytes
│   └── match_result.dart     # ThemeMatch · MatchResult (NLP personalisation)
│
├── api/
│   └── api_service.dart      # HTTP client — scan · recommend · match · feedback
│                             # Also re-exports all models for backward compat
│
├── services/
│   ├── yolo_service.dart     # TFLite wrapper (YOLOv11 CPU-only)
│   ├── liked_books_store.dart# ChangeNotifier singleton — in-memory liked books
│   └── theme_provider.dart   # ValueNotifier<ThemeMode> singleton
│
├── screen/                   # Thin scaffold files — import widgets, no heavy logic
│   ├── home_screen.dart      # Navigation shell (BottomNav + FAB + AppBar)
│   ├── live_detection_screen.dart  # CameraPreview + YOLO bounding boxes
│   ├── preview_screen.dart   # Captured image + "Get Recommendation" button
│   ├── book_spine_detail_screen.dart  # Tab-per-spine layout (DefaultTabController)
│   └── book_detail_screen.dart        # Full-page book detail with NLP card
│
└── widgets/
    ├── home.dart             # Home tab content (hero card, how-it-works)
    ├── library.dart          # Liked books grid
    ├── profile.dart          # User stats + genre breakdown
    ├── settings.dart         # Dark mode, confidence, API info
    ├── book_result_sheet.dart# Draggable bottom sheet (quick-peek)
    │
    ├── spine_detail/         # Widgets used by BookSpineDetailScreen
    │   ├── spine_app_bar.dart      # Back button + "N Books Found" title
    │   ├── spine_image.dart        # Cropped spine thumbnail
    │   ├── book_metadata.dart      # Title · author · rating · description · categories
    │   ├── action_buttons.dart     # Like + Share buttons
    │   ├── similar_section.dart    # SimilarSection (card/list toggle) · SimilarBookCard
    │   └── spine_card.dart         # Stateful orchestrator for one spine
    │
    └── book_detail/          # Widgets used by BookDetailScreen
        ├── hero_cover.dart         # Collapsible sliver hero with blurred bg
        ├── meta_row.dart           # Compact info chips (year · publisher · rating)
        ├── like_button.dart        # Stateful Like toggle with LikedBooksStore
        ├── personalisation_card.dart # NLP fit score · "why you'd like it" · shared genres
        ├── decision_card.dart      # "Should You Read It?" heuristic signals
        ├── similar_book_tile.dart  # "Because You Liked" tile → BookDetail
        └── section_title.dart      # Bold section heading
```

## Key UI Behaviours

### Gallery Import (AppBar)
The top-right AppBar icon (`gallery-import.svg`) opens the native image picker. The selected photo goes through the same YOLO → OCR → recommendation pipeline as a camera capture. `YoloService` is lazily initialised once per session.

### Tab-per-Spine (BookSpineDetailScreen)
- **1 spine**: simple scrollable card, no tab bar
- **2+ spines**: `DefaultTabController` + pill-style `TabBar` (truncated book title as label) + independently scrollable `TabBarView` pages

### Similar Books — List / Card Toggle (SimilarSection)
View mode state lives in `BookSpineDetailScreen`, shared across all tabs via props. Toggling on any tab changes the layout on every tab immediately.

| Mode | Layout |
|---|---|
| Card (default) | Horizontal `ListView` — 120×190 cover cards |
| List | Vertical `Column` — cover · title · author · rating · match % badge |

## Routes (`main.dart`)

| Route | Screen | Argument type |
|---|---|---|
| `/` | `HomeScreen` | — |
| `/live` | `LiveDetectionScreen` | — |
| `/preview` | `PreviewScreen` | `Map<String,dynamic>` {imageFile, visionModel} |
| `/spine-detail` | `BookSpineDetailScreen` | `Map<String,dynamic>` {entries, userId?} |
| `/book-detail` | `BookDetailScreen` | `BookResult` |

## Build

```bash
# Android
flutter build apk --dart-define=API_BASE_URL=http://<ip>:8000

# iOS
flutter build ios --dart-define=API_BASE_URL=http://<ip>:8000
```
