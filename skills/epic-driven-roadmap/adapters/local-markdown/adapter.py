"""Local-markdown reference storage adapter.

read/write/list/exists for .touchstone/epics/<slug>/index.md.
Atomic-or-throw on write (tmp + os.rename).
"""
from __future__ import annotations

import hashlib
import os
import re
from dataclasses import asdict
from pathlib import Path
from typing import Optional

import yaml

from . import schema as S
from .schema import (
    AdapterInternalError,
    CanonicalSerialisationError,
    EpicData,
    EpicNotFound,
    PhaseData,
    SCHEMA_VERSION,
    SchemaValidationError,
    SchemaVersionMismatch,
    SidecarUnstorableError,
    StructuralHostMissingError,
    validate_sidecar_value,
)

CANONICAL_FRONTMATTER_KEYS = {
    "schema_version", "slug", "status", "started", "landed",
}
SECTION_RE = re.compile(r"^##\s+(.+?)\s*$", re.MULTILINE)
AIM_RE = re.compile(r"^\*\*Aim:\*\*[ \t]*(.*?)[ \t]*$", re.MULTILINE)
BULLET_RE = re.compile(r"^-\s+(.+?)\s*$", re.MULTILINE)
INTENTION_BULLET_RE = re.compile(r"^-\s+Intention:\s*(.+?)\s*$", re.MULTILINE)
OOS_BULLET_RE = re.compile(r"^-\s+Out of scope:\s*(.+?)\s*$", re.MULTILINE)
PHASE_ROW_RE = re.compile(
    # Capture the four primary columns; allow any number of trailing | cells
    # (6-column rows with spec/plan sidecar columns must still match).
    # Use [ \t]* (not \s*) to prevent matching across newlines.
    r"^\|[ \t]*(\d+)[ \t]*\|[ \t]*([^\n|]+?)[ \t]*\|[ \t]*([a-z]+)[ \t]*\|[ \t]*([^\n|]*?)[ \t]*\|(?:[ \t]*[^\n|]*[ \t]*\|)*[ \t]*$",
    re.MULTILINE,
)


