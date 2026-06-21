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
#   CMUXUP_CMUX        1 | 0   (install the cmux terminal app itself)
#   CMUXUP_LAZYGIT     1 | 0
#   CMUXUP_EDITOR      helix | nvim | vim | none
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
  CMUXUP_CMUX        Install cmux terminal  1|0     (default: 1)
  CMUXUP_LAZYGIT     Install lazygit  1|0           (default: 1)
  CMUXUP_EDITOR      helix | nvim | vim | none      (default: helix)
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
    -e "s|{{LG_ACCENT}}|${LG_ACCENT}|g" \
    -e "s|{{LG_SELECTION_BG}}|${LG_SELECTION_BG}|g" \
    -e "s|{{LG_UNSTAGED}}|${LG_UNSTAGED}|g" \
    -e "s|{{LG_AUTHOR}}|${LG_AUTHOR}|g" \
    "$1")"
  _write_file "$2" "$content"
}

_spin() { # "label" pid
  local label="$1" pid="$2"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${_C_SUBTEXT}%s %s...${_C_RESET}" "${frames[$((i % 10))]}" "$label"
    i=$(( i + 1 ))
    sleep 0.08
  done
  printf "\r\033[K"
}

_brew_install() { # formula [binary]
  local formula="$1" binary="${2:-$1}"
  if command -v "$binary" >/dev/null 2>&1; then
    _skip "$formula already installed"; return
  fi
  if [ "$DRY_RUN" -eq 1 ]; then _dry "would brew install $formula"; return; fi
  brew install "$formula" >/dev/null 2>&1 &
  local brew_pid=$!
  _spin "installing $formula" "$brew_pid"
  local exit_code=0
  wait "$brew_pid" || exit_code=$?
  if [ "$exit_code" -eq 0 ]; then
    _ok "installed $formula"
  else
    _err "failed to install $formula"; return 1
  fi
}

_brew_install_cask() { # cask app_path
  # Casks aren't on PATH, so detect by the installed .app bundle, not command -v.
  local cask="$1" app_path="$2"
  if [ -d "$app_path" ] || command -v "$cask" >/dev/null 2>&1; then
    _skip "$cask already installed"; return
  fi
  if [ "$DRY_RUN" -eq 1 ]; then _dry "would brew install --cask $cask"; return; fi
  brew install --cask "$cask" >/dev/null 2>&1 &
  local pid=$!
  _spin "installing $cask" "$pid"
  local exit_code=0
  wait "$pid" || exit_code=$?
  if [ "$exit_code" -eq 0 ]; then
    _ok "installed $cask"
  else
    _err "failed to install $cask"; return 1
  fi
}

_theme_variants() {
  # DELTA_THEME / HELIX_THEME — syntax themes for delta and helix.
  # BAT_THEME              — bat syntax theme (matches delta where possible).
  # LG_ACCENT / LG_SELECTION_BG / LG_UNSTAGED / LG_AUTHOR — lazygit theme palette
  #                         (accent for borders/options, subtle bg for selection,
  #                          red-ish for unstaged, author tint).
  case "$1" in
    "Catppuccin Mocha")
      DELTA_THEME="Catppuccin Mocha"; HELIX_THEME="catppuccin_mocha"; BAT_THEME="Catppuccin Mocha"
      LG_ACCENT="#89b4fa"; LG_SELECTION_BG="#313244"; LG_UNSTAGED="#f38ba8"; LG_AUTHOR="#b4befe" ;;
    "TokyoNight Storm")
      DELTA_THEME="TwoDark"; HELIX_THEME="dark_plus"; BAT_THEME="TwoDark"
      LG_ACCENT="#7aa2f7"; LG_SELECTION_BG="#2f334d"; LG_UNSTAGED="#f7768e"; LG_AUTHOR="#bb9af7" ;;
    "Gruvbox Dark Hard")
      DELTA_THEME="gruvbox-dark"; HELIX_THEME="gruvbox_dark_hard"; BAT_THEME="gruvbox-dark"
      LG_ACCENT="#83a598"; LG_SELECTION_BG="#3c3836"; LG_UNSTAGED="#fb4934"; LG_AUTHOR="#fe8019" ;;
    "Kanagawa Wave")
      DELTA_THEME="Nord"; HELIX_THEME="catppuccin_mocha"; BAT_THEME="Nord"
      LG_ACCENT="#7e9cd8"; LG_SELECTION_BG="#223249"; LG_UNSTAGED="#ff5d62"; LG_AUTHOR="#957fb8" ;;
    *)
      DELTA_THEME="Catppuccin Mocha"; HELIX_THEME="catppuccin_mocha"; BAT_THEME="Catppuccin Mocha"
      LG_ACCENT="#89b4fa"; LG_SELECTION_BG="#313244"; LG_UNSTAGED="#f38ba8"; LG_AUTHOR="#b4befe" ;;
  esac
}

