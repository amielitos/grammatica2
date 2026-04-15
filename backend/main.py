from fastapi import FastAPI, HTTPException, File, UploadFile
from pydantic import BaseModel
from typing import List
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn
import os
import shutil
import fitz  # PyMuPDF
from markitdown import MarkItDown

# Initialize MarkItDown
markitdown = MarkItDown()

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("🚀 Grammatica Backend starting up...")
    try:
        # In version 0.1.5, converters are wrapped in ConverterRegistration
        # and PdfConverter is in markitdown.converters._pdf_converter
        found_pdf = False
        for reg in markitdown._converters:
            conv = getattr(reg, "converter", None)
            if conv and "PdfConverter" in type(conv).__name__:
                found_pdf = True
                break
        
        if found_pdf:
            print("✅ PDF Support is ENABLED in MarkItDown.")
        else:
            print("❌ PDF Support is DISABLED in MarkItDown. Fallback is ready.")
    except Exception as e:
        print(f"⚠️ Could not verify PDF support: {e}")
    yield
    print("🛑 Grammatica Backend shutting down...")

app = FastAPI(title="Grammatica AI API", lifespan=lifespan)

# Enable CORS for Flutter development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For local dev, allow all. Change to specific app URL in production.
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request Models
class GenerationRequest(BaseModel):
    rawText: str

class QuizQuestion(BaseModel):
    question: str
    options: List[str]
    correctAnswer: str

SYSTEM_PROMPT = """You are Grammatica AI Teacher. Your job is to format raw text into clean English grammar lessons."""

@app.post("/generate/lesson")
async def generate_lesson(request: GenerationRequest):
    return {"markdown": f"# Lesson Generated (Local AI Removed)\n\nExtracted content: {request.rawText[:200]}..."}

@app.post("/generate/quiz")
async def generate_quiz(request: GenerationRequest) -> List[QuizQuestion]:
    # Placeholder for future quiz integration
    mock_questions = [
        QuizQuestion(
            question="Placeholder: How many parts of speech are there?",
            options=["5", "8", "10", "12"],
            correctAnswer="8"
        )
    ]
    return mock_questions

@app.post("/convert/markdown")
async def convert_to_markdown(file: UploadFile = File(...)):
    """
    Receives a PDF file and converts it into Markdown using MarkItDown.
    Includes a fallback to PyMuPDF if direct conversion fails.
    """
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")

    temp_path = f"temp_{file.filename}"
    try:
        # Save the uploaded file
        with open(temp_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        try:
            # Attempt direct conversion
            print(f"Attempting direct MarkItDown conversion for {file.filename}...")
            result = markitdown.convert(temp_path)
            markdown_output = result.text_content
            print("✅ Direct conversion successful.")
        except Exception as direct_error:
            print(f"⚠️ Direct conversion failed: {direct_error}")
            print("🔄 Falling back to PyMuPDF extraction...")
            
            # Fallback: Extract text using PyMuPDF
            doc = fitz.open(temp_path)
            full_text = ""
            for page in doc:
                full_text += page.get_text()
            doc.close()

            if not full_text.strip():
                raise Exception("PyMuPDF fallback extracted no text from the PDF.")

            # Now use MarkItDown to convert this text to Markdown (text conversion is more reliable)
            temp_text_path = "temp_fallback_text.txt"
            with open(temp_text_path, "w", encoding="utf-8") as f:
                f.write(full_text)
            
            try:
                result = markitdown.convert(temp_text_path)
                markdown_output = result.text_content
                print("✅ Fallback conversion successful.")
            finally:
                if os.path.exists(temp_text_path):
                    os.remove(temp_text_path)
        
        return {"markdown": markdown_output}
    except Exception as e:
        import traceback
        error_msg = traceback.format_exc()
        print(f"❌ Critical error during conversion:\n{error_msg}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Cleanup
        if os.path.exists(temp_path):
            os.remove(temp_path)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
