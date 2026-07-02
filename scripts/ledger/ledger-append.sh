#!/usr/bin/env bash
# ledger-append.sh — the SINGLE writer to .touchstone/ledger/entries.jsonl.
# Modes:
#   stdin batch : catch-miss/v1 JSONL, one entry per line, on stdin
#   label       : ledger-append.sh --label '<json>'  (forces schema/source=label,
#                 always fills id/ts/dedupe_key)
# Exit 0 = every well-formed entry appended or deduped (no-op).
# Exit 1 = schema violation / lock contention / symlink refusal / gitignore
#          self-heal failure — nothing is written in any of these cases.
set -u

if [ -n "${TOUCHSTONE_LEDGER_DIR:-}" ]; then
  DIR="$TOUCHSTONE_LEDGER_DIR"
else
  TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$TOPLEVEL" ]; then
    echo "ledger-append: not inside a git repo; set TOUCHSTONE_LEDGER_DIR" >&2
    exit 1
  fi
  DIR="$TOPLEVEL/.touchstone/ledger"
fi
LEDGER="$DIR/entries.jsonl"
LOCK="$DIR/.lock"
LOCK_TIMEOUT="${TOUCHSTONE_LEDGER_LOCK_TIMEOUT:-5}"

GAP_CLASSES="missing-AC false-green no-gate"
SOURCES="label sweep:transcript sweep:git sweep:reckoning sweep:firelog"
LOCUS_LIST="design-review plan-review code-review:per-commit code-review:batch anvil:final test-suite live-probe human"

# --- symlink refusal (AC-24): never write through a pre-existing symlink,
# checked before anything else touches the filesystem ---
PARENT_DIR="$(dirname "$DIR")"
if [ -L "$DIR" ] || [ -L "$PARENT_DIR" ]; then
  echo "ledger-append: refusing symlinked ledger path ($DIR)" >&2
  exit 1
fi

LABEL_JSON=""
if [ "${1:-}" = "--label" ]; then
  LABEL_JSON="${2:-}"
  if [ -z "$LABEL_JSON" ]; then
    echo "ledger-append: --label requires a JSON argument" >&2
    exit 1
  fi
fi

in_list() { # <needle> <space-separated haystack...>
  local needle="$1"; shift
  local x
  for x in "$@"; do
    [ "$x" = "$needle" ] && return 0
  done
  return 1
}

locus_ok() {
  case "$1" in
    checker:*) return 0 ;;
  esac
  # shellcheck disable=SC2086  # intentional word-splitting: in_list takes each vocabulary word as a separate arg
  in_list "$1" $LOCUS_LIST
}

