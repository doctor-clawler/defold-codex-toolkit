#!/bin/sh
set -eu

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/defold-helper"
CACHE_FILE="$CACHE_DIR/llms-full.txt"
DOC_URL="https://defold.com/llms-full.txt"

usage() {
  cat <<'EOF'
Usage:
  defold-docs.sh fetch
  defold-docs.sh search <term>
  defold-docs.sh context <line> [radius]
EOF
}

fetch_docs() {
  mkdir -p "$CACHE_DIR"
  curl -fsSL "$DOC_URL" -o "$CACHE_FILE"
  printf '%s\n' "$CACHE_FILE"
}

ensure_cache() {
  if [ ! -f "$CACHE_FILE" ]; then
    fetch_docs >/dev/null
  fi
}

search_docs() {
  if [ "$#" -lt 1 ]; then
    usage >&2
    exit 1
  fi

  ensure_cache
  pattern="$*"
  grep -n -i -- "$pattern" "$CACHE_FILE" | head -n 20
}

context_docs() {
  if [ "$#" -lt 1 ]; then
    usage >&2
    exit 1
  fi

  ensure_cache
  line="$1"
  radius="${2:-20}"

  case "$line" in
    ''|*[!0-9]*)
      printf 'line must be a positive integer\n' >&2
      exit 1
      ;;
  esac

  case "$radius" in
    ''|*[!0-9]*)
      printf 'radius must be a positive integer\n' >&2
      exit 1
      ;;
  esac

  start=$((line - radius))
  if [ "$start" -lt 1 ]; then
    start=1
  fi
  end=$((line + radius))

  sed -n "${start},${end}p" "$CACHE_FILE"
}

command_name="${1:-}"
if [ "$#" -gt 0 ]; then
  shift
fi

case "$command_name" in
  fetch)
    fetch_docs
    ;;
  search)
    search_docs "$@"
    ;;
  context)
    context_docs "$@"
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
