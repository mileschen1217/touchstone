"""
Close-readiness check — negative-fixture suite.

Runs check-close-ready.sh against each fixture and asserts:
- PASS fixtures: exit code 0
- FAIL fixtures: exit code non-zero

The check must locate the Status column by its header label (never hard-coded
index), so a reordered / narrower table that still carries a "Status" header
passes (pass_reordered_status_col.md).
"""
import subprocess
from pathlib import Path

FIXTURES_DIR = Path(__file__).parent
CHECK = Path(__file__).resolve().parents[2] / "check-close-ready.sh"


def _run(fixture_name: str) -> subprocess.CompletedProcess:
    fixture = FIXTURES_DIR / fixture_name
    return subprocess.run(
        ["bash", str(CHECK), str(fixture)],
        capture_output=True,
        text=True,
    )


# ---------------------------------------------------------------------------
# Fixtures that MUST pass (exit 0)
# ---------------------------------------------------------------------------

def test_pass_well_formed():
    r = _run("pass_well_formed.md")
    assert r.returncode == 0, f"Expected PASS but got rc={r.returncode}\nstdout={r.stdout}\nstderr={r.stderr}"


def test_pass_reordered_status_col():
    """Header-driven lookup: a reordered/narrower table with a Status header passes."""
    r = _run("pass_reordered_status_col.md")
    assert r.returncode == 0, f"Expected PASS but got rc={r.returncode}\nstdout={r.stdout}\nstderr={r.stderr}"


# ---------------------------------------------------------------------------
# Fixtures that MUST fail loud (exit non-zero, message naming the fault)
# ---------------------------------------------------------------------------

def _assert_fail(fixture_name: str, expected_keyword: str = ""):
    r = _run(fixture_name)
    assert r.returncode != 0, (
        f"Expected FAIL LOUD for {fixture_name} but got rc=0\nstdout={r.stdout}\nstderr={r.stderr}"
    )
    combined = r.stdout + r.stderr
    assert combined.strip(), f"Expected a fault message but got no output for {fixture_name}"
    if expected_keyword:
        assert expected_keyword.lower() in combined.lower(), (
            f"Expected '{expected_keyword}' in output for {fixture_name}\noutput={combined}"
        )


def test_fail_no_phases_section():
    _assert_fail("fail_no_phases_section.md", "phases")


def test_fail_zero_phase_rows():
    _assert_fail("fail_zero_phase_rows.md", "row")


def test_fail_no_status_header():
    _assert_fail("fail_no_status_header.md", "status")


def test_fail_duplicate_status_header():
    _assert_fail("fail_duplicate_status_header.md", "status")


def test_fail_row_width_mismatch():
    _assert_fail("fail_row_width_mismatch.md", "width")


def test_fail_phase_not_done():
    _assert_fail("fail_phase_not_done.md", "done")


def test_fail_invalid_status_enum():
    _assert_fail("fail_invalid_status_enum.md", "status")


def test_fail_missing_started():
    _assert_fail("fail_missing_started.md", "started")


def test_fail_missing_landed():
    _assert_fail("fail_missing_landed.md", "landed")


def test_fail_bad_landed_format():
    _assert_fail("fail_bad_landed_format.md", "landed")


def test_fail_missing_required_key():
    _assert_fail("fail_missing_required_key.md", "slug")


def test_fail_duplicate_frontmatter_key():
    _assert_fail("fail_duplicate_frontmatter_key.md", "duplicate")


def test_fail_duplicate_phases_section():
    _assert_fail("fail_duplicate_phases_section.md", "phases")


# ---------------------------------------------------------------------------
# New negative fixtures: A1 / A2 / A3 / A4 honesty-floor hardening
# ---------------------------------------------------------------------------

def test_fail_status_not_done():
    """A1: epic with status: active (even with all phases done) must fail."""
    _assert_fail("fail_status_not_done.md", "done")


def test_fail_nonnumeric_phase_number():
    """A2: a phase row whose first column is not numeric must fail."""
    _assert_fail("fail_nonnumeric_phase_number.md", "number")


def test_fail_intable_malformed_row():
    """A2: an in-table row that breaks the pipe-delimited shape must fail loud."""
    _assert_fail("fail_intable_malformed_row.md", "malformed")


def test_fail_no_fm_close_delimiter():
    """A3: frontmatter with no closing --- delimiter must fail."""
    _assert_fail("fail_no_fm_close_delimiter.md", "closing")


def test_fail_calendar_invalid_date():
    """A4: a landed date with calendar-invalid month or day must fail."""
    _assert_fail("fail_calendar_invalid_date.md", "range")


def test_fail_phases_in_frontmatter():
    """C1: a Phases table embedded inside the frontmatter block must not satisfy
    the body Phases requirement — the check scopes its scan to the body only."""
    _assert_fail("fail_phases_in_frontmatter.md", "Phases")


def test_fail_status_no_space():
    """No-space false-green: status:done (no space after colon) is a YAML plain
    scalar, not a mapping entry — the check must treat status as missing."""
    _assert_fail("fail_status_no_space.md", "status")
