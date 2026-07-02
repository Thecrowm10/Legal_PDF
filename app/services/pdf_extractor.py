import io
from typing import Generator

import pymupdf as fitz
import pytesseract
from PIL import Image

from app.core.config import settings

if settings.TESSERACT_CMD:
    pytesseract.pytesseract.tesseract_cmd = settings.TESSERACT_CMD


def extract_pages(file_path: str) -> Generator[tuple[int, str], None, None]:
    doc = fitz.open(file_path)
    try:
        for index in range(len(doc)):
            page = doc[index]
            text = page.get_text("text").strip()

            if not text:
                # Scanned/image-only page — render at 2× and OCR
                pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))
                img = Image.open(io.BytesIO(pix.tobytes("png")))
                text = pytesseract.image_to_string(img, lang=settings.TESSERACT_LANG).strip()

            if text:
                yield index + 1, text
    finally:
        doc.close()
