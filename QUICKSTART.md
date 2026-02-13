# Quick Start Guide

This guide will help you get the ShelfScanner application up and running quickly.

## Prerequisites

### Backend
- Python 3.10+
- Conda (recommended) or pip
- CUDA-compatible GPU (optional, for faster inference)

### Frontend
- Flutter SDK (latest stable version)
- Android Studio / Xcode (for mobile development)
- Chrome (for web development)

## Getting Started

### 1. Backend Setup

```bash
# Navigate to backend directory
cd backend

# Create conda environment
conda create -n shelfscanner python=3.10 -y
conda activate shelfscanner

# Install dependencies
pip install -r requirements.txt

# Run the backend server
python app/main.py
```

The backend API will be available at `http://localhost:8000`

### 2. Frontend Setup

```bash
# Navigate to frontend directory
cd frontend

# Install Flutter dependencies
flutter pub get

# Run on your preferred platform
flutter run  # Will prompt you to select a device

# Or specify a platform:
flutter run -d chrome        # Web
flutter run -d macos         # macOS
flutter run -d android       # Android
flutter run -d ios           # iOS
```

## Development Workflow

### Backend Development

1. Make changes to Python files in `backend/app/`
2. The FastAPI server supports hot reload
3. Test API endpoints using the interactive docs at `http://localhost:8000/docs`

### Frontend Development

1. Make changes to Dart files in `frontend/lib/`
2. Flutter supports hot reload (press `r` in terminal or save file)
3. Use Flutter DevTools for debugging

## Project Structure

```
shelf-scanner-merged/
├── backend/              # Python backend
│   ├── app/             # Application code
│   │   ├── api/         # API endpoints
│   │   ├── services/    # Business logic
│   │   └── models/      # ML models
│   ├── data/            # Datasets
│   └── requirements.txt # Python dependencies
│
└── frontend/            # Flutter frontend
    ├── lib/            # Dart code
    │   ├── api/        # API integration
    │   ├── screen/     # App screens
    │   └── widgets/    # UI components
    ├── assets/         # Images, icons, models
    └── pubspec.yaml    # Flutter dependencies
```

## Common Issues

### Backend

**Issue**: Module not found errors
**Solution**: Make sure you've activated the conda environment and installed all dependencies

**Issue**: CUDA errors
**Solution**: The app will fall back to CPU if CUDA is not available

### Frontend

**Issue**: Flutter command not found
**Solution**: Make sure Flutter is added to your PATH

**Issue**: Build errors on iOS
**Solution**: Run `pod install` in the `ios` directory

**Issue**: Android build errors
**Solution**: Make sure Android SDK is properly configured

## Next Steps

- Read the full documentation in `README.md`
- Check backend API documentation at `backend/README.md`
- Check frontend documentation at `frontend/README.md`
- Explore the codebase and start contributing!

## Support

For issues and questions, please check the project documentation or create an issue in the repository.
