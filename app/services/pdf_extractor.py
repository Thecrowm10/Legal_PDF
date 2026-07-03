import io
import os
from typing import Generator

import pymupdf as fitz
import pytesseract
from PIL import Image

from app.core.config import settings

if settings.TESSERACT_CMD:
    pytesseract.pytesseract.tesseract_cmd = settings.TESSERACT_CMD


def extract_pages(file_path: str) -> Generator[tuple[int, str], None, None]:
    ext = os.path.splitext(file_path)[1].lower()
    if ext == ".docx":
        yield from _extract_docx(file_path)
    else:
        yield from _extract_pdf(file_path)


def _extract_pdf(file_path: str) -> Generator[tuple[int, str], None, None]:
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


def _extract_docx(file_path: str) -> Generator[tuple[int, str], None, None]:
    import docx  # imported lazily — python-docx is optional for PDF-only deployments
    doc = docx.Document(file_path)
    text = "\n".join(p.text for p in doc.paragraphs if p.text.strip())
    if text:
        yield 1, text