# validate_line <json-entry> — prints a reason to stderr and returns 1 on any
# schema violation; the ledger is never touched for a rejected entry.
validate_line() {
  local e="$1"
  echo "$e" | jq -e . >/dev/null 2>&1 || { echo "ledger-append: not valid JSON" >&2; return 1; }

  local schema
  schema="$(echo "$e" | jq -r '.schema // empty')"
  [ "$schema" = "catch-miss/v1" ] || { echo "ledger-append: schema must be catch-miss/v1 (got '$schema')" >&2; return 1; }

  local what
  what="$(echo "$e" | jq -r '.what // empty')"
  [ -n "$what" ] || { echo "ledger-append: missing field: what" >&2; return 1; }

  local gap_class
  gap_class="$(echo "$e" | jq -r '.gap_class // empty')"
  # shellcheck disable=SC2086  # intentional word-splitting: in_list takes each enum word as a separate arg
  in_list "$gap_class" $GAP_CLASSES || { echo "ledger-append: invalid gap_class: '$gap_class'" >&2; return 1; }

  local source
  source="$(echo "$e" | jq -r '.source // empty')"
  # shellcheck disable=SC2086  # intentional word-splitting: in_list takes each enum word as a separate arg
  in_list "$source" $SOURCES || { echo "ledger-append: invalid source: '$source'" >&2; return 1; }

  local ev_nonempty
  ev_nonempty="$(echo "$e" | jq -r '(.evidence // []) | if (type=="array") then (length>=1) else false end')"
  [ "$ev_nonempty" = "true" ] || { echo "ledger-append: evidence must be a non-empty array" >&2; return 1; }

  local ev_shape
  ev_shape="$(echo "$e" | jq -r '.evidence | all(type=="object" and has("kind") and has("ref") and (.kind|type=="string") and (.ref|type=="string") and (.kind|length>0) and (.ref|length>0))')"
  [ "$ev_shape" = "true" ] || { echo "ledger-append: evidence entries need non-empty kind+ref" >&2; return 1; }

  local caught_by should_have
  caught_by="$(echo "$e" | jq -r '.caught_by // empty')"
  should_have="$(echo "$e" | jq -r '.should_have // empty')"
  [ -n "$caught_by" ] || { echo "ledger-append: missing field: caught_by" >&2; return 1; }
  [ -n "$should_have" ] || { echo "ledger-append: missing field: should_have" >&2; return 1; }
  locus_ok "$caught_by" || { echo "ledger-append: caught_by not in closed locus vocabulary: '$caught_by'" >&2; return 1; }
  locus_ok "$should_have" || { echo "ledger-append: should_have not in closed locus vocabulary: '$should_have'" >&2; return 1; }

  return 0
}

# fill_line <json-entry> <force|""> — fills id/ts when absent (or always, when
# forced by --label mode); dedupe_key is always recomputed (derived field).
fill_line() {
  local e="$1" force="$2"
  local id ts
  id="$(echo "$e" | jq -r '.id // empty')"
  ts="$(echo "$e" | jq -r '.ts // empty')"

  if [ -z "$id" ] || [ "$force" = "force" ]; then
    id="$(date -u +%Y%m%dT%H%M%SZ)-$$-$RANDOM"
  fi
  if [ -z "$ts" ] || [ "$force" = "force" ]; then
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  local refs dedupe_key
  refs="$(echo "$e" | jq -r '[.evidence[].ref] | sort | .[]')"
  dedupe_key="$(printf '%s\n' "$refs" | shasum -a 256 | awk '{print $1}')"

  echo "$e" | jq -c --arg id "$id" --arg ts "$ts" --arg dk "$dedupe_key" \
    '.id=$id | .ts=$ts | .dedupe_key=$dk'
}

# refs_overlap <new-refs-json-array> <existing-refs-json-array> -> "true"/"false"
# Per-kind overlap rule: transcript refs overlap only when same path AND byte
# ranges intersect (a bare transcript:<path> ref — label-only, no byte range —
# never overlaps anything, too coarse); every other kind overlaps on exact
# normalized-ref string equality.
refs_overlap() {
  jq -n --argjson new "$1" --argjson old "$2" '
    def parse_t(r):
      if (r | test("^transcript:.*#[0-9]+-[0-9]+$")) then
        (r | capture("^transcript:(?<path>.*)#(?<start>[0-9]+)-(?<end>[0-9]+)$")
           | {path, start: (.start|tonumber), end: (.end|tonumber), bare: false})
      else
        {path: (r | sub("^transcript:"; "")), start: null, end: null, bare: true}
      end;
    def ov(a; b):
      if (a | startswith("transcript:")) and (b | startswith("transcript:")) then
        (parse_t(a)) as $pa | (parse_t(b)) as $pb |
        if ($pa.bare or $pb.bare) then false
        else ($pa.path == $pb.path) and ($pa.start <= $pb.end) and ($pb.start <= $pa.end)
        end
      else
        a == b
      end;
    ([$new[] as $n | $old[] as $o | ov($n; $o)] | any)
  '
}

