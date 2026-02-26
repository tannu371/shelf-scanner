"""
ShelfScanner Backend — Entrypoint
Run with:  python app/main.py
Or via Docker: uvicorn app.api.main:app --host 0.0.0.0 --port 8000
"""
import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "app.api.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,  # Auto-reload on code changes during development
        log_level="info",
    )
