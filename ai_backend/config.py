import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    """Application settings loaded from environment variables."""

    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    API_SECRET_KEY: str = os.getenv("API_SECRET_KEY", "")
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8001"))

    # Gemini model to use
    GEMINI_MODEL: str = "gemini-2.5-flash"

    # Static files directory for generated/uploaded images
    STATIC_DIR: str = os.path.join(os.path.dirname(__file__), "static")
    IMAGES_DIR: str = os.path.join(STATIC_DIR, "images")

    def validate(self):
        """Validate that all required settings are present."""
        if not self.GEMINI_API_KEY:
            raise ValueError("GEMINI_API_KEY is not set in .env")
        if not self.API_SECRET_KEY:
            raise ValueError("API_SECRET_KEY is not set in .env")


settings = Settings()
