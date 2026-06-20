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
#   CMUXUP_LAZYGIT     1 | 0
#   CMUXUP_EDITOR      helix | nvim | vim | none
#   CMUXUP_EXTRAS      space-separated: "yazi bat fd ripgrep"
#   CMUXUP_OVERWRITE   1 = overwrite existing configs without prompting

VERSION="0.1.0"
DRY_RUN=0
REPO="ITZSHOAIB/cmuxup"
BRANCH="main"

# When piped via stdin (curl ... | bash), BASH_SOURCE[0] is unset and template
# files are unavailable. Download the repo tarball and re-exec from a real file.
# The </dev/tty restores TTY after pipe exhaustion so interactive prompts work.
_SELF="${BASH_SOURCE[0]:-}"
if [[ -z "$_SELF" || "$_SELF" == "bash" || "$_SELF" == "-bash" ]]; then
  _TMP="$(mktemp -d)"
  trap 'rm -rf "$_TMP"' EXIT
  echo "Downloading cmuxup..."
  curl -fsSL "https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz" \
    | tar -xz -C "$_TMP" --strip-components=1
  exec bash "$_TMP/install.sh" "$@" </dev/tty
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── ANSI colours (Catppuccin Mocha palette) ───────────────────────────────────
_C_RESET='\033[0m'
_C_BOLD='\033[1m'
_C_MAUVE='\033[38;2;203;166;247m'   # #cba6f7
_C_GREEN='\033[38;2;166;227;161m'   # #a6e3a1
_C_BLUE='\033[38;2;137;180;250m'    # #89b4fa
_C_SUBTEXT='\033[38;2;147;153;178m' # #9399b2
_C_BORDER='\033[38;2;69;71;90m'     # #45475a

# fzf colour scheme (reused by all _pick / _pick_multi calls).
_FZF_COLORS="fg:#cdd6f4,bg:#1e1e2e,hl:#f38ba8,fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8,border:#45475a,info:#6c7086,prompt:#cba6f7,pointer:#f5c2e7,marker:#a6e3a1,header:#89b4fa"

usage() {
  cat <<EOF
Usage: bash install.sh [options]

Install cmuxup: a terminal-first agentic workspace setup for cmux.

Options:
  --help, -h    Show this help message
  --dry-run     Show what would be installed without making changes

Non-interactive env vars (set CMUXUP_NON_INTERACTIVE=1):
  CMUXUP_THEME       Theme name                     (default: Catppuccin Mocha)
  CMUXUP_FONT_SIZE   Font size                      (default: 14)
  CMUXUP_AGENT       AI agent command               (default: claude)
  CMUXUP_LAZYGIT     Install lazygit  1|0           (default: 1)
  CMUXUP_EDITOR      helix | nvim | vim | none      (default: helix)
  CMUXUP_EXTRAS      Space-separated extras         (default: "yazi bat fd ripgrep")
  CMUXUP_OVERWRITE   Overwrite existing configs 1|0 (default: 0)
EOF
}

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────

_log()  { printf "  %s\n" "$*"; }
_ok()   { printf "  ${_C_GREEN}✓${_C_RESET} %s\n" "$*"; }
_skip() { printf "  ${_C_SUBTEXT}− %s (skipped)${_C_RESET}\n" "$*"; }
_dry()  { printf "  ${_C_SUBTEXT}[dry-run] %s${_C_RESET}\n" "$*"; }
_err()  { printf "  ${_C_MAUVE}✗ %s${_C_RESET}\n" "$*" >&2; }

_write_file() { # dest content
  local dest="$1" content="$2"
  if [ "$DRY_RUN" -eq 1 ]; then _dry "would write $dest"; return; fi
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ]; then
    [ "${CMUXUP_OVERWRITE:-0}" != "1" ] && { _skip "$dest already exists"; return; }
    cp "$dest" "${dest}.bak"
    _log "backed up ${dest} → ${dest}.bak"
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
  printf "  ${_C_SUBTEXT}○ installing %s...${_C_RESET}" "$formula"
  if brew install "$formula" >/dev/null 2>&1; then
    printf "\r\033[K"; _ok "installed $formula"
  else
    printf "\r\033[K"; _err "failed to install $formula"; return 1
  fi
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

# Single-select via fzf. Prints the chosen item.
_pick() { # "Header text" option1 option2 ...
  local header="$1"; shift
  printf '%s\n' "$@" | fzf \
    --prompt "  > " \
    --header "  ${header}" \
    --height="~$((${#@} + 5))" \
    --layout=reverse --border=rounded \
    --no-info --no-sort \
    --color="$_FZF_COLORS"
}

# Multi-select via fzf (TAB toggles, CTRL-A all/none). All pre-selected.
_pick_multi() { # "Header text" option1 option2 ...
  local header="$1"; shift
  printf '%s\n' "$@" | fzf \
    --multi \
    --prompt "  > " \
    --header "  ${header}  (TAB=toggle  CTRL-A=all/none)" \
    --bind "start:select-all,tab:toggle,ctrl-a:toggle-all" \
    --height="~$((${#@} + 6))" \
    --layout=reverse --border=rounded \
    --no-info --no-sort \
    --marker="✓ " \
    --color="$_FZF_COLORS" \
    || true
}

