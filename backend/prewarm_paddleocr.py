"""
Pre-warms PaddleOCR by triggering model download at Docker build time.
Run once during `docker build` so the det/rec/cls model tar files are
already present when the container starts — eliminates the forked-worker
race condition entirely.
"""
import os
os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")

from paddleocr import PaddleOCR  # noqa: E402

print("Downloading PaddleOCR det/rec/cls models …")
PaddleOCR(use_angle_cls=False, lang="en", show_log=False)
print("PaddleOCR models ready.")
