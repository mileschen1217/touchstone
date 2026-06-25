# skills/epic-driven-roadmap/tests/test_procedure_prose_purity.py
#
# test_skill_md_calls_cli_at_least_once — DROPPED: the adapter CLI is
# removed; SKILL.md must NOT contain cli.py invocations.
#
# _build_forbidden_tokens now derives its list from a literal / the template,
# not from the deleted adapter schema.


def _build_forbidden_tokens() -> list[str]:
    """
    Derive forbidden tokens from the index template's canonical field set
    and known structural anchors — no adapter schema import required.
    """
    # Frontmatter keys that appear in the index template's required field set.
    fm_keys = [
        "slug:",
        "status:",
        "started:",
        "landed:",
    ]
    section_headers = [
        "## Foundation", "## Phases", "## Retrospective", "## Open Questions",
    ]
    body_anchors = [r"\*\*Aim:\*\*"]
    structural = [r"\.touchstone/epics/", r"index\.md"]
    shape_phrases = ["the Phases table", "the index file", "the index frontmatter"]

    return fm_keys + section_headers + body_anchors + structural + shape_phrases


def test_index_access_prose_has_no_direct_filesystem_references():
    """Schema-driven grep over in-scope index-access files."""
    import re
    from pathlib import Path
    REPO = Path(__file__).resolve().parents[1]
    in_scope = [
        REPO / "SKILL.md",
        REPO / "references" / "close-and-doc-reckoning.md",
        REPO / "references" / "tasks.md",
    ]
    tokens = _build_forbidden_tokens()
    forbidden = re.compile("|".join(tokens))
    fence_re = re.compile(r"^```")

    violations: list[str] = []
    for f in in_scope:
        if not f.exists():
            continue  # file may not exist yet during partial task execution
        in_fence = False
        for lineno, line in enumerate(f.read_text().splitlines(), 1):
            if fence_re.match(line.strip()):
                in_fence = not in_fence; continue
            if in_fence:
                continue
            if "phase-2-carve-out" in line:
                continue
            if "ROADMAP.md" in line:
                continue
            if forbidden.search(line):
                violations.append(f"{f.relative_to(REPO)}:{lineno}: {line.strip()}")

    assert not violations, "Prose purity violations:\n" + "\n".join(violations)


def test_audit_and_bootstrap_carve_out_lines_are_marked():
    """Every line in audit.md or bootstrap.md that names .touchstone/epics/ or
    index.md must carry the <!-- phase-2-carve-out --> marker, OR sit inside
    a fenced code block."""
    from pathlib import Path
    import re
    REPO = Path(__file__).resolve().parents[1]
    targets = [
        REPO / "references" / "audit.md",
        REPO / "references" / "bootstrap.md",
    ]
    forbidden = re.compile(r"\.touchstone/epics/|index\.md")
    fence_re = re.compile(r"^```")
    for f in targets:
        if not f.exists():
            continue  # file may not exist yet during partial task execution
        in_fence = False
        for lineno, line in enumerate(f.read_text().splitlines(), 1):
            if fence_re.match(line.strip()):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            if forbidden.search(line):
                assert "phase-2-carve-out" in line, (
                    f"{f.name}:{lineno} names index-access path without carve-out marker: {line!r}"
                )