# ── Pure-bash interactive menus ───────────────────────────────────────────────

_read_key() {
  local k1 k2
  IFS= read -r -s -n1 k1 </dev/tty
  if [[ "$k1" == $'\033' ]]; then
    IFS= read -r -s -n2 -t 0.05 k2 </dev/tty || true
    case "$k2" in
      '[A') printf 'UP';   return ;;
      '[B') printf 'DOWN'; return ;;
    esac
    printf 'ESC'; return
  fi
  if [[ "$k1" == $'\r' || -z "$k1" ]]; then printf 'ENTER'; return; fi
  if [[ "$k1" == ' ' ]];                 then printf 'SPACE'; return; fi
  printf 'OTHER'
}

# Single-select arrow-key menu. Prints chosen item to stdout; all display to stderr.
_pick() { # "title" opt1 opt2 ...
  local title="$1"; shift
  local opts=("$@")
  local n=${#opts[@]}
  local cur=0
  local lines=$(( n + 5 ))  # blank + title + blank + n items + blank + hint

  _pick_draw() {
    printf '\033[%dA' "$lines" >&2
    printf '\n' >&2
    printf '  \033[1m\033[38;2;203;166;247m✦  %s\033[0m\n' "$title" >&2
    printf '\n' >&2
    local j=0
    while (( j < n )); do
      if (( j == cur )); then
        printf '  \033[1m\033[38;2;203;166;247m❯  %s\033[0m\n' "${opts[$j]}" >&2
      else
        printf '  \033[38;2;108;112;134m   %s\033[0m\n' "${opts[$j]}" >&2
      fi
      j=$(( j + 1 ))
    done
    printf '\n' >&2
    printf '  \033[38;2;108;112;134m↑ ↓  move   ↵  select\033[0m\n' >&2
  }

  # Initial draw (no cursor-up on first paint).
  printf '\033[?25l' >&2
  printf '\n' >&2
  printf '  \033[1m\033[38;2;203;166;247m✦  %s\033[0m\n' "$title" >&2
  printf '\n' >&2
  local i=0
  while (( i < n )); do
    if (( i == cur )); then
      printf '  \033[1m\033[38;2;203;166;247m❯  %s\033[0m\n' "${opts[$i]}" >&2
    else
      printf '  \033[38;2;108;112;134m   %s\033[0m\n' "${opts[$i]}" >&2
    fi
    i=$(( i + 1 ))
  done
  printf '\n' >&2
  printf '  \033[38;2;108;112;134m↑ ↓  move   ↵  select\033[0m\n' >&2

  local key
  while true; do
    key="$(_read_key)"
    case "$key" in
      UP)
        if (( cur == 0 )); then
          cur=$(( n - 1 ))
        else
          cur=$(( cur - 1 ))
        fi
        _pick_draw
        ;;
      DOWN)
        cur=$(( (cur + 1) % n ))
        _pick_draw
        ;;
      ENTER)
        printf '\033[%dA\033[J' "$lines" >&2
        printf '  \033[38;2;108;112;134m✦  %s\033[0m   \033[1m\033[38;2;205;214;244m%s\033[0m\n' \
          "$title" "${opts[$cur]}" >&2
        printf '\033[?25h' >&2
        printf '%s' "${opts[$cur]}"
        return
        ;;
    esac
  done
}

# Simple y/N confirmation. Reads from /dev/tty (works after curl-pipe re-exec).
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

# ── Gather choices ────────────────────────────────────────────────────────────

