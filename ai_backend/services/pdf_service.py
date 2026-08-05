"""
PDF text extraction service using PyMuPDF.
"""

import fitz  # PyMuPDF
from typing import Optional


async def extract_text_from_pdf(file_path: str) -> str:
    """
    Extract all text content from a PDF file.

    Args:
        file_path: Path to the PDF file on disk.

    Returns:
        The concatenated text of all pages.

    Raises:
        ValueError: If the PDF contains no extractable text.
    """
    doc = fitz.open(file_path)
    pages_text = []
    for page_num, page in enumerate(doc, start=1):
        text = page.get_text()
        if text.strip():
            pages_text.append(f"--- Page {page_num} ---\n{text}")
    doc.close()

    full_text = "\n\n".join(pages_text)

    if not full_text.strip():
        raise ValueError(
            "The PDF file contains no extractable text. "
            "It may be a scanned document or image-only PDF."
        )

    return full_text
