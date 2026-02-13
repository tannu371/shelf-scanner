# ShelfScanner/app/data_pipeline/api_clients.py
import os
import time
import asyncio
import httpx # Using httpx for async compatibility if we later combine with FastAPI
import requests
from typing import Optional, Dict, List, Any
import xml.etree.ElementTree as ET
import xmltodict # For easier XML parsing, install with: pip install xmltodict
from dotenv import load_dotenv

# Load environment variables (e.g., API keys)
load_dotenv()

# --- 1. API Configuration & Libraries ---
GOOGLE_BOOKS_URL = "https://www.googleapis.com/books/v1/volumes"
OPEN_LIBRARY_URL = "https://openlibrary.org/api/books"
GOODREADS_URL = "https://www.goodreads.com/book/review_counts.json"
WORLDCAT_URL = "https://classify.oclc.org/classify2/Classify"

# You can get API keys from environment variables
# GOOGLE_BOOKS_API_KEY = os.getenv("GOOGLE_BOOKS_API_KEY")

HEADERS = {'User-Agent': 'ShelfScanner-FYP-App (contact: tannukumari03072004@gmail.com)'}

# --- 2. Custom Data Fetching Functions ---

# Fetch data from Goodreads API
async def fetch_goodreads_data(isbn: str) -> dict:
    """
    Fetches rating and review counts from Goodreads using their unofficial JSON endpoint.
    Note: The official Goodreads API is deprecated. This endpoint may be unstable.
    """
    print(f"  -> Fetching data from Goodreads for {isbn}...")
    params = {'isbns': isbn}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(GOODREADS_URL, params=params, headers=HEADERS)
            response.raise_for_status()
            data = response.json()
            
            if data.get('books') and len(data['books']) > 0:
                book_data = data['books'][0]
                print("  -> Successfully fetched data from Goodreads.")
                return {
                    'goodreads_rating': float(book_data.get('average_rating', 0.0)),
                    'goodreads_rating_count': int(book_data.get('work_ratings_count', 0))
                }
                
    except httpx.RequestError as e:
        print(f"  -> Goodreads API network error for {isbn}: {e}")
    except httpx.HTTPStatusError as e:
        print(f"  -> Goodreads API HTTP error for {isbn}: {e.response.status_code} - {e.response.text}")
    except Exception as e: # Catch all other potential errors (e.g., JSON parsing)
        print(f"  -> Goodreads API unexpected error for {isbn}: {e}")
    
    print("  -> Could not fetch data from Goodreads.")
    return {'goodreads_rating': None, 'goodreads_rating_count': None}