class LocalMarkdownAdapter:
    def __init__(self, root: Path):
        self.root = Path(root)

    # ---------- public surface ----------

    def list(self) -> list[str]:
        if not self.root.exists():
            return []
        out = []
        for child in sorted(self.root.iterdir()):
            if not child.is_dir():
                continue
            if (child / "index.md").exists():
                out.append(child.name)
        return out

    def exists(self, slug: str) -> bool:
        return (self.root / slug / "index.md").exists()

    def read(self, slug: str) -> EpicData:
        path = self.root / slug / "index.md"
        if not path.exists():
            raise EpicNotFound(slug=slug)
        text = path.read_text()
        return self._parse(text, slug=slug)

    # ---------- write ----------

    def write(self, slug: str, data: EpicData) -> None:
        # Slug discipline (AC-10 mismatch)
        if not slug:
            raise SchemaValidationError(field="slug", reason="slug required")
        if not data.slug:
            raise SchemaValidationError(field="slug", slug=slug, reason="slug required")
        if data.slug != slug:
            raise SchemaValidationError(field="slug", slug=slug, reason="path/data mismatch")

        # Stamp schema_version (AC-7b)
        data.schema_version = SCHEMA_VERSION

        # Validate sidecar tag shapes BEFORE touching disk (AC-4c)
        for k, v in (data.sidecar or {}).items():
            try:
                validate_sidecar_value(v)
            except SidecarUnstorableError as e:
                raise SidecarUnstorableError(
                    field=f"sidecar.{k}", backend="local-markdown", reason=e.reason,
                )
        for i, ph in enumerate(data.phases or []):
            for k, v in (ph.sidecar or {}).items():
                try:
                    validate_sidecar_value(v)
                except SidecarUnstorableError as e:
                    raise SidecarUnstorableError(
                        field=f"phases[{i}].sidecar.{k}", backend="local-markdown", reason=e.reason,
                    )

        # Phases-table cell host can only carry `str` tag.
        # list[str] / dict[str, str] are valid SidecarValue at the schema
        # layer but cannot be expressed in a single table cell — refuse
        # rather than coerce (AC-6 tag preservation).
        for i, ph in enumerate(data.phases or []):
            for k, v in (ph.sidecar or {}).items():
                if isinstance(v, list):
                    raise SidecarUnstorableError(
                        field=f"phases[{i}].sidecar.{k}",
                        backend="local-markdown",
                        reason=(
                            "list[str] cannot be expressed in a "
                            "Phases-table cell — promote to epic-level "
                            "sidecar (YAML frontmatter) or use a "
                            "sidecar-only schema bump"
                        ),
                    )
                if isinstance(v, dict):
                    raise SidecarUnstorableError(
                        field=f"phases[{i}].sidecar.{k}",
                        backend="local-markdown",
                        reason=(
                            "dict[str, str] cannot be expressed in a "
                            "Phases-table cell — promote to epic-level "
                            "sidecar (YAML frontmatter) or use a "
                            "sidecar-only schema bump"
                        ),
                    )
                if isinstance(v, str) and "|" in v:
                    raise SidecarUnstorableError(
                        field=f"phases[{i}].sidecar.{k}",
                        backend="local-markdown",
                        reason=(
                            "phase-sidecar str value contains a literal "
                            "'|' which cannot be expressed in a "
                            "Phases-table cell without breaking row "
                            "delimitation — promote to epic-level sidecar "
                            "(YAML frontmatter) or strip the pipe upstream"
                        ),
                    )

        # Conditional-required canonical rules (AC-4 on write). 'cancelled' is exempted.
        if data.status in ("active", "paused", "done") and data.started is None:
            raise SchemaValidationError(
                field="started", slug=slug, reason=f"required when status == {data.status!r}",
            )
        if data.status == "done" and data.landed is None:
            raise SchemaValidationError(
                field="landed", slug=slug, reason="required when status == done",
            )

        target_dir = self.root / slug
        target_dir.mkdir(parents=True, exist_ok=True)
        target = target_dir / "index.md"
        tmp = target_dir / f"index.md.tmp.{os.getpid()}"

        try:
            try:
                text = self._serialise(data)
            except (CanonicalSerialisationError, SidecarUnstorableError):
                self._cleanup_tmp(target_dir)
                raise
            tmp.write_text(text)
            os.rename(tmp, target)
        except (CanonicalSerialisationError, SidecarUnstorableError):
            self._cleanup_tmp(target_dir)
            raise
        except Exception as e:
            self._cleanup_tmp(target_dir)
            raise AdapterInternalError(cause=f"{type(e).__name__}: {e}")

    def _cleanup_tmp(self, target_dir: Path) -> None:
        for stray in target_dir.glob("index.md.tmp.*"):
            try:
                stray.unlink()
            except OSError:
                pass

    def _serialise(self, data: EpicData) -> str:
        # frontmatter
        fm = {
            "schema_version": data.schema_version,
            "slug": data.slug,
            "status": data.status,
            "started": data.started,
            "landed": data.landed,
        }
        for k, v in (data.sidecar or {}).items():
            # only str / list[str] / dict[str,str] reach here (validated upstream)
            if k not in fm:
                fm[k] = v
        try:
            fm_text = yaml.safe_dump(fm, sort_keys=False, default_flow_style=False).strip()
        except yaml.YAMLError as e:
            raise CanonicalSerialisationError(field="<frontmatter>", backend="local-markdown")

        parts = ["---", fm_text, "---", ""]
        parts.append(f"**Aim:** {data.aim}")
        parts.append("")
        parts.append("## Foundation")
        parts.append("")
        if data.intention:
            parts.append(f"- Intention: {data.intention}")
        for o in data.out_of_scope:
            parts.append(f"- Out of scope: {o}")
        parts.append("")
        parts.append("## Phases")
        parts.append("")
        if data.phases:
            # Collect union of phase sidecar keys (preserve first-seen order)
            extra_cols: list[str] = []
            seen: set[str] = set()
            for ph in data.phases:
                for k in (ph.sidecar or {}):
                    if k not in seen:
                        seen.add(k); extra_cols.append(k)
            header = ["n", "title", "status", "landed"] + extra_cols
            parts.append("| " + " | ".join(header) + " |")
            parts.append("|" + "|".join("---" for _ in header) + "|")
            for ph in data.phases:
                cells = [str(ph.n), ph.title, ph.status, ph.landed or ""]
                for col in extra_cols:
                    val = (ph.sidecar or {}).get(col, "")
                    assert isinstance(val, str), (
                        f"phases[].sidecar.{col} reached _serialise as "
                        f"{type(val).__name__}; host-capability guard "
                        f"in write() must have been bypassed"
                    )
                    cells.append(val)
                parts.append("| " + " | ".join(cells) + " |")
        parts.append("")
        parts.append("## Retrospective")
        parts.append("")
        for r in data.retrospective:
            parts.append(f"- {r}")
        parts.append("")
        parts.append("## Open Questions")
        parts.append("")
        for q in data.open_questions:
            parts.append(f"- {q}")
        parts.append("")
        return "\n".join(parts)

    # ---------- parse ----------

    def _parse(self, text: str, slug: str) -> EpicData:
        fm, body = self._split_frontmatter(text, slug=slug)
        self._validate_frontmatter(fm, slug=slug)

        epic = EpicData()
        epic.schema_version = int(fm["schema_version"])
        epic.slug = str(fm["slug"])
        epic.status = str(fm["status"])
        epic.started = self._coerce_date(fm.get("started"))
        epic.landed = self._coerce_date(fm.get("landed"))

        # sidecar = unknown frontmatter keys
        for k, v in fm.items():
            if k not in CANONICAL_FRONTMATTER_KEYS:
                try:
                    validate_sidecar_value(v)
                except SidecarUnstorableError:
                    # on read we tolerate broader yaml types by stringifying
                    v = str(v)
                epic.sidecar[k] = v

        # aim
        m = AIM_RE.search(body)
        epic.aim = m.group(1).strip() if m else ""

        sections = self._sections(body)

        # Foundation: parse Intention + Out of scope bullets
        foundation = sections.get("Foundation")
        if foundation is not None:
            mi = INTENTION_BULLET_RE.search(foundation)
            epic.intention = mi.group(1).strip() if mi else ""
            for m_oos in OOS_BULLET_RE.finditer(foundation):
                epic.out_of_scope.append(m_oos.group(1).strip())

        # Phases table
        phases_section = sections.get("Phases")
        if phases_section is not None:
            for m_row in PHASE_ROW_RE.finditer(phases_section):
                landed_raw = m_row.group(4).strip()
                ph_status = m_row.group(3).strip()
                # M1 — phase.status must be one of STATUS_VALUES
                if ph_status not in S.STATUS_VALUES:
                    raise SchemaValidationError(
                        field=f"phases[{int(m_row.group(1))}].status",
                        slug=slug,
                        reason=f"invalid status value: {ph_status!r}",
                    )
                epic.phases.append(PhaseData(
                    n=int(m_row.group(1)),
                    title=m_row.group(2).strip(),
                    status=ph_status,
                    landed=landed_raw if landed_raw else None,
                ))

        # Phase sidecar — extra columns beyond (n, title, status, landed).
        # Header-driven split: index each row's cells by column position.
        if phases_section is not None and epic.phases:
            # Find the header row (first table row in the section that starts with `|`)
            header_match = None
            for line in phases_section.splitlines():
                if line.lstrip().startswith("|") and "n" in line.lower():
                    header_match = line
                    break
            if header_match:
                # Split header on `|`, strip, drop leading/trailing empties from
                # the outer pipes.
                cols = [c.strip() for c in header_match.split("|")]
                cols = [c for c in cols if c != ""]
                extra_cols = cols[4:]  # past n / title / status / landed
                if extra_cols:
                    # Build slug→PhaseData lookup by n.
                    by_n = {ph.n: ph for ph in epic.phases}
                    for line in phases_section.splitlines():
                        s = line.strip()
                        if not s.startswith("|"):
                            continue
                        # Skip header and separator (---|---|...)
                        if "---" in s:
                            continue
                        cells = [c.strip() for c in s.split("|")]
                        cells = [c for c in cells if c != ""]
                        if not cells or not cells[0].isdigit():
                            continue
                        n = int(cells[0])
                        ph = by_n.get(n)
                        if ph is None:
                            continue
                        for i, col_name in enumerate(extra_cols):
                            idx = 4 + i
                            if idx >= len(cells):
                                continue
                            val = cells[idx]
                            if val:
                                ph.sidecar[col_name] = val

        # Retrospective bullets
        retro = sections.get("Retrospective")
        if retro is not None:
            epic.retrospective = [m.group(1).strip() for m in BULLET_RE.finditer(retro)]

        # Open Questions — host MUST exist; absence is StructuralHostMissingError
        if "Open Questions" not in sections:
            raise StructuralHostMissingError(field="open_questions")
        oq = sections["Open Questions"]
        epic.open_questions = [m.group(1).strip() for m in BULLET_RE.finditer(oq)]

        # conditional-required: started if status in {active, paused, done}; landed if status == done.
        # 'cancelled' is a terminal status exempted — epics folded before work began legitimately
        # have no started date.
        if epic.status in ("active", "paused", "done") and epic.started is None:
            raise SchemaValidationError(
                field="started", slug=slug, schema_version=epic.schema_version,
                reason=f"required when status == {epic.status!r}",
            )
        if epic.status == "done" and epic.landed is None:
            raise SchemaValidationError(
                field="landed", slug=slug, schema_version=epic.schema_version,
                reason="required when status == done",
            )

        return epic

    def _split_frontmatter(self, text: str, slug: str):
        if not text.startswith("---\n"):
            raise SchemaValidationError(field="<frontmatter>", slug=slug, reason="missing frontmatter delimiter")
        end = text.find("\n---\n", 4)
        if end < 0:
            raise SchemaValidationError(field="<frontmatter>", slug=slug, reason="unterminated frontmatter")
        fm_text = text[4:end]
        body = text[end + 5 :]
        try:
            fm = yaml.safe_load(fm_text) or {}
        except yaml.YAMLError as e:
            raise SchemaValidationError(field="<frontmatter>", slug=slug, reason=f"yaml error: {e}")
        if not isinstance(fm, dict):
            raise SchemaValidationError(field="<frontmatter>", slug=slug, reason="frontmatter not a mapping")
        return fm, body

    def _validate_frontmatter(self, fm: dict, slug: str) -> None:
        # Legacy accommodation: pre-adapter epics lack schema_version. Default to
        # version 1 and let write() stamp it explicitly on next save.
        if "schema_version" not in fm:
            fm["schema_version"] = SCHEMA_VERSION
        try:
            sv = int(fm["schema_version"])
        except (TypeError, ValueError):
            raise SchemaValidationError(field="schema_version", slug=slug, reason="not an integer")
        if sv != SCHEMA_VERSION:
            raise SchemaVersionMismatch(found=sv, expected=SCHEMA_VERSION)
        for required in ("slug", "status"):
            if required not in fm:
                raise SchemaValidationError(field=required, slug=slug, reason="missing")
        if fm["status"] not in S.STATUS_VALUES:
            raise SchemaValidationError(field="status", slug=slug, reason=f"unknown status: {fm['status']}")

    @staticmethod
    def _coerce_date(value) -> Optional[str]:
        """Return ISO-8601 string or None; handles yaml.safe_load datetime.date objects."""
        import datetime
        if value is None or value == "":
            return None
        if isinstance(value, (datetime.date, datetime.datetime)):
            return value.isoformat()[:10]
        return str(value)

    def _sections(self, body: str) -> dict[str, str]:
        out: dict[str, str] = {}
        matches = list(SECTION_RE.finditer(body))
        for i, m in enumerate(matches):
            name = m.group(1).strip()
            start = m.end()
            end = matches[i + 1].start() if i + 1 < len(matches) else len(body)
            out[name] = body[start:end]
        return out
