#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$(mktemp -d)"

cleanup() {
  rm -rf "$FIXTURE"
}
trap cleanup EXIT

mkdir -p "$FIXTURE/features/dev-test"
printf '%s\n' 'dev-test' > "$FIXTURE/CURRENT_FEATURE"
printf '%s\n' '# feature: dev-test' > "$FIXTURE/features/dev-test/AGENTS.md"

# The wrapper creates a relative root link for the selected feature.
HARNESS_ROOT="$FIXTURE" "$ROOT/.codex/bin/codex-feature" --dry-run >/dev/null
test -L "$FIXTURE/AGENTS.md"
test "$(readlink "$FIXTURE/AGENTS.md")" = 'features/dev-test/AGENTS.md'

# A user's ordinary AGENTS.md is never replaced or rewritten.
rm "$FIXTURE/AGENTS.md"
printf '%s' 'protected' > "$FIXTURE/AGENTS.md"
cp "$FIXTURE/AGENTS.md" "$FIXTURE/AGENTS.md.expected"
set +e
collision_output="$(HARNESS_ROOT="$FIXTURE" "$ROOT/.codex/bin/codex-feature" --dry-run 2>&1)"
collision_rc=$?
set -e
test "$collision_rc" -ne 0
cmp -s "$FIXTURE/AGENTS.md.expected" "$FIXTURE/AGENTS.md"
grep -Fq '普通文件' <<<"$collision_output"

# A missing feature context reports the exact expected path and leaves no link.
rm "$FIXTURE/AGENTS.md" "$FIXTURE/AGENTS.md.expected"
printf '%s\n' 'missing-feature' > "$FIXTURE/CURRENT_FEATURE"
set +e
missing_feature_output="$(HARNESS_ROOT="$FIXTURE" "$ROOT/.codex/bin/codex-feature" --dry-run 2>&1)"
missing_feature_rc=$?
set -e
test "$missing_feature_rc" -ne 0
test ! -e "$FIXTURE/AGENTS.md"
test ! -L "$FIXTURE/AGENTS.md"
grep -Fq 'features/missing-feature/AGENTS.md' <<<"$missing_feature_output"

# The branch checker reports missing repositories from its feature manifest.
BRANCH_ROOT="$FIXTURE/branch-root"
mkdir -p "$BRANCH_ROOT/features/dev-test" "$BRANCH_ROOT/repos/one"
printf '%s\n' \
  $'repos/one\tdev-test\tfirst repository' \
  $'repos/two\tdev-test\tsecond repository' \
  > "$BRANCH_ROOT/features/dev-test/repos.tsv"
git -C "$BRANCH_ROOT/repos/one" init -q -b dev-test
git -C "$BRANCH_ROOT/repos/one" -c user.name=test -c user.email=test@example.com \
  commit --allow-empty -qm init

set +e
missing_repo_output="$(HARNESS_ROOT="$BRANCH_ROOT" FEATURE_NAME=dev-test \
  "$ROOT/features/dev-sidebar/check-branch.sh" 2>&1)"
missing_repo_rc=$?
set -e
test "$missing_repo_rc" -ne 0
grep -Fq 'MISSING repos/two' <<<"$missing_repo_output"

# All repositories on the requested symbolic branch pass.
mkdir -p "$BRANCH_ROOT/repos/two"
git -C "$BRANCH_ROOT/repos/two" init -q -b dev-test
git -C "$BRANCH_ROOT/repos/two" -c user.name=test -c user.email=test@example.com \
  commit --allow-empty -qm init
HARNESS_ROOT="$BRANCH_ROOT" FEATURE_NAME=dev-test \
  "$ROOT/features/dev-sidebar/check-branch.sh" >/dev/null

# Demo mode always includes a deterministic deliberate drift.
set +e
demo_output="$("$ROOT/features/dev-sidebar/check-branch.sh" --demo 2>&1)"
demo_rc=$?
set -e
test "$demo_rc" -ne 0
grep -Fq 'DRIFT' <<<"$demo_output"

# In a repo tree, branch validation runs before link selection and fails closed.
rm -rf "$FIXTURE/.repo"
mkdir "$FIXTURE/.repo"
printf '%s\n' 'dev-test' > "$FIXTURE/CURRENT_FEATURE"
printf '%s\n' $'missing/repository\tdev-test\twrapper failure fixture' \
  > "$FIXTURE/features/dev-test/repos.tsv"
ln -s "$ROOT/features/dev-sidebar/check-branch.sh" \
  "$FIXTURE/features/dev-test/check-branch.sh"
set +e
wrapper_output="$(HARNESS_ROOT="$FIXTURE" "$ROOT/.codex/bin/codex-feature" --dry-run 2>&1)"
wrapper_rc=$?
set -e
test "$wrapper_rc" -ne 0
grep -Fq 'MISSING missing/repository' <<<"$wrapper_output"
test ! -e "$FIXTURE/AGENTS.md"
test ! -L "$FIXTURE/AGENTS.md"

