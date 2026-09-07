#!/usr/bin/env bash
# Validate and resolve the harness registry without embedding host decisions in
# workflow skills. The operation contract is documented in
# skills/.shared/harness-runtime.md; output exposes only the selected adapter.
set -uo pipefail

usage() {
  echo "usage: resolve-harness.sh [--root <plugin-root>] [--registry <path>] (--check | --harness <id> [--require <capability>])" >&2
}

self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$self_dir/.." && pwd)"
registry=""
harness=""
check=0
required_capability=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root) root="${2:-}"; shift 2 ;;
    --registry) registry="${2:-}"; shift 2 ;;
    --harness) harness="${2:-}"; shift 2 ;;
    --require) required_capability="${2:-}"; shift 2 ;;
    --check) check=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

[ -n "$root" ] || { echo "resolve-harness.sh: empty --root" >&2; exit 2; }
root="$(cd "$root" 2>/dev/null && pwd -P)" || {
  echo "resolve-harness.sh: root is not a readable directory" >&2; exit 2;
}
[ -n "$registry" ] || registry="$root/skills/.shared/harness-registry.yaml"
[ "$check" -eq 1 ] && [ -n "$harness" ] && { usage; exit 2; }
[ "$check" -eq 1 ] || [ -n "$harness" ] || { usage; exit 2; }
command -v python3 >/dev/null 2>&1 || {
  echo "resolve-harness.sh: python3 not found" >&2; exit 2;
}
python3 -c 'import yaml' >/dev/null 2>&1 || {
  echo "resolve-harness.sh: PyYAML not installed" >&2; exit 2;
}

python3 - "$root" "$registry" "$harness" "$check" "$required_capability" <<'PY'
import os
import re
import sys

import yaml

root, registry_path, requested, check, required_capability = sys.argv[1:]


def fail(message):
    print(f"resolve-harness.sh: {message}", file=sys.stderr)
    raise SystemExit(1)


try:
    with open(registry_path, encoding="utf-8") as handle:
        document = yaml.safe_load(handle)
except (OSError, yaml.YAMLError) as exc:
    fail(f"cannot read registry {registry_path}: {exc}")

if not isinstance(document, dict) or document.get("schema") != "touchstone-harness-registry/v1":
    fail("schema must be touchstone-harness-registry/v1")
harnesses = document.get("harnesses")
if not isinstance(harnesses, dict) or not harnesses:
    fail("harnesses must be a non-empty mapping")

required = {"provider_family", "adapter", "manifest", "capabilities"}
identifier = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
for harness_id, entry in harnesses.items():
    if not isinstance(harness_id, str) or not identifier.fullmatch(harness_id):
        fail(f"invalid harness id: {harness_id!r}")
    if not isinstance(entry, dict) or set(entry) != required:
        fail(f"harness {harness_id}: fields must be {sorted(required)}")
    family = entry["provider_family"]
    if not isinstance(family, str) or not identifier.fullmatch(family):
        fail(f"harness {harness_id}: invalid provider_family")
    for field in ("adapter", "manifest"):
        rel = entry[field]
        if not isinstance(rel, str) or os.path.isabs(rel) or ".." in rel.split(os.sep):
            fail(f"harness {harness_id}: {field} must stay under the plugin root")
        if not os.path.isfile(os.path.join(root, rel)):
            fail(f"harness {harness_id}: {field} does not exist: {rel}")
    capabilities = entry["capabilities"]
    if (
        not isinstance(capabilities, list)
        or not capabilities
        or len(capabilities) != len(set(capabilities))
        or any(not isinstance(item, str) or not identifier.fullmatch(item) for item in capabilities)
    ):
        fail(f"harness {harness_id}: capabilities must be unique kebab-case ids")

if check == "1":
    print(f"harness-registry: ok ({len(harnesses)} harnesses)")
    raise SystemExit(0)

entry = harnesses.get(requested)
if entry is None:
    fail(f"unknown harness: {requested}")
if required_capability and required_capability not in entry["capabilities"]:
    fail(f"harness {requested}: missing capability: {required_capability}")
print(f"harness={requested}")
print(f"provider_family={entry['provider_family']}")
print(f"adapter={entry['adapter']}")
print(f"manifest={entry['manifest']}")
print("capabilities=" + ",".join(entry["capabilities"]))
PY
