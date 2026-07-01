#!/usr/bin/env bash
# setup-otel.sh — one-shot, idempotent setup of the OpenTelemetry collector that funnels Claude Code
# telemetry into a local JSONL sink, so metrics-report.sh (/touchstone:insight) can attribute
# CC-subagent token/cost. Does the whole install/config/run/env chain; re-running is safe.
#
# Steps: (1) resolve otelcol-contrib (or brew-install it); (2) write the collector config with the
# LOGS pipeline the reader actually consumes; (3) install + load a launchd agent (macOS) so the
# collector runs persistently; (4) append an idempotent env-var block to your shell profile.
#
# Env overrides: OTELCOL_BIN (collector binary), PROFILE_FILE (shell rc to edit), OTEL_HTTP_PORT,
# SETUP_CONFIG / SETUP_SINK / SETUP_PLIST (managed file paths), SETUP_SKIP_AGENT=1 (skip the launchd
# load — for Linux, CI, or "I'll run the collector myself"). Idempotent: managed files are overwritten
# in place; the profile block is replaced between markers.
set -uo pipefail

OTEL_HTTP_PORT="${OTEL_HTTP_PORT:-4318}"
GRPC_PORT="${OTEL_GRPC_PORT:-4317}"
CONFIG="${SETUP_CONFIG:-$HOME/.config/otelcol/config.yaml}"; CONFIG_DIR="$(dirname "$CONFIG")"
SINK="${SETUP_SINK:-$HOME/.claude/metrics/otel-export.jsonl}"; SINK_DIR="$(dirname "$SINK")"
PLIST="${SETUP_PLIST:-$HOME/Library/LaunchAgents/com.touchstone.otel.plist}"
LABEL="com.touchstone.otel"
PROFILE_FILE="${PROFILE_FILE:-$HOME/.zshrc}"
M0="# >>> touchstone otel >>>"
M1="# <<< touchstone otel <<<"

say() { printf '[setup-otel] %s\n' "$*"; }
die() { printf '[setup-otel] error: %s\n' "$*" >&2; exit 1; }

# --- 1. resolve otelcol -------------------------------------------------------------------------
# We need otelcol-CONTRIB specifically: the `file` exporter is a contrib-only component, and there
# is no Homebrew formula for it — so if it isn't already present we download the release binary for
# this OS/arch. (SETUP_BIN_DIR overrides where it lands; default ~/.local/bin.)
RELEASES=https://github.com/open-telemetry/opentelemetry-collector-releases/releases
OTELCOL="${OTELCOL_BIN:-$(command -v otelcol-contrib || true)}"
for cand in /opt/homebrew/bin/otelcol-contrib /usr/local/bin/otelcol-contrib "$HOME/.local/bin/otelcol-contrib"; do
  [ -n "$OTELCOL" ] && break
  [ -x "$cand" ] && OTELCOL="$cand"
done
if [ -z "$OTELCOL" ]; then
  os="$(uname | tr '[:upper:]' '[:lower:]')"
  case "$(uname -m)" in arm64|aarch64) arch=arm64;; x86_64|amd64) arch=amd64;; *) die "unsupported arch $(uname -m) — download otelcol-contrib manually from $RELEASES and set OTELCOL_BIN";; esac
  ver="$(curl -fsSL "https://api.github.com/repos/open-telemetry/opentelemetry-collector-releases/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1)"
  [ -n "$ver" ] || die "could not resolve latest otelcol-contrib version (network?). Download manually from $RELEASES, set OTELCOL_BIN, re-run."
  bindir="${SETUP_BIN_DIR:-$HOME/.local/bin}"; mkdir -p "$bindir"
  tgz="$(mktemp)"
  say "otelcol-contrib not found — downloading v${ver} (${os}/${arch}) → $bindir …"
  curl -fsSL "$RELEASES/download/v${ver}/otelcol-contrib_${ver}_${os}_${arch}.tar.gz" -o "$tgz" \
    || die "download failed — get it manually from $RELEASES, set OTELCOL_BIN, re-run."
  tar -xzf "$tgz" -C "$bindir" otelcol-contrib || die "extract failed"
  rm -f "$tgz"; chmod +x "$bindir/otelcol-contrib"; OTELCOL="$bindir/otelcol-contrib"
fi
[ -x "$OTELCOL" ] || die "otelcol resolved to '$OTELCOL' but it is not executable"
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
if [ -n "${SETUP_SKIP_AGENT:-}" ]; then
  say "SETUP_SKIP_AGENT set — not loading launchd. Start the collector yourself: $OTELCOL --config $CONFIG"
elif [ "$(uname)" = Darwin ]; then
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