REGRESSION_FAILURES=0

run_regression() {
  local name="$1"
  shift
  if "$@"; then
    return 0
  fi
  echo "FAIL  $name" >&2
  REGRESSION_FAILURES=$((REGRESSION_FAILURES + 1))
}

init_repo() {
  local path="$1"
  local branch="$2"

  mkdir -p "$path"
  git -C "$path" init -q -b "$branch"
  git -C "$path" -c user.name=test -c user.email=test@example.com \
    commit --allow-empty -qm init
}

test_invalid_current_features() {
  local index=0 value case_root legacy_context output rc
  local invalid_values=(
    '../escape'
    '/absolute'
    'dev/test'
    'dev test'
    '.'
    '..'
    $'dev-test\nsecond'
    ''
  )

  for value in "${invalid_values[@]}"; do
    index=$((index + 1))
    case_root="$FIXTURE/invalid-feature-$index"
    mkdir -p "$case_root/features"
    printf '%s' "$value" > "$case_root/CURRENT_FEATURE"

    case "$value" in
      '../escape') legacy_context="$case_root/escape/AGENTS.md" ;;
      '/absolute') legacy_context="$case_root/features/absolute/AGENTS.md" ;;
      'dev test') legacy_context="$case_root/features/devtest/AGENTS.md" ;;
      '.') legacy_context="$case_root/features/AGENTS.md" ;;
      '..') legacy_context="$case_root/AGENTS.md" ;;
      $'dev-test\nsecond') legacy_context="$case_root/features/dev-testsecond/AGENTS.md" ;;
      '') legacy_context='' ;;
    esac
    if [[ -n "$legacy_context" ]]; then
      mkdir -p "$(dirname "$legacy_context")"
      printf '%s\n' '# invalid feature must not select this file' > "$legacy_context"
    fi

    set +e
    output="$(HARNESS_ROOT="$case_root" "$ROOT/.codex/bin/codex-feature" --dry-run 2>&1)"
    rc=$?
    set -e
    [[ "$rc" -ne 0 ]] || return 1
    grep -Fq 'INVALID feature' <<<"$output" || return 1
  done
}

test_invalid_active_features() {
  local case_root="$FIXTURE/invalid-active-feature"
  local value output rc

  mkdir -p "$case_root/features" "$case_root/escape"
  printf '%s\n' $'repos/one\t../escape\tdescription' \
    > "$case_root/escape/repos.tsv"

  for value in '../escape' $'dev-test\nsecond'; do
    set +e
    output="$(HARNESS_ROOT="$case_root" FEATURE_NAME="$value" \
      "$ROOT/features/dev-sidebar/check-branch.sh" 2>&1)"
    rc=$?
    set -e
    [[ "$rc" -ne 0 ]] || return 1
    grep -Fq 'INVALID feature' <<<"$output" || return 1
  done
}

test_nul_current_feature() {
  local case_root="$FIXTURE/nul-current-feature"
  local output rc

  mkdir -p "$case_root/features/dev-testsuffix"
  printf '%s\n' '# invalid normalized context' \
    > "$case_root/features/dev-testsuffix/AGENTS.md"
  printf 'dev-test\0suffix\n' > "$case_root/CURRENT_FEATURE"

  set +e
  output="$(HARNESS_ROOT="$case_root" "$ROOT/.codex/bin/codex-feature" --dry-run 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fq 'INVALID feature' <<<"$output" || return 1
  [[ ! -L "$case_root/AGENTS.md" ]]
}

test_anchor_feature_detection() {
  local case_root="$FIXTURE/anchor-feature"

  mkdir -p "$case_root/features/dev-anchor" "$case_root/features/dev-fallback"
  printf '%s\n' '# anchor context' > "$case_root/features/dev-anchor/AGENTS.md"
  printf '%s\n' '# fallback context' > "$case_root/features/dev-fallback/AGENTS.md"
  printf '%s\n' 'dev-fallback' > "$case_root/CURRENT_FEATURE"
  init_repo "$case_root/frameworks/base" dev-anchor || return 1

  HARNESS_ROOT="$case_root" "$ROOT/.codex/bin/codex-feature" --dry-run >/dev/null || return 1
  [[ "$(readlink "$case_root/AGENTS.md")" == 'features/dev-anchor/AGENTS.md' ]]
}

