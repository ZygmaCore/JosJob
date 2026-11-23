"""Rebuild deterministic, fictional CV fixtures from the seed manifest.

Requires reportlab and pypdf. These are development artifact tools, not app deps.
"""

from pathlib import Path
from html import escape
import json

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, HRFlowable
from pypdf import PdfReader, PdfWriter


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "apps/josjob_rag/priv/demo/cv_relevance.json"
FIXTURES = ROOT / "apps/josjob_web/priv/static/assets/demo-cvs"
OUTPUT = ROOT / "output/pdf"


def generate():
    FIXTURES.mkdir(parents=True, exist_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    ink, blue, muted = colors.HexColor("#192E4B"), colors.HexColor("#2855AE"), colors.HexColor("#53627A")
    styles = {
        "name": ParagraphStyle("name", fontName="Helvetica-Bold", fontSize=25, leading=31, textColor=ink, spaceAfter=6),
        "role": ParagraphStyle("role", fontName="Helvetica", fontSize=13, leading=19, textColor=blue, spaceAfter=5),
        "meta": ParagraphStyle("meta", fontName="Helvetica", fontSize=9, leading=14, textColor=muted),
        "section": ParagraphStyle("section", fontName="Helvetica-Bold", fontSize=10, leading=15, textColor=blue, spaceBefore=22, spaceAfter=8),
        "body": ParagraphStyle("body", fontName="Helvetica", fontSize=10.5, leading=17, textColor=ink, alignment=TA_LEFT),
        "title": ParagraphStyle("title", fontName="Helvetica-Bold", fontSize=11, leading=17, textColor=ink, spaceAfter=4),
    }
    pack = PdfWriter()
    for person in data["candidates"]:
        path = FIXTURES / (person["slug"] + ".pdf")
        document = SimpleDocTemplate(str(path), pagesize=A4, rightMargin=54, leftMargin=54,
                                     topMargin=52, bottomMargin=60, invariant=1,
                                     title=person["name"] + " - Fictional CV", author="JosJob Demo Fixtures")
        content = []

        def text(value, kind="body"):
            content.append(Paragraph(escape(value), styles[kind]))

        text("JOSJOB / FICTIONAL CV DEMO", "meta")
        content.append(Spacer(1, 18))
        text(person["name"], "name")
        text(person["headline"], "role")
        text(person["email"] + "  |  Bandung, Indonesia", "meta")
        content.append(Spacer(1, 17))
        content.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor("#DDE5F1")))
        text("PROFILE", "section")
        text(person["summary"])
        text("SKILLS", "section")
        text(" | ".join(person["skills"]))
        text("EXPERIENCE", "section")
        for entry in person["experience"]:
            text(entry["title"], "title")
            text(entry["company"] + "  |  " + entry["start_date"] + " - " + entry["end_date"], "meta")
            content.append(Spacer(1, 7))
            text(entry["description"])
        text("EDUCATION", "section")
        for entry in person["education"]:
            text(entry["degree"] + " in " + entry["field"], "title")
            text(entry["institution"] + "  |  " + entry["start_date"] + " - " + entry["end_date"], "meta")
        text("DEMO PURPOSE", "section")
        text("This CV contains synthetic facts for testing job relevance. It does not describe a real person or employment history.")

        def footer(canvas, _doc):
            canvas.setFont("Helvetica", 8)
            canvas.setFillColor(muted)
            canvas.drawString(54, 32, "Synthetic test data - no real candidate information")
            canvas.drawRightString(A4[0] - 54, 32, "JosJob CV relevance / " + person["slug"])

        document.build(content, onFirstPage=footer)
        reader = PdfReader(path)
        assert len(reader.pages) == 1, f"Unexpected overflow: {path.name}"
        extracted = " ".join(reader.pages[0].extract_text().split())
        for skill in person["skills"]:
            assert skill in extracted, f"Missing skill {skill} in {path.name}"
        assert person["email"] in extracted
        pack.add_page(reader.pages[0])
    pack.add_metadata({"/Title": "JosJob - Six Fictional CV Profiles", "/Author": "JosJob Demo Fixtures"})
    with (OUTPUT / "demo-cv-pack.pdf").open("wb") as stream:
        pack.write(stream)
    print(f"Generated and text-checked {len(data['candidates'])} one-page CV fixtures and the combined pack.")


if __name__ == "__main__":
    generate()
