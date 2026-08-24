from pypdf import PdfReader
import json

# Read LinkedIn PDF
try:
    reader = PdfReader("./data/linkedin.pdf")
    linkedin = ""
    for page in reader.pages:
        text = page.extract_text()
        if text:
            linkedin += text
except FileNotFoundError:
    linkedin = "LinkedIn profile not available"

def _read_file_safe(file_path: str, default: str = "") -> str:
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return f.read()
    except (FileNotFoundError, IOError):
        return default


def _read_json_safe(file_path: str, default: dict = None) -> dict:
    if default is None:
        default = {}
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, IOError, json.JSONDecodeError):
        return default


summary = _read_file_safe("./data/summary.txt", "Professional AI Engineer.")
style = _read_file_safe("./data/style.txt", "Direct and technical.")
facts = _read_json_safe(
    "./data/facts.json",
    {"name": "Sami Rautanen", "full_name": "Sami Rautanen", "title": "AI Engineer"}
)