# Fetch data from Open Library API
async def fetch_open_library_data(isbn: str) -> Dict[str, Any]:
    """Fetches book data from the Open Library API."""
    print(f"  -> Fetching data from Open Library for {isbn}...")

    # Initialize all possible return fields to prevent UnboundLocalError
    title = ''
    authors = []
    publishers = []
    publishDate = ''
    subjects = []
    cover_links = {}
    pageCount = None
    description = ''
    avg_rating = None
    rating_count = None
    
    async with httpx.AsyncClient(timeout=10) as client:
        try:
            # --- 1. FETCH BOOK DATA ---
            params = {'bibkeys': f'ISBN:{isbn}', 'format': 'json', 'jscmd': 'data'}
            response = await client.get(OPEN_LIBRARY_URL, params=params, headers=HEADERS)
            response.raise_for_status()
            data = response.json()
            
            book_key = f'ISBN:{isbn}'
            if not data or book_key not in data:
                print(f"  -> No data found on Open Library for {isbn} (main data).")
                # Return defaults
                return {'title': title, 'authors': authors, 'publishers': publishers, 
                        'publishDate': publishDate, 'description': description, 
                        'ol_average_rating': avg_rating, 'ol_rating_count': rating_count, 
                        'pageCount': pageCount, 'categories': subjects, 'coverURL': ''}
            
            book_data = data[book_key]
            
            # --- 2. EXTRACT BOOK DATA ---
            title = book_data.get('title', '')
            authors = [author['name'] for author in book_data.get('authors', [])]
            publishers = [publisher['name'] for publisher in book_data.get('publishers', [])]
            publishDate = book_data.get('publish_date', '')
            subjects = [subject['name'] for subject in book_data.get('subjects', [])]
            cover_links = book_data.get('cover', {})
            
            await asyncio.sleep(0.5) # Be polite

            # --- 3. FETCH EDITION DATA ---
            edition_url = f"https://openlibrary.org/isbn/{isbn}.json"
            response = await client.get(edition_url)
            response.raise_for_status()
            edition_data = response.json()
            
            # -- 4. EXTRACT PAGECOUNT FROM EDITION DATA --  
            pageCount = edition_data.get('number_of_pages', None)

            works_list = edition_data.get('works', [])
            if not works_list:
                print(f"  -> Open Library: Edition {isbn} not linked to a Work (no description/ratings).")
            else:
                work_key = works_list[0]['key']
                
                await asyncio.sleep(0.5) # Be polite

                # --- 5. FETCH WORK DATA FOR DESCRIPTION ---
                work_url = f"https://openlibrary.org{work_key}.json"
                work_response = await client.get(work_url)
                work_response.raise_for_status()
                work_data = work_response.json()
                
                # --- 6. EXTRACT DESCRIPTION FROM WORK DATA ---
                description = work_data.get('description', '')
                
                await asyncio.sleep(0.5) # Be polite
                
                # --  7. FETCH RATING DATA --- 
                ratings_url = f"https://openlibrary.org{work_key}/ratings.json"
                ratings_response = await client.get(ratings_url)
                ratings_response.raise_for_status()
                ratings_data = ratings_response.json()
                
                # --- 8. EXTRACT RATING DATA --
                ratings_info = ratings_data.get('summary', {})
                avg_rating_raw = ratings_info.get('average')
                rating_count = ratings_info.get('count')
                
                if avg_rating_raw:
                    avg_rating = round(avg_rating_raw, 2)
            
            print(f"  -> Successfully fetched data from Open Library for {isbn}.")
            return {
                'title': title,
                'authors': authors,
                'publishers': publishers,
                'publishDate': publishDate,
                'description': description if isinstance(description, str) else description.get('value', ''),
                'ol_average_rating': avg_rating,
                'ol_rating_count': rating_count,
                'pageCount': pageCount,
                'categories': subjects,
                'coverURL': cover_links.get('large') or cover_links.get('medium') or cover_links.get('small')
            }

        except httpx.RequestError as e:
            print(f"  -> Open Library API network error for {isbn}: {e}")
        except httpx.HTTPStatusError as e:
            print(f"  -> Open Library API HTTP error for {isbn}: {e.response.status_code} - {e.response.text}")
        except Exception as e:
            print(f"  -> Open Library API unexpected error for {isbn}: {e}")
        
        # Return defaults on any error
        return {'title': title, 'authors': authors, 'publishers': publishers, 
                'publishDate': publishDate, 'description': description, 
                'ol_average_rating': avg_rating, 'ol_rating_count': rating_count, 
                'pageCount': pageCount, 'categories': subjects, 'coverURL': ''}

