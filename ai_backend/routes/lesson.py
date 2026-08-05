"""
Lesson generation API route.

POST /api/v1/extract-lesson
  - Accepts a PDF file via multipart/form-data.
  - Extracts text, sends it to Gemini, validates the output,
    generates placeholder images, and returns the structured JSON.
"""

import os
import shutil
import uuid
from fastapi import APIRouter, File, UploadFile, HTTPException, Depends, Request
from middleware.auth import verify_api_key
from services.pdf_service import extract_text_from_pdf
from services.gemini_service import generate_lesson
from services.image_service import generate_placeholder_image

router = APIRouter(prefix="/api/v1", tags=["Lesson"])


@router.post("/extract-lesson", dependencies=[Depends(verify_api_key)])
async def extract_lesson(request: Request, file: UploadFile = File(...)):
    """
    Upload a PDF and receive a structured, summarized lesson JSON.

    The response JSON follows the LessonResponse schema with content blocks
    of type: text, list, table, or image.
    """
    # Validate file type
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported.")

    # Save uploaded file temporarily
    temp_filename = f"temp_{uuid.uuid4().hex}.pdf"
    temp_path = os.path.join(os.path.dirname(__file__), "..", temp_filename)

    try:
        with open(temp_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Step 1: Extract text from PDF
        try:
            raw_text = await extract_text_from_pdf(temp_path)
        except ValueError as e:
            raise HTTPException(status_code=422, detail=str(e))

        # Step 2: Generate lesson via Gemini (with automatic validation)
        try:
            lesson_data = await generate_lesson(raw_text)
        except ValueError as e:
            raise HTTPException(
                status_code=502,
                detail=f"AI generated an invalid response. Please try again. Error: {str(e)}",
            )

        # Step 3: Process image content blocks — generate placeholder images
        base_url = str(request.base_url).rstrip("/")
        for block in lesson_data.get("content", []):
            if block.get("type") == "image" and isinstance(block.get("data"), str):
                # The AI put a descriptive prompt in data; turn it into a real image URL
                prompt = block["data"]
                image_url = generate_placeholder_image(prompt, base_url)
                block["data"] = image_url

        return lesson_data

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

from pydantic import BaseModel

class GenerateLessonRequest(BaseModel):
    rawText: str

@router.post("/generate-lesson", dependencies=[Depends(verify_api_key)])
async def generate_lesson_from_text(request_data: GenerateLessonRequest, request: Request):
    """
    Generate a lesson directly from raw text.
    """
    try:
        # Generate lesson via Gemini
        lesson_data = await generate_lesson(request_data.rawText)

        # Process image content blocks — generate placeholder images
        base_url = str(request.base_url).rstrip("/")
        for block in lesson_data.get("content", []):
            if block.get("type") == "image" and isinstance(block.get("data"), str):
                prompt = block["data"]
                image_url = generate_placeholder_image(prompt, base_url)
                block["data"] = image_url

        return lesson_data
    except ValueError as e:
        raise HTTPException(
            status_code=502,
            detail=f"AI generated an invalid response. Please try again. Error: {str(e)}",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
