"""
Gemini API integration service.

Handles all communication with the Google Gemini API, including structured
JSON output generation for lessons and quizzes.
"""

import json
from google import genai
from google.genai import types
from config import settings
from models.schemas import LessonResponse, QuizResponse


# ---------------------------------------------------------------------------
# Client Initialization
# ---------------------------------------------------------------------------

_client = None


def _get_client() -> genai.Client:
    """Lazy-initialize and return the Gemini client."""
    global _client
    if _client is None:
        if not settings.GEMINI_API_KEY:
            raise ValueError("GEMINI_API_KEY is not configured in settings or environment.")
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
You are Grammatica AI, an expert quiz creator. Your task is to generate an engaging, varied set \
of quiz questions based on the provided lesson content.

Question Variety Requirement:
Do NOT generate only multiple choice questionnaires. You MUST vary the questionnaire types across:
1. "multiple_choice": Standard 4-choice questions.
2. "fill_in_the_blank": Missing multiple words (2 to 3 words, not only one word, but not too many). Words that are missing must be enclosed in square brackets [word].
3. "pronunciation": The learner must pronounce the missing word instead of typing it. Enclose the target word to say in square brackets [word].

Rules:
1. The JSON must follow this exact structure:
   {
     "questions": [<array of question objects>]
   }
2. Each question object has:
   - "questionType": one of "multiple_choice", "fill_in_the_blank", "pronunciation"
   - "content": an array of content blocks (types: text, image, list, table). Use this to build the question body.
   - "options": array of 4 distinct strings for multiple_choice. Use empty array [] for fill_in_the_blank and pronunciation.
   - "correctAnswer": string matching the correct answer.
   - "blankAnswers": array of strings listing the missing words in order for fill_in_the_blank (e.g. ["sat", "mat"]). Use empty array [] for other types.
   - "targetWord": string containing the exact word the user must pronounce for pronunciation (e.g. "pronunciation"). Use null or empty string for other types.
3. For "fill_in_the_blank", formulate a sentence where 2 or 3 words are missing and placed in brackets like "The quick [brown] fox jumps over the [lazy] dog."
4. For "pronunciation", formulate a sentence where the target word is placed in brackets like "Please speak the missing word clearly: Good morning [teacher]."
5. For "multiple_choice", provide exactly 4 plausible options with 1 correct answer.
6. Distribute questions across multiple choice, fill in the blanks, and pronunciation.
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
