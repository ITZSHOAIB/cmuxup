#!/usr/bin/env bash
set -euo pipefail

# cmuxup installer
# Usage: curl -fsSL https://raw.githubusercontent.com/ITZSHOAIB/cmuxup/main/install.sh | bash
# Or:    bash install.sh [--help] [--dry-run]
#
# Non-interactive mode (for CI / testing):
#   CMUXUP_NON_INTERACTIVE=1  skip all gum prompts, use env vars below
#   CMUXUP_THEME              one of: "Catppuccin Mocha" | "TokyoNight Storm" | "Gruvbox Dark Hard" | "Kanagawa Wave"
#   CMUXUP_FONT_SIZE          13 | 14 | 15
#   CMUXUP_AGENT              claude | opencode | codex | none
#   CMUXUP_EDITOR             helix | nvim | vim
#   CMUXUP_OVERWRITE          1 = overwrite existing configs without prompting

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="0.1.0"
DRY_RUN=0

usage() {
  cat <<EOF
Usage: bash install.sh [options]

Install cmuxup: a terminal-first agentic workspace setup for cmux.

Options:
  --help, -h    Show this help message
  --dry-run     Show what would be installed without making changes

Non-interactive env vars (set CMUXUP_NON_INTERACTIVE=1):
  CMUXUP_THEME       Theme name           (default: Catppuccin Mocha)
  CMUXUP_FONT_SIZE   Font size            (default: 14)
  CMUXUP_AGENT       AI agent command     (default: claude)
  CMUXUP_EDITOR      Editor for hx tab    (default: helix)
  CMUXUP_OVERWRITE   Overwrite existing configs (default: 0)
EOF
}

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────

_log()  { echo "  $*"; }
_ok()   { echo "  ✓ $*"; }
_skip() { echo "  - $* (skipped)"; }
_dry()  { echo "  [dry-run] $*"; }

_write_file() { # dest content
  local dest="$1" content="$2"
  if [ "$DRY_RUN" -eq 1 ]; then
    _dry "would write $dest"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ] && [ "${CMUXUP_OVERWRITE:-0}" != "1" ]; then
    if [ "${CMUXUP_NON_INTERACTIVE:-0}" = "1" ]; then
      _skip "$dest already exists"
      return
    fi
    if command -v gum >/dev/null 2>&1; then
      gum confirm "Overwrite $dest?" || { _skip "$dest already exists"; return; }
    else
      _skip "$dest already exists (use CMUXUP_OVERWRITE=1 to overwrite)"
      return
    fi
  fi
  printf '%s\n' "$content" > "$dest"
  _ok "wrote $dest"
}

_apply_template() { # template_file dest theme font_size delta_theme helix_theme
  local tpl="$1" dest="$2" theme="$3" font_size="$4" delta_theme="$5" helix_theme="$6"
  local content
  content="$(sed \
    -e "s|{{THEME}}|$theme|g" \
    -e "s|{{FONT_SIZE}}|$font_size|g" \
    -e "s|{{DELTA_THEME}}|$delta_theme|g" \
    -e "s|{{HELIX_THEME}}|$helix_theme|g" \
    "$tpl")"
  _write_file "$dest" "$content"
}

_brew_install() { # formula
  if command -v "$1" >/dev/null 2>&1; then
    _skip "$1 already installed"
    return
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    _dry "would brew install $1"
    return
  fi
  if command -v gum >/dev/null 2>&1; then
    gum spin --spinner dot --title "Installing $1..." -- brew install "$1"
  else
    brew install "$1"
  fi
  _ok "installed $1"
}

# ── Map theme name to variants used by different tools ────────────────────────
_theme_variants() { # theme_name → sets DELTA_THEME and HELIX_THEME
  case "$1" in
    "Catppuccin Mocha") DELTA_THEME="Catppuccin Mocha"; HELIX_THEME="catppuccin_mocha" ;;
    "TokyoNight Storm") DELTA_THEME="TwoDark";          HELIX_THEME="dark_plus" ;;
    "Gruvbox Dark Hard") DELTA_THEME="gruvbox-dark";    HELIX_THEME="gruvbox_dark_hard" ;;
    "Kanagawa Wave")    DELTA_THEME="Nord";              HELIX_THEME="catppuccin_mocha" ;;
    *)                  DELTA_THEME="Catppuccin Mocha"; HELIX_THEME="catppuccin_mocha" ;;
  esac
}

# ── Preflight ─────────────────────────────────────────────────────────────────

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew is required. Install it from https://brew.sh then re-run." >&2
  exit 1
fi

# Bootstrap gum for the interactive UI (skip in dry-run or non-interactive).
if [ "${CMUXUP_NON_INTERACTIVE:-0}" != "1" ] && [ "$DRY_RUN" -eq 0 ]; then
  if ! command -v gum >/dev/null 2>&1; then
    echo "Installing gum for the interactive UI..."
    brew install gum >/dev/null 2>&1
  fi
fi

# ── Gather choices ────────────────────────────────────────────────────────────

if [ "${CMUXUP_NON_INTERACTIVE:-0}" = "1" ] || [ "$DRY_RUN" -eq 1 ]; then
  THEME="${CMUXUP_THEME:-Catppuccin Mocha}"
  FONT_SIZE="${CMUXUP_FONT_SIZE:-14}"
  AGENT="${CMUXUP_AGENT:-claude}"
  EDITOR_CHOICE="${CMUXUP_EDITOR:-helix}"
