# ShelfScanner Backend

Python-based backend for book spine detection and recommendation system.

## Features

- YOLO-based book spine detection
- OCR for text extraction from book spines
- Book recommendation engine
- FastAPI REST API

## Setup

1. Create conda environment:
```bash
conda create -n shelfscanner python=3.10 -y
conda activate shelfscanner
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Run the server:
```bash
python app/main.py
```

## Project Structure

```
backend/
├── app/
│   ├── api/              # API endpoints
│   ├── data_pipeline/    # Data processing
│   ├── models/           # ML models
│   ├── services/         # Business logic
│   └── main.py          # Application entry point
├── data/                # Datasets
├── helper/              # Utility scripts
├── input/               # Input images
├── output/              # Processed results
└── runs/                # Training runs
```

## API Endpoints

The backend exposes RESTful API endpoints for:
- Book spine detection
- OCR processing
- Book recommendations

See API documentation for details.
