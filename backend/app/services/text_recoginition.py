"""
ShelfScanner — Text Recognition Service (PaddleOCR)
Refactored to accept raw image bytes (API-friendly).
"""
import io
import logging
import threading

import numpy as np
from PIL import Image
from paddleocr import PaddleOCR

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# OCR engine — loaded once, protected by a lock so two uvicorn workers
# don't download the same model files simultaneously.
# ---------------------------------------------------------------------------
_ocr: PaddleOCR | None = None
_ocr_lock = threading.Lock()


def get_ocr() -> PaddleOCR:
    global _ocr
    if _ocr is None:
        with _ocr_lock:
            if _ocr is None:          # double-checked locking
                logger.info("Initialising PaddleOCR engine …")
                _ocr = PaddleOCR(
                    use_angle_cls=False,  # faster; angle classification not needed for spines
                    lang="en",
                    show_log=False,
                )
                logger.info("PaddleOCR ready.")
    return _ocr


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def extract_text_from_bytes(image_bytes: bytes) -> dict:
    """
    Run OCR on raw image bytes.
    Returns a dict compatible with BookParser.parse_spine():
        {
            "rec_texts":  list[str],
            "rec_boxes":  list[[x1,y1,x2,y2]],
            "rec_scores": list[float],
        }
    """
    ocr = get_ocr()

    # Convert bytes → numpy array
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    img_np = np.array(img)

    # PaddleOCR ≤ 2.x API: ocr.ocr(img) returns list-of-pages.
    # Each page: list of [polygon_box, (text, score)]
    raw = ocr.ocr(img_np, cls=False)

    rec_texts, rec_boxes, rec_scores = [], [], []

    if raw and raw[0]:          # raw[0] = first (only) page
        for line in raw[0]:
            if line is None:
                continue
            box, (text, score) = line
            # Flatten quad polygon → axis-aligned [x1,y1,x2,y2]
            xs = [p[0] for p in box]
            ys = [p[1] for p in box]
            rec_texts.append(text)
            rec_boxes.append([min(xs), min(ys), max(xs), max(ys)])
            rec_scores.append(float(score))

    return {
        "rec_texts": rec_texts,
        "rec_boxes": rec_boxes,
        "rec_scores": rec_scores,
    }


def extract_raw_text(image_bytes: bytes) -> str:
    """
    Convenience wrapper — returns a single joined string of all detected text.
    Useful for search queries.
    """
    ocr_data = extract_text_from_bytes(image_bytes)
    return " ".join(ocr_data["rec_texts"])
