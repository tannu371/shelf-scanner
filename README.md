# ShelfScanner - AI Powered Book Recommendation System

A full-stack application that uses AI to scan book shelves, detect book spines, and provide intelligent book recommendations.

## Project Structure

```
shelf-scanner-merged/
├── backend/          # Python FastAPI backend with ML models
├── frontend/         # Flutter mobile/web application
└── README.md         # This file
```

## Backend (Python/FastAPI)

The backend handles book spine detection using YOLO models, OCR for text extraction, and book recommendations.

### Setup

1. Create and activate conda environment:
```bash
cd backend
conda create -n shelfscanner python=3.10 -y
conda activate shelfscanner
conda install ipykernel
python3 -m ipykernel install --user --name shelfscanner --display-name "Python (shelfscanner)"
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Run the backend:
```bash
python app/main.py
```

### Features
- Book spine detection using YOLO
- OCR for text extraction from book spines
- Book recommendation engine
- RESTful API endpoints

## Frontend (Flutter)

The frontend is a cross-platform Flutter application for iOS, Android, and Web.

### Setup

1. Install Flutter: https://docs.flutter.dev/get-started/install

2. Install dependencies:
```bash
cd frontend
flutter pub get
```

3. Run the application:
```bash
flutter run
```

### Supported Platforms
- iOS
- Android
- Web
- macOS
- Linux
- Windows

## Development

### Backend Development
- Main application: `backend/app/main.py`
- API routes: `backend/app/api/`
- ML models: `backend/app/models/`
- Data pipeline: `backend/app/data_pipeline/`

### Frontend Development
- Main entry: `frontend/lib/main.dart`
- Screens: `frontend/lib/screen/`
- Widgets: `frontend/lib/widgets/`
- API integration: `frontend/lib/api/`

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

[Add your license here]
