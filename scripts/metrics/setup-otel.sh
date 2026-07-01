#!/usr/bin/env bash
# setup-otel.sh — one-shot, idempotent setup of the OpenTelemetry collector that funnels Claude Code
# telemetry into a local JSONL sink, so metrics-report.sh (/touchstone:insight) can attribute
# CC-subagent token/cost. Does the whole install/config/run/env chain; re-running is safe.
#
# Steps: (1) resolve otelcol-contrib (or brew-install it); (2) write the collector config with the
# LOGS pipeline the reader actually consumes; (3) install + load a launchd agent (macOS) so the
# collector runs persistently; (4) append an idempotent env-var block to your shell profile.
#
# Env overrides: OTELCOL_BIN (collector binary), PROFILE_FILE (shell rc to edit), OTEL_HTTP_PORT.
# Idempotent: managed files are overwritten in place, the profile block is replaced between markers.
set -uo pipefail

OTEL_HTTP_PORT="${OTEL_HTTP_PORT:-4318}"
GRPC_PORT=4317
CONFIG_DIR="$HOME/.config/otelcol"
CONFIG="$CONFIG_DIR/config.yaml"
SINK_DIR="$HOME/.claude/metrics"
SINK="$SINK_DIR/otel-export.jsonl"
PLIST="$HOME/Library/LaunchAgents/com.touchstone.otel.plist"
LABEL="com.touchstone.otel"
PROFILE_FILE="${PROFILE_FILE:-$HOME/.zshrc}"
M0="# >>> touchstone otel >>>"
M1="# <<< touchstone otel <<<"

say() { printf '[setup-otel] %s\n' "$*"; }
die() { printf '[setup-otel] error: %s\n' "$*" >&2; exit 1; }

# --- 1. resolve otelcol ---------------------------------------------------------------------------
OTELCOL="${OTELCOL_BIN:-$(command -v otelcol-contrib || command -v otelcol || true)}"
if [ -z "$OTELCOL" ]; then
  if command -v brew >/dev/null 2>&1; then
    say "otelcol not found — installing via brew (otelcol-contrib)…"
    brew install otelcol-contrib || die "brew install otelcol-contrib failed — install manually, then re-run"
    OTELCOL="$(command -v otelcol-contrib || command -v otelcol || true)"
  fi
fi
[ -n "$OTELCOL" ] || die "otelcol-contrib not found and brew unavailable. Download the darwin build from
  https://github.com/open-telemetry/opentelemetry-collector-releases/releases
  put it on PATH (or set OTELCOL_BIN=/path/to/otelcol-contrib), then re-run."
say "otelcol: $OTELCOL ($("$OTELCOL" --version 2>&1 | head -1))"

# --- 2. write config (LOGS pipeline is what metrics-report.sh reads; metrics/traces harmless) ------
mkdir -p "$CONFIG_DIR" "$SINK_DIR"
cat > "$CONFIG" <<YAML
receivers:
  otlp:
    protocols:
      http: { endpoint: 127.0.0.1:${OTEL_HTTP_PORT} }
      grpc: { endpoint: 127.0.0.1:${GRPC_PORT} }
processors:
  batch: { timeout: 1s }
exporters:
  file: { path: ${SINK} }
service:
  telemetry: { logs: { level: warn } }
  pipelines:
    logs:    { receivers: [otlp], processors: [batch], exporters: [file] }
    metrics: { receivers: [otlp], processors: [batch], exporters: [file] }
    traces:  { receivers: [otlp], processors: [batch], exporters: [file] }
YAML
say "wrote $CONFIG (sink → $SINK)"

# --- 3. launchd agent (macOS) -> persistent collector ---------------------------------------------
if [ "$(uname)" = Darwin ]; then
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>              <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${OTELCOL}</string>
    <string>--config</string>
    <string>${CONFIG}</string>
  </array>
  <key>RunAtLoad</key>          <true/>
  <key>KeepAlive</key>          <true/>
  <key>StandardOutPath</key>    <string>/tmp/touchstone-otel.log</string>
  <key>StandardErrorPath</key>  <string>/tmp/touchstone-otel.err</string>
</dict>
</plist>
PLIST
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load "$PLIST" 2>/dev/null || die "launchctl load failed — check /tmp/touchstone-otel.err"
  say "launchd agent $LABEL loaded (logs: /tmp/touchstone-otel.log)"
else
  say "non-macOS: run the collector yourself → $OTELCOL --config $CONFIG"
fi

# --- 4. env vars (idempotent block in the shell profile) ------------------------------------------
touch "$PROFILE_FILE"
tmp="$(mktemp)"
awk -v m0="$M0" -v m1="$M1" '
  $0==m0 {skip=1} !skip {print} $0==m1 {skip=0}' "$PROFILE_FILE" > "$tmp"
{
  cat "$tmp"
  echo "$M0"
  echo "export CLAUDE_CODE_ENABLE_TELEMETRY=1"
  echo "export OTEL_METRICS_EXPORTER=otlp"
  echo "export OTEL_LOGS_EXPORTER=otlp"
  echo "export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf"
  echo "export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:${OTEL_HTTP_PORT}"
  echo "export TOUCHSTONE_OTEL_EXPORT=${SINK}"
  echo "$M1"
} > "$PROFILE_FILE"
rm -f "$tmp"
say "wrote env block to $PROFILE_FILE (TOUCHSTONE_OTEL_EXPORT=$SINK)"

say "done. Open a NEW shell (or 'source $PROFILE_FILE') so telemetry env vars take effect,"
say "then run touchstone gates and read the report with /touchstone:insight."
