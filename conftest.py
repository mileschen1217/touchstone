# conftest.py (repo root) — only if not already present
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "skills"))
# Symlink import path: skills.epic-driven-roadmap → skills.epic_driven_roadmap
import types
_pkg = types.ModuleType("epic_driven_roadmap")
_pkg.__path__ = [str(ROOT / "skills/epic-driven-roadmap")]
sys.modules["epic_driven_roadmap"] = _pkg
# also expose under skills.* path
_skills = types.ModuleType("skills"); _skills.__path__ = [str(ROOT / "skills")]
sys.modules["skills"] = _skills
sys.modules["skills.epic_driven_roadmap"] = _pkg
# register tests sub-package for epic_driven_roadmap (avoids No module named 'tests.test_*')
_tests = types.ModuleType("epic_driven_roadmap.tests")
_tests.__path__ = [str(ROOT / "skills/epic-driven-roadmap/tests")]
sys.modules["epic_driven_roadmap.tests"] = _tests
sys.modules["skills.epic_driven_roadmap.tests"] = _tests