test_invalid_anchor_feature() {
  local case_root="$FIXTURE/invalid-anchor"
  local output rc

  mkdir -p "$case_root/features/feature/dev-anchor" "$case_root/features/dev-fallback"
  printf '%s\n' '# invalid nested context' > "$case_root/features/feature/dev-anchor/AGENTS.md"
  printf '%s\n' '# fallback context' > "$case_root/features/dev-fallback/AGENTS.md"
  printf '%s\n' 'dev-fallback' > "$case_root/CURRENT_FEATURE"
  init_repo "$case_root/frameworks/base" feature/dev-anchor || return 1

  set +e
  output="$(HARNESS_ROOT="$case_root" "$ROOT/.codex/bin/codex-feature" --dry-run 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fq 'INVALID feature' <<<"$output" || return 1
  [[ ! -L "$case_root/AGENTS.md" ]]
}

test_invalid_anchor_metadata_is_skipped() {
  local case_root="$FIXTURE/invalid-anchor-metadata"

  mkdir -p "$case_root/frameworks/base/.git" "$case_root/features/dev-native"
  printf '%s\n' '# native anchor context' > "$case_root/features/dev-native/AGENTS.md"
  printf '%s\n' 'dev-fallback' > "$case_root/CURRENT_FEATURE"
  init_repo "$case_root/frameworks/native" dev-native || return 1

  HARNESS_ROOT="$case_root" "$ROOT/.codex/bin/codex-feature" --dry-run >/dev/null || return 1
  [[ "$(readlink "$case_root/AGENTS.md")" == 'features/dev-native/AGENTS.md' ]]
}

test_malformed_manifests() {
  local case_root="$FIXTURE/malformed-manifest"
  local output rc row

  mkdir -p "$case_root/features/dev-test"
  init_repo "$case_root/repos/one" dev-test || return 1

  for row in \
    $'\tdev-test\tdescription' \
    $'repos/one\t\tdescription' \
    $'repos/one\tdev-test' \
    $'repos/one\tdev-test\t' \
    $'repos/one\tdev-test\tdescription\textra'; do
    printf '%s\n' "$row" > "$case_root/features/dev-test/repos.tsv"
    set +e
    output="$(HARNESS_ROOT="$case_root" FEATURE_NAME=dev-test \
      "$ROOT/features/dev-sidebar/check-branch.sh" 2>&1)"
    rc=$?
    set -e
    [[ "$rc" -ne 0 ]] || return 1
    grep -Fq 'INVALID manifest' <<<"$output" || return 1
  done
}

test_mismatched_manifest_feature() {
  local case_root="$FIXTURE/mismatched-manifest"
  local output rc

  mkdir -p "$case_root/features/dev-test"
  init_repo "$case_root/repos/one" dev-test || return 1
  printf '%s\n' $'repos/one\tother-feature\tdescription' \
    > "$case_root/features/dev-test/repos.tsv"

  set +e
  output="$(HARNESS_ROOT="$case_root" FEATURE_NAME=dev-test \
    "$ROOT/features/dev-sidebar/check-branch.sh" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fq 'INVALID manifest' <<<"$output"
}

test_nul_manifest_feature() {
  local case_root="$FIXTURE/nul-manifest-feature"
  local output rc

  mkdir -p "$case_root/features/dev-test"
  init_repo "$case_root/repos/one" dev-test || return 1
  printf 'repos/one\tdev-\0test\tdescription\n' \
    > "$case_root/features/dev-test/repos.tsv"

  set +e
  output="$(HARNESS_ROOT="$case_root" FEATURE_NAME=dev-test \
    "$ROOT/features/dev-sidebar/check-branch.sh" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fq 'INVALID manifest' <<<"$output"
}

test_actual_branch_drift() {
  local case_root="$FIXTURE/actual-drift"
  local output rc

  mkdir -p "$case_root/features/dev-test"
  init_repo "$case_root/repos/one" dev-other || return 1
  printf '%s\n' $'repos/one\tdev-test\tdescription' \
    > "$case_root/features/dev-test/repos.tsv"

  set +e
  output="$(HARNESS_ROOT="$case_root" FEATURE_NAME=dev-test \
    "$ROOT/features/dev-sidebar/check-branch.sh" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fq 'DRIFT   repos/one @ dev-other' <<<"$output"
}

