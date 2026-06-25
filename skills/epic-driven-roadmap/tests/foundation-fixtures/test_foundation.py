"""
Foundation structural/contract test — parses a static index .md fixture and
asserts that aim, intention, and out-of-scope entries are extractable.

DOES NOT drive or invoke cli.py — the adapter has been removed. These are
structural checks asserting the same fields that the old CLI test extracted.
"""
import re
from pathlib import Path

FIXTURE = Path(__file__).parent / "foundation_epic.md"

# Expected values — must match foundation_epic.md exactly.
EXPECTED_AIM = "ship the adapter."
EXPECTED_INTENTION = "prove the contract."
EXPECTED_OOS = {"Obsidian backend.", "concurrency."}


def _read_fixture() -> str:
    return FIXTURE.read_text()


def _extract_aim(text: str) -> str:
    """Extract the Aim value from '**Aim:** <value>' in the body."""
    m = re.search(r"^\*\*Aim:\*\*\s*(.+)$", text, re.MULTILINE)
    assert m, "No **Aim:** line found in fixture"
    return m.group(1).strip()


def _extract_foundation_section(text: str) -> str:
    """Return the content of the ## Foundation section."""
    m = re.search(r"^## Foundation\s*\n(.*?)(?=^##|\Z)", text,
                  re.MULTILINE | re.DOTALL)
    assert m, "No ## Foundation section found in fixture"
    return m.group(1)


def _extract_intention(foundation_text: str) -> str:
    """Extract the Intention (why) value from the Foundation section."""
    m = re.search(r"\*\*Intention \(why\):\*\*\s*(.+)$", foundation_text, re.MULTILINE)
    assert m, "No Intention (why) line found in Foundation section"
    return m.group(1).strip()


def _extract_out_of_scope(foundation_text: str) -> set[str]:
    """Extract all Out of scope sub-bullet values from the Foundation section."""
    # The Out of scope block uses "- **Out of scope:**" followed by sub-bullets "  - <value>"
    oos_block_m = re.search(
        r"\*\*Out of scope:\*\*\s*\n((?:\s+-\s+.+\n?)*)",
        foundation_text,
    )
    assert oos_block_m, "No Out of scope block found in Foundation section"
    entries = re.findall(r"^\s+-\s+(.+)$", oos_block_m.group(1), re.MULTILINE)
    return {e.strip() for e in entries}


def test_aim_is_extractable():
    """The EXACT aim value is extractable from the fixture."""
    text = _read_fixture()
    aim = _extract_aim(text)
    assert aim == EXPECTED_AIM, f"Expected aim {EXPECTED_AIM!r}, got {aim!r}"


def test_intention_is_extractable():
    """The EXACT intention value is extractable from the Foundation section."""
    text = _read_fixture()
    foundation = _extract_foundation_section(text)
    intention = _extract_intention(foundation)
    assert intention == EXPECTED_INTENTION, (
        f"Expected intention {EXPECTED_INTENTION!r}, got {intention!r}"
    )


def test_both_out_of_scope_entries_are_extractable():
    """Both out-of-scope entries are extractable from the Foundation section."""
    text = _read_fixture()
    foundation = _extract_foundation_section(text)
    oos = _extract_out_of_scope(foundation)
    assert oos == EXPECTED_OOS, (
        f"Expected out-of-scope {EXPECTED_OOS!r}, got {oos!r}"
    )
