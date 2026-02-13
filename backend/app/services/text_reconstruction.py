import json
from rapidfuzz import process, fuzz

class BookParser:
    def __init__(self, confidence_threshold=0.6, min_text_length=3):
        self.conf_thresh = confidence_threshold
        self.min_len = min_text_length

    def parse_spine(self, ocr_data):
        raw_items = []
        for text, box, score in zip(ocr_data['rec_texts'], ocr_data['rec_boxes'], ocr_data['rec_scores']):
            # height is a strong indicator of Title vs. Author
            height = box[3] - box[1]
            # mid_y helps in sorting text from top to bottom
            mid_y = (box[1] + box[3]) / 2
            
            if score >= self.conf_thresh and len(text) >= self.min_len:
                raw_items.append({
                    "text": text,
                    "height": height,
                    "score": score,
                    "mid_y": mid_y
                })

        # Sort by position (Top to Bottom) to keep title/author sequence logical
        raw_items.sort(key=lambda x: x['mid_y'])
        
        # Heuristic: Title is usually the largest font size
        sorted_by_size = sorted(raw_items, key=lambda x: x['height'], reverse=True)
        
        title_candidate = sorted_by_size[0]['text'] if sorted_by_size else ""
        
        # Author candidate: Smaller text that isn't the title
        # We also filter common publisher noise or metadata numbers
        author_candidate = ""
        for item in sorted_by_size[1:]:
            # Simple check for numbers/special chars often found in ISBN/Catalog codes
            if any(char.isdigit() for char in item['text']):
                continue
            author_candidate = item['text']
            break

        # Combined text for the final 'Global Search'
        combined_text = " ".join([item['text'] for item in raw_items])
        
        return {
            "title_guess": title_candidate,
            "author_guess": author_candidate,
            "combined_query": combined_text
        }

# --- Execution ---

# Load local JSON
with open("ocr.json") as f:
    ocr_result = json.load(f)

parser = BookParser()
extracted = parser.parse_spine(ocr_result)

# Mock Database
book_titles_list = ["Handbook of Digital Imaging", "Clean Code", "Design Patterns"]
authors_list = ["Michael Kriss", "Robert C. Martin", "Erich Gamma"]

# Fuzzy Search using the combined query for higher accuracy
best_title = process.extractOne(
    extracted["combined_query"], 
    book_titles_list, 
    scorer=fuzz.partial_token_set_ratio # Best for messy OCR
)

best_author = process.extractOne(
    extracted["combined_query"], 
    authors_list, 
    scorer=fuzz.partial_token_set_ratio
)

print(f"Heuristic Title: {extracted['title_guess']}")
print(f"DB Match: {best_title[0]} ({round(best_title[1], 2)}% match) by {best_author[0]}")