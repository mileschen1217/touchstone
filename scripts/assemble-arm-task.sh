#!/usr/bin/env bash
# scripts/assemble-arm-task.sh — builds one dispatched arm's two round-dir files
# (its lens and its review subject) OUTSIDE any gate session's own context,
# printing only paths and fragment ids. Manifest shape:
# skills/_shared/lens-manifest.yaml (read its own header before editing this).
#
# Usage:
#   assemble-arm-task.sh --arm <label> --round-dir <dir> \
#       (--lens <manifest lens name> | --lens-file <path to pre-composed lens text>) \
#       (--subject-file <path> | --subject-cmd <shell command whose stdout is the subject>) \
#       [--root <repo root>]
#
# Writes <round-dir>/lens-<arm>.md and <round-dir>/subject-<arm>.md. Prints
# EXACTLY three lines to stdout: the lens path, the subject path, and the
# space-separated fragment ids (empty third line when --lens-file was used).
# Neither file's content is ever printed to stdout or stderr — the subject is
# produced by copy (--subject-file) or shell redirect (--subject-cmd); the
# fragment bodies are written straight to the lens file by a subprocess and
# never pass through a shell variable in this script.
#
# --lens-file exists for the one caller whose lens composition is already
# single-homed elsewhere (a rubric slicer). It takes no manifest entry and
# the third stdout line is empty.
#
# Unknown lens name, missing ref path, unresolvable heading, or missing
# --round-dir: exit non-zero, name the offending value on stderr, write
# nothing.
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: assemble-arm-task.sh --arm <label> --round-dir <dir> \
    (--lens <manifest lens name> | --lens-file <path to pre-composed lens text>) \
    (--subject-file <path> | --subject-cmd <shell command whose stdout is the subject>) \
    [--root <repo root>]

Writes <round-dir>/lens-<arm>.md and <round-dir>/subject-<arm>.md. Prints
exactly three lines to stdout: the lens path, the subject path, and the
space-separated fragment ids (empty third line when --lens-file was used).
Neither file's content is ever printed. Manifest shape:
skills/_shared/lens-manifest.yaml.

  --self-test   exercise the system_prompt_file > system_prompt > built-in
                precedence documented in agents/codex-reviewer.md (AC-46).
USAGE
}

self_dir="$(cd "$(dirname "$0")" && pwd)"
default_root="$(cd "$self_dir/.." && pwd)"

# resolve_role_prompt -- the same precedence agents/codex-reviewer.md's
# dispatch block documents: system_prompt_file (read from disk) beats
# system_prompt (inline text) beats the built-in role prompt. Exercised in
# isolation by --self-test (AC-46); kept here as the one runnable assertion
# of that documented precedence, independent of the codex CLI.
resolve_role_prompt() {
  local spf="$1" sp="$2" builtin="$3"
  if [ -n "$spf" ]; then
    cat -- "$spf"
  elif [ -n "$sp" ]; then
    printf '%s' "$sp"
  else
    printf '%s' "$builtin"
  fi
}

run_self_test() {
  local tmp out rc=0
  tmp="$(mktemp)"
  printf 'FROM_FILE' > "$tmp"

  out="$(resolve_role_prompt "$tmp" "FROM_INLINE" "FROM_BUILTIN")"
  if [ "$out" != "FROM_FILE" ]; then
    echo "self-test: system_prompt_file + system_prompt + built-in -> expected FROM_FILE, got '$out'" >&2
    rc=1
  fi

  out="$(resolve_role_prompt "" "FROM_INLINE" "FROM_BUILTIN")"
  if [ "$out" != "FROM_INLINE" ]; then
    echo "self-test: system_prompt + built-in (no file) -> expected FROM_INLINE, got '$out'" >&2
    rc=1
  fi

  out="$(resolve_role_prompt "" "" "FROM_BUILTIN")"
  if [ "$out" != "FROM_BUILTIN" ]; then
    echo "self-test: built-in only -> expected FROM_BUILTIN, got '$out'" >&2
    rc=1
  fi

  rm -f "$tmp"
  [ "$rc" -eq 0 ] && echo "self-test: ok (system_prompt_file > system_prompt > built-in)"
  return "$rc"
}

arm="" round_dir="" lens_name="" lens_file="" subject_file="" subject_cmd="" root="" self_test=0

while [ $# -gt 0 ]; do
  case "$1" in
    --arm) arm="${2:-}"; shift 2 ;;
    --round-dir) round_dir="${2:-}"; shift 2 ;;
    --lens) lens_name="${2:-}"; shift 2 ;;
    --lens-file) lens_file="${2:-}"; shift 2 ;;
    --subject-file) subject_file="${2:-}"; shift 2 ;;
    --subject-cmd) subject_cmd="${2:-}"; shift 2 ;;
    --root) root="${2:-}"; shift 2 ;;
    --self-test) self_test=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "assemble-arm-task.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ "$self_test" -eq 1 ]; then
  run_self_test
  exit $?
fi

[ -n "$root" ] || root="$default_root"

# --arm is a free-form label naming this arm INSTANCE — the vendor alone (`cc`,
# `codex`) where a round dir hosts one arm per vendor, `<lens>-<vendor>` where two
# same-vendor arms share a round dir (design-review's challenger-cc beside its
# design-soundness-cc). The label only names files; vendor semantics live in the
# manifest's `arms` and the gate's dispatch.
case "$arm" in
  '') echo "assemble-arm-task.sh: missing --arm" >&2; exit 2 ;;
  *[!A-Za-z0-9_-]*) echo "assemble-arm-task.sh: --arm must be a [A-Za-z0-9_-]+ label, got: '${arm}'" >&2; exit 2 ;;