# Simple y/N prompt (reads from /dev/tty so it works after pipe re-exec).
_confirm() { # "Question?"
  local answer
  printf "  %s [Y/n] " "$1"
  read -r answer </dev/tty
  case "${answer:-Y}" in [Yy]*|"") return 0 ;; *) return 1 ;; esac
}

_banner() {
  printf "\n"
  printf "  ${_C_BOLD}${_C_MAUVE}╭──────────────────────────────────────────╮${_C_RESET}\n"
  printf "  ${_C_BOLD}${_C_MAUVE}│  ✦  cmuxup %-31s│${_C_RESET}\n" "v${VERSION}"
  printf "  ${_C_BOLD}${_C_MAUVE}│     Terminal-first agentic workspace     │${_C_RESET}\n"
  printf "  ${_C_BOLD}${_C_MAUVE}╰──────────────────────────────────────────╯${_C_RESET}\n"
  printf "\n"
}

_done_msg() {
  local lg_label; [ "${INSTALL_LAZYGIT}" = "1" ] && lg_label="yes" || lg_label="no"
  printf "\n"
  printf "  ${_C_BOLD}${_C_GREEN}✦ cmuxup is ready ✦${_C_RESET}\n\n"
  printf "  ${_C_SUBTEXT}Theme:   %s${_C_RESET}\n" "$THEME"
  printf "  ${_C_SUBTEXT}Font:    %spt  |  Agent: %s  |  Editor: %s  |  Lazygit: %s${_C_RESET}\n" \
    "$FONT_SIZE" "$AGENT" "$EDITOR_CHOICE" "$lg_label"
  printf "\n"
  printf "  ${_C_BOLD}${_C_MAUVE}Next steps:${_C_RESET}\n"
  printf "  ${_C_BLUE}  1. Open a new shell  (or: source ~/.zshrc)${_C_RESET}\n"
  printf "  ${_C_BLUE}  2. Launch a workspace:  cmuxup ~/your-project${_C_RESET}\n"
  printf "  ${_C_BLUE}  3. Reload cmux config:  cmux reload-config${_C_RESET}\n"
  printf "\n"
  printf "  ${_C_SUBTEXT}https://github.com/ITZSHOAIB/cmuxup${_C_RESET}\n\n"
}

# ── Preflight ─────────────────────────────────────────────────────────────────

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew is required. Install it from https://brew.sh" >&2; exit 1
fi

if [ "${CMUXUP_NON_INTERACTIVE:-0}" != "1" ] && [ "$DRY_RUN" -eq 0 ]; then
  if ! command -v fzf >/dev/null 2>&1; then
    printf "  Installing fzf...\n"
    brew install fzf >/dev/null 2>&1
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
  _banner

  THEME="$(_pick "Theme:" \
    "Catppuccin Mocha" "TokyoNight Storm" "Gruvbox Dark Hard" "Kanagawa Wave")"

  FONT_SIZE="$(_pick "Font size:" "14" "13" "15")"

  AGENT="$(_pick "AI agent (main pane):" "claude" "opencode" "codex" "none")"

  if _confirm "Install lazygit? (git TUI for the right-top pane)"; then
    INSTALL_LAZYGIT=1
  else
    INSTALL_LAZYGIT=0
  fi

  EDITOR_CHOICE="$(_pick "Editor tab (right-top pane):" "helix" "nvim" "vim" "none")"

  EXTRAS_RAW="$(_pick_multi "Optional tools:" \
    "yazi" "bat" "fd" "ripgrep")"

  EXTRAS=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    EXTRAS+=("$line")
  done <<< "$EXTRAS_RAW"

  printf "\n"
  _confirm "Ready to install?" || { printf "  Aborted.\n"; exit 0; }
fi

_theme_variants "$THEME"

# ── Ask once about overwriting configs ────────────────────────────────────────

if [ "${CMUXUP_NON_INTERACTIVE:-0}" != "1" ] && [ "$DRY_RUN" -eq 0 ] && [ "${CMUXUP_OVERWRITE:-0}" != "1" ]; then
  _EXISTING=()
  for f in "${HOME}/.config/ghostty/config" "${HOME}/.config/helix/config.toml" \
            "${HOME}/Library/Application Support/lazygit/config.yml" \
            "${HOME}/.config/yazi/yazi.toml"; do
    [ -f "$f" ] && _EXISTING+=("$f")
  done
  if [ "${#_EXISTING[@]}" -gt 0 ]; then
    printf "\n"
    _log "${#_EXISTING[@]} config file(s) already exist."
    _confirm "Overwrite existing configs?" && CMUXUP_OVERWRITE=1 || CMUXUP_OVERWRITE=0
  fi
fi

# ── Install tools ─────────────────────────────────────────────────────────────

printf "\n"
_log "Installing tools..."

