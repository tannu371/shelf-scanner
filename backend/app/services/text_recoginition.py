import os
import cv2
import numpy as np
from paddleocr import PaddleOCR

# Initialize OCR (angle classifier is KEY)
ocr = PaddleOCR(
    use_doc_orientation_classify=True,
    use_doc_unwarping=True,
    use_textline_orientation=True,
    lang='en',)

def extract_text(image_dir, output_dir) :
    for img_name in os.listdir(image_dir):
        if not img_name.lower().endswith(('.jpg', '.png', '.jpeg')):
            continue

        img_path = os.path.join(image_dir, img_name)
        results = ocr.predict(img_path)

        # Visualize the results and save the JSON results
        for res in results:
            res.print()
            res.save_to_img(output_dir)
            res.save_to_json(output_dir)
            

image_dir = "output/book_spines_cropped/WhatsApp Image 2026-01-07 at 11.16.24 PM"
output_dir = "output/ocr_results/WhatsApp Image 2026-01-07 at 11.16.24 PM"
extract_text(image_dir, output_dir)
