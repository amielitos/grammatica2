"""
Image generation / placeholder service.

Handles creating images for lesson and quiz content blocks.
When the AI marks a content block as type "image", the `data` field contains
a descriptive prompt. This service either generates an image from that prompt
or produces a placeholder, then returns a URL the frontend can load.
"""

import os
import uuid
import textwrap
from PIL import Image, ImageDraw, ImageFont
from config import settings


def _ensure_dirs():
    """Ensure the static/images directory exists."""
    os.makedirs(settings.IMAGES_DIR, exist_ok=True)


def generate_placeholder_image(prompt: str, base_url: str) -> str:
    """
    Generate a styled placeholder image with the descriptive prompt text
    rendered on it. Returns the public URL to the saved image.

    Args:
        prompt: The descriptive text from the AI (e.g., "Diagram of a plant cell").
        base_url: The base URL of the server for constructing the image URL.

    Returns:
        A full URL pointing to the generated placeholder image.
    """
    _ensure_dirs()

    filename = f"{uuid.uuid4().hex}.png"
    filepath = os.path.join(settings.IMAGES_DIR, filename)

    # Create a clean placeholder image
    width, height = 600, 300
    img = Image.new("RGB", (width, height), color=(45, 45, 58))
    draw = ImageDraw.Draw(img)

    # Try to use a decent font, fall back to default
    try:
        font_title = ImageFont.truetype("arial.ttf", 18)
        font_body = ImageFont.truetype("arial.ttf", 14)
    except (IOError, OSError):
        font_title = ImageFont.load_default()
        font_body = ImageFont.load_default()

    # Draw a border
    draw.rectangle([(10, 10), (width - 10, height - 10)], outline=(100, 100, 140), width=2)

    # Title
    draw.text((30, 25), "📷  Image Placeholder", fill=(180, 180, 220), font=font_title)

    # Wrap and draw the prompt text
    wrapped = textwrap.wrap(prompt, width=55)
    y_offset = 65
    for line in wrapped[:6]:  # Limit to 6 lines
        draw.text((30, y_offset), line, fill=(200, 200, 200), font=font_body)
        y_offset += 22

    # Hint at bottom
    draw.text(
        (30, height - 40),
        "Teacher can replace this image.",
        fill=(120, 120, 150),
        font=font_body,
    )

    img.save(filepath, "PNG")
    return f"{base_url}/static/images/{filename}"


def save_generated_image(image_bytes: bytes, base_url: str) -> str:
    """
    Save raw image bytes (e.g., from a generation API) to disk and return the URL.

    Args:
        image_bytes: Raw PNG/JPEG bytes.
        base_url: The base URL of the server.

    Returns:
        A full URL pointing to the saved image.
    """
    _ensure_dirs()

    filename = f"{uuid.uuid4().hex}.png"
    filepath = os.path.join(settings.IMAGES_DIR, filename)

    with open(filepath, "wb") as f:
        f.write(image_bytes)

    return f"{base_url}/static/images/{filename}"
