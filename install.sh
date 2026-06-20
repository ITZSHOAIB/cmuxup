#!/usr/bin/env bash
set -euo pipefail

# cmuxup installer
# Usage: curl -fsSL https://raw.githubusercontent.com/ITZSHOAIB/cmuxup/main/install.sh | bash
# Or:    bash install.sh [--help] [--dry-run]
#
# Non-interactive mode (for CI / testing):
#   CMUXUP_NON_INTERACTIVE=1
#   CMUXUP_THEME       "Catppuccin Mocha" | "TokyoNight Storm" | "Gruvbox Dark Hard" | "Kanagawa Wave"
#   CMUXUP_FONT_SIZE   13 | 14 | 15
#   CMUXUP_AGENT       claude | opencode | codex | none
#   CMUXUP_LAZYGIT     1 | 0   (install lazygit)
#   CMUXUP_EDITOR      helix | nvim | vim | none
#   CMUXUP_EXTRAS      space-separated: "yazi bat fd ripgrep"
#   CMUXUP_OVERWRITE   1 = overwrite existing configs without prompting

VERSION="0.1.0"
DRY_RUN=0
REPO="ITZSHOAIB/cmuxup"
BRANCH="main"

# When piped via stdin (curl ... | bash), BASH_SOURCE[0] is unset and template
# files are unavailable. Download the repo tarball and re-exec from a real file.
_SELF="${BASH_SOURCE[0]:-}"
if [[ -z "$_SELF" || "$_SELF" == "bash" || "$_SELF" == "-bash" ]]; then
  _TMP="$(mktemp -d)"
  trap 'rm -rf "$_TMP"' EXIT
  echo "Downloading cmuxup..."
  curl -fsSL "https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz" \
    | tar -xz -C "$_TMP" --strip-components=1
  # Restore /dev/tty as stdin so gum interactive prompts work after pipe exhaustion.
  exec bash "$_TMP/install.sh" "$@" </dev/tty
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: bash install.sh [options]

Install cmuxup: a terminal-first agentic workspace setup for cmux.

Options:
  --help, -h    Show this help message
  --dry-run     Show what would be installed without making changes

Non-interactive env vars (set CMUXUP_NON_INTERACTIVE=1):
  CMUXUP_THEME       Theme name             (default: Catppuccin Mocha)
  CMUXUP_FONT_SIZE   Font size              (default: 14)
  CMUXUP_AGENT       AI agent command       (default: claude)
  CMUXUP_LAZYGIT     Install lazygit        (default: 1)
  CMUXUP_EDITOR      Editor: helix/nvim/vim/none  (default: helix)
  CMUXUP_EXTRAS      Space-separated extras (default: "yazi bat fd ripgrep")
  CMUXUP_OVERWRITE   Overwrite existing configs   (default: 0)
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
  if [ "$DRY_RUN" -eq 1 ]; then _dry "would write $dest"; return; fi
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ] && [ "${CMUXUP_OVERWRITE:-0}" != "1" ]; then
    _skip "$dest already exists"; return
  fi
  printf '%s\n' "$content" > "$dest"
  _ok "wrote $dest"
}

_apply_template() { # template_file dest theme font_size delta_theme helix_theme
  local content
  content="$(sed \
    -e "s|{{THEME}}|$3|g" \
    -e "s|{{FONT_SIZE}}|$4|g" \
    -e "s|{{DELTA_THEME}}|$5|g" \
    -e "s|{{HELIX_THEME}}|$6|g" \
    "$1")"
  _write_file "$2" "$content"
}

_brew_install() { # formula [binary]
  local formula="$1" binary="${2:-$1}"
  if command -v "$binary" >/dev/null 2>&1; then
    _skip "$formula already installed"; return
  fi
  if [ "$DRY_RUN" -eq 1 ]; then _dry "would brew install $formula"; return; fi
  if command -v gum >/dev/null 2>&1; then
    gum spin --spinner dot --title "Installing $formula..." -- brew install "$formula"
  else
    brew install "$formula"
  fi
  _ok "installed $formula"
}

_theme_variants() {
  case "$1" in
    "Catppuccin Mocha")  DELTA_THEME="Catppuccin Mocha"; HELIX_THEME="catppuccin_mocha"  ;;
    "TokyoNight Storm")  DELTA_THEME="TwoDark";          HELIX_THEME="dark_plus"          ;;
    "Gruvbox Dark Hard") DELTA_THEME="gruvbox-dark";     HELIX_THEME="gruvbox_dark_hard"  ;;
    "Kanagawa Wave")     DELTA_THEME="Nord";              HELIX_THEME="catppuccin_mocha"   ;;
    *)                   DELTA_THEME="Catppuccin Mocha"; HELIX_THEME="catppuccin_mocha"   ;;
  esac
}

