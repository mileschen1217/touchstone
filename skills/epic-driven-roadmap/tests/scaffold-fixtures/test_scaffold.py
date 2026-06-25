"""
Scaffold structural/contract test — asserts that:
1. The epic-index template carries required frontmatter keys and sections
   (so a scaffold that copies the template will carry them).
2. A representative scaffolded fixture carries the same required structure,
   non-empty slug and started values, and at least one Phases table row.

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


# ---------------------------------------------------------------------------
# D1 — additional strength: non-empty field values + ≥1 Phases table row
# ---------------------------------------------------------------------------

def _frontmatter_values(text: str) -> dict[str, str]:
    """Return key→value mapping from the YAML frontmatter block."""
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    assert m, "No frontmatter block found"
    values = {}
    for line in m.group(1).splitlines():
        kv = re.match(r"^(\w+)\s*:\s*(.*)$", line)
        if kv:
            values[kv.group(1)] = kv.group(2).strip()
    return values


def _phases_data_rows(text: str) -> list[str]:
    """Return data rows from the Phases table (excludes header and separator)."""
    in_phases = False
    rows = []
    for line in text.splitlines():
        if re.match(r"^## Phases\s*$", line):
            in_phases = True
            continue
        if in_phases and re.match(r"^## ", line):
            break
        if in_phases and line.startswith("|"):
            # skip separator rows
            if re.match(r"^\|[-| :]+\|?$", line):
                continue
            rows.append(line)
    return rows[1:] if rows else []  # skip header row


def test_scaffolded_fixture_slug_is_nonempty():
    """The scaffolded fixture's slug frontmatter value is non-empty."""
    text = _read(SCAFFOLDED_FIXTURE)
    vals = _frontmatter_values(text)
    slug = vals.get("slug", "")
    assert slug, f"Expected non-empty slug, got: {slug!r}"


def test_scaffolded_fixture_started_is_nonempty():
    """The scaffolded fixture's started frontmatter value is non-empty."""
    text = _read(SCAFFOLDED_FIXTURE)
    vals = _frontmatter_values(text)
    started = vals.get("started", "")
    assert started, f"Expected non-empty started, got: {started!r}"


def test_scaffolded_fixture_phases_has_at_least_one_row():
    """The scaffolded fixture's Phases table contains at least one data row."""
    text = _read(SCAFFOLDED_FIXTURE)
    rows = _phases_data_rows(text)
    assert len(rows) >= 1, (
        f"Expected at least 1 Phases table data row, got {len(rows)}\n"
        "The scaffold must include an example phase row."
    )
