# ShelfScanner Frontend

Flutter-based cross-platform mobile application for scanning book shelves.

## Features

- Camera integration for book shelf scanning
- Real-time book spine detection
- Book library management
- User profile and settings
- Cross-platform support (iOS, Android, Web, Desktop)

## Setup

1. Install Flutter: https://docs.flutter.dev/get-started/install

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Project Structure

```
frontend/
├── lib/
│   ├── api/              # Backend API integration
│   ├── screen/           # App screens
│   ├── widgets/          # Reusable widgets
│   └── main.dart        # App entry point
├── assets/              # Images, icons, models
├── android/             # Android-specific code
├── ios/                 # iOS-specific code
├── web/                 # Web-specific code
└── test/                # Tests
```

## Available Screens

- Home Screen
- Live Detection Screen
- Preview Screen
- Library
- Profile
- Settings

## Building

### Android
```bash
flutter build apk
```

### iOS
```bash
flutter build ios
```

### Web
```bash
flutter build web
```
