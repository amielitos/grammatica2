"""
Quiz generation API route.

POST /api/v1/generate-quiz
  - Accepts lesson text (or raw text) as JSON body.
  - Sends it to Gemini, validates the output,
    generates placeholder images for any image-type content blocks,
    and returns the structured quiz JSON.
"""

import os
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel, Field
from middleware.auth import verify_api_key
from services.gemini_service import generate_quiz
from services.image_service import generate_placeholder_image

router = APIRouter(prefix="/api/v1", tags=["Quiz"])


class QuizGenerationRequest(BaseModel):
    """Request body for quiz generation."""
    lessonText: str = Field(..., min_length=50, description="The lesson text to generate questions from.")
    numQuestions: int = Field(default=10, ge=1, le=30, description="Number of questions to generate.")


@router.post("/generate-quiz", dependencies=[Depends(verify_api_key)])
async def generate_quiz_endpoint(request: Request, body: QuizGenerationRequest):
    """
    Generate quiz questions from lesson content.

    The response JSON follows the QuizResponse schema with diverse
    question types and mixed content blocks.
    """
    try:
        quiz_data = await generate_quiz(body.lessonText, body.numQuestions)
    except ValueError as e:
        raise HTTPException(
            status_code=502,
            detail=f"AI generated an invalid response. Please try again. Error: {str(e)}",
        )

    # Process image content blocks in questions
    base_url = str(request.base_url).rstrip("/")
    for question in quiz_data.get("questions", []):
        for block in question.get("content", []):
            if block.get("type") == "image" and isinstance(block.get("data"), str):
                prompt = block["data"]
                image_url = generate_placeholder_image(prompt, base_url)
                block["data"] = image_url

    return quiz_data