# Fetch data from Google Books API
async def fetch_google_books_data(isbn: str) -> Dict[str, Any]:
    """
    Fetches detailed data (like description and categories) from Google Books API.
    """
    print(f"  -> Fetching data from Google Books for {isbn}...")
    params = {'q': f'isbn:{isbn}', 'maxResults': 1}
    # if GOOGLE_BOOKS_API_KEY: # Add API key if needed
    #     params['key'] = GOOGLE_BOOKS_API_KEY 
        
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(GOOGLE_BOOKS_URL, params=params, headers=HEADERS)
            response.raise_for_status()
            data = response.json()
            
            if data.get('totalItems', 0) > 0:
                volume_info = data['items'][0]['volumeInfo']
                cover_links = volume_info.get('imageLinks', {})
                print("  -> Successfully fetched data from Google Books.")
                return {
                    'title': volume_info.get('title', ''),
                    'authors': volume_info.get('authors', []),
                    'publisher': volume_info.get('publisher', ''),
                    'publishedDate': volume_info.get('publishedDate', ''),
                    'description': volume_info.get('description', ''),
                    'pageCount': volume_info.get('pageCount', None),
                    'categories': volume_info.get('categories', []),
                    'coverURL': cover_links.get('extraLarge') or cover_links.get('large') or cover_links.get('thumbnail')
                }
                
    except httpx.RequestError as e:
        print(f"  -> Google Books API network error for {isbn}: {e}")
    except httpx.HTTPStatusError as e:
        print(f"  -> Google Books API HTTP error for {isbn}: {e.response.status_code} - {e.response.text}")
    except Exception as e:
        print(f"  -> Google Books API unexpected error for {isbn}: {e}")
        
    print("  -> Could not fetch data from Google Books.")
    return {}

# Fetch data from WorldCat Classify API
HEADERS = {
    "User-Agent": "BookMetadataFetcher/1.0",
    "Accept": "text/xml"
}

async def fetch_worldcat_data(isbn: str) -> Dict[str, Any]:
    """Fetch book data from WorldCat Classify API (robust version)."""
    print(f"  -> Fetching data from WorldCat for {isbn}...")

    params = {
        "isbn": isbn,
        "summary": "true"
    }

    try:
        async with httpx.AsyncClient(
            timeout=10,
            follow_redirects=True,   # 🔑 FIX #1
            headers=HEADERS
        ) as client:

            response = await client.get(WORLDCAT_URL, params=params)
            response.raise_for_status()

            content_type = response.headers.get("Content-Type", "")
            if "xml" not in content_type.lower():
                print(f"  -> WorldCat returned non-XML response for {isbn}.")
                return {}

            xml_dict = xmltodict.parse(response.text)

            classify_response = xml_dict.get("classify:response")
            if not classify_response:
                print(f"  -> Invalid WorldCat XML structure for {isbn}.")
                return {}

            # Code meanings:
            # 0 = not found
            # 2 = single work
            if classify_response.get("@code") != "2":
                return {}

            work = classify_response.get("classify:work")
            if not work:
                return {}

            authors_raw = work.get("@author", "")
            authors = (
                [a.strip() for a in authors_raw.split("|") if a.strip()]
                if isinstance(authors_raw, str)
                else []
            )

            print(f"  -> Successfully fetched data from WorldCat.")

            return {
                "title": work.get("@title", ""),
                "authors": authors,
                "year": work.get("@sy"),   # start year
            }

    except httpx.HTTPStatusError as e:
        print(
            f"  -> WorldCat API HTTP error for {isbn}: "
            f"{e.response.status_code}"
        )
        return {}

    except httpx.RequestError as e:
        print(f"  -> WorldCat API network error for {isbn}: {e}")
        return {}

    except Exception as e:
        print(f"  -> WorldCat API parsing error for {isbn}: {e}")
        return {}


async def download_cover_image(url: str, isbn: str, download_dir: str) -> Optional[str]:
    """Downloads an image from a URL and saves it using the ISBN as the filename."""
    os.makedirs(download_dir, exist_ok=True) # Ensure directory exists
    image_path = os.path.join(download_dir, f"{isbn}.jpg")
    
    if os.path.exists(image_path):
        # print(f"  -> Image already exists for {isbn}.")
        return image_path
        
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            img_response = await client.get(url, headers=HEADERS)
            img_response.raise_for_status()
            with open(image_path, 'wb') as f:
                f.write(img_response.content)
            print(f"  -> Successfully downloaded image for {isbn}.")
            return image_path
            
    except httpx.RequestError as e:
        print(f"  -> Error downloading image from {url}: {e}")
        return None
    except httpx.HTTPStatusError as e:
        print(f"  -> HTTP error downloading image from {url}: {e.response.status_code} - {e.response.text}")
        return None
    except Exception as e:
        print(f"  -> Unexpected error downloading image from {url}: {e}")
        return None