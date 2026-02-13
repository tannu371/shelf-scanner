# ShelfScanner/app/api/main.py
from fastapi import FastAPI, HTTPException
from dotenv import load_dotenv
import os
import asyncio
from typing import Dict, Any

# --- Import your data pipeline functions ---
# We use '...' to go up one directory from 'api' to 'app'
# then into 'data_pipeline'
from ..data_pipeline.api_clients import (
    fetch_google_books_data,
    fetch_open_library_data,
    fetch_worldcat_data,
    fetch_goodreads_data
)

# Load environment variables from .env file
load_dotenv()

app = FastAPI(
    title="ShelfScanner Backend API",
    description="API for book metadata, recommendations, and cover scanning."
)

@app.get("/")
async def root():
    return {"message": "Welcome to the ShelfScanner API! Head to /docs for API details."}


# --- NEW ENDPOINT FOR STEP: Backend Testing ---

@app.get("/metadata/{isbn}", response_model=Dict[str, Any])
async def get_live_book_metadata(isbn: str):
    """
    Fetches complete, live book metadata for a given ISBN
    by querying all external APIs in parallel.
    
    This endpoint confirms that all data sources are accessible 
    and functional before building the UI.
    """
    print(f"Received request for live metadata: {isbn}")

    # 1. Fetch from all sources concurrently (just like in the dataset generator)
    # This demonstrates the core logic is working in a live API environment.
    try:
        google_task = fetch_google_books_data(isbn)
        openlib_task = fetch_open_library_data(isbn)
        worldcat_task = fetch_worldcat_data(isbn)
        goodreads_task = fetch_goodreads_data(isbn)

        google_data, openlib_data, worldcat_data, goodreads_data = await asyncio.gather(
            google_task, openlib_task, worldcat_task, goodreads_task
        )
    except Exception as e:
        print(f"Error during API calls: {e}")
        raise HTTPException(status_code=503, detail=f"An error occurred while contacting external APIs: {e}")

    # 2. Initialize the final, normalized dictionary
    final_data = {
        'isbn': isbn, 'title': '', 'authors': [], 'publisher': '', 'year': '',
        'description': '', 'categories': [], 'cover_url': '',
        'ol_average_rating': None, 'ol_rating_count': None,
        'goodreads_rating': None, 'goodreads_rating_count': None
    }

    # 3. Cascade and merge data (same logic as your pipeline)
    final_data['title'] = google_data.get('title') or openlib_data.get('title') or worldcat_data.get('title', '')

    # Authors (Combine all, then deduplicate)
    authors = google_data.get('authors', []) + openlib_data.get('authors', []) + worldcat_data.get('authors', [])
    final_data['authors'] = sorted(list(set(authors))) # Get unique authors

    final_data['publisher'] = google_data.get('publisher') or (openlib_data.get('publishers') and openlib_data['publishers'][0]) or ''
    
    final_data['description'] = google_data.get('description', '') or openlib_data.get('description', '') or ''

    year_str = str(worldcat_data.get('year') or google_data.get('publishedDate') or openlib_data.get('publishDate', ''))
    if year_str:
        final_data['year'] = year_str.split('-')[0]

    categories = google_data.get('categories', []) + openlib_data.get('categories', [])
    final_data['categories'] = sorted(list(set(categories)))

    final_data['cover_url'] = google_data.get('coverURL') or openlib_data.get('coverURL', '')

    final_data['ol_average_rating'] = openlib_data.get('ol_average_rating')
    final_data['ol_rating_count'] = openlib_data.get('ol_rating_count')

    final_data.update(goodreads_data)

    # 4. Check if we found anything at all
    if not final_data['title']:
        raise HTTPException(
            status_code=404,
            detail=f"Metadata not found for ISBN {isbn}. All external APIs returned no data."
        )

    # 5. Return the complete, merged data
    return final_data