if [ "${CMUXUP_NON_INTERACTIVE:-0}" = "1" ] || [ "$DRY_RUN" -eq 1 ]; then
  THEME="${CMUXUP_THEME:-Catppuccin Mocha}"
  FONT_SIZE="${CMUXUP_FONT_SIZE:-14}"
  AGENT="${CMUXUP_AGENT:-claude}"
  INSTALL_CMUX="${CMUXUP_CMUX:-1}"
  INSTALL_LAZYGIT="${CMUXUP_LAZYGIT:-1}"
  EDITOR_CHOICE="${CMUXUP_EDITOR:-helix}"
else
  # Ensure cursor is always restored on exit (Ctrl-C, errors, etc.)
  trap 'printf "\033[?25h" >&2' EXIT

  _banner

  THEME="$(_pick "Theme" \
    "Catppuccin Mocha" "TokyoNight Storm" "Gruvbox Dark Hard" "Kanagawa Wave")"

  FONT_SIZE="$(_pick "Font size" "14" "13" "15")"

  AGENT="$(_pick "AI agent  (main pane)" "claude" "opencode" "codex" "none")"

  if _confirm "Install cmux terminal? (the app the whole setup runs in)"; then
    INSTALL_CMUX=1
  else
    INSTALL_CMUX=0
  fi

  if _confirm "Install lazygit? (git TUI for the right-top pane)"; then
    INSTALL_LAZYGIT=1
  else
    INSTALL_LAZYGIT=0
  fi

  EDITOR_CHOICE="$(_pick "Editor  (right-top pane)" "helix" "nvim" "vim" "none")"

  printf "\n"
  _confirm "Ready to install?" || { printf "  Aborted.\n"; exit 0; }
fi

_theme_variants "$THEME"

# ── Ask once about overwriting configs ────────────────────────────────────────

if [ "${CMUXUP_NON_INTERACTIVE:-0}" != "1" ] && [ "$DRY_RUN" -eq 0 ] && [ "${CMUXUP_OVERWRITE:-0}" != "1" ]; then
  _EXISTING=()
  for f in "${HOME}/.config/ghostty/config" "${HOME}/.config/helix/config.toml" \
            "${HOME}/Library/Application Support/lazygit/config.yml"; do
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

# cmux itself — the terminal app the whole workspace runs in. Installed first
# so the rest of the setup (and the cmux.json config below) has somewhere to land.
[ "${INSTALL_CMUX}" = "1" ] && _brew_install_cask cmux "/Applications/cmux.app" || true

# Core tools — the foundation every cmuxup workspace relies on:
#   delta   — syntax-highlighted git diffs (terminal + lazygit)
#   ripgrep — fast search, powers the editor's project-wide search
#   fd      — fast file finding, powers the editor's file picker
#   zoxide  — smart directory jumping
#   fzf     — fuzzy finder: history (ctrl-r), files (ctrl-t), cd (alt-c)
#   bat     — syntax-highlighted file preview (powers fzf previews)
_brew_install git-delta delta
_brew_install ripgrep rg
_brew_install fd
_brew_install zoxide
_brew_install fzf
_brew_install bat

[ "${INSTALL_LAZYGIT}" = "1" ] && _brew_install lazygit || true

case "$EDITOR_CHOICE" in
  helix) _brew_install helix hx ;;
  nvim)  _brew_install neovim nvim ;;
  vim)   command -v vim >/dev/null 2>&1 || _brew_install vim ;;
esac

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

# fzf + bat terminal toolkit — fuzzy find with syntax-highlighted previews.
_SB+=('source <(fzf --zsh)')                       # ctrl-r history, ctrl-t files, alt-c cd
_SB+=("export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'")
_SB+=('export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"')
_SB+=("export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'")
_SB+=("export FZF_DEFAULT_OPTS=\"--height 45% --layout=reverse --border --info=inline\"")
_SB+=("export FZF_CTRL_T_OPTS=\"--preview 'bat --color=always --line-range=:300 {}'\"")
_SB+=("export FZF_ALT_C_OPTS=\"--preview 'ls -la {}'\"")
_SB+=("export BAT_THEME=\"$BAT_THEME\"")

[ "${INSTALL_LAZYGIT}" = "1" ] && _SB+=('alias lg="lazygit"') || true
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
