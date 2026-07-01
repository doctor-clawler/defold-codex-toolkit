#!/bin/zsh
set -eu

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

USER_HOME="${HOME:-/Users/$(id -un)}"
PROJECT_ROOT="${DEFOLD_TOOLKIT_REPO:-/Volumes/BigHugeMemory/works/defold-helper-marketplace}"
LOG_DIR="$USER_HOME/Library/Logs/defold-codex-toolkit"
PYTHON_BIN="${DEFOLD_TOOLKIT_PYTHON_BIN:-/opt/homebrew/bin/python3}"

mkdir -p "$LOG_DIR"
exec >>"$LOG_DIR/latest-check.stdout.log" 2>>"$LOG_DIR/latest-check.stderr.log"

if [ ! -x "$PYTHON_BIN" ]; then
  PYTHON_BIN="$(command -v python3 || true)"
fi

if [ -z "$PYTHON_BIN" ] || [ ! -x "$PYTHON_BIN" ]; then
  printf '[latest-check] python3 executable not found\n' >&2
  exit 127
fi

if [ ! -f "$PROJECT_ROOT/scripts/check_latest_and_update.py" ]; then
  printf '[latest-check] script not found under %s\n' "$PROJECT_ROOT" >&2
  exit 1
fi

printf '[latest-check] %s starting repo=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$PROJECT_ROOT"
cd "$PROJECT_ROOT"
exec "$PYTHON_BIN" "$PROJECT_ROOT/scripts/check_latest_and_update.py"
