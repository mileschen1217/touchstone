"""
Close structural/contract test — parses a static closed index .md fixture.

DOES NOT drive or invoke cli.py — the adapter has been removed. These are
structural checks: assert the same fields are well-formed / extractable in
the fixture. The behavioural guarantee that close stamps these fields lives
in the AC-5 close-check that gates the agent, not in a procedure-driving test.
"""
import re
from pathlib import Path

FIXTURE = Path(__file__).parent / "closed_epic.md"


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


def test_closed_fixture_status_is_done():
    """A closed epic fixture parses with status == done."""
    text = _read_fixture()
    fm = _frontmatter(text)
    assert fm.get("status") == "done", (
        f"Expected status=done, got {fm.get('status')!r}"
    )


def test_closed_fixture_landed_is_stamped():
    """A closed epic fixture has a landed date in YYYY-MM-DD format."""
    text = _read_fixture()
    fm = _frontmatter(text)
    landed = fm.get("landed", "")
    assert re.match(r"^\d{4}-\d{2}-\d{2}$", landed), (
        f"Expected YYYY-MM-DD landed, got {landed!r}"
    )


def test_closed_fixture_retrospective_content_present():
    """A closed epic fixture has non-empty retrospective content."""
    text = _read_fixture()
    # Locate the ## Retrospective section and assert at least one non-blank
    # content line (beyond the header itself)
    m = re.search(r"^## Retrospective\s*\n(.*?)(?=^##|\Z)", text,
                  re.MULTILINE | re.DOTALL)
    assert m, "No ## Retrospective section found in fixture"
    content = m.group(1).strip()
    assert content, "## Retrospective section is empty — expected content in a closed epic"
