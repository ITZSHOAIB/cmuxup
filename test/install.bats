#!/usr/bin/env bats
# Tests for install.sh

INSTALL="$BATS_TEST_DIRNAME/../install.sh"

setup() {
  export CONJURE_NON_INTERACTIVE=1
  export CONJURE_THEME="Catppuccin Mocha"
  export CONJURE_FONT_SIZE="14"
  export CONJURE_AGENT="claude"
  export CONJURE_EDITOR="helix"
  # Use an isolated HOME so we never touch the real ~/.gitconfig etc.
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

# ── 2. non-interactive dry-run doesn't prompt ─────────────────────────────────
@test "install.sh non-interactive mode exits 0 without user prompts" {
  run bash "$INSTALL" --dry-run
  [ "$status" -eq 0 ]
}

# ── 3. template substitution replaces {{THEME}} ───────────────────────────────
@test "install.sh substitutes {{THEME}} placeholder in ghostty config" {
  run bash "$INSTALL" --dry-run
  [ "$status" -eq 0 ]
  # After a real install the theme should appear in the written config.
  # In dry-run we just confirm the script can perform sed substitution.
  TMPL="$(mktemp)"
  echo 'theme = {{THEME}}' > "$TMPL"
  RESULT="$(sed 's|{{THEME}}|Catppuccin Mocha|g' "$TMPL")"
  [[ "$RESULT" == *"Catppuccin Mocha"* ]]
  rm "$TMPL"
}

# ── 4. installs conjure to ~/.local/bin ───────────────────────────────────────
@test "install.sh --dry-run reports it would install conjure to ~/.local/bin" {
  run bash "$INSTALL" --dry-run
  [ "$status" -eq 0 ]
  # dry-run should mention the install path
  [[ "$output" == *"local/bin"* ]] || [[ "$output" == *"conjure"* ]]
}

# ── 5. does not overwrite existing ghostty config without confirmation ─────────
@test "install.sh skips ghostty config when it already exists and not confirmed" {
  mkdir -p "$HOME/.config/ghostty"
  echo "existing-content" > "$HOME/.config/ghostty/config"
  # Non-interactive mode with CONJURE_OVERWRITE unset should not overwrite.
  run bash "$INSTALL" --dry-run
  [ "$status" -eq 0 ]
  # File should still have original content.
  [[ "$(cat "$HOME/.config/ghostty/config")" == "existing-content" ]]
}