test_detached_and_invalid_repositories() {
  local detached_root="$FIXTURE/detached-repo"
  local invalid_root="$FIXTURE/invalid-repo"
  local invalid_head_root="$FIXTURE/invalid-head-repo"
  local output rc

  mkdir -p "$detached_root/features/dev-test"
  init_repo "$detached_root/repos/one" dev-test || return 1
  git -C "$detached_root/repos/one" checkout -q --detach || return 1
  printf '%s\n' $'repos/one\tdev-test\tdescription' \
    > "$detached_root/features/dev-test/repos.tsv"
  set +e
  output="$(HARNESS_ROOT="$detached_root" FEATURE_NAME=dev-test \
    "$ROOT/features/dev-sidebar/check-branch.sh" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fq 'DRIFT   repos/one @ DETACHED' <<<"$output" || return 1

  mkdir -p "$invalid_root/features/dev-test" "$invalid_root/repos/bad/.git"
  printf '%s\n' $'repos/bad\tdev-test\tdescription' \
    > "$invalid_root/features/dev-test/repos.tsv"
  set +e
  output="$(HARNESS_ROOT="$invalid_root" FEATURE_NAME=dev-test \
    "$ROOT/features/dev-sidebar/check-branch.sh" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fq 'INVALID repos/bad' <<<"$output" || return 1

  mkdir -p "$invalid_head_root/features/dev-test"
  init_repo "$invalid_head_root/repos/bad-head" dev-test || return 1
  printf '%040d\n' 0 > "$invalid_head_root/repos/bad-head/.git/HEAD"
  printf '%s\n' $'repos/bad-head\tdev-test\tdescription' \
    > "$invalid_head_root/features/dev-test/repos.tsv"
  set +e
  output="$(HARNESS_ROOT="$invalid_head_root" FEATURE_NAME=dev-test \
    "$ROOT/features/dev-sidebar/check-branch.sh" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fq 'INVALID repos/bad-head' <<<"$output" || return 1
  ! grep -Fq 'DETACHED' <<<"$output"
}

test_stale_and_broken_links() {
  local kind case_root fake_bin

  for kind in stale broken; do
    case_root="$FIXTURE/$kind-link"
    fake_bin="$case_root/fake-bin"
    mkdir -p "$case_root/features/dev-test" "$fake_bin"
    printf '%s\n' 'dev-test' > "$case_root/CURRENT_FEATURE"
    printf '%s\n' '# selected context' > "$case_root/features/dev-test/AGENTS.md"
    if [[ "$kind" == stale ]]; then
      mkdir -p "$case_root/features/dev-old"
      printf '%s\n' '# old context' > "$case_root/features/dev-old/AGENTS.md"
    fi
    ln -s 'features/dev-old/AGENTS.md' "$case_root/AGENTS.md"
    printf '%s\n' '#!/usr/bin/env bash' 'exit 97' > "$fake_bin/mv"
    chmod +x "$fake_bin/mv"

    PATH="$fake_bin:$PATH" HARNESS_ROOT="$case_root" \
      "$ROOT/.codex/bin/codex-feature" --dry-run >/dev/null || return 1
    [[ "$(readlink "$case_root/AGENTS.md")" == 'features/dev-test/AGENTS.md' ]] || return 1
  done
}

test_old_link_survives_branch_failure() {
  local case_root="$FIXTURE/preserve-old-link"
  local output rc

  mkdir -p "$case_root/.repo" "$case_root/features/dev-test" "$case_root/features/dev-old"
  printf '%s\n' 'dev-test' > "$case_root/CURRENT_FEATURE"
  printf '%s\n' '# selected context' > "$case_root/features/dev-test/AGENTS.md"
  printf '%s\n' '# old context' > "$case_root/features/dev-old/AGENTS.md"
  printf '%s\n' $'missing/repository\tdev-test\tdescription' \
    > "$case_root/features/dev-test/repos.tsv"
  ln -s "$ROOT/features/dev-sidebar/check-branch.sh" \
    "$case_root/features/dev-test/check-branch.sh"
  ln -s 'features/dev-old/AGENTS.md' "$case_root/AGENTS.md"

  set +e
  output="$(HARNESS_ROOT="$case_root" "$ROOT/.codex/bin/codex-feature" --dry-run 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fq 'MISSING missing/repository' <<<"$output" || return 1
  [[ "$(readlink "$case_root/AGENTS.md")" == 'features/dev-old/AGENTS.md' ]]
}

test_repo_marker_file_is_ignored() {
  local case_root="$FIXTURE/repo-marker-file"

  mkdir -p "$case_root/features/dev-test"
  printf '%s\n' 'dev-test' > "$case_root/CURRENT_FEATURE"
  printf '%s\n' '# selected context' > "$case_root/features/dev-test/AGENTS.md"
  printf '%s\n' 'not a repo directory' > "$case_root/.repo"

  HARNESS_ROOT="$case_root" "$ROOT/.codex/bin/codex-feature" --dry-run >/dev/null || return 1
  [[ "$(readlink "$case_root/AGENTS.md")" == 'features/dev-test/AGENTS.md' ]]
}

test_launch_cwd_and_arguments() {
  local case_root="$FIXTURE/normal-launch"
  local fake_bin="$case_root/fake-bin"
  local capture="$case_root/capture"

  mkdir -p "$case_root/features/dev-test" "$fake_bin" "$capture"
  printf '%s\n' 'dev-test' > "$case_root/CURRENT_FEATURE"
  printf '%s\n' '# selected context' > "$case_root/features/dev-test/AGENTS.md"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "%s\n" "$PWD" > "$CODEX_CAPTURE/cwd"' \
    'printf "%s\n" "$@" > "$CODEX_CAPTURE/args"' \
    > "$fake_bin/codex"
  chmod +x "$fake_bin/codex"

  CODEX_CAPTURE="$capture" PATH="$fake_bin:$PATH" HARNESS_ROOT="$case_root" \
    "$ROOT/.codex/bin/codex-feature" alpha 'two words' --flag >/dev/null || return 1
  [[ "$(cat "$capture/cwd")" == "$case_root" ]] || return 1
  printf '%s\n' alpha 'two words' --flag > "$capture/expected-args"
  cmp -s "$capture/expected-args" "$capture/args"
}