# ── Preflight ─────────────────────────────────────────────────────────────────

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew is required. Install it from https://brew.sh" >&2; exit 1
fi

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
  INSTALL_LAZYGIT="${CMUXUP_LAZYGIT:-1}"
  EDITOR_CHOICE="${CMUXUP_EDITOR:-helix}"
  IFS=' ' read -r -a EXTRAS <<< "${CMUXUP_EXTRAS:-yazi bat fd ripgrep}"
else
  gum style \
    --border double --border-foreground 212 \
    --padding "1 4" --margin "1 0" \
    --bold --foreground 212 \
    "  cmuxup v${VERSION}  " \
    "Terminal-first agentic workspace for cmux"

  THEME="$(gum choose --header "Theme:" \
    "Catppuccin Mocha" "TokyoNight Storm" "Gruvbox Dark Hard" "Kanagawa Wave")"

  FONT_SIZE="$(gum choose --header "Font size:" "14" "13" "15")"

  AGENT="$(gum choose --header "AI agent (main pane):" \
    "claude" "opencode" "codex" "none")"

  if gum confirm "Install lazygit? (git TUI for the right-top pane)"; then
    INSTALL_LAZYGIT=1
  else
    INSTALL_LAZYGIT=0
  fi

  EDITOR_CHOICE="$(gum choose --header "Editor tab (right-top pane):" \
    "helix" "nvim" "vim" "none")"

  echo ""
  _log "Select optional extras (space to toggle, enter to confirm):"
  EXTRAS_RAW="$(gum choose --no-limit \
    --selected="yazi,bat,fd,ripgrep" \
    --header "Optional tools:" \
    "yazi (file manager)" \
    "bat (better cat)" \
    "fd (better find)" \
    "ripgrep (better grep)" \
    || true)"

  # Extract just the tool names from "yazi (file manager)" → "yazi"
  EXTRAS=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    EXTRAS+=("$(echo "$line" | awk '{print $1}')")
  done <<< "$EXTRAS_RAW"

  echo ""
  gum confirm "Ready to install?" || { echo "Aborted."; exit 0; }
fi

_theme_variants "$THEME"

# ── Ask once about overwriting existing configs ───────────────────────────────
if [ "${CMUXUP_NON_INTERACTIVE:-0}" != "1" ] && [ "$DRY_RUN" -eq 0 ] && [ "${CMUXUP_OVERWRITE:-0}" != "1" ]; then
  _EXISTING=()
  for f in "${HOME}/.config/ghostty/config" "${HOME}/.config/helix/config.toml" \
            "${HOME}/Library/Application Support/lazygit/config.yml" \
            "${HOME}/.config/yazi/yazi.toml"; do
    [ -f "$f" ] && _EXISTING+=("$f")
  done
  if [ "${#_EXISTING[@]}" -gt 0 ]; then
    echo ""
    _log "${#_EXISTING[@]} config file(s) already exist."
    if command -v gum >/dev/null 2>&1; then
      gum confirm "Overwrite existing configs?" && CMUXUP_OVERWRITE=1 || CMUXUP_OVERWRITE=0
    fi
  fi
fi

# ── Install core tools (always required) ─────────────────────────────────────

echo ""
_log "Installing core tools..."
_brew_install git-delta delta
_brew_install zoxide

# ── Install optional: lazygit ─────────────────────────────────────────────────

if [ "${INSTALL_LAZYGIT}" = "1" ]; then
  _brew_install lazygit
fi

# ── Install optional: editor ──────────────────────────────────────────────────

case "$EDITOR_CHOICE" in
  helix) _brew_install helix hx ;;
  nvim)  _brew_install neovim nvim ;;
  vim)   command -v vim >/dev/null 2>&1 || _brew_install vim ;;
esac

# ── Install optional extras ───────────────────────────────────────────────────

for tool in "${EXTRAS[@]:-}"; do
  case "$tool" in
    yazi)    _brew_install yazi ;;
    bat)     _brew_install bat ;;
    fd)      _brew_install fd ;;
    ripgrep) _brew_install ripgrep rg ;;
  esac
done

# ── Write configs ─────────────────────────────────────────────────────────────

echo ""
_log "Writing configs..."

TEMPLATES="$SCRIPT_DIR/templates"

_apply_template "$TEMPLATES/ghostty.config" \
  "${HOME}/.config/ghostty/config" \
  "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"

if [ "$EDITOR_CHOICE" = "helix" ]; then
  _apply_template "$TEMPLATES/helix.toml" \
    "${HOME}/.config/helix/config.toml" \
    "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"
fi

if [ "${INSTALL_LAZYGIT}" = "1" ]; then
  _apply_template "$TEMPLATES/lazygit.yml" \
    "${HOME}/Library/Application Support/lazygit/config.yml" \
    "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"