acquire_lock() {
  local start now elapsed holder
  start="$(date +%s)"
  while ! mkdir "$LOCK" 2>/dev/null; do
    now="$(date +%s)"
    elapsed=$((now - start))
    if [ "$elapsed" -ge "$LOCK_TIMEOUT" ]; then
      if [ -f "$LOCK/pid" ]; then
        holder="$(cat "$LOCK/pid" 2>/dev/null)"
        if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
          echo "ledger-append: lock contention (holder pid $holder alive)" >&2
          return 1
        fi
      fi
      # stale lock (dead holder, or no pid file yet): break it and re-enter
      # the acquire loop — mkdir stays the only acquisition primitive, so of
      # any two breakers racing on the same stale lock exactly one wins.
      rm -rf "$LOCK" 2>/dev/null
      start="$(date +%s)"
      continue
    fi
    sleep 0.1
  done
  echo $$ > "$LOCK/pid"
  return 0
}

# shellcheck disable=SC2329  # invoked indirectly via `trap 'release_lock' EXIT` below
release_lock() {
  rm -rf "$LOCK" 2>/dev/null
}

# --- gather entries: stdin batch, or a single --label entry ---
LINES=()
if [ -n "$LABEL_JSON" ]; then
  echo "$LABEL_JSON" | jq -e . >/dev/null 2>&1 || { echo "ledger-append: --label argument is not valid JSON" >&2; exit 1; }
  LINES=("$(echo "$LABEL_JSON" | jq -c '. + {schema:"catch-miss/v1", source:"label"}')")
else
  while IFS= read -r rawline || [ -n "$rawline" ]; do
    [ -n "$rawline" ] || continue
    LINES+=("$rawline")
  done
fi

if [ "${#LINES[@]}" -eq 0 ]; then
  exit 0
fi

# validate ALL entries before any write — a schema-invalid line anywhere in
# the batch leaves the ledger completely unchanged (AC-18).
for ln in "${LINES[@]}"; do
  validate_line "$ln" || exit 1
done

mkdir -p "$DIR" || { echo "ledger-append: cannot create ledger dir $DIR" >&2; exit 1; }

acquire_lock || exit 1
trap 'release_lock' EXIT

# --- gitignore self-heal (AC-3), inside the lock, before any entry write ---
TOPLEVEL="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$TOPLEVEL" ]; then
  if ! git -C "$DIR" check-ignore -q "$LEDGER" 2>/dev/null; then
    GITIGNORE="$TOPLEVEL/.gitignore"
    ALREADY_PRESENT=0
    [ -f "$GITIGNORE" ] && grep -qxF '.touchstone/ledger/' "$GITIGNORE" && ALREADY_PRESENT=1
    if [ "$ALREADY_PRESENT" -eq 0 ]; then
      printf '%s\n' '.touchstone/ledger/' >> "$GITIGNORE" 2>/dev/null || {
        echo "ledger-append: cannot self-heal .gitignore ($GITIGNORE)" >&2
        exit 1
      }
    fi
  fi
fi

EXISTING_JSON="$(jq -R -s -c 'split("\n") | map(select(length>0))' <<EOF
$(jq -r 'select(.evidence != null) | .evidence[].ref' "$LEDGER" 2>/dev/null)
EOF
)"

FORCE=""
[ -n "$LABEL_JSON" ] && FORCE="force"

for ln in "${LINES[@]}"; do
  FILLED="$(fill_line "$ln" "$FORCE")"
  NEW_REFS="$(echo "$FILLED" | jq -c '[.evidence[].ref]')"
  IS_DUP="$(refs_overlap "$NEW_REFS" "$EXISTING_JSON")"
  if [ "$IS_DUP" = "true" ]; then
    continue
  fi
  printf '%s\n' "$FILLED" >> "$LEDGER"
  EXISTING_JSON="$(jq -c -n --argjson a "$EXISTING_JSON" --argjson b "$NEW_REFS" '$a + $b')"
done

exit 0
