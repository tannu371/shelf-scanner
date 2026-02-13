import random
from ultralytics import YOLO
from PIL import Image
import cv2
import numpy as np
import os
from pathlib import Path

# Function to convert HEIC to an OpenCV-compatible format (like numpy array in BGR format)
def read_heic_as_opencv(heic_path):
    with Image.open(heic_path) as img:
        # Convert to RGB, then to a numpy array
        img_rgb = img.convert('RGB')
        img_np = np.array(img_rgb)
        # OpenCV uses BGR color order by default
        img_bgr = cv2.cvtColor(img_np, cv2.COLOR_RGB2BGR)
        return img_bgr

def crop_bounding_boxes(results , output_path, source_name):
    img = results[0].orig_img
    for r in results:
        # Bounding Box Crop
        for i, box in enumerate(r.boxes.xyxy):
            x1, y1, x2, y2 = map(int, box)
            crop = img[y1:y2, x1:x2]
            file_name = f'{source_name}_box_{i:04d}.png'
            file_path = os.path.join(output_path, file_name)
            cv2.imwrite(file_path, crop)

def order_points(pts):
    """
    Orders points as: top-left, top-right, bottom-right, bottom-left
    """
    rect = np.zeros((4, 2), dtype="float32")

    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]  # top-left
    rect[2] = pts[np.argmax(s)]  # bottom-right

    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]  # top-right
    rect[3] = pts[np.argmax(diff)]  # bottom-left

    return rect


def crop_from_obb(image, points):
    pts = np.array(points, dtype=np.float32)

    # 🔑 FIX: reorder points
    pts = order_points(pts)

    (tl, tr, br, bl) = pts

    # compute width
    widthA = np.linalg.norm(br - bl)
    widthB = np.linalg.norm(tr - tl)
    maxWidth = int(max(widthA, widthB))

    # compute height
    heightA = np.linalg.norm(tr - br)
    heightB = np.linalg.norm(tl - bl)
    maxHeight = int(max(heightA, heightB))

    dst = np.array([
        [0, 0],
        [maxWidth - 1, 0],
        [maxWidth - 1, maxHeight - 1],
        [0, maxHeight - 1]
    ], dtype="float32")

    M = cv2.getPerspectiveTransform(pts, dst)
    warped = cv2.warpPerspective(image, M, (maxWidth, maxHeight))

    return warped


def crop_from_bbox(results, output_path, source_name):
    img = results[0].orig_img

    for i, r in enumerate(results):
        if r.obb is None:
            continue

        for j, poly in enumerate(r.obb.xyxyxyxy.cpu().numpy()):
            crop = crop_from_obb(img, poly)

            file_name = f'{source_name}_box_{i}_{j}.png'
            cv2.imwrite(os.path.join(output_path, file_name), crop)

def predict_crop(
    model,
    image_dir,
    output_dir,
    conf=0.5,
):
    image_dir = Path(image_dir)
    output_dir = Path(output_dir)

    exts = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".heic"}
    selected_images = [p for p in image_dir.iterdir() if p.suffix.lower() in exts]
    assert selected_images, f"No images found in {image_dir}"
    # selected_images = 
    # random.shuffle(selected_images)
    # selected_images = selected_images[:10]

    for img_path in selected_images:
        results =  model(str(img_path), conf=conf, save=True)
        source_name = Path(img_path).stem
        output_path = os.path.join(output_dir, source_name)
        os.makedirs(output_path, exist_ok=True) 
        # crop_bounding_boxes(results, output_path, source_name)
        crop_from_bbox(results, output_path, source_name)
        print(f"✔ Processed {img_path.name}")
        
# 1. Load the models
detect_model = YOLO('runs/detect/book-train4/weights/best.pt') 
obb_model = YOLO('runs/obb/train/weights/best.pt')
word_model = YOLO('runs/detect/word-train2/weights/best.pt')

# 2. Define source and destination directories
book_source = 'input/books'
book_destination = 'output/book_spines_cropped'

predict_crop(obb_model, book_source, book_destination)

# results = word_model.predict('output/book_spines_cropped/IMG_0022/IMG_0022_box_0_4.png', conf=0.5, save=True)