esac
[ -n "$round_dir" ] || { echo "assemble-arm-task.sh: missing --round-dir" >&2; exit 2; }
if { [ -n "$lens_name" ] && [ -n "$lens_file" ]; } || { [ -z "$lens_name" ] && [ -z "$lens_file" ]; }; then
  echo "assemble-arm-task.sh: pass exactly one of --lens or --lens-file" >&2; exit 2
fi
if { [ -n "$subject_file" ] && [ -n "$subject_cmd" ]; } || { [ -z "$subject_file" ] && [ -z "$subject_cmd" ]; }; then
  echo "assemble-arm-task.sh: pass exactly one of --subject-file or --subject-cmd" >&2; exit 2
fi

mkdir -p "$round_dir" 2>/dev/null
[ -d "$round_dir" ] || { echo "assemble-arm-task.sh: --round-dir does not exist and could not be created: $round_dir" >&2; exit 2; }

read_back_line() {
  printf 'You MUST open your report with the line: fragments_read: %s' "$1"
}

lens_out="$round_dir/lens-$arm.md"
subject_out="$round_dir/subject-$arm.md"
ids=""
tmp_lens="$(mktemp)"

if [ -n "$lens_file" ]; then
  if [ ! -f "$lens_file" ]; then
    echo "assemble-arm-task.sh: --lens-file does not exist: $lens_file" >&2
    rm -f "$tmp_lens"
    exit 2
  fi
  {
    printf 'fragments: \n'
    read_back_line ""
    printf '\n\n'
    cat -- "$lens_file"
  } > "$tmp_lens"
else
  manifest="$root/skills/_shared/lens-manifest.yaml"
  pyfile="$(mktemp)"
  errfile="$(mktemp)"
  bodyfile="$(mktemp)"
  cat > "$pyfile" <<'PY'
import os, re, sys

root, manifest_path, lens_name, out_body = sys.argv[1:5]


def fail(msg):
    sys.stderr.write(msg + "\n")
    sys.exit(2)


try:
    import yaml
except ImportError:
    fail("PyYAML not available -- cannot parse lens-manifest.yaml")

if not os.path.isfile(manifest_path):
    fail("manifest not found: %s" % manifest_path)

with open(manifest_path) as f:
    data = yaml.safe_load(f.read()) or {}

lenses = data.get('lenses') if isinstance(data, dict) else None
if not isinstance(lenses, list):
    fail("manifest has no 'lenses' list: %s" % manifest_path)

lens = next((entry for entry in lenses if isinstance(entry, dict) and entry.get('name') == lens_name), None)
if lens is None:
    fail("unknown lens name: %s" % lens_name)

sections = lens.get('sections') or []
heading_re = re.compile(r'^(#{1,6})\s+(.*\S)\s*$')


def extract(ref):
    if '#' in ref:
        path, heading = ref.split('#', 1)
    else:
        path, heading = ref, None
    abspath = os.path.join(root, path)
    if not os.path.isfile(abspath):
        fail("ref path does not exist: %s" % path)
    with open(abspath) as f:
        lines = f.read().splitlines()
    if heading is None:
        return '\n'.join(lines)
    start, start_level = None, None
    for i, line in enumerate(lines):
        m = heading_re.match(line)
        if m and m.group(2).strip() == heading.strip():
            start, start_level = i, len(m.group(1))
            break
    if start is None:
        fail("heading not found: %s#%s" % (path, heading))
    end = len(lines)
    for j in range(start + 1, len(lines)):
        m = heading_re.match(lines[j])
        if m and len(m.group(1)) <= start_level:
            end = j
            break
    return '\n'.join(lines[start:end])


ids, bodies = [], []
for sec in sections:
    if not isinstance(sec, dict) or sec.get('destination') != 'arm':
        continue
    ref, sid = sec.get('ref'), sec.get('id')
    if not ref or not sid:
        fail("lens '%s' has a section missing ref or id" % lens_name)
    bodies.append(extract(ref))
    ids.append(str(sid))

with open(out_body, 'w') as f:
    f.write('\n\n'.join(bodies))

print(' '.join(ids))
PY
  ids="$(python3 "$pyfile" "$root" "$manifest" "$lens_name" "$bodyfile" 2>"$errfile")"
  prc=$?
  if [ "$prc" -ne 0 ]; then
    cat "$errfile" >&2
    rm -f "$pyfile" "$errfile" "$bodyfile" "$tmp_lens"
    exit "$prc"
  fi
  {
    printf 'fragments: %s\n' "$ids"
    read_back_line "$ids"
    printf '\n\n'
    cat -- "$bodyfile"
  } > "$tmp_lens"
  rm -f "$pyfile" "$errfile" "$bodyfile"
fi

mv "$tmp_lens" "$lens_out"

# ---- subject file: copy (--subject-file) or shell redirect (--subject-cmd).
# The subject bytes are never captured into a shell variable and never echoed
# -- `cat` streams a copy, `sh -c` streams a redirect, both straight into the
# one output redirection below (AC-8).
{
  printf '<<< UNTRUSTED DATA >>>\n'
  if [ -n "$subject_file" ]; then
    cat -- "$subject_file"
  else
    sh -c "$subject_cmd"
  fi
  printf '\n<<< END UNTRUSTED DATA >>>\n'
} > "$subject_out"

printf '%s\n%s\n%s\n' "$lens_out" "$subject_out" "$ids"
