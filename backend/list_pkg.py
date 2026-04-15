
from markitdown import MarkItDown
import markitdown.converters

md = MarkItDown()
print(f"Checking {len(md._converters)} converters...")
found = False
for reg in md._converters:
    conv = reg.converter
    name = type(conv).__name__
    mod = type(conv).__module__
    if "Pdf" in name or "pdf" in name:
        print(f"✅ FOUND PDF CONVERTER: {mod}.{name}")
        found = True

if not found:
    print("❌ No PDF converter found in the active list.")
    # Let's list all to be sure
    for i, reg in enumerate(md._converters):
        print(f" {i}: {type(reg.converter).__name__}")
