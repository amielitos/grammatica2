"""
Gemini API integration service.

Handles all communication with the Google Gemini API, including structured
JSON output generation for lessons and quizzes.
"""

import json
from google import genai
from google.genai import types
from config import settings
from models.schemas import LessonResponse, QuizResponse, ContentBlock


# ---------------------------------------------------------------------------
# Client Initialization
# ---------------------------------------------------------------------------

_client = None


def _get_client() -> genai.Client:
    """Lazy-initialize and return the Gemini client."""
    global _client
    if _client is None:
        _client = genai.Client(api_key=settings.GEMINI_API_KEY)
    return _client


# ---------------------------------------------------------------------------
# System Prompts
# ---------------------------------------------------------------------------

LESSON_SYSTEM_PROMPT = """\
You are Grammatica AI, an expert educational content creator. Your task is to \
read raw lesson text extracted from a PDF and produce a well-structured, \
summarized lesson in JSON format.

Rules:
1. The JSON must follow this exact structure:
   {
     "title": "<A clear, concise lesson title>",
     "content": [<array of content blocks>]
   }
2. Each content block has a "type" and a "data" field.
3. Supported types:
   - "text": data is a string containing a paragraph or explanation.
   - "list": data is an array of strings (key points, bullet items).
   - "table": data is an array of objects. Each object is a row. \
All objects MUST have the same keys, which serve as column headers.
   - "image": data is a descriptive prompt string describing an image, \
diagram, or illustration that would help the learner understand the concept. \
Be very specific about what the image should depict.
4. Use a variety of content types to make the lesson engaging.
5. Place images exactly where they would be most helpful in the lesson flow.
6. Summarize the content clearly — do not just copy-paste from the source.
7. Output ONLY the JSON object, nothing else.
"""

QUIZ_SYSTEM_PROMPT = """\
You are Grammatica AI, an expert quiz creator. Your task is to generate a set \
of quiz questions based on the provided lesson content.

Rules:
1. The JSON must follow this exact structure:
   {
     "questions": [<array of question objects>]
   }
2. Each question object has:
   - "questionType": one of "multiple_choice", "true_false", "short_answer", \
"fill_in_the_blank", "matching"
   - "content": an array of content blocks (same types as lessons: text, image, \
list, table). Use this to build the question body. You can include images \
(as descriptive prompt strings) when a visual diagram or illustration would \
enhance the question.
   - "options": array of strings (required for multiple_choice and true_false, \
empty for short_answer)
   - "correctAnswer": string with the correct answer
3. Generate a mix of question types.
4. For true_false questions, options MUST be exactly ["True", "False"].
5. For multiple_choice, provide 3-4 options.
6. Make questions that test comprehension, not just memorization.
7. Output ONLY the JSON object, nothing else.
"""


# ---------------------------------------------------------------------------
# Generation Functions
# ---------------------------------------------------------------------------

async def generate_lesson(raw_text: str) -> dict:
    """
    Send extracted PDF text to Gemini and get back a structured lesson JSON.

    Args:
        raw_text: The text extracted from the PDF.

    Returns:
        A validated dictionary matching the LessonResponse schema.

    Raises:
        ValueError: If the Gemini output fails validation.
    """
    client = _get_client()

    response = client.models.generate_content(
        model=settings.GEMINI_MODEL,
        contents=f"Generate a summarized lesson from the following content:\n\n{raw_text}",
        config=types.GenerateContentConfig(
            system_instruction=LESSON_SYSTEM_PROMPT,
            response_mime_type="application/json",
            temperature=0.7,
        ),
    )

    raw_json = response.text.strip()

    # Parse and validate against our Pydantic schema
    try:
        parsed = json.loads(raw_json)
    except json.JSONDecodeError as e:
        raise ValueError(f"Gemini returned invalid JSON: {e}\nRaw output: {raw_json[:500]}")

    # Validate with Pydantic — this will raise if the structure is wrong
    validated = LessonResponse.model_validate(parsed)
    return validated.model_dump()


async def generate_quiz(lesson_text: str, num_questions: int = 10) -> dict:
    """
    Send lesson content to Gemini and get back structured quiz questions.

    Args:
        lesson_text: The lesson text to generate questions from.
        num_questions: How many questions to generate.

    Returns:
        A validated dictionary matching the QuizResponse schema.

    Raises:
        ValueError: If the Gemini output fails validation.
    """
    client = _get_client()

    response = client.models.generate_content(
        model=settings.GEMINI_MODEL,
        contents=(
            f"Generate {num_questions} quiz questions based on the following lesson content. "
            f"Use a variety of question types.\n\n{lesson_text}"
        ),
        config=types.GenerateContentConfig(
            system_instruction=QUIZ_SYSTEM_PROMPT,
            response_mime_type="application/json",
            temperature=0.8,
        ),
    )

    raw_json = response.text.strip()

    try:
        parsed = json.loads(raw_json)
    except json.JSONDecodeError as e:
        raise ValueError(f"Gemini returned invalid JSON: {e}\nRaw output: {raw_json[:500]}")

    validated = QuizResponse.model_validate(parsed)
    return validated.model_dump()
