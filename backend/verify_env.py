
import importlib.util
import sys

packages = [
    "markitdown",
    "pdfminer",
    "fitz",  # PyMuPDF
    "bs4",   # BeautifulSoup
    "lxml",
    "python-multipart"
]

print(f"Python version: {sys.version}")
print("-" * 30)

for pkg in packages:
    spec = importlib.util.find_spec(pkg)
    if spec is not None:
        print(f"✅ {pkg}: INSTALLED")
    else:
        print(f"❌ {pkg}: MISSING")

print("-" * 30)
try:
    from markitdown import MarkItDown
    md = MarkItDown()
    print("MarkItDown initialized successfully.")
    print(f"Converters found: {len(md._converters)}")
    for converter in md._converters:
        print(f" - {type(converter).__name__}")
except Exception as e:
    print(f"Error initializing MarkItDown: {e}")
