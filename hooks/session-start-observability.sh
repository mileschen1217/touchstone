#!/usr/bin/env bash
# session-start-observability.sh — SessionStart hook: keep the OTel collector
# alive and warn (never block) when the telemetry env is missing. Output on
# stdout lands in the session context as an informational note.
#
# SAFETY CONTRACT: always exit 0; observability never blocks a session.
set -u

warn=""

# telemetry env present? Check only what child processes can SEE: CC strips the
# OTEL_* exporter vars from children (verified live 2026-07-04), so their absence
# here proves nothing — CLAUDE_CODE_ENABLE_TELEMETRY is the child-visible signal
# that the settings.json env block is applied.
if [ -z "${CLAUDE_CODE_ENABLE_TELEMETRY:-}" ]; then
  warn="telemetry env missing (CLAUDE_CODE_ENABLE_TELEMETRY not set — check the settings.json env block); subagent token capture is dark this session."
fi

# collector keepalive: if a touchstone collector is configured but not running,
# kickstart it via launchd (macOS) — best-effort, silent on failure.
if [ -n "${TOUCHSTONE_OTEL_EXPORT:-}" ]; then
  if ! pgrep -f "otelcol.*config" >/dev/null 2>&1; then
    plist="$HOME/Library/LaunchAgents/com.touchstone.otel.plist"
    if [ -f "$plist" ] && command -v launchctl >/dev/null 2>&1; then
      launchctl load "$plist" 2>/dev/null || true
      launchctl kickstart "gui/$(id -u)/com.touchstone.otel" 2>/dev/null || true
      sleep 1
      if pgrep -f "otelcol.*config" >/dev/null 2>&1; then
        echo "[touchstone] OTel collector was down — restarted via launchd."
      else
        warn="${warn:+$warn }OTel collector is not running and could not be restarted (bash scripts/metrics/setup-otel.sh to repair); subagent token capture is dark."
      fi
    else
      warn="${warn:+$warn }OTel collector is not running (no launchd agent found — run bash scripts/metrics/setup-otel.sh); subagent token capture is dark."
    fi
  fi
fi

[ -n "$warn" ] && echo "[touchstone] WARNING: $warn"
exit 0
