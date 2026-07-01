#!/usr/bin/env bash
# capture-otel-fixture.sh — produce a REAL OpenTelemetry capture of a live
# CLAUDE_CODE_ENABLE_TELEMETRY=1 Claude Code session that dispatches a subagent,
# for the metrics-capture OTel real-capture fixture (and for re-binding the real CC telemetry
# schema). Stands up otelcol once, runs a headless `claude -p` that launches one
# subagent, stops the collector, scrubs PII, and writes a fixture + provenance file.
#
# Usage: capture-otel-fixture.sh [output_jsonl]
#   output_jsonl defaults to scripts/tests/fixtures/metrics/otel-export.jsonl
#   OTELCOL_BIN env overrides the collector binary (else: otelcol-contrib on PATH).
#
# Why this exists: a raw otelcol export is NESTED OTLP JSON, and CC's real attribute
# keys are dotted (`session.id`, `agent.name`) with `query_source` of the form
# `agent:<source>:<type>` for subagents (NOT the literal `subagent`). The synthetic
# unit-test fixtures use a flattened shape; this script captures the ground truth so
# the OTel reader can be re-pointed at the real schema.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$REPO_ROOT/scripts/tests/fixtures/metrics/otel-export.jsonl}"
PROV="${OUT%.jsonl}.provenance.txt"
OTELCOL="${OTELCOL_BIN:-$(command -v otelcol-contrib || true)}"
PORT_HTTP=4318

if [ -z "$OTELCOL" ]; then
  echo "error: otelcol-contrib not found. Set OTELCOL_BIN, or install from" >&2
  echo "  https://github.com/open-telemetry/opentelemetry-collector-releases/releases (otelcol-contrib_<ver>_darwin_arm64.tar.gz)" >&2
  exit 2
fi
command -v claude >/dev/null || { echo "error: claude CLI not on PATH" >&2; exit 2; }
command -v jq >/dev/null     || { echo "error: jq not on PATH" >&2; exit 2; }

work="$(mktemp -d)"
raw="$work/otel-raw.jsonl"
cfg="$work/config.yaml"
cleanup() { [ -n "${COLL_PID:-}" ] && kill "$COLL_PID" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT

cat > "$cfg" <<YAML
receivers:
  otlp:
    protocols:
      http: { endpoint: 127.0.0.1:${PORT_HTTP} }
      grpc: { endpoint: 127.0.0.1:4317 }
processors:
  batch: { timeout: 1s }
exporters:
  file: { path: ${raw} }
service:
  telemetry: { logs: { level: warn } }
  pipelines:
    metrics: { receivers: [otlp], processors: [batch], exporters: [file] }
    logs:    { receivers: [otlp], processors: [batch], exporters: [file] }
    traces:  { receivers: [otlp], processors: [batch], exporters: [file] }
YAML

echo "[capture] starting collector ($("$OTELCOL" --version 2>&1 | head -1))" >&2
"$OTELCOL" --config "$cfg" > "$work/collector.log" 2>&1 &
COLL_PID=$!
# wait for the OTLP http endpoint to accept connections (415 = up but wrong content-type)
for _ in $(seq 1 20); do
  code="$(curl -s -o /dev/null -w '%{http_code}' -m 2 -X POST "http://127.0.0.1:${PORT_HTTP}/v1/metrics" 2>/dev/null || true)"
  [ "$code" = "415" ] || [ "$code" = "400" ] && break
  sleep 0.5
done

echo "[capture] running telemetry-enabled headless claude (launches one subagent)" >&2
CLAUDE_CODE_ENABLE_TELEMETRY=1 \
OTEL_METRICS_EXPORTER=otlp \
OTEL_LOGS_EXPORTER=otlp \
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:${PORT_HTTP}" \
OTEL_METRIC_EXPORT_INTERVAL=3000 \
OTEL_LOGS_EXPORT_INTERVAL=2000 \
  timeout 240 claude -p \
  "Use the Task tool to launch ONE general-purpose subagent whose entire job is to reply with the single word DONE. Then tell me you are finished." \
  --dangerously-skip-permissions > "$work/claude.out" 2>"$work/claude.err"
rc=$?
echo "[capture] claude exit=$rc" >&2
sleep 6   # let the batch processor flush

[ -s "$raw" ] || { echo "error: no telemetry captured (collector export empty)" >&2; cat "$work/collector.log" >&2; exit 1; }

# --- scrub PII: redact values of identity attributes anywhere in the nested structure ---
jq -c '
  def scrub: map(
    if (.key|test("email|account|user\\.id|user_id|^user\\."))
    then .value = {"stringValue":"REDACTED"} else . end);
  walk(if (type=="object" and has("attributes") and (.attributes|type=="array"))
       then .attributes |= scrub else . end)
' "$raw" > "$OUT"

# sanity: assert no obvious PII survived
if grep -qiE '@(gmail|yahoo|anthropic)\.com' "$OUT"; then
  echo "error: PII survived scrub — refusing to write fixture" >&2; rm -f "$OUT"; exit 1
fi

# --- provenance sidecar (read by the OTel real-capture test; never inside the JSONL) ---
sid="$(jq -r 'select(has("resourceLogs"))|.resourceLogs[]?.scopeLogs[]?.logRecords[]?|(.attributes//[])[]|select(.key=="session.id")|.value.stringValue' "$OUT" 2>/dev/null | head -1)"
{
  echo "# metrics-capture OTel fixture — REAL otelcol capture"
  echo "capture date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "otelcol version: $("$OTELCOL" --version 2>&1 | head -1)"
  echo "CC version: $(claude --version 2>&1 | head -1)"
  echo "CLAUDE_CODE_ENABLE_TELEMETRY=1 OTLP/http capture of a headless claude -p session that launched one subagent."
  echo ""
  echo "## Real CC telemetry schema bound by this capture (vs the synthetic flat fixtures)"
  echo "shape:          nested OTLP — resourceLogs[].scopeLogs[].logRecords[]; event name in .body.stringValue; ts = .timeUnixNano (ns)"
  echo "session-id key: session.id      (dotted attribute, NOT session_id)"
  echo "agent-name key: agent.name      (dotted attribute, NOT agent_name)"
  echo "subagent filter: query_source has the form 'agent:<source>:<type>' (e.g. agent:builtin:general-purpose) — the literal 'subagent' NEVER appears"
  echo "main-loop:      query_source = 'sdk' (headless) / 'user' (interactive)"
  echo "token/cost keys: input_tokens,output_tokens,cache_read_tokens,cache_creation_tokens (intValue); cost_usd (doubleValue); cost_usd_micros"
  echo "captured session.id: ${sid:-<none>}"
} > "$PROV"

echo "[capture] wrote $OUT ($(wc -l < "$OUT" | tr -d ' ') batches) + $PROV" >&2
echo "$OUT"
