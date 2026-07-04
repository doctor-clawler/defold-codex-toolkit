#!/bin/zsh
set -eu

SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/defold-codex-toolkit"
PLIST_TEMPLATE="$PROJECT_ROOT/launchd/com.doctorclawler.defold-codex-toolkit.latest-check.plist"
PLIST_PATH="$LAUNCH_AGENTS_DIR/com.doctorclawler.defold-codex-toolkit.latest-check.plist"
ENGINE_PLIST_TEMPLATE="$PROJECT_ROOT/launchd/com.doctorclawler.defold-engine-release-check.plist"
ENGINE_PLIST_PATH="$LAUNCH_AGENTS_DIR/com.doctorclawler.defold-engine-release-check.plist"

mkdir -p "$LAUNCH_AGENTS_DIR" "$LOG_DIR"
sed \
  -e "s|__PROJECT_ROOT__|$PROJECT_ROOT|g" \
  -e "s|__HOME__|$HOME|g" \
  "$PLIST_TEMPLATE" >"$PLIST_PATH"
sed \
  -e "s|__PROJECT_ROOT__|$PROJECT_ROOT|g" \
  -e "s|__HOME__|$HOME|g" \
  "$ENGINE_PLIST_TEMPLATE" >"$ENGINE_PLIST_PATH"

launchctl bootout "gui/$(id -u)/com.doctorclawler.defold-codex-toolkit.latest-check" >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)/com.doctorclawler.defold-engine-release-check" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
launchctl bootstrap "gui/$(id -u)" "$ENGINE_PLIST_PATH"
launchctl print "gui/$(id -u)/com.doctorclawler.defold-codex-toolkit.latest-check"
launchctl print "gui/$(id -u)/com.doctorclawler.defold-engine-release-check"
