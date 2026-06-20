#!/usr/bin/env bats
# Tests for bin/conjure — run with: bats test/conjure.bats

CONJURE="$BATS_TEST_DIRNAME/../bin/conjure"

setup() {
  # Prepend mock cmux to PATH so conjure never touches the real cmux socket.
  export PATH="$BATS_TEST_DIRNAME/bin:$PATH"
  export CMUX_QUIET=1
  # Clean up mock call log before each test.
  rm -f "${BATS_TMPDIR}/cmux_calls" "${BATS_TMPDIR}/cmux_split_count"
}

# ── 1. --help ─────────────────────────────────────────────────────────────────
@test "conjure --help exits 0 and shows Usage" {
  run "$CONJURE" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# ── 2. --version ──────────────────────────────────────────────────────────────
@test "conjure --version exits 0 and prints a semver" {
  run "$CONJURE" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

# ── 3. bad directory ──────────────────────────────────────────────────────────
@test "conjure /nonexistent exits 1 with error on stderr" {
  run "$CONJURE" /this-does-not-exist-cmux-conjure
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"not a directory"* ]] || [[ "$output" == *"not a directory"* ]]
}

# ── 4. calls new-workspace with correct --cwd ─────────────────────────────────
@test "conjure calls cmux new-workspace with --cwd set to project dir" {
  TMPDIR_PROJ="$(mktemp -d)"
  run "$CONJURE" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "new-workspace" "${BATS_TMPDIR}/cmux_calls"
  grep -q -- "--cwd" "${BATS_TMPDIR}/cmux_calls"
  grep -q "$TMPDIR_PROJ" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 5. calls new-split right ──────────────────────────────────────────────────
@test "conjure calls cmux new-split right for the git/editor pane" {
  TMPDIR_PROJ="$(mktemp -d)"
  run "$CONJURE" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "new-split right" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 6. calls new-split down ───────────────────────────────────────────────────
@test "conjure calls cmux new-split down for the dev terminal pane" {
  TMPDIR_PROJ="$(mktemp -d)"
  run "$CONJURE" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "new-split down" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 7. calls new-surface --pane for the helix tab ─────────────────────────────
@test "conjure calls cmux new-surface --type terminal --pane for helix tab" {
  TMPDIR_PROJ="$(mktemp -d)"
  run "$CONJURE" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "new-surface" "${BATS_TMPDIR}/cmux_calls"
  grep -q -- "--pane" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 8. renames both tabs ──────────────────────────────────────────────────────
@test "conjure renames tabs to lazygit and helix" {
  TMPDIR_PROJ="$(mktemp -d)"
  run "$CONJURE" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "rename-tab" "${BATS_TMPDIR}/cmux_calls"
  grep -q "lazygit" "${BATS_TMPDIR}/cmux_calls"
  grep -q "helix" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 9. sends commands via send + send-key Enter ───────────────────────────────
@test "conjure sends commands to panes via cmux send and send-key Enter" {
  TMPDIR_PROJ="$(mktemp -d)"
  run "$CONJURE" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "^send " "${BATS_TMPDIR}/cmux_calls"
  grep -q "send-key" "${BATS_TMPDIR}/cmux_calls"
  grep -q "Enter" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 10. CONJURE_MAIN_CMD override ─────────────────────────────────────────────
@test "CONJURE_MAIN_CMD env override is used instead of claude" {
  TMPDIR_PROJ="$(mktemp -d)"
  run env CONJURE_MAIN_CMD="my-custom-agent" "$CONJURE" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "my-custom-agent" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}
