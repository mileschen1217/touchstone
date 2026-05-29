"""AC-3 happy path — adapter.read() parses an all-populated epic to EpicData."""
import textwrap
from pathlib import Path

import pytest

from skills.epic_driven_roadmap.adapters.local_markdown import adapter as A
from skills.epic_driven_roadmap.adapters.local_markdown import schema as S


FIXTURE = textwrap.dedent("""\
    ---
    schema_version: 1
    slug: demo-epic
    status: active
    started: 2026-05-01
    landed: null
    ---

    **Aim:** ship the demo.

    ## Foundation

    - Intention: prove the loop.
    - Out of scope: scope creep.

    ## Phases

    | n | title | status | landed |
    |---|---|---|---|
    | 1 | Discover | done | 2026-05-10 |
    | 2 | Build | active |  |

    ## Retrospective

    - Tighter scope helped.

    ## Open Questions

    - Concurrency?
    """)


def test_read_populated_epic(tmp_path: Path):
    root = tmp_path / "epics"
    (root / "demo-epic").mkdir(parents=True)
    (root / "demo-epic" / "index.md").write_text(FIXTURE)

    a = A.LocalMarkdownAdapter(root=root)
    data = a.read("demo-epic")

    assert data.schema_version == 1
    assert data.slug == "demo-epic"
    assert data.status == "active"
    assert data.started == "2026-05-01"
    assert data.landed is None
    assert data.aim == "ship the demo."
    assert "prove the loop." in data.intention
    assert data.out_of_scope == ["scope creep."]
    assert len(data.phases) == 2
    assert data.phases[0].n == 1
    assert data.phases[0].title == "Discover"
    assert data.phases[0].status == "done"
    assert data.phases[0].landed == "2026-05-10"
    assert data.phases[1].landed is None
    assert data.retrospective == ["Tighter scope helped."]
    assert data.open_questions == ["Concurrency?"]