test_hook_configuration() {
  python3 - "$ROOT/.codex/hooks.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as config_file:
    actual = json.load(config_file)

expected = {
    "description": "Select and guard the active AOSP feature context.",
    "hooks": {
        "SessionStart": [{
            "matcher": "startup",
            "hooks": [{
                "type": "command",
                "command": "./.codex/hooks/session-start.sh",
                "timeout": 10,
                "statusMessage": "Recording the active AOSP feature",
            }],
        }],
        "UserPromptSubmit": [{
            "hooks": [{
                "type": "command",
                "command": "./.codex/hooks/check-branch-drift.sh",
                "timeout": 10,
                "statusMessage": "Checking AOSP feature consistency",
            }],
        }],
    },
}
assert actual == expected
PY
}

test_session_snapshots_and_branch_drift() {
  local state_dir="$FIXTURE/state"
  local session_start="$ROOT/.codex/hooks/session-start.sh"
  local drift_check="$ROOT/.codex/hooks/check-branch-drift.sh"
  local session_a_input session_a_drift_input session_b_input session_b_drift_input
  local session_start_output drift_output

  session_a_input="$(printf \
    '{"session_id":"session-a","cwd":"%s","hook_event_name":"SessionStart"}' \
    "$FIXTURE")"
  session_b_input="$(printf \
    '{"session_id":"session-b","cwd":"%s","hook_event_name":"SessionStart"}' \
    "$FIXTURE")"
  session_a_drift_input="$(printf \
    '{"session_id":"session-a","cwd":"%s","hook_event_name":"UserPromptSubmit"}' \
    "$FIXTURE")"
  session_b_drift_input="$(printf \
    '{"session_id":"session-b","cwd":"%s","hook_event_name":"UserPromptSubmit"}' \
    "$FIXTURE")"

  printf '%s\n' 'dev-test' > "$FIXTURE/CURRENT_FEATURE"
  mkdir -p "$state_dir"
  chmod 755 "$state_dir"
  session_start_output="$(printf '%s\n' "$session_a_input" | \
    HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR="$state_dir" \
    "$session_start")" || return 1
  [[ -z "$session_start_output" ]] || return 1

  [[ "$(cat "$state_dir/session-a.feature")" == 'dev-test' ]] || return 1
  [[ "$(stat -c '%a' "$state_dir")" == '700' ]] || return 1
  [[ "$(stat -c '%a' "$state_dir/session-a.feature")" == '600' ]] || return 1

  drift_output="$(printf '%s\n' "$session_a_drift_input" | \
    HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR="$state_dir" \
    "$drift_check")" || return 1
  [[ -z "$drift_output" ]] || return 1

  mkdir -p "$FIXTURE/features/dev-next"
  printf '%s\n' '# feature: dev-next' > "$FIXTURE/features/dev-next/AGENTS.md"
  printf '%s\n' 'dev-next' > "$FIXTURE/CURRENT_FEATURE"

  session_start_output="$(printf '%s\n' "$session_b_input" | \
    HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR="$state_dir" \
    "$session_start")" || return 1
  [[ -z "$session_start_output" ]] || return 1
  [[ "$(cat "$state_dir/session-b.feature")" == 'dev-next' ]] || return 1
  [[ "$(stat -c '%a' "$state_dir/session-b.feature")" == '600' ]] || return 1

  drift_output="$(printf '%s\n' "$session_a_drift_input" | \
    HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR="$state_dir" \
    "$drift_check")" || return 1

  python3 - "$drift_output" <<'PY' || return 1
import json
import sys

data = json.loads(sys.argv[1])
assert data == {
    "continue": False,
    "stopReason": (
        "AOSP feature drift: session started on 'dev-test', "
        "current feature is 'dev-next'."
    ),
    "systemMessage": (
        "Feature changed during this Codex session. Restart with "
        "./.codex/bin/codex-feature before continuing."
    ),
}
PY

  drift_output="$(printf '%s\n' "$session_b_drift_input" | \
    HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR="$state_dir" \
    "$drift_check")" || return 1
  [[ -z "$drift_output" ]] || return 1
  [[ "$(cat "$state_dir/session-a.feature")" == 'dev-test' ]] || return 1
  [[ "$(cat "$state_dir/session-b.feature")" == 'dev-next' ]]
}

