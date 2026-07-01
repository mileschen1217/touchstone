#!/usr/bin/env bash
# Offline deterministic tests for setup-otel.sh — config generation + env-block idempotency.
# Uses a stub otelcol (OTELCOL_BIN) + SETUP_SKIP_AGENT + temp paths, so no network download, no real
# collector, no launchd, and nothing outside the temp dir is touched. (The full download + live
# OTLP round-trip is verified out-of-band, not in this offline suite.)
# shellcheck disable=SC2015,SC2181
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SETUP="$REPO_ROOT/scripts/metrics/setup-otel.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# stub otelcol: satisfies the `-x` check + the `--version` call, does nothing else
STUB="$TMP/otelcol-stub"; printf '#!/bin/sh\necho "otelcol-contrib version 0.0.0-stub"\n' > "$STUB"; chmod +x "$STUB"

run() {
  OTELCOL_BIN="$STUB" SETUP_SKIP_AGENT=1 \
  SETUP_CONFIG="$TMP/config.yaml" SETUP_SINK="$TMP/sink/otel.jsonl" \
  PROFILE_FILE="$TMP/zshrc" OTEL_HTTP_PORT=14318 \
  bash "$SETUP" >/dev/null 2>&1
}

printf 'preexisting-line\n' > "$TMP/zshrc"
run; rc=$?
[ "$rc" -eq 0 ] && ok "SU-1 setup-otel exits 0 (stub otelcol, skip-agent)" || fail "SU-1 rc=$rc"

# config: the LOGS pipeline the reader consumes + file exporter → the sink path
grep -qE 'logs:.*receivers: \[otlp\].*exporters: \[file\]' "$TMP/config.yaml" \
  && ok "SU-2 config has the logs pipeline the reader consumes" || fail "SU-2 missing logs pipeline"
grep -q "path: $TMP/sink/otel.jsonl" "$TMP/config.yaml" \
  && ok "SU-3 config file exporter points at the sink" || fail "SU-3 sink path wrong"

# env block: key vars present + existing profile line preserved
grep -q "export TOUCHSTONE_OTEL_EXPORT=$TMP/sink/otel.jsonl" "$TMP/zshrc" \
  && ok "SU-4 env block sets TOUCHSTONE_OTEL_EXPORT to the sink" || fail "SU-4 TOUCHSTONE_OTEL_EXPORT missing"
grep -q "export CLAUDE_CODE_ENABLE_TELEMETRY=1" "$TMP/zshrc" \
  && ok "SU-5 env block enables CC telemetry" || fail "SU-5 telemetry env missing"
grep -q "^preexisting-line" "$TMP/zshrc" \
  && ok "SU-6 existing profile lines preserved" || fail "SU-6 existing line clobbered"

# idempotent: 3 runs → exactly one marker block
run; run
n="$(grep -c 'touchstone otel >>>' "$TMP/zshrc")"
[ "$n" = 1 ] && ok "SU-7 profile env block idempotent (exactly one after 3 runs)" || fail "SU-7 $n blocks"

echo ""; echo "PASS=$pass FAIL=$fail"; [ "$fail" -eq 0 ]
