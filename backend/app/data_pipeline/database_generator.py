import os
import time
import pandas as pd
from typing import Dict, Any, List
import asyncio # For async functions

# Import the API client functions
from api_clients import (
    fetch_google_books_data,
    fetch_open_library_data,
    fetch_worldcat_data,
    fetch_goodreads_data,
    download_cover_image
)

# --- Unified Cascading Function ---

async def get_complete_book_data(isbn: str, download_dir: str) -> Dict[str, Any]:
    """
    Fetches data using a cascading strategy from our custom functions
    and returns a normalized dictionary.
    """
    # Initialize a dictionary to hold the final, merged data
    final_data = {
        'isbn': isbn, 'title': '', 'authors': [], 'publisher': '', 'year': '',
        'description': '', 'categories': [], 'cover_url': '', 'image_path': None,
        'ol_average_rating': None, 'ol_rating_count': None, # Added OL specific ratings
        'goodreads_rating': None, 'goodreads_rating_count': None
    }

    # 1. Fetch from all sources concurrently (using asyncio.gather)
    print(f"  -> Fetching from all sources for ISBN: {isbn}")
    
    # Run all API calls in parallel to speed up the process
    google_task = fetch_google_books_data(isbn)
    openlib_task = fetch_open_library_data(isbn)
    worldcat_task = fetch_worldcat_data(isbn)
    goodreads_task = fetch_goodreads_data(isbn)

    google_data, openlib_data, worldcat_data, goodreads_data = await asyncio.gather(
        google_task, openlib_task, worldcat_task, goodreads_task
    )

    # 2. Cascade and merge data, prioritizing the best sources
    # Priority Order: Google -> OpenLibrary -> WorldCat (for general fields)
    
    # Title (Google is usually best)
    final_data['title'] = google_data.get('title') or openlib_data.get('title') or worldcat_data.get('title', '')

    # Authors (Combine all, then deduplicate)
    authors = google_data.get('authors', []) + openlib_data.get('authors', []) + worldcat_data.get('authors', [])
    final_data['authors'] = sorted(list(set(authors))) # Get unique authors

    # Publisher
    final_data['publisher'] = google_data.get('publisher') or (openlib_data.get('publishers') and openlib_data['publishers'][0]) or ''
    
    # Description
    final_data['description'] = google_data.get('description', '') or openlib_data.get('description', '') or ''

    # Year (WorldCat is often most accurate, then Google)
    year_str = str(worldcat_data.get('year') or google_data.get('publishedDate') or openlib_data.get('publishDate', ''))
    if year_str:
        final_data['year'] = year_str.split('-')[0] # Extract just the year

    # Categories/Subjects (Combine Google and OpenLibrary)
    categories = google_data.get('categories', []) + openlib_data.get('categories', [])
    final_data['categories'] = sorted(list(set(categories)))

    # Cover URL (Google is best, then Open Library)
    final_data['cover_url'] = google_data.get('coverURL') or openlib_data.get('coverURL', '')

    # Open Library specific ratings
    final_data['ol_average_rating'] = openlib_data.get('ol_average_rating')
    final_data['ol_rating_count'] = openlib_data.get('ol_rating_count')

    # Goodreads data
    final_data.update(goodreads_data) # This will overwrite if keys are same

    # 3. Check if we found any data at all
    if not final_data['title']:
        print(f"  -> WARNING: Could not find any significant data for ISBN {isbn}.")
        return {}

    # 4. Download Image
    if final_data['cover_url']:
        final_data['image_path'] = await download_cover_image(final_data['cover_url'], isbn, download_dir)
        
    # Convert lists to comma-separated strings for CSV
    final_data['authors'] = ', '.join(final_data['authors'])
    final_data['categories'] = ', '.join(final_data['categories'])

    return final_data


async def generate_dataset(isbn_list: List[str], download_dir: str, output_file: str):
    """
    Main function to process a list of ISBNs, fetch data, and save to a CSV.
    """
    all_books_data = []
    os.makedirs(download_dir, exist_ok=True)
    
    print(f"Starting data pipeline to fetch {len(isbn_list)} ISBNs...")
    for i, isbn in enumerate(isbn_list):
        print(f"\n[{i+1}/{len(isbn_list)}] Processing ISBN: {isbn}")
        
        book_record = await get_complete_book_data(isbn, download_dir)
        
        if book_record:
            all_books_data.append(book_record)
        
        # Rate Limiting: Essential to avoid getting blocked by public APIs
        # Combined sleep for external API politeness. Individual API calls have their own sleeps.
        await asyncio.sleep(1.0) # Wait 1 second between processing each ISBN

    df = pd.DataFrame(all_books_data)
    df.to_csv(output_file, index=False)
    
    print("\n" + "="*40)
    print("  DATA PIPELINE COMPLETE")
    print("="*40)
    print(f"Total unique books processed: {len(df)}")
    print(f"Dataset saved to {output_file}")
    print(f"Cover images saved to {download_dir}/")


if __name__ == "__main__":
    # --- Configuration ---
    DOWNLOAD_DIR = '/Users/tannu/Capstone Projects/ShelfScanner/data/book_covers'
    OUTPUT_FILE = '/Users/tannu/Capstone Projects/ShelfScanner/data/master_book_dataset.csv'

    # Load the ISBNs from the CSV file
    isbn_source_df = pd.read_csv('/Users/tannu/Capstone Projects/ShelfScanner/data/isbn_list.csv', dtype=str)
    SOURCE_ISBNS = isbn_source_df['ISBN'].tolist()
    
    # Run the dataset generation
    asyncio.run(generate_dataset(SOURCE_ISBNS, DOWNLOAD_DIR, OUTPUT_FILE))