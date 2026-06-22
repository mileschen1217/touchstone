#!/usr/bin/env bash
# Deterministic acceptance check for the keystone refactor. Exit 0 = complete.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
fail=0
err() { echo "FAIL: $*" >&2; fail=1; }
SELF='scripts/tests/keystone-refactor-checks.sh'

# --- AC-1: keystone dir + frontmatter name; arch-review gone ---
[ -f skills/keystone/SKILL.md ]        || err "AC-1 skills/keystone/SKILL.md missing"
[ -f skills/keystone/README.md ]       || err "AC-1 skills/keystone/README.md missing"
[ -f skills/keystone/adr-authoring.md ]|| err "AC-1 skills/keystone/adr-authoring.md missing"
[ -d skills/arch-review ]              && err "AC-1 skills/arch-review/ still exists"
if [ -f skills/keystone/SKILL.md ]; then
  name_ok=$(python3 - <<'PY'
import sys,yaml
lines=open("skills/keystone/SKILL.md",encoding="utf-8").read().split("\n")
# frontmatter MUST begin at line 1 (line-1-anchored — leading text before a later --- must NOT pass)
if not lines or lines[0].strip()!="---":
    print("BAD"); sys.exit()
end=next((i for i in range(1,len(lines)) if lines[i].strip()=="---"), None)
if end is None:
    print("BAD"); sys.exit()
block=lines[1:end]
try:
    fm=yaml.safe_load("\n".join(block))
except Exception:
    print("ERR"); sys.exit()
# reject duplicate name keys: count raw 'name:' lines in the frontmatter block only
n=sum(1 for l in block if l.strip().startswith("name:"))
print("OK" if isinstance(fm,dict) and fm.get("name")=="keystone" and n==1 else "BAD")
PY
)
  [ "$name_ok" = OK ] || err "AC-1 frontmatter name is not exactly one key == keystone"
fi

# --- AC-9: body lines >=30, whole-file <=80 ---
if [ -f skills/keystone/SKILL.md ]; then
  whole=$(wc -l < skills/keystone/SKILL.md)
  body=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{f=0;b=1;next} b{c++} END{print c+0}' skills/keystone/SKILL.md)
  [ "$whole" -le 80 ] || err "AC-9 whole-file $whole > 80"
  [ "$body"  -ge 30 ] || err "AC-9 body $body < 30"
fi

# --- AC-5: arch-discovery dir gone ---
[ -d skills/arch-discovery ] && err "AC-5 skills/arch-discovery/ still exists"

