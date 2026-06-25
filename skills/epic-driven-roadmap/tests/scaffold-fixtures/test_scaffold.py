"""
Scaffold structural/contract test (AC-10) — asserts that:
1. The epic-index template carries required frontmatter keys and sections
   (so a scaffold that copies the template will carry them).
2. A representative scaffolded fixture carries the same required structure.

DOES NOT drive the scaffold procedure — no agent step can be invoked from
a test. These are structural/contract checks closing the coverage gap left
by deleting the adapter write tests.

Required frontmatter keys: slug, status, started
Required sections (## headings): Aim (via **Aim:** in body), Foundation, Phases
"""
import re
from pathlib import Path

TEMPLATE = (
    Path(__file__).resolve().parents[2] / "templates" / "epic-index.md"
)
SCAFFOLDED_FIXTURE = Path(__file__).parent / "scaffolded_epic.md"

REQUIRED_FM_KEYS = {"slug", "status", "started"}
REQUIRED_SECTIONS = {"Foundation", "Phases"}  # ## headings
REQUIRED_AIM_PATTERN = re.compile(r"^\*\*Aim:\*\*", re.MULTILINE)


def _read(path: Path) -> str:
    assert path.exists(), f"File not found: {path}"
    return path.read_text()


def _frontmatter_keys(text: str) -> set[str]:
    """Return the set of key names present in the YAML frontmatter block."""
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    assert m, f"No frontmatter block found"
    keys = set()
    for line in m.group(1).splitlines():
        kv = re.match(r"^(\w+)\s*:", line)
        if kv:
            keys.add(kv.group(1))
    return keys


def _section_headers(text: str) -> set[str]:
    """Return the set of ## section names present in the document."""
    return {m.group(1).strip() for m in re.finditer(r"^##\s+(.+)$", text, re.MULTILINE)}


# ---------------------------------------------------------------------------
# Template assertions
# ---------------------------------------------------------------------------

def test_template_has_required_frontmatter_keys():
    """The epic-index template carries all required frontmatter keys."""
    text = _read(TEMPLATE)
    keys = _frontmatter_keys(text)
    missing = REQUIRED_FM_KEYS - keys
    assert not missing, (
        f"Template missing required frontmatter keys: {missing!r}\n"
        f"Found: {keys!r}"
    )


def test_template_has_required_sections():
    """The epic-index template carries all required ## sections."""
    text = _read(TEMPLATE)
    sections = _section_headers(text)
    missing = REQUIRED_SECTIONS - sections
    assert not missing, (
        f"Template missing required sections: {missing!r}\n"
        f"Found: {sections!r}"
    )


def test_template_has_aim_field():
    """The epic-index template contains an **Aim:** field in the body."""
    text = _read(TEMPLATE)
    assert REQUIRED_AIM_PATTERN.search(text), (
        "Template missing **Aim:** field in body"
    )


# ---------------------------------------------------------------------------
# Representative scaffolded fixture assertions
# ---------------------------------------------------------------------------

def test_scaffolded_fixture_has_required_frontmatter_keys():
    """A representative scaffolded fixture carries all required frontmatter keys."""
    text = _read(SCAFFOLDED_FIXTURE)
    keys = _frontmatter_keys(text)
    missing = REQUIRED_FM_KEYS - keys
    assert not missing, (
        f"Scaffolded fixture missing required frontmatter keys: {missing!r}\n"
        f"Found: {keys!r}"
    )


def test_scaffolded_fixture_has_required_sections():
    """A representative scaffolded fixture carries all required ## sections."""
    text = _read(SCAFFOLDED_FIXTURE)
    sections = _section_headers(text)
    missing = REQUIRED_SECTIONS - sections
    assert not missing, (
        f"Scaffolded fixture missing required sections: {missing!r}\n"
        f"Found: {sections!r}"
    )


def test_scaffolded_fixture_has_aim_field():
    """A representative scaffolded fixture contains an **Aim:** field in the body."""
    text = _read(SCAFFOLDED_FIXTURE)
    assert REQUIRED_AIM_PATTERN.search(text), (
        "Scaffolded fixture missing **Aim:** field in body"
    )


def test_scaffolded_fixture_status_is_valid_enum():
    """A freshly-scaffolded fixture has a valid status enum value."""
    text = _read(SCAFFOLDED_FIXTURE)
    keys = {}
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    assert m, "No frontmatter block found"
    for line in m.group(1).splitlines():
        kv = re.match(r"^(\w+):\s*(.*)$", line)
        if kv:
            keys[kv.group(1)] = kv.group(2).strip()
    status = keys.get("status", "")
    valid_statuses = {"proposed", "active", "paused", "done", "cancelled"}
    assert status in valid_statuses, (
        f"Scaffolded fixture status {status!r} not in valid enum {valid_statuses!r}"
    )