_brew_install git-delta delta
_brew_install zoxide

[ "${INSTALL_LAZYGIT}" = "1" ] && _brew_install lazygit || true

case "$EDITOR_CHOICE" in
  helix) _brew_install helix hx ;;
  nvim)  _brew_install neovim nvim ;;
  vim)   command -v vim >/dev/null 2>&1 || _brew_install vim ;;
esac

for tool in "${EXTRAS[@]:-}"; do
  case "$tool" in
    yazi)    _brew_install yazi ;;
    bat)     _brew_install bat ;;
    fd)      _brew_install fd ;;
    ripgrep) _brew_install ripgrep rg ;;
  esac
done

# ── Write configs ─────────────────────────────────────────────────────────────

printf "\n"
_log "Writing configs..."

TEMPLATES="$SCRIPT_DIR/templates"

_apply_template "$TEMPLATES/ghostty.config" \
  "${HOME}/.config/ghostty/config" \
  "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"

[ "$EDITOR_CHOICE" = "helix" ] && _apply_template "$TEMPLATES/helix.toml" \
  "${HOME}/.config/helix/config.toml" \
  "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME" || true

[ "${INSTALL_LAZYGIT}" = "1" ] && _apply_template "$TEMPLATES/lazygit.yml" \
  "${HOME}/Library/Application Support/lazygit/config.yml" \
  "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME" || true

echo "${EXTRAS[*]:-}" | grep -qw "yazi" && _apply_template "$TEMPLATES/yazi.toml" \
  "${HOME}/.config/yazi/yazi.toml" \
  "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME" || true

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

CMUX_JSON="${HOME}/.config/cmux/cmux.json"
if [ -f "$CMUX_JSON" ] && grep -q '"diffViewer"' "$CMUX_JSON" 2>/dev/null; then
  _skip "cmux.json already has cmuxup settings"
else
  _apply_template "$TEMPLATES/cmux-settings.jsonc" "$CMUX_JSON" \
    "$THEME" "$FONT_SIZE" "$DELTA_THEME" "$HELIX_THEME"
fi

# ── Install cmuxup command ────────────────────────────────────────────────────

printf "\n"
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

case "$EDITOR_CHOICE" in
  helix) _EDITOR_BIN="hx" ;;
  nvim)  _EDITOR_BIN="nvim" ;;
  vim)   _EDITOR_BIN="vim" ;;
  *)     _EDITOR_BIN="" ;;
esac

# Build block line by line — avoids set -e triggering on empty-variable $() subshells.
_SB=()
_SB+=("# ── cmuxup shell integration ──────────────────────────────────────────")
[ -n "$_EDITOR_BIN" ] && _SB+=("export EDITOR=\"$_EDITOR_BIN\"")   || true
[ -n "$_EDITOR_BIN" ] && _SB+=("export VISUAL=\"$_EDITOR_BIN\"")   || true
[ "$AGENT"           != "none" ] && _SB+=("export CMUXUP_MAIN_CMD=\"$AGENT\"") || true
[ "${INSTALL_LAZYGIT}" = "1"   ] && _SB+=('export CMUXUP_LG_CMD="lazygit"')   || true
case "$EDITOR_CHOICE" in
  helix) _SB+=('export CMUXUP_HX_CMD="hx ."') ;;
  nvim)  _SB+=('export CMUXUP_HX_CMD="nvim ."') ;;
  vim)   _SB+=('export CMUXUP_HX_CMD="vim ."') ;;
  none)  _SB+=('export CMUXUP_HX_CMD=""') ;;
esac
_SB+=('eval "$(zoxide init zsh)"')

echo "${EXTRAS[*]:-}" | grep -qw "yazi" && {
  _SB+=('function y() {')
  _SB+=('  local tmp cwd')
  _SB+=('  tmp="$(mktemp -t yazi-cwd.XXXXXX)"')
  _SB+=('  yazi "$@" --cwd-file="$tmp"')
  _SB+=('  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then')
  _SB+=('    builtin cd -- "$cwd"')
  _SB+=('  fi')
  _SB+=('  rm -f -- "$tmp"')
  _SB+=("}")
} || true

_SB+=('alias lg="lazygit"')
[ -n "$_EDITOR_BIN" ] && _SB+=("alias e=\"$_EDITOR_BIN\"") || true
_SB+=("# ── end cmuxup ─────────────────────────────────────────────────────────")

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
  printf '%s\n' "$SHELL_BLOCK" >> "$ZSHRC"
  _ok "added shell integration to $ZSHRC"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

if [ "$DRY_RUN" -eq 0 ] && [ "${CMUXUP_NON_INTERACTIVE:-0}" != "1" ]; then
  _done_msg
else
  printf "\n✦ cmuxup is ready ✦\n"
  printf "  Theme: %s | Font: %spt | Agent: %s | Editor: %s\n" \
    "$THEME" "$FONT_SIZE" "$AGENT" "$EDITOR_CHOICE"
  printf "  Next: source ~/.zshrc && cmuxup ~/your-project\n"
fi
