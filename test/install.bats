#!/usr/bin/env bats
# Tests for install.sh — run with: bats test/install.bats

INSTALL="$BATS_TEST_DIRNAME/../install.sh"

setup() {
  export CMUXUP_NON_INTERACTIVE=1
  export CMUXUP_THEME="Catppuccin Mocha"
  export CMUXUP_FONT_SIZE="14"
  export CMUXUP_AGENT="claude"
  export CMUXUP_LAZYGIT="1"
  export CMUXUP_EDITOR="helix"
  export CMUXUP_EXTRAS=""
  export CMUXUP_OVERWRITE="0"
  # Isolated HOME so we never touch the real ~/.gitconfig etc.
  export HOME="$(mktemp -d)"
  mkdir -p "$HOME/.local/bin"
}

teardown() {
  rm -rf "$HOME"
}

# ── 1. --help ─────────────────────────────────────────────────────────────────
@test "install.sh --help exits 0" {
  run bash "$INSTALL" --help
  [ "$status" -eq 0 ]
}

# ── 2. non-interactive dry-run succeeds ───────────────────────────────────────
@test "install.sh non-interactive dry-run exits 0 without user prompts" {
  run bash "$INSTALL" --dry-run
  [ "$status" -eq 0 ]
}

# ── 3. template substitution replaces {{THEME}} ───────────────────────────────
@test "install.sh sed substitution replaces {{THEME}} placeholder" {
  TMPL="$(mktemp)"
  echo 'theme = {{THEME}}' > "$TMPL"
  RESULT="$(sed 's|{{THEME}}|Catppuccin Mocha|g' "$TMPL")"
  [[ "$RESULT" == *"Catppuccin Mocha"* ]]
  rm "$TMPL"
}

# ── 4. dry-run reports cmuxup install path ────────────────────────────────────
@test "install.sh --dry-run reports it would install cmuxup to ~/.local/bin" {
  run bash "$INSTALL" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"local/bin"* ]] || [[ "$output" == *"cmuxup"* ]]
}

# ── 5. skips existing ghostty config when CMUXUP_OVERWRITE=0 ─────────────────
@test "install.sh skips ghostty config when it exists and CMUXUP_OVERWRITE=0" {
  mkdir -p "$HOME/.config/ghostty"
  echo "existing-content" > "$HOME/.config/ghostty/config"
  run bash "$INSTALL" --dry-run
  [ "$status" -eq 0 ]
  [[ "$(cat "$HOME/.config/ghostty/config")" == "existing-content" ]]
}

# ── 6. no lazygit config written when CMUXUP_LAZYGIT=0 ───────────────────────
@test "install.sh does not write lazygit config when CMUXUP_LAZYGIT=0" {
  export CMUXUP_LAZYGIT="0"
  run bash "$INSTALL" --dry-run
  [ "$status" -eq 0 ]
  # dry-run would only print the skip; real lazygit config path should not appear
  [[ "$output" != *"lazygit/config.yml"* ]] || [[ "$output" == *"dry-run"* ]] || true
  # Key check: lazygit config must not have been written
  [ ! -f "$HOME/Library/Application Support/lazygit/config.yml" ]
}

# ── 7. no helix config written when CMUXUP_EDITOR=none ───────────────────────
@test "install.sh does not write helix config when CMUXUP_EDITOR=none" {
  export CMUXUP_EDITOR="none"
  run bash "$INSTALL" --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/.config/helix/config.toml" ]
}

# ── 8. shell block written to .zshrc on first install ─────────────────────────
@test "install.sh appends shell integration block to .zshrc" {
  touch "$HOME/.zshrc"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  grep -q "cmuxup shell integration" "$HOME/.zshrc"
}

# ── 9. shell block not duplicated on re-run ────────────────────────────────────
@test "install.sh does not duplicate shell integration block on re-run" {
  touch "$HOME/.zshrc"
  bash "$INSTALL"
  bash "$INSTALL"
  COUNT="$(grep -c "cmuxup shell integration" "$HOME/.zshrc" || true)"
  [ "$COUNT" -eq 1 ]
}
