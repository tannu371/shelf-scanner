"""
ShelfScanner — Text Recognition Service (PaddleOCR)
Refactored to accept raw image bytes (API-friendly).
Previously: only worked as a script with file paths.
"""
import io
import logging
import numpy as np
from PIL import Image
from paddleocr import PaddleOCR

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# OCR engine — loaded once as module-level singleton
# ---------------------------------------------------------------------------
_ocr: PaddleOCR | None = None


def get_ocr() -> PaddleOCR:
    global _ocr
    if _ocr is None:
        logger.info("Initialising PaddleOCR engine …")
        _ocr = PaddleOCR(
            use_doc_orientation_classify=True,
            use_doc_unwarping=True,
            use_textline_orientation=True,
            lang="en",
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

    # Convert bytes → numpy array (PaddleOCR v4 accepts ndarray)
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    img_np = np.array(img)

    results = ocr.predict(img_np)

    rec_texts, rec_boxes, rec_scores = [], [], []
    for res in results:
        for text, box, score in zip(
            res.get("rec_texts", []),
            res.get("rec_boxes", []),
            res.get("rec_scores", []),
        ):
            rec_texts.append(text)
            rec_boxes.append(box)
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
