import os
import shutil
from fastapi import APIRouter, File, UploadFile, HTTPException
from markitdown import MarkItDown
import fitz  # PyMuPDF

router = APIRouter(tags=["Convert"])
markitdown = MarkItDown()

@router.post("/convert/markdown")
async def convert_to_markdown(file: UploadFile = File(...)):
    """
    Receives a PDF file and converts it into Markdown using MarkItDown.
    Includes a fallback to PyMuPDF if direct conversion fails.
    """
    if not file.filename or not file.filename.lower().endswith(".pdf"):
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

            # Now use MarkItDown to convert this text to Markdown
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