# --- AC-6: zero arch-discovery in tracked files (excl docs/adr + this script) ---
# -z for filename safety; grep -Fl (fixed-string, NO -I — a binary carrying the token must
# still be caught, not silently skipped as -I would do)
sweep() { # $1 = literal token; prints tracked files (minus docs/adr + SELF) containing it
  git ls-files -z | while IFS= read -r -d '' f; do
    case "$f" in docs/adr/*|"$SELF") continue;; esac
    grep -Fl "$1" "$f"
  done
}
disc=$(sweep 'arch-discovery')
[ -z "$disc" ] || err "AC-6 arch-discovery still referenced in: $disc"

# --- AC-10: zero arch-review (excl docs/adr + this script) + positive per-consumer keystone ---
ar=$(sweep 'arch-review')
[ -z "$ar" ] || err "AC-10 arch-review still referenced in: $ar"
for c in README.md CONTEXT.md agents/codex-adversarial-reviewer.md scripts/migration-audit.sh \
         skills/_shared/inject/bridge-content-gate.md skills/_shared/inject/standing-vs-transient-bridge.md \
         skills/cross-provider-architect/SKILL.md skills/cross-provider-reviewer/SKILL.md \
         skills/code-review/README.md skills/design-spec/README.md \
         skills/design-spec/references/architect-dispatch.md; do
  [ -f "$c" ] || { err "AC-10 consumer $c missing"; continue; }
  grep -qw keystone "$c" || err "AC-10 consumer $c lacks whole-word keystone"
done

# --- AC-7: design-review discovery capability removed + positive scope set ---
DR=skills/design-review/SKILL.md
[ -f "$DR" ] || err "AC-7 $DR missing (cannot false-green by deletion)"
if [ -f "$DR" ]; then
  neg=$(grep -nE 'type:[[:space:]]*discovery|\*-discovery\.md|discovery system prompt|For discovery doc|/touchstone:arch-discovery' "$DR")
  [ -z "$neg" ] || err "AC-7 residual discovery token in design-review: $neg"
  kinds=$(grep '→ in scope' "$DR" | grep -oE 'type: [a-z]+' | sed 's/type: //' | sort -u | tr '\n' ',')
  [ "$kinds" = "adr,plan,spec," ] || err "AC-7 scope-in kinds != {spec,plan,adr}: '$kinds'"
  pc=$(grep -c 'You are reviewing an authored design document' "$DR")
  [ "$pc" = 1 ] || err "AC-7 doc-review prompt first line count = $pc (want 1)"
fi

# --- AC-11: exactly 4 arch-review in docs/adr (excl 0018/0019); each same-line (now keystone) ---
adr_lines=$(grep -rn 'arch-review' docs/adr/ | grep -vE '/001[89]-')
cnt=$(printf '%s\n' "$adr_lines" | grep -c . )
[ "$cnt" -eq 4 ] || err "AC-11 expected exactly 4 non-exempt arch-review lines, got $cnt"
miss=$(printf '%s\n' "$adr_lines" | grep -v '(now keystone)')
[ -z "$miss" ] || err "AC-11 arch-review line(s) missing (now keystone): $miss"

# --- AC-13: runner exists + literal-free + CLAUDE.md registration + propagation ---
[ -f scripts/tests/run-all.sh ] || err "AC-13 run-all.sh missing"
if [ -f scripts/tests/run-all.sh ]; then
  grep -qE 'arch-review|arch-discovery' scripts/tests/run-all.sh && err "AC-13 run-all.sh carries an arch literal"
  # Propagation probe WITHOUT recursion: copy the COMMITTED run-all.sh into a temp dir
  # alongside one always-fail stub and run it there (the temp dir does NOT contain this
  # check, so no infinite recursion). A runner that swallows failures exits 0 here → fail.
  tmp=$(mktemp -d)
  cp scripts/tests/run-all.sh "$tmp/run-all.sh"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/_probe_fail.sh"
  if ( cd "$tmp" && bash run-all.sh >/dev/null 2>&1 ); then
    err "AC-13 committed run-all.sh does NOT propagate a sub-check failure"
  fi
  rm -rf "$tmp"
fi
# require an actual invocation line, not just a path mention
grep -qE 'bash[[:space:]]+scripts/tests/run-all\.sh' CLAUDE.md \
  || err "AC-13 CLAUDE.md does not register an invocation of run-all.sh"

# --- AC-14: standing ADRs present (exactly one per prefix), Accepted + kill-on in
#           FRONTMATTER (not body), self-contained ---
for pref in 0018 0019; do
  # shellcheck disable=SC2086
  set -- docs/adr/${pref}-*.md
  if [ ! -e "$1" ]; then err "AC-14 docs/adr/${pref}-*.md missing"; continue; fi
  if [ "$#" -ne 1 ]; then err "AC-14 multiple docs/adr/${pref}-*.md ($*)"; continue; fi
  adr="$1"
  ok=$(python3 - "$adr" <<'PY'
import sys,yaml
lines=open(sys.argv[1],encoding="utf-8").read().split("\n")
# frontmatter MUST begin at line 1 (leading body text before a later --- must NOT pass)
if not lines or lines[0].strip()!="---":
    print("BAD"); sys.exit()
end=next((i for i in range(1,len(lines)) if lines[i].strip()=="---"), None)
if end is None:
    print("BAD"); sys.exit()
fm=yaml.safe_load("\n".join(lines[1:end]))
ok = isinstance(fm,dict) and str(fm.get("status","")).lower()=="accepted" and bool(fm.get("kill-on"))
print("OK" if ok else "BAD")
PY
)
  [ "$ok" = OK ] || err "AC-14 $adr frontmatter must have status: Accepted + kill-on:"
  leak=$(grep -nE '\.touchstone/|AC-[0-9]+|Task [0-9]+' "$adr")
  [ -z "$leak" ] || err "AC-14 $adr leaks local-only ref: $leak"
done

[ "$fail" = 0 ] && echo "keystone-refactor-checks: PASS"
exit "$fail"