fi

if echo "${EXTRAS[*]:-}" | grep -qw "yazi"; then
  _apply_template "$TEMPLATES/yazi.toml" \
    "${HOME}/.config/yazi/yazi.toml" \
    "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"
fi

# Wire delta into git.
_apply_template "$TEMPLATES/gitconfig-delta.ini" \
  "${TMPDIR:-/tmp}/cmuxup-gitdelta.ini" \
  "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"

if [ "$DRY_RUN" -eq 0 ]; then
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

# cmux.json settings.
CMUX_JSON="${HOME}/.config/cmux/cmux.json"
if [ -f "$CMUX_JSON" ] && grep -q '"diffViewer"' "$CMUX_JSON" 2>/dev/null; then
  _skip "cmux.json already has cmuxup settings"
else
  _apply_template "$TEMPLATES/cmux-settings.jsonc" "$CMUX_JSON" \
    "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"
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

# Resolve editor binary for EDITOR env var.
case "$EDITOR_CHOICE" in
  helix) _EDITOR_BIN="hx" ;;
  nvim)  _EDITOR_BIN="nvim" ;;
  vim)   _EDITOR_BIN="vim" ;;
  *)     _EDITOR_BIN="" ;;
esac

# Build env overrides for cmuxup command defaults.
# Build the shell integration block line by line to avoid set -e on empty conditionals.
_SB=()
_SB+=("# ── cmuxup shell integration ──────────────────────────────────────────")
[ -n "$_EDITOR_BIN" ] && _SB+=("export EDITOR=\"$_EDITOR_BIN\"") || true
[ -n "$_EDITOR_BIN" ] && _SB+=("export VISUAL=\"$_EDITOR_BIN\"") || true
[ "$AGENT" != "none" ] && _SB+=("export CMUXUP_MAIN_CMD=\"$AGENT\"") || true
[ "${INSTALL_LAZYGIT}" = "1" ] && _SB+=('export CMUXUP_LG_CMD="lazygit"') || true
case "$EDITOR_CHOICE" in
  helix) _SB+=('export CMUXUP_HX_CMD="hx ."') ;;
  nvim)  _SB+=('export CMUXUP_HX_CMD="nvim ."') ;;
  vim)   _SB+=('export CMUXUP_HX_CMD="vim ."') ;;
  none)  _SB+=('export CMUXUP_HX_CMD=""') ;;
esac
_SB+=('eval "$(zoxide init zsh)"')

# Add yazi shell function if installed.
if echo "${EXTRAS[*]:-}" | grep -qw "yazi"; then
  _SB+=('function y() {')
  _SB+=('  local tmp cwd')
  _SB+=('  tmp="$(mktemp -t yazi-cwd.XXXXXX)"')
  _SB+=('  yazi "$@" --cwd-file="$tmp"')
  _SB+=('  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then')
  _SB+=('    builtin cd -- "$cwd"')
  _SB+=('  fi')
  _SB+=('  rm -f -- "$tmp"')
  _SB+=("}")
fi

_SB+=('alias lg="lazygit"')
[ -n "$_EDITOR_BIN" ] && _SB+=("alias e=\"$_EDITOR_BIN\"") || true
_SB+=("# ── end cmuxup ─────────────────────────────────────────────────────────")

# Join the array with newlines.
SHELL_BLOCK=""
for _line in "${_SB[@]}"; do
  SHELL_BLOCK="${SHELL_BLOCK}
${_line}"
done

ZSHRC="${HOME}/.zshrc"
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
  gum style \
    --border double --border-foreground 212 \
    --padding "1 4" --margin "1 0" \
    --bold --foreground 212 \
    "  ✦ cmuxup is ready  ✦"
  gum style --foreground 245 --margin "0 2" \
    "Theme:   $THEME" \
    "Font:    ${FONT_SIZE}pt  |  Agent: $AGENT  |  Editor: $EDITOR_CHOICE  |  Lazygit: $([ "$INSTALL_LAZYGIT" = "1" ] && echo yes || echo no)"
  echo ""
  gum style --foreground 212 --bold --margin "0 2" "  Next steps:"
  gum style --foreground 255 --margin "0 2" \
    "  1. Open a new shell (or: source ~/.zshrc)" \
    "  2. Launch a workspace:  cmuxup ~/your-project" \
    "  3. Reload cmux config:  cmux reload-config"
  echo ""
  gum style --foreground 240 --margin "0 2" \
    "  https://github.com/ITZSHOAIB/cmuxup"
else
  echo "✦ cmuxup is ready ✦"
  echo "  Theme: $THEME | Font: ${FONT_SIZE}pt | Agent: $AGENT | Editor: $EDITOR_CHOICE"
  echo "  Next: source ~/.zshrc && cmuxup ~/your-project"
fi