test_invalid_hook_inputs_are_rejected() {
  local state_dir="$FIXTURE/state"
  local before_files after_files hook payload output rc
  local hooks=(
    "$ROOT/.codex/hooks/session-start.sh"
    "$ROOT/.codex/hooks/check-branch-drift.sh"
  )
  local invalid_inputs=(
    'not-json'
    '{}'
    '{"session_id":""}'
    '{"session_id":null}'
    '{"session_id":"../escape"}'
    '{"session_id":"nested/session"}'
    '{"session_id":"."}'
    '{"session_id":".."}'
  )

  before_files="$(find "$state_dir" -maxdepth 1 -type f -printf '%f\n' | sort)"
  for hook in "${hooks[@]}"; do
    for payload in "${invalid_inputs[@]}"; do
      set +e
      output="$(printf '%s\n' "$payload" | \
        HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR="$state_dir" \
        "$hook" 2>&1)"
      rc=$?
      set -e
      [[ "$rc" -ne 0 ]] || return 1
      [[ "$output" == 'error: invalid hook input' ]] || return 1
    done
  done
  after_files="$(find "$state_dir" -maxdepth 1 -type f -printf '%f\n' | sort)"

  [[ "$before_files" == "$after_files" ]] || return 1
  [[ ! -e "$FIXTURE/escape.feature" ]] || return 1
  [[ ! -e "$state_dir/nested/session.feature" ]]
}

test_session_id_length_boundaries() {
  local state_dir="$FIXTURE/state"
  local session_start="$ROOT/.codex/hooks/session-start.sh"
  local drift_check="$ROOT/.codex/hooks/check-branch-drift.sh"
  local accepted_id rejected_id accepted_input rejected_input hook output rc
  local hooks=("$session_start" "$drift_check")

  accepted_id="$(python3 -c 'print("a" * 128, end="")')"
  rejected_id="$(python3 -c 'print("b" * 129, end="")')"
  accepted_input="$(printf '{"session_id":"%s"}' "$accepted_id")"
  rejected_input="$(printf '{"session_id":"%s"}' "$rejected_id")"

  output="$(printf '%s\n' "$accepted_input" | \
    HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR="$state_dir" \
    "$session_start")" || return 1
  [[ -z "$output" ]] || return 1
  [[ "$(cat "$state_dir/$accepted_id.feature")" == 'dev-next' ]] || return 1
  output="$(printf '%s\n' "$accepted_input" | \
    HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR="$state_dir" \
    "$drift_check")" || return 1
  [[ -z "$output" ]] || return 1

  for hook in "${hooks[@]}"; do
    set +e
    output="$(printf '%s\n' "$rejected_input" | \
      HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR="$state_dir" \
      "$hook" 2>&1)"
    rc=$?
    set -e
    [[ "$rc" -ne 0 ]] || return 1
    [[ "$output" == 'error: invalid hook input' ]] || return 1
  done
  [[ ! -e "$state_dir/$rejected_id.feature" ]]
}

test_state_directory_creation_and_default_path() {
  local session_start="$ROOT/.codex/hooks/session-start.sh"
  local drift_check="$ROOT/.codex/hooks/check-branch-drift.sh"
  local new_state="$FIXTURE/new-state"
  local private_tmp="$FIXTURE/private-tmp"
  local default_state="$private_tmp/aosp-codex-harness-$UID"
  local relative_root="$FIXTURE/relative-state-root"
  local input output

  input='{"session_id":"state-creation"}'
  [[ ! -e "$new_state" ]] || return 1
  output="$(printf '%s\n' "$input" | \
    HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR="$new_state" \
    "$session_start")" || return 1
  [[ -z "$output" ]] || return 1
  [[ "$(stat -c '%a' "$new_state")" == '700' ]] || return 1
  [[ "$(cat "$new_state/state-creation.feature")" == 'dev-next' ]] || return 1

  mkdir -p "$private_tmp"
  input='{"session_id":"default-state"}'
  output="$(printf '%s\n' "$input" | env -u CODEX_HARNESS_STATE_DIR \
    TMPDIR="$private_tmp" HARNESS_ROOT="$FIXTURE" "$session_start")" || return 1
  [[ -z "$output" ]] || return 1
  [[ "$(stat -c '%a' "$default_state")" == '700' ]] || return 1
  [[ "$(cat "$default_state/default-state.feature")" == 'dev-next' ]] || return 1

  mkdir -p "$relative_root"
  input='{"session_id":"relative-state"}'
  output="$(cd "$relative_root" && printf '%s\n' "$input" | \
    HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR='state' \
    "$session_start")" || return 1
  [[ -z "$output" ]] || return 1
  [[ "$(stat -c '%a' "$relative_root/state")" == '700' ]] || return 1
  [[ "$(cat "$relative_root/state/relative-state.feature")" == 'dev-next' ]] || return 1
  output="$(cd "$relative_root" && printf '%s\n' "$input" | \
    HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR='state' \
    "$drift_check")" || return 1
  [[ -z "$output" ]]
}

