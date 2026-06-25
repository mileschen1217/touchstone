"""
Doc Reckoning structural/contract test — parses a static closed-with-reckoning
index .md fixture.

DOES NOT drive or invoke cli.py — the adapter has been removed. These are
structural checks: assert the same fields are well-formed / extractable in the
fixture. The ## Doc Reckoning section assertion is NEW coverage (the old
stage7 test never checked for its presence).

Renamed from test_stage7.py (stage7-fixtures/) — see REQ-6 / AC-9.
"""
import re
from pathlib import Path

FIXTURE = Path(__file__).parent / "closed_with_reckoning.md"


def _read_fixture() -> str:
    return FIXTURE.read_text()


def _frontmatter(text: str) -> dict[str, str]:
    """Extract key→value pairs from the YAML frontmatter block."""
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    assert m, "No frontmatter found in fixture"
    result = {}
    for line in m.group(1).splitlines():
        kv = re.match(r"^(\w+):\s*(.*)$", line)
        if kv:
            result[kv.group(1)] = kv.group(2).strip()
    return result


def _parse_phases_table(text: str) -> list[dict[str, str]]:
    """
    Locate the ## Phases section, find the header row, and extract rows as
    dicts keyed by column header (lower-cased). Header-driven: column
    order/count independent.
    """
    m = re.search(r"^## Phases\s*\n(.*?)(?=^##|\Z)", text,
                  re.MULTILINE | re.DOTALL)
    assert m, "No ## Phases section found in fixture"
    lines = [l.strip() for l in m.group(1).splitlines() if l.strip().startswith("|")]
    assert len(lines) >= 2, "Phases table needs a header row and at least one data row"

    # Parse header — line[0]; line[1] is the separator row
    headers = [h.strip().lower() for h in lines[0].split("|") if h.strip()]
    rows = []
    for line in lines[2:]:
        # split on "|"; drop the empty leading/trailing elements from pipe borders
        cells = [c.strip() for c in line.split("|")]
        if cells and cells[0] == "":
            cells = cells[1:]
        if cells and cells[-1] == "":
            cells = cells[:-1]
        if not cells:
            continue
        rows.append(dict(zip(headers, cells)))
    return rows


def test_every_phase_row_has_landed_value():
    """Every phase row in the closed-with-reckoning fixture has a non-empty Landed value."""
    text = _read_fixture()
    rows = _parse_phases_table(text)
    assert rows, "Expected at least one phase row"
    for row in rows:
        landed = row.get("landed", "").strip()
        assert landed and landed != "—", (
            f"Phase row missing landed value: {row}"
        )


def test_closed_with_reckoning_status_is_done():
    """Epic frontmatter status == done in the closed fixture."""
    text = _read_fixture()
    fm = _frontmatter(text)
    assert fm.get("status") == "done", (
        f"Expected status=done, got {fm.get('status')!r}"
    )


def test_closed_with_reckoning_landed_is_stamped():
    """Epic frontmatter landed is a YYYY-MM-DD date in the closed fixture."""
    text = _read_fixture()
    fm = _frontmatter(text)
    landed = fm.get("landed", "")
    assert re.match(r"^\d{4}-\d{2}-\d{2}$", landed), (
        f"Expected YYYY-MM-DD landed, got {landed!r}"
    )


def test_doc_reckoning_section_present():
    """A closed-with-reckoning fixture contains a ## Doc Reckoning section.

    This is NEW coverage absent from the old stage7 test.
    """
    text = _read_fixture()
    assert re.search(r"^## Doc Reckoning", text, re.MULTILINE), (
        "Expected a ## Doc Reckoning section in the closed-with-reckoning fixture"
    )
