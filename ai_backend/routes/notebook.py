"""
NotebookLM synthesis and media transcription routes for Grammatica AI backend.
"""

import json
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, File, UploadFile
from pydantic import BaseModel
from google.genai import types

try:
    from middleware.auth import verify_api_key
    from config import settings
    from services.gemini_service import _get_client
except ImportError:
    from ai_backend.middleware.auth import verify_api_key
    from ai_backend.config import settings
    from ai_backend.services.gemini_service import _get_client

router = APIRouter(prefix="/api/v1", tags=["Notebook"])


def _extract_json_from_response(text: str) -> dict:
    """Strips markdown code fences if present and parses JSON."""
    cleaned = text.strip()
    if cleaned.startswith("```json"):
        cleaned = cleaned[7:]
    elif cleaned.startswith("```"):
        cleaned = cleaned[3:]
    if cleaned.endswith("```"):
        cleaned = cleaned[:-3]
    cleaned = cleaned.strip()
    return json.loads(cleaned)


# ---------------------------------------------------------------------------
# Request Models
# ---------------------------------------------------------------------------

class FlashcardRequest(BaseModel):
    sourceText: str
    count: int = 15
    difficulty: Optional[str] = None


class StudyGuideRequest(BaseModel):
    sourceText: str


class TimelineRequest(BaseModel):
    sourceText: str


class BriefingRequest(BaseModel):
    sourceText: str


class FAQRequest(BaseModel):
    sourceText: str
    count: int = 10


class MindMapRequest(BaseModel):
    sourceText: str


class PresentationRequest(BaseModel):
    sourceText: str
    customPrompt: Optional[str] = None
    slideCount: int = 6



# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/generate-flashcards", dependencies=[Depends(verify_api_key)])
async def generate_flashcards(body: FlashcardRequest):
    """Generate active recall flashcards from source material."""
    client = _get_client()
    system_prompt = (
        f"You are an expert educational AI specialized in active recall and spaced repetition learning.\n"
        f"Analyze the provided source material and generate approximately {body.count} high-yield flashcards.\n"
        f"{f'Target difficulty level: {body.difficulty}.' if body.difficulty else ''}\n"
        "Rules:\n"
        "1. Each card MUST test a single, atomic concept (front: question/term, back: concise definition/answer).\n"
        "2. Provide an optional subtle hint for challenging concepts.\n"
        "3. Categorize each card with 1-2 relevant tags.\n"
        "Return ONLY a valid JSON object strictly matching:\n"
        "{\n"
        '  "title": "Topic title",\n'
        '  "description": "Short description",\n'
        '  "cards": [\n'
        '    {"id": "card_1", "front": "...", "back": "...", "hint": "...", "tags": ["..."]}\n'
        "  ]\n"
        "}\n"
    )

    try:
        response = client.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=f"Generate flashcards for:\n\n{body.sourceText}",
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                response_mime_type="application/json",
                temperature=0.7,
            ),
        )
        return _extract_json_from_response(response.text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate flashcards: {str(e)}")


@router.post("/generate-study-guide", dependencies=[Depends(verify_api_key)])
async def generate_study_guide(body: StudyGuideRequest):
    """Generate a comprehensive study guide from source material."""
    client = _get_client()
    system_prompt = (
        "You are an elite academic tutor creating a comprehensive study guide from provided sources.\n"
        "Organize content into clear sections, identify key terminology, and distill essential takeaways.\n"
        "Return ONLY a valid JSON object matching:\n"
        "{\n"
        '  "title": "Study Guide Title",\n'
        '  "summary": "High-level overview",\n'
        '  "sections": [{"heading": "...", "content": "...", "bulletPoints": ["..."]}],\n'
        '  "keyTerms": [{"term": "...", "definition": "..."}],\n'
        '  "keyTakeaways": ["..."]\n'
        "}\n"
    )

    try:
        response = client.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=f"Generate study guide for:\n\n{body.sourceText}",
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                response_mime_type="application/json",
                temperature=0.6,
            ),
        )
        return _extract_json_from_response(response.text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate study guide: {str(e)}")


@router.post("/generate-timeline", dependencies=[Depends(verify_api_key)])
async def generate_timeline(body: TimelineRequest):
    """Extract chronological timeline events from source material."""
    client = _get_client()
    system_prompt = (
        "You are an expert historian extracting chronological milestones.\n"
        "Return ONLY a valid JSON object matching:\n"
        "{\n"
        '  "title": "Timeline Title",\n'
        '  "description": "Contextual overview",\n'
        '  "events": [\n'
        '    {"dateOrPeriod": "...", "title": "...", "description": "...", "category": "..."}\n'
        "  ]\n"
        "}\n"
    )

    try:
        response = client.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=f"Extract timeline for:\n\n{body.sourceText}",
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                response_mime_type="application/json",
                temperature=0.6,
            ),
        )
        return _extract_json_from_response(response.text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate timeline: {str(e)}")


@router.post("/generate-briefing", dependencies=[Depends(verify_api_key)])
async def generate_briefing(body: BriefingRequest):
    """Distill source material into an executive briefing."""
    client = _get_client()
    system_prompt = (
        "You are a senior executive briefing specialist.\n"
        "Return ONLY a valid JSON object matching:\n"
        "{\n"
        '  "title": "Executive Briefing: ...",\n'
        '  "executiveSummary": "...",\n'
        '  "keyPoints": ["..."],\n'
        '  "actionItems": [{"text": "...", "isDone": false, "priority": "high"}],\n'
        '  "conclusion": "..."\n'
        "}\n"
    )

    try:
        response = client.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=f"Generate briefing for:\n\n{body.sourceText}",
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                response_mime_type="application/json",
                temperature=0.6,
            ),
        )
        return _extract_json_from_response(response.text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate briefing: {str(e)}")


@router.post("/generate-faq", dependencies=[Depends(verify_api_key)])
async def generate_faq(body: FAQRequest):
    """Generate frequently asked questions from source material."""
    client = _get_client()
    system_prompt = (
        f"You are an educator anticipating student questions. Generate approximately {body.count} questions.\n"
        "Return ONLY a valid JSON object matching:\n"
        "{\n"
        '  "title": "FAQ Title",\n'
        '  "description": "FAQ Description",\n'
        '  "items": [\n'
        '    {"question": "...", "answer": "...", "category": "..."}\n'
        "  ]\n"
        "}\n"
    )

    try:
        response = client.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=f"Generate FAQ for:\n\n{body.sourceText}",
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                response_mime_type="application/json",
                temperature=0.7,
            ),
        )
        return _extract_json_from_response(response.text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate FAQ: {str(e)}")


@router.post("/generate-mind-map", dependencies=[Depends(verify_api_key)])
async def generate_mind_map(body: MindMapRequest):
    """Generate a conceptual graph / mind map from source material."""
    client = _get_client()
    system_prompt = (
        "You are a visual knowledge architect constructing a concept graph / mind map.\n"
        "Return ONLY a valid JSON object matching:\n"
        "{\n"
        '  "title": "Mind Map Title",\n'
        '  "centralTopic": "Core Topic",\n'
        '  "nodes": [\n'
        '    {"id": "node_0", "label": "...", "parentId": null, "category": "Core", "colorHex": "#10B981", "description": "..."}\n'
        "  ],\n"
        '  "edges": [\n'
        '    {"fromId": "node_0", "toId": "node_1", "label": "..."}\n'
        "  ]\n"
        "}\n"
    )

    try:
        response = client.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=f"Generate mind map for:\n\n{body.sourceText}",
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                response_mime_type="application/json",
                temperature=0.6,
            ),
        )
        return _extract_json_from_response(response.text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate mind map: {str(e)}")


@router.post("/generate-presentation", dependencies=[Depends(verify_api_key)])
async def generate_presentation(body: PresentationRequest):
    """Generate an instructional presentation slide deck from source material."""
    client = _get_client()
    system_prompt = (
        "You are an expert presentation designer and educator creating an instructional slide deck.\n"
        f"Synthesize the provided source documents into a slideshow of approximately {body.slideCount} slides.\n"
        f"{f'Special Instructions: {body.customPrompt}' if body.customPrompt else ''}\n"
        "Return ONLY a valid JSON object matching:\n"
        "{\n"
        '  "title": "Presentation Title",\n'
        '  "subtitle": "Subtitle or Overview",\n'
        '  "slides": [\n'
        '    {\n'
        '      "title": "Slide Title",\n'
        '      "subtitle": "Optional subtitle",\n'
        '      "bulletPoints": ["Key point 1", "Key point 2", "Key point 3"],\n'
        '      "speakerNotes": "Presenter talking points"\n'
        '    }\n'
        "  ]\n"
        "}\n"
    )

    try:
        response = client.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=f"Generate presentation for:\n\n{body.sourceText}",
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                response_mime_type="application/json",
                temperature=0.7,
            ),
        )
        return _extract_json_from_response(response.text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate presentation: {str(e)}")


@router.post("/transcribe", dependencies=[Depends(verify_api_key)])
async def transcribe_media(file: UploadFile = File(...)):
    """Transcribe audio/video uploaded file using Gemini multimodal capabilities."""
    client = _get_client()
    content = await file.read()
    mime_type = file.content_type or "audio/mp3"

    try:
        response = client.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=[
                types.Part.from_bytes(data=content, mime_type=mime_type),
                "Provide a clean, punctuated, and accurate transcription of this recording followed by key highlights.",
            ],
        )
        return {"transcription": response.text.strip()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to transcribe media: {str(e)}")
