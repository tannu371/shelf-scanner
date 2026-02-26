"""
ShelfScanner — Text Reconstruction / BookParser
Heuristically extracts title + author from raw OCR data,
then does fuzzy-search against a candidate list.

The script-level execution block has been removed so this
module is safely importable from the FastAPI application.
"""
import logging
from rapidfuzz import process, fuzz

logger = logging.getLogger(__name__)


class BookParser:
    """
    Converts raw PaddleOCR output into a structured
    { title_guess, author_guess, combined_query } dict.
    """

    def __init__(self, confidence_threshold: float = 0.6, min_text_length: int = 3):
        self.conf_thresh = confidence_threshold
        self.min_len = min_text_length

    def parse_spine(self, ocr_data: dict) -> dict:
        """
        ocr_data must contain:
            rec_texts:  list[str]
            rec_boxes:  list[[x1,y1,x2,y2]]
            rec_scores: list[float]
        """
        raw_items = []
        for text, box, score in zip(
            ocr_data.get("rec_texts", []),
            ocr_data.get("rec_boxes", []),
            ocr_data.get("rec_scores", []),
        ):
            height = box[3] - box[1]
            mid_y = (box[1] + box[3]) / 2
            if score >= self.conf_thresh and len(text) >= self.min_len:
                raw_items.append(
                    {"text": text, "height": height, "score": score, "mid_y": mid_y}
                )

        # Sort top-to-bottom
        raw_items.sort(key=lambda x: x["mid_y"])

        # Title heuristic: largest font
        sorted_by_size = sorted(raw_items, key=lambda x: x["height"], reverse=True)
        title_candidate = sorted_by_size[0]["text"] if sorted_by_size else ""

        # Author heuristic: next-largest, no pure digits
        author_candidate = ""
        for item in sorted_by_size[1:]:
            if not any(c.isdigit() for c in item["text"]):
                author_candidate = item["text"]
                break

        combined_text = " ".join(item["text"] for item in raw_items)

        return {
            "title_guess": title_candidate,
            "author_guess": author_candidate,
            "combined_query": combined_text,
        }

    def fuzzy_match(
        self,
        query: str,
        candidates: list[str],
        limit: int = 5,
        score_cutoff: float = 40.0,
    ) -> list[tuple[str, float]]:
        """
        Return up to `limit` (match, score) tuples from `candidates`
        using partial token set ratio — best scorer for messy OCR text.
        """
        results = process.extract(
            query,
            candidates,
            scorer=fuzz.partial_token_set_ratio,
            limit=limit,
            score_cutoff=score_cutoff,
        )
        return [(match, score) for match, score, _ in results]