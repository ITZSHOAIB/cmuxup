#!/usr/bin/env bats
# Tests for bin/cmuxup — run with: bats test/cmuxup.bats

CMUXUP="$BATS_TEST_DIRNAME/../bin/cmuxup"

setup() {
  # Prepend mock cmux to PATH so cmuxup never touches the real cmux socket.
  export PATH="$BATS_TEST_DIRNAME/bin:$PATH"
  export CMUX_QUIET=1
  # Clean up mock call log before each test.
  rm -f "${BATS_TMPDIR}/cmux_calls" "${BATS_TMPDIR}/cmux_split_count"
}

# ── 1. --help ─────────────────────────────────────────────────────────────────
@test "cmuxup --help exits 0 and shows Usage" {
  run "$CMUXUP" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# ── 2. --version ──────────────────────────────────────────────────────────────
@test "cmuxup --version exits 0 and prints a semver" {
  run "$CMUXUP" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

# ── 3. bad directory ──────────────────────────────────────────────────────────
@test "cmuxup /nonexistent exits 1 with error on stderr" {
  run "$CMUXUP" /this-does-not-exist-cmuxup
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"not a directory"* ]] || [[ "$output" == *"not a directory"* ]]
}

# ── 4. calls new-workspace with correct --cwd ─────────────────────────────────
@test "cmuxup calls cmux new-workspace with --cwd set to project dir" {
  TMPDIR_PROJ="$(mktemp -d)"
  run "$CMUXUP" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "new-workspace" "${BATS_TMPDIR}/cmux_calls"
  grep -q -- "--cwd" "${BATS_TMPDIR}/cmux_calls"
  grep -q "$TMPDIR_PROJ" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 5. calls new-split right ──────────────────────────────────────────────────
@test "cmuxup calls cmux new-split right for the right-top pane" {
  TMPDIR_PROJ="$(mktemp -d)"
  run "$CMUXUP" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "new-split right" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 6. calls new-split down ───────────────────────────────────────────────────
@test "cmuxup calls cmux new-split down for the dev terminal pane" {
  TMPDIR_PROJ="$(mktemp -d)"
  run "$CMUXUP" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "new-split down" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 7. creates second tab when both LG and HX are set (default) ───────────────
@test "cmuxup calls new-surface --pane for second tab when both tools configured" {
  TMPDIR_PROJ="$(mktemp -d)"
  run env CMUXUP_LG_CMD="lazygit" CMUXUP_HX_CMD="hx ." "$CMUXUP" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "new-surface" "${BATS_TMPDIR}/cmux_calls"
  grep -q -- "--pane" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 8. renames both tabs when both tools configured ───────────────────────────
@test "cmuxup renames tabs to lazygit and editor when both tools configured" {
  TMPDIR_PROJ="$(mktemp -d)"
  run env CMUXUP_LG_CMD="lazygit" CMUXUP_HX_CMD="hx ." "$CMUXUP" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "rename-tab" "${BATS_TMPDIR}/cmux_calls"
  grep -q "lazygit" "${BATS_TMPDIR}/cmux_calls"
  grep -q "editor" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 9. sends commands via send + send-key Enter ───────────────────────────────
@test "cmuxup sends commands to panes via cmux send and send-key Enter" {
  TMPDIR_PROJ="$(mktemp -d)"
  run "$CMUXUP" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "^send " "${BATS_TMPDIR}/cmux_calls"
  grep -q "send-key" "${BATS_TMPDIR}/cmux_calls"
  grep -q "Enter" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 10. CMUXUP_MAIN_CMD override ─────────────────────────────────────────────
@test "CMUXUP_MAIN_CMD env override is used instead of claude" {
  TMPDIR_PROJ="$(mktemp -d)"
  run env CMUXUP_MAIN_CMD="my-custom-agent" "$CMUXUP" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  grep -q "my-custom-agent" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 11. adaptive: no second tab when LG_CMD is empty ─────────────────────────
@test "cmuxup skips second tab when CMUXUP_LG_CMD is empty" {
  TMPDIR_PROJ="$(mktemp -d)"
  run env CMUXUP_LG_CMD="" CMUXUP_HX_CMD="hx ." "$CMUXUP" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  # new-surface --pane is only called for the second tab — should NOT appear.
  ! grep -q "new-surface" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 12. adaptive: no second tab when HX_CMD is empty ─────────────────────────
@test "cmuxup skips second tab when CMUXUP_HX_CMD is empty" {
  TMPDIR_PROJ="$(mktemp -d)"
  run env CMUXUP_LG_CMD="lazygit" CMUXUP_HX_CMD="" "$CMUXUP" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  ! grep -q "new-surface" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}

# ── 13. adaptive: no tabs or rename when both LG and HX are empty ────────────
@test "cmuxup creates no tool tabs when both LG_CMD and HX_CMD are empty" {
  TMPDIR_PROJ="$(mktemp -d)"
  run env CMUXUP_LG_CMD="" CMUXUP_HX_CMD="" "$CMUXUP" "$TMPDIR_PROJ"
  [ "$status" -eq 0 ]
  ! grep -q "new-surface" "${BATS_TMPDIR}/cmux_calls"
  ! grep -q "rename-tab" "${BATS_TMPDIR}/cmux_calls"
  rm -rf "$TMPDIR_PROJ"
}
