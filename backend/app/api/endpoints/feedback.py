"""
ShelfScanner — /log_feedback endpoint

POST /log_feedback
  Log a user action (confirm / like / skip) for HITL model retraining.
"""
import logging

from fastapi import APIRouter, HTTPException

from ..schemas import FeedbackRequest
from ...db.database import get_pool

logger = logging.getLogger(__name__)

router = APIRouter(prefix="", tags=["Feedback"])

VALID_ACTIONS = {"confirm", "like", "skip"}


@router.post("/log_feedback")
async def log_feedback(req: FeedbackRequest):
    """
    Log a user feedback action for Human-in-the-Loop (HITL) model retraining.

    Actions:
      - **confirm**: user confirms the book identification is correct
      - **like**: user saves / likes the book
      - **skip**: user dismisses the result (incorrect match)
    """
    if req.action not in VALID_ACTIONS:
        raise HTTPException(400, f"action must be one of: {', '.join(VALID_ACTIONS)}")

    pool = await get_pool()
    async with pool.connection() as conn:
        await conn.execute(
            """
            INSERT INTO feedback_log
                (user_id, isbn, action, ocr_raw_text, spine_image_b64)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (req.user_id, req.isbn, req.action,
             req.ocr_raw_text, req.spine_image_b64),
        )
    return {"status": "ok"}