test_feature_detection_errors_are_concise() {
  local missing_root="$FIXTURE/hook-missing-feature"
  local context_root="$FIXTURE/hook-missing-context"
  local input hook case_root expected state_dir output rc
  local hooks=(
    "$ROOT/.codex/hooks/session-start.sh"
    "$ROOT/.codex/hooks/check-branch-drift.sh"
  )

  mkdir -p "$missing_root/features" "$context_root/features/dev-test"
  printf '%s\n' 'dev-test' > "$context_root/CURRENT_FEATURE"
  input='{"session_id":"feature-error"}'

  for hook in "${hooks[@]}"; do
    for case_root in "$missing_root" "$context_root"; do
      if [[ "$case_root" == "$missing_root" ]]; then
        expected='error: unable to detect active feature'
      else
        expected='error: active feature context is unavailable'
      fi
      state_dir="$case_root/state"
      set +e
      output="$(printf '%s\n' "$input" | \
        HARNESS_ROOT="$case_root" CODEX_HARNESS_STATE_DIR="$state_dir" \
        "$hook" 2>&1)"
      rc=$?
      set -e
      [[ "$rc" -ne 0 ]] || return 1
      [[ "$output" == "$expected" ]] || return 1
      [[ ! -e "$state_dir" ]] || return 1
    done
  done
}

test_python_encoding_cannot_redirect_hook_state() {
  local session_start="$ROOT/.codex/hooks/session-start.sh"
  local drift_check="$ROOT/.codex/hooks/check-branch-drift.sh"
  local encoding_root="$FIXTURE/encoding-state-root"
  local redirect_target="$FIXTURE/encoding-redirect-target"
  local bom_state="$encoding_root/"$'\357\273\277''validated-state'
  local input output

  mkdir -p \
    "$encoding_root/validated-state" \
    "$redirect_target" \
    "$FIXTURE/features/dev-encoding"
  ln -s "$redirect_target" "$bom_state"
  printf '%s\n' '# feature: dev-encoding' \
    > "$FIXTURE/features/dev-encoding/AGENTS.md"
  input='{"session_id":"encoding-session"}'

  output="$(cd "$encoding_root" && printf '%s\n' "$input" | \
    PYTHONIOENCODING='utf-8-sig' HARNESS_ROOT="$FIXTURE" \
    CODEX_HARNESS_STATE_DIR='validated-state' "$session_start")" || return 1
  [[ -z "$output" ]] || return 1
  [[ "$(cat "$encoding_root/validated-state/encoding-session.feature")" == 'dev-next' ]] || return 1
  [[ ! -e "$redirect_target/encoding-session.feature" ]] || return 1

  output="$(cd "$encoding_root" && printf '%s\n' "$input" | \
    PYTHONIOENCODING='utf-8-sig' HARNESS_ROOT="$FIXTURE" \
    CODEX_HARNESS_STATE_DIR='validated-state' "$drift_check")" || return 1
  [[ -z "$output" ]] || return 1

  printf '%s\n' 'dev-encoding' > "$FIXTURE/CURRENT_FEATURE"
  output="$(cd "$encoding_root" && printf '%s\n' "$input" | \
    PYTHONIOENCODING='utf-8-sig' HARNESS_ROOT="$FIXTURE" \
    CODEX_HARNESS_STATE_DIR='validated-state' "$drift_check")" || return 1
  python3 - "$output" <<'PY' || return 1
import json
import sys

data = json.loads(sys.argv[1])
assert data == {
    "continue": False,
    "stopReason": (
        "AOSP feature drift: session started on 'dev-next', "
        "current feature is 'dev-encoding'."
    ),
    "systemMessage": (
        "Feature changed during this Codex session. Restart with "
        "./.codex/bin/codex-feature before continuing."
    ),
}
PY
  printf '%s\n' 'dev-next' > "$FIXTURE/CURRENT_FEATURE"
}