else
  if command -v gum >/dev/null 2>&1; then
    gum style \
      --border double --border-foreground 212 \
      --padding "1 4" --margin "1 0" \
      --bold "cmuxup v${VERSION}" \
      "Terminal-first agentic workspace for cmux"

    THEME="$(gum choose --header "Choose your theme:" \
      "Catppuccin Mocha" "TokyoNight Storm" "Gruvbox Dark Hard" "Kanagawa Wave")"

    FONT_SIZE="$(gum choose --header "Font size:" "14" "13" "15")"

    AGENT="$(gum choose --header "AI agent for main pane:" \
      "claude" "opencode" "codex" "none")"

    EDITOR_CHOICE="$(gum choose --header "Editor tab:" "helix" "nvim" "vim")"

    gum confirm "Ready to install with these settings?" || { echo "Aborted."; exit 0; }
  else
    THEME="Catppuccin Mocha"
    FONT_SIZE="14"
    AGENT="claude"
    EDITOR_CHOICE="helix"
  fi
fi

_theme_variants "$THEME"

# ── Install tools ─────────────────────────────────────────────────────────────

echo ""
_log "Installing tools..."
_brew_install lazygit
_brew_install git-delta
_brew_install helix
_brew_install yazi
_brew_install starship
_brew_install zoxide
_brew_install bat
_brew_install fd
_brew_install ripgrep

# ── Write configs ─────────────────────────────────────────────────────────────

echo ""
_log "Writing configs (theme: $THEME, font: $FONT_SIZE, agent: $AGENT, editor: $EDITOR_CHOICE)..."

TEMPLATES="$SCRIPT_DIR/templates"

_apply_template "$TEMPLATES/ghostty.config"      "${HOME}/.config/ghostty/config"      "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"
_apply_template "$TEMPLATES/helix.toml"          "${HOME}/.config/helix/config.toml"   "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"
_apply_template "$TEMPLATES/lazygit.yml"         "${HOME}/Library/Application Support/lazygit/config.yml" "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"
_apply_template "$TEMPLATES/yazi.toml"           "${HOME}/.config/yazi/yazi.toml"      "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"
_apply_template "$TEMPLATES/starship.toml"       "${HOME}/.config/starship.toml"       "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"
_apply_template "$TEMPLATES/gitconfig-delta.ini" "${TMPDIR:-/tmp}/cmuxup-gitdelta.ini" "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"

# Merge delta git config (non-destructive: only sets keys not already present).
if [ "$DRY_RUN" -eq 0 ]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^\[.*\]$ || -z "$line" ]] && continue
    key="$(echo "$line" | sed 's/ *= *.*//' | xargs)"
    val="$(echo "$line" | sed 's/.*= *//' | xargs)"
    section=""
    # We'll use git config --global directly.
    true
  done < "${TMPDIR:-/tmp}/cmuxup-gitdelta.ini"
  git config --global core.pager "delta"
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.navigate true
  git config --global delta.dark true
  git config --global delta.side-by-side true
  git config --global delta.line-numbers true
  git config --global delta.syntax-theme "$DELTA_THEME"
  git config --global merge.conflictstyle zdiff3
  _ok "configured git delta"
else
  _dry "would configure git delta"
fi

# Write cmux.json settings if not already customized.
CMUX_JSON="${HOME}/.config/cmux/cmux.json"
if [ -f "$CMUX_JSON" ] && grep -q '"diffViewer"' "$CMUX_JSON" 2>/dev/null; then
  _skip "cmux.json already has cmuxup settings"
else
  _apply_template "$TEMPLATES/cmux-settings.jsonc" "$CMUX_JSON" "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"
fi

# ── Install cmuxup command ────────────────────────────────────────────────────

echo ""
_log "Installing cmuxup command..."
INSTALL_DIR="${HOME}/.local/bin"
if [ "$DRY_RUN" -eq 1 ]; then
  _dry "would install cmuxup to $INSTALL_DIR/cmuxup"
else
  mkdir -p "$INSTALL_DIR"
  cp "$SCRIPT_DIR/bin/cmuxup" "$INSTALL_DIR/cmuxup"
  chmod +x "$INSTALL_DIR/cmuxup"
  _ok "installed cmuxup to $INSTALL_DIR/cmuxup"
fi

# ── Shell integration ─────────────────────────────────────────────────────────

ZSHRC="${HOME}/.zshrc"
SHELL_BLOCK='
# ── cmuxup shell integration ──────────────────────────────────────────
export EDITOR="hx"
export VISUAL="hx"
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
function y() {
  local tmp cwd
  tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}
alias lg="lazygit"
alias e="hx"
# ── end cmuxup ─────────────────────────────────────────────────────────'

if [ "$DRY_RUN" -eq 1 ]; then
  _dry "would append shell integration to $ZSHRC"
elif grep -q "cmuxup shell integration" "$ZSHRC" 2>/dev/null; then
  _skip "shell integration already in $ZSHRC"
else
  echo "$SHELL_BLOCK" >> "$ZSHRC"
  _ok "added shell integration to $ZSHRC"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
if command -v gum >/dev/null 2>&1 && [ "$DRY_RUN" -eq 0 ] && [ "${CMUXUP_NON_INTERACTIVE:-0}" != "1" ]; then
  gum style --foreground 212 --bold "cmuxup is ready."
  gum style "Open a new shell and run: cmuxup ~/your-project"
else
  echo "cmuxup is ready."
  echo "Open a new shell and run: cmuxup ~/your-project"
fi
