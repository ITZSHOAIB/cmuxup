#!/usr/bin/env bash
# lib/cmux.sh — cmux socket API helpers
# Source this file: source "$(dirname "$0")/../lib/cmux.sh"

CMUX_BIN="${CMUX_BIN:-$(command -v cmux 2>/dev/null || echo /Applications/cmux.app/Contents/Resources/bin/cmux)}"
export CMUX_QUIET=1

cx() { "$CMUX_BIN" "$@"; }

# Parse the first "type:N" ref from stdin (e.g. workspace:1, surface:2).
cmux_ref() { grep -oE "$1:[0-9]+" | head -1; }

# Find the pane containing a surface, by parsing cmux tree output.
cmux_pane_of_surface() { # workspace surface
  cx tree --workspace "$1" | awk -v s="$2" '
    { for (i=1;i<=NF;i++) { if ($i ~ /^pane:[0-9]+$/) p=$i; if ($i==s) { print p; found=1 } } }
    found { exit }'
}

# Send a shell command to a surface and press Enter.
cmux_run_in() { # surface workspace command
  [ -n "${3:-}" ] || return 0
  cx send     --surface "$1" --workspace "$2" "$3"  >/dev/null
  cx send-key --surface "$1" --workspace "$2" Enter >/dev/null
}

# Wait for the cmux socket to become reachable (launches the app if needed).
cmux_ensure_running() {
  if ! cx ping >/dev/null 2>&1; then
    open -a cmux 2>/dev/null || true
    for _ in $(seq 1 30); do
      cx ping >/dev/null 2>&1 && return 0
      sleep 0.5
    done
    echo "cmux: control socket not responding" >&2
    return 1
  fi
}
