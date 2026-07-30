"""
Pydantic models defining the JSON schemas for Lesson and Quiz outputs.

These schemas serve a dual purpose:
1. They are used by the Gemini API's `response_schema` to constrain the LLM output.
2. They are used by the backend to validate the LLM's response before sending it to the frontend.
"""

from __future__ import annotations
from pydantic import BaseModel, field_validator
from typing import List, Union, Any
from enum import Enum


# ---------------------------------------------------------------------------
# Content Block Types
# ---------------------------------------------------------------------------

class ContentType(str, Enum):
    """The type of a content block inside a lesson or question."""
    TEXT = "text"
    IMAGE = "image"
    TABLE = "table"
    LIST = "list"


class ContentBlock(BaseModel):
    """
    A single content block. The `type` field tells the frontend how to render
    the `data` field.

    - text:  data is a string
    - image: data is a string (URL or image prompt for generation)
    - list:  data is a list of strings
    - table: data is a list of dicts, where each dict is a row and keys are column headers
    """
    type: ContentType
    data: Any  # Validated below based on `type`

    @field_validator("data")
    @classmethod
    def validate_data_matches_type(cls, v, info):
        content_type = info.data.get("type")
        if content_type in (ContentType.TEXT, ContentType.IMAGE):
            if not isinstance(v, str):
                raise ValueError(f"For type '{content_type}', data must be a string.")
        elif content_type == ContentType.LIST:
            if not isinstance(v, list) or not all(isinstance(item, str) for item in v):
                raise ValueError("For type 'list', data must be a list of strings.")
        elif content_type == ContentType.TABLE:
            if not isinstance(v, list):
                raise ValueError("For type 'table', data must be a list of objects.")
            if len(v) > 0:
                if not all(isinstance(row, dict) for row in v):
                    raise ValueError("Each table row must be an object (dict).")
                # Ensure all rows have the same keys as the first row
                expected_keys = set(v[0].keys())
                for i, row in enumerate(v[1:], start=2):
                    if set(row.keys()) != expected_keys:
                        raise ValueError(
                            f"Table row {i} has keys {set(row.keys())} but expected {expected_keys}."
                        )
        return v


# ---------------------------------------------------------------------------
# Lesson Schema
# ---------------------------------------------------------------------------

class LessonResponse(BaseModel):
    """The full JSON response for a generated lesson."""
    title: str
    content: List[ContentBlock]


# ---------------------------------------------------------------------------
# Quiz Schema
# ---------------------------------------------------------------------------

class QuestionType(str, Enum):
    """Supported question types."""
    MULTIPLE_CHOICE = "multiple_choice"
    TRUE_FALSE = "true_false"
    SHORT_ANSWER = "short_answer"
    FILL_IN_THE_BLANK = "fill_in_the_blank"
    MATCHING = "matching"


class QuizQuestion(BaseModel):
    """A single quiz question with mixed content (text, images, etc.)."""
    questionType: QuestionType
    content: List[ContentBlock]
    options: List[str] = []
    correctAnswer: str

    @field_validator("options")
    @classmethod
    def validate_options_for_type(cls, v, info):
        q_type = info.data.get("questionType")
        if q_type == QuestionType.MULTIPLE_CHOICE and len(v) < 2:
            raise ValueError("Multiple choice questions must have at least 2 options.")
        if q_type == QuestionType.TRUE_FALSE:
            if sorted([o.lower() for o in v]) != ["false", "true"]:
                raise ValueError("True/false questions must have exactly 'True' and 'False' options.")
        return v


class QuizResponse(BaseModel):
    """The full JSON response for generated quiz questions."""
    questions: List[QuizQuestion]