test_unsafe_state_paths_are_rejected() {
  local state_file="$FIXTURE/unsafe-state-file"
  local state_target="$FIXTURE/unsafe-state-target"
  local state_link="$FIXTURE/unsafe-state-link"
  local parent_target="$FIXTURE/unsafe-parent-target"
  local parent_link="$FIXTURE/unsafe-parent-link"
  local newline_target="$FIXTURE/unsafe-newline-target"
  local newline_link="$FIXTURE/unsafe-newline-state"
  local newline_path input hook state_path output rc
  local hooks=(
    "$ROOT/.codex/hooks/session-start.sh"
    "$ROOT/.codex/hooks/check-branch-drift.sh"
  )

  input="$(printf \
    '{"session_id":"state-safety","cwd":"%s","hook_event_name":"SessionStart"}' \
    "$FIXTURE")"
  printf '%s\n' 'not a directory' > "$state_file"
  mkdir -p "$state_target" "$parent_target" "$newline_target"
  ln -s "$state_target" "$state_link"
  ln -s "$parent_target" "$parent_link"
  ln -s "$newline_target" "$newline_link"
  newline_path="$newline_link"$'\n'

  for hook in "${hooks[@]}"; do
    for state_path in \
      "$state_file" \
      "$state_link" \
      "$state_link/" \
      "$state_link/." \
      "$state_link/./" \
      "$state_target/./dot-component" \
      "$state_target/../dotdot-component" \
      "$newline_path" \
      "$parent_link/nested-state"; do
      set +e
      output="$(printf '%s\n' "$input" | \
        HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR="$state_path" \
        "$hook" 2>&1)"
      rc=$?
      set -e
      [[ "$rc" -ne 0 ]] || return 1
      [[ "$output" == 'error: unsafe harness state directory' ]] || return 1
    done
  done

  [[ ! -e "$state_target/state-safety.feature" ]] || return 1
  [[ ! -e "$state_target/dot-component" ]] || return 1
  [[ ! -e "$FIXTURE/dotdot-component" ]] || return 1
  [[ ! -e "$newline_target/state-safety.feature" ]] || return 1
  [[ ! -e "$newline_path" ]] || return 1
  [[ ! -e "$parent_target/nested-state" ]]
}

test_missing_session_snapshot_fails_closed() {
  local state_dir="$FIXTURE/state"
  local drift_check="$ROOT/.codex/hooks/check-branch-drift.sh"
  local input output

  input="$(printf \
    '{"session_id":"session-missing","cwd":"%s","hook_event_name":"UserPromptSubmit"}' \
    "$FIXTURE")"
  [[ ! -e "$state_dir/session-missing.feature" ]] || return 1
  output="$(printf '%s\n' "$input" | \
    HARNESS_ROOT="$FIXTURE" CODEX_HARNESS_STATE_DIR="$state_dir" \
    "$drift_check")" || return 1

  python3 - "$output" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
assert data["continue"] is False
assert "session-missing" in data["stopReason"]
assert "snapshot" in data["stopReason"].lower()
assert "restart" in data["stopReason"].lower()
assert data["systemMessage"] == (
    "Feature changed during this Codex session. Restart with "
    "./.codex/bin/codex-feature before continuing."
)
PY
}

run_regression 'invalid CURRENT_FEATURE values are rejected' test_invalid_current_features
run_regression 'invalid active feature values are rejected' test_invalid_active_features
run_regression 'NUL bytes in CURRENT_FEATURE are rejected' test_nul_current_feature
run_regression 'attached anchor branch selects the feature' test_anchor_feature_detection
run_regression 'invalid anchor feature is rejected' test_invalid_anchor_feature
run_regression 'invalid anchor Git metadata is skipped' test_invalid_anchor_metadata_is_skipped
run_regression 'malformed TSV rows are rejected' test_malformed_manifests
run_regression 'mismatched manifest feature is rejected' test_mismatched_manifest_feature
run_regression 'NUL bytes in manifest features are rejected' test_nul_manifest_feature
run_regression 'actual branch drift is reported' test_actual_branch_drift
run_regression 'detached and invalid repositories are distinguished' test_detached_and_invalid_repositories
run_regression 'stale and broken links are portably replaced' test_stale_and_broken_links
run_regression 'old link survives branch validation failure' test_old_link_survives_branch_failure
run_regression '.repo regular file does not trigger validation' test_repo_marker_file_is_ignored
run_regression 'normal launch preserves cwd and arguments' test_launch_cwd_and_arguments
run_regression 'hook registrations match the Codex contract' test_hook_configuration
run_regression 'sessions retain independent feature snapshots and detect drift' test_session_snapshots_and_branch_drift
run_regression 'hook input rejects malformed and unsafe session identifiers' test_invalid_hook_inputs_are_rejected
run_regression 'session identifiers have a filesystem-safe length bound' test_session_id_length_boundaries
run_regression 'state directories are created privately at override and default paths' test_state_directory_creation_and_default_path
run_regression 'feature detection errors are concise and create no state' test_feature_detection_errors_are_concise
run_regression 'Python encoding cannot redirect validated hook state' test_python_encoding_cannot_redirect_hook_state
run_regression 'hooks reject unsafe state directory paths' test_unsafe_state_paths_are_rejected
run_regression 'missing session snapshots fail closed with restart guidance' test_missing_session_snapshot_fails_closed

if [[ "$REGRESSION_FAILURES" -ne 0 ]]; then
  echo "FAIL  $REGRESSION_FAILURES Codex harness regression case(s)" >&2
  exit 1
fi

echo 'PASS  Codex feature context selection and branch checks'
