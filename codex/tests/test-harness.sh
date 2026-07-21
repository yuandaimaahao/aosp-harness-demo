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

assert_skill_frontmatter() {
  local file="$1"
  local expected_name="$2"
  local expected_description="$3"

  python3 - "$file" "$expected_name" "$expected_description" <<'PY'
from pathlib import Path
import sys

skill_path = Path(sys.argv[1])
expected_name = sys.argv[2]
expected_description = sys.argv[3]
lines = skill_path.read_text(encoding="utf-8").splitlines()

assert lines and lines[0] == "---", f"{skill_path}: missing opening frontmatter boundary"
try:
    closing_boundary = lines.index("---", 1)
except ValueError as exc:
    raise AssertionError(f"{skill_path}: missing closing frontmatter boundary") from exc

frontmatter = lines[1:closing_boundary]
entries = []
for line in frontmatter:
    key, separator, value = line.partition(":")
    assert separator and key, f"{skill_path}: malformed frontmatter line: {line!r}"
    entries.append((key, value.strip()))

assert [key for key, _ in entries] == ["name", "description"], (
    f"{skill_path}: frontmatter keys must be exactly name and description"
)
metadata = dict(entries)
assert metadata["name"] == expected_name, f"{skill_path}: unexpected skill name"
assert metadata["description"], f"{skill_path}: description must not be empty"
assert metadata["description"] == expected_description, (
    f"{skill_path}: description differs from the repository contract"
)
PY
}

require_skill_texts() {
  local file="$1"
  shift
  local text

  for text in "$@"; do
    grep -Fq "$text" "$file" || return 1
  done
}

test_process_skill_artifacts() {
  local services="$ROOT/.agents/skills/build-services-jar/SKILL.md"
  local sepolicy="$ROOT/.agents/skills/build-sepolicy/SKILL.md"
  local services_description
  local sepolicy_description

  services_description='Build and deploy AOSP services.jar after changes under frameworks/base/services, including SystemServer services; use for compile targets, artifacts, push steps, ART cache risks, and feature verification.'
  sepolicy_description='Build and verify AOSP SELinux policy after changes under system/sepolicy, especially new system services requiring service_contexts, service types, allow rules, denial checks, and full feature verification.'

  [[ -f "$services" ]] || return 1
  [[ -f "$sepolicy" ]] || return 1
  assert_skill_frontmatter "$services" build-services-jar "$services_description" || return 1
  assert_skill_frontmatter "$sepolicy" build-sepolicy "$sepolicy_description" || return 1

  if grep -Eq '^[[:space:]]*paths:' "$services" "$sepolicy"; then
    return 1
  fi
  if grep -Eiq 'automatic(ally)?[[:space:]-]+activat|auto-activat|自动激活' \
      "$services" "$sepolicy"; then
    return 1
  fi

  require_skill_texts "$services" \
    '$build-services-jar' \
    'AGENTS.md' \
    'description' \
    'File paths alone do not select skills.' \
    'bash -c' \
    'source build/envsetup.sh' \
    'lunch aosp_cf_x86_64_phone-trunk_staging-userdebug' \
    'm services' \
    'same exec session' \
    'build_log="$(mktemp "${TMPDIR:-/tmp}/build-services.XXXXXX.log")"' \
    'while kill -0 "$build_pid" 2>/dev/null; do' \
    'wait "$build_pid"' \
    'build_rc=$?' \
    '[[ "$build_rc" -ne 0 ]]' \
    '#### build completed successfully ####' \
    'out/target/product/vsoc_x86_64/system/framework/services.jar' \
    '[[ -f "$artifact" ]]' \
    'device_serial="${ANDROID_SERIAL:?Set ANDROID_SERIAL to the explicitly confirmed target serial}"' \
    'adb -s "$device_serial" get-state' \
    'adb -s "$device_serial" root' \
    'adb -s "$device_serial" remount' \
    'adb -s "$device_serial" push' \
    'adb -s "$device_serial" reboot' \
    'target device' \
    'change device state' \
    'ART' \
    'dexpreopt' \
    '/data/dalvik-cache/' \
    'full_build_log="$(mktemp "${TMPDIR:-/tmp}/build-full-services.XXXXXX.log")"' \
    'full_build_pid=$!' \
    'while kill -0 "$full_build_pid" 2>/dev/null; do' \
    'wait "$full_build_pid"' \
    'full_build_rc=$?' \
    '[[ "$full_build_rc" -ne 0 ]]' \
    'grep -Fq "#### build completed successfully ####" "$full_build_log"' \
    'image_artifact="out/target/product/vsoc_x86_64/system.img"' \
    '[[ -f "$image_artifact" ]]' \
    'cvd fleet' \
    'cvd_group="${CVD_GROUP:?Set CVD_GROUP to the explicitly confirmed group from cvd fleet}"' \
    'cvd --group_name="$cvd_group" stop' \
    'cvd --group_name="$cvd_group" start' \
    'm update-api' \
    'SELinux' \
    'verify-*.sh' \
    'RESULT PASS' || return 1

  require_skill_texts "$sepolicy" \
    '$build-sepolicy' \
    'AGENTS.md' \
    'description' \
    'File paths alone do not select skills.' \
    'bash -c' \
    'source build/envsetup.sh' \
    'lunch aosp_cf_x86_64_phone-trunk_staging-userdebug' \
    'm selinux_policy' \
    'same exec session' \
    'build_log="$(mktemp "${TMPDIR:-/tmp}/build-sepolicy.XXXXXX.log")"' \
    'while kill -0 "$build_pid" 2>/dev/null; do' \
    'wait "$build_pid"' \
    'build_rc=$?' \
    '[[ "$build_rc" -ne 0 ]]' \
    '#### build completed successfully ####' \
    'out/target/product/vsoc_x86_64/system/etc/selinux/plat_sepolicy.cil' \
    '[[ -f "$artifact" ]]' \
    'service_contexts' \
    'type sidebar_service, system_server_service, service_manager_type;' \
    'add_service(system_server, system_server_service)' \
    'allow sidebar_app sidebar_service:service_manager find;' \
    'avc: denied' \
    'service list' \
    'device_serial="${ANDROID_SERIAL:?Set ANDROID_SERIAL to the explicitly confirmed target serial}"' \
    'adb -s "$device_serial" get-state' \
    'adb -s "$device_serial" shell dmesg' \
    'adb -s "$device_serial" shell service list' \
    'full image' \
    'full_build_log="$(mktemp "${TMPDIR:-/tmp}/build-full-sepolicy.XXXXXX.log")"' \
    'full_build_pid=$!' \
    'while kill -0 "$full_build_pid" 2>/dev/null; do' \
    'wait "$full_build_pid"' \
    'full_build_rc=$?' \
    '[[ "$full_build_rc" -ne 0 ]]' \
    'grep -Fq "#### build completed successfully ####" "$full_build_log"' \
    'image_artifact="out/target/product/vsoc_x86_64/system.img"' \
    '[[ -f "$image_artifact" ]]' \
    'cvd fleet' \
    'cvd_group="${CVD_GROUP:?Set CVD_GROUP to the explicitly confirmed group from cvd fleet}"' \
    'cvd --group_name="$cvd_group" stop' \
    'cvd --group_name="$cvd_group" start' \
    'not a services.jar push' \
    'verify-*.sh' \
    'RESULT PASS' || return 1

  if grep -Eq '^[[:space:]]*adb[[:space:]]+(root|remount|push|reboot)' "$services"; then
    return 1
  fi
  if grep -Eq '^[[:space:]]*adb[[:space:]]+shell[[:space:]]+(dmesg|service)' "$sepolicy"; then
    return 1
  fi
  if grep -Eq '^[[:space:]]*cvd[[:space:]]+(stop|start)' "$services" "$sepolicy"; then
    return 1
  fi
  if grep -Fq 'allow system_server sidebar_service:service_manager { add find };' "$sepolicy"; then
    return 1
  fi
}

test_process_layer_checker() {
  local checker="$ROOT/.codex/bin/check-process-layer"
  local arbitrary_cwd="$FIXTURE/process-layer-cwd"
  local expected output

  [[ -x "$checker" ]] || return 1
  mkdir -p "$arbitrary_cwd"
  output="$(cd "$arbitrary_cwd" && "$checker")" || return 1
  expected="$(printf '%s\n' \
    'PASS  build-services-jar skill 工件完整' \
    'PASS  build-sepolicy skill 工件完整' \
    'RESULT PASS')"
  [[ "$output" == "$expected" ]]
}

test_process_layer_checker_rejects_fact() {
  local case_name="$1"
  local skill_name="$2"
  local original_text="$3"
  local replacement_text="$4"
  local expected_label="$5"
  local checker="$ROOT/.codex/bin/check-process-layer"
  local case_root="$FIXTURE/process-layer-negative-$case_name"
  local source_services="$ROOT/.agents/skills/build-services-jar/SKILL.md"
  local source_sepolicy="$ROOT/.agents/skills/build-sepolicy/SKILL.md"
  local fixture_services="$case_root/.agents/skills/build-services-jar/SKILL.md"
  local fixture_sepolicy="$case_root/.agents/skills/build-sepolicy/SKILL.md"
  local target_file
  local output rc

  [[ -x "$checker" ]] || return 1
  [[ -f "$source_services" ]] || return 1
  [[ -f "$source_sepolicy" ]] || return 1
  mkdir -p "$(dirname "$fixture_services")" "$(dirname "$fixture_sepolicy")"
  cp "$source_services" "$fixture_services"
  cp "$source_sepolicy" "$fixture_sepolicy"

  case "$skill_name" in
    build-services-jar) target_file="$fixture_services" ;;
    build-sepolicy) target_file="$fixture_sepolicy" ;;
    *) return 1 ;;
  esac
  python3 - "$target_file" "$original_text" "$replacement_text" <<'PY' || return 1
from pathlib import Path
import sys

path = Path(sys.argv[1])
original = sys.argv[2]
replacement = sys.argv[3]
content = path.read_text(encoding="utf-8")
occurrences = content.count(original)
if occurrences >= 1:
    content = content.replace(original, replacement)
else:
    assert replacement in content, (
        f"{path}: fixture has neither {original!r} nor existing {replacement!r}"
    )
path.write_text(content, encoding="utf-8")
PY

  set +e
  output="$(HARNESS_ROOT="$case_root" "$checker" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fq "FAIL  $expected_label:" <<<"$output"
}

test_process_layer_checker_rejects_full_build_line() {
  local case_name="$1" skill_name="$2" original_line="$3" replacement_line="$4"
  local expected_label="$5" checker="$ROOT/.codex/bin/check-process-layer"
  local case_root="$FIXTURE/process-layer-full-section-$case_name"
  local source_services="$ROOT/.agents/skills/build-services-jar/SKILL.md"
  local source_sepolicy="$ROOT/.agents/skills/build-sepolicy/SKILL.md"
  local fixture_services="$case_root/.agents/skills/build-services-jar/SKILL.md"
  local fixture_sepolicy="$case_root/.agents/skills/build-sepolicy/SKILL.md"
  local target_file start_marker output rc

  mkdir -p "$(dirname "$fixture_services")" "$(dirname "$fixture_sepolicy")"
  cp "$source_services" "$fixture_services"
  cp "$source_sepolicy" "$fixture_sepolicy"
  case "$skill_name" in
    build-services-jar)
      target_file="$fixture_services"
      start_marker='build-full-services.XXXXXX.log'
      ;;
    build-sepolicy)
      target_file="$fixture_sepolicy"
      start_marker='build-full-sepolicy.XXXXXX.log'
      ;;
    *) return 1 ;;
  esac

  python3 - "$target_file" "$start_marker" "$original_line" "$replacement_line" <<'PY' || return 1
from pathlib import Path
import sys

path = Path(sys.argv[1])
start_marker, original, replacement = sys.argv[2:]
lines = path.read_text(encoding="utf-8").splitlines()
start = next(i for i, line in enumerate(lines) if start_marker in line)
end = next(i for i in range(start, len(lines)) if '[[ -f "$image_artifact" ]]' in lines[i])
matches = [i for i in range(start, end + 1) if lines[i] == original]
assert len(matches) == 1, f"{path}: expected one full-build line {original!r}"
lines[matches[0]] = replacement
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

  set +e
  output="$(HARNESS_ROOT="$case_root" "$checker" 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fq "FAIL  $expected_label:" <<<"$output"
}

run_sidebar_verifier() {
  local output_name="$1"
  local rc_name="$2"
  shift 2
  local captured_output captured_rc

  set +e
  captured_output="$("$ROOT/features/dev-sidebar/verify-sidebar.sh" "$@" 2>&1)"
  captured_rc=$?
  set -e
  printf -v "$output_name" '%s' "$captured_output"
  printf -v "$rc_name" '%s' "$captured_rc"
}

test_sidebar_verifier_demo_results() {
  local output rc

  run_sidebar_verifier output rc --demo
  [[ "$rc" -eq 0 ]] || return 1
  [[ "$(grep -c '^PASS  ' <<<"$output")" -eq 5 ]] || return 1
  [[ "$(tail -n 1 <<<"$output")" == 'RESULT PASS' ]] || return 1
  grep -Fxq 'SUMMARY PASS=5 FAIL=0 SKIP=0' <<<"$output" || return 1

  set +e
  output="$(DEMO_APP_INSTALLED=0 \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fxq 'SKIP  com.android.sidebar 未安装' <<<"$output" || return 1
  [[ "$(tail -n 1 <<<"$output")" == 'RESULT INCOMPLETE' ]] || return 1

  set +e
  output="$(DEMO_APP_INSTALLED=0 \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --allow-skip --demo 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || return 1
  [[ "$(tail -n 1 <<<"$output")" == 'RESULT PASS (SKIP allowed)' ]] || return 1

  set +e
  output="$(DEMO_BOOT_COMPLETED=0 DEMO_APP_INSTALLED=0 \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo --allow-skip 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fxq 'SUMMARY PASS=3 FAIL=1 SKIP=1' <<<"$output" || return 1
  [[ "$(grep -c '^PASS  ' <<<"$output")" -eq 3 ]] || return 1
  [[ "$(grep -c '^FAIL  ' <<<"$output")" -eq 1 ]] || return 1
  [[ "$(grep -c '^SKIP  ' <<<"$output")" -eq 1 ]] || return 1
  [[ "$(tail -n 1 <<<"$output")" == 'RESULT FAIL' ]]
}

test_sidebar_verifier_crash_baselines() {
  local output rc

  set +e
  output="$(DEMO_CRASH_LOG='100.000 1 1 E AndroidRuntime: FATAL EXCEPTION: old' \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo --since 200 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || return 1
  grep -Fxq 'PASS  crash buffer 自 200 起无崩溃' <<<"$output" || return 1

  set +e
  output="$(DEMO_CRASH_LOG='300.000 1 1 E AndroidRuntime: FATAL EXCEPTION: new' \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --since 200 --demo 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fxq 'FAIL  crash buffer 自 200 起发现崩溃' <<<"$output" || return 1
  [[ "$(tail -n 1 <<<"$output")" == 'RESULT FAIL' ]] || return 1

  set +e
  output="$(DEMO_CRASH_QUERY_FAIL=1 \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fxq 'FAIL  crash buffer 查询失败' <<<"$output" || return 1
  [[ "$(tail -n 1 <<<"$output")" == 'RESULT FAIL' ]] || return 1

  set +e
  output="$(DEMO_BOOT_TIME=250 \
    DEMO_CRASH_LOG='249.999 1 1 E AndroidRuntime: FATAL EXCEPTION: before boot' \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || return 1
  grep -Fxq 'PASS  crash buffer 自 250 起无崩溃' <<<"$output" || return 1

  set +e
  output="$(DEMO_BOOT_TIME=999 \
    DEMO_CRASH_LOG='200.499 1 1 E AndroidRuntime: FATAL EXCEPTION: old' \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo --since 200.500 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || return 1
  grep -Fxq 'PASS  crash buffer 自 200.500 起无崩溃' <<<"$output" || return 1

  set +e
  output="$(DEMO_CRASH_LOG='200.500 1 1 E AndroidRuntime: FATAL EXCEPTION: boundary' \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo --since 200.500 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fxq 'FAIL  crash buffer 自 200.500 起发现崩溃' <<<"$output" || return 1

  set +e
  output="$(DEMO_CRASH_LOG='200.500600000 1 1 F DEBUG: *** ***' \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo \
    --since 200.500500000 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fxq 'FAIL  crash buffer 自 200.500500000 起发现崩溃' \
    <<<"$output" || return 1

  set +e
  output="$(DEMO_CRASH_LOG='200.500499999 1 1 F DEBUG: *** ***' \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo \
    --since 200.500500000 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || return 1
  grep -Fxq 'PASS  crash buffer 自 200.500500000 起无崩溃' \
    <<<"$output" || return 1

  set +e
  output="$(DEMO_CRASH_LOG='1753000000.500499999 1 1 E AndroidRuntime: FATAL' \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo \
    --since 1753000000.500500000 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || return 1
  grep -Fxq 'PASS  crash buffer 自 1753000000.500500000 起无崩溃' \
    <<<"$output" || return 1

  set +e
  output="$(DEMO_CRASH_LOG='1753000000.500500001 1 1 I any crash record' \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo \
    --since 1753000000.500500000 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fxq 'FAIL  crash buffer 自 1753000000.500500000 起发现崩溃' \
    <<<"$output"
}

test_sidebar_verifier_usage_errors() {
  local output rc args

  for args in \
    '--unknown' \
    '--since' \
    '--since -1' \
    '--since nope' \
    '--since 1.2.3' \
    '--since 1.1234567890'; do
    set +e
    # shellcheck disable=SC2086 # Each fixture deliberately expands into CLI words.
    output="$("$ROOT/features/dev-sidebar/verify-sidebar.sh" $args 2>&1)"
    rc=$?
    set -e
    [[ "$rc" -eq 2 ]] || return 1
    grep -Fq 'Usage:' <<<"$output" || return 1
  done

  run_sidebar_verifier output rc --help
  [[ "$rc" -eq 0 ]] || return 1
  grep -Fq 'Usage:' <<<"$output" || return 1

  run_sidebar_verifier output rc --demo --since 1.123456789
  [[ "$rc" -eq 0 ]]
}

test_sidebar_verifier_real_mode_pins_adb() {
  local adb_log="$FIXTURE/sidebar-adb.log"
  local output rc

  adb() {
    printf '%q ' adb "$@" >> "$ADB_LOG"
    printf '\n' >> "$ADB_LOG"
    [[ "$1" == '-s' && "$2" == 'demo-serial' ]] || return 91
    shift 2
    case "$*" in
      'shell getprop sys.boot_completed') printf '%s\n' '1' ;;
      'shell pidof system_server') printf '%s\n' '1423' ;;
      'shell cat /proc/stat') printf '%s\n' 'cpu 1 2 3' 'btime 200' ;;
      'logcat -b crash -d -v epoch,nsec -T 200.000000000') ;;
      'shell service list') printf '%s\n' '42 sidebar: [android.os.ISidebar]' ;;
      'shell pm list packages') printf '%s\n' 'package:com.android.sidebar' ;;
      *) return 92 ;;
    esac
  }
  export -f adb
  export ADB_LOG="$adb_log"

  set +e
  output="$(ANDROID_SERIAL=demo-serial \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --since 200 2>&1)"
  rc=$?
  set -e
  unset -f adb
  unset ADB_LOG

  [[ "$rc" -eq 0 ]] || return 1
  [[ "$(tail -n 1 <<<"$output")" == 'RESULT PASS' ]] || return 1
  [[ "$(wc -l < "$adb_log")" -eq 5 ]] || return 1
  [[ "$(grep -c '^adb -s demo-serial ' "$adb_log")" -eq 5 ]] || return 1
  grep -Fxq 'adb -s demo-serial logcat -b crash -d -v epoch\,nsec -T 200.000000000 ' \
    "$adb_log"
}

test_sidebar_verifier_real_default_baseline_and_crlf() {
  local adb_log="$FIXTURE/sidebar-default-adb.log"
  local output rc

  adb() {
    printf '%q ' adb "$@" >> "$ADB_LOG"
    printf '\n' >> "$ADB_LOG"
    [[ "$1" == '-s' && "$2" == 'demo-serial' ]] || return 91
    shift 2
    case "$*" in
      'shell getprop sys.boot_completed') printf '1 \r\n' ;;
      'shell pidof system_server') printf '1423\t\r\n' ;;
      'shell cat /proc/stat') printf 'cpu 1 2 3\r\nbtime 200 \t\r\n' ;;
      'logcat -b crash -d -v epoch,nsec -T 200.000000000')
        printf '%s\r\n' '--------- beginning of crash'
        ;;
      'shell service list')
        printf '42 sidebar: [android.os.ISidebar] \t\r\n'
        ;;
      'shell pm list packages')
        printf 'package:com.android.sidebar \t\r\n'
        ;;
      *) return 92 ;;
    esac
  }
  export -f adb
  export ADB_LOG="$adb_log"

  set +e
  output="$(ANDROID_SERIAL=demo-serial \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" 2>&1)"
  rc=$?
  set -e
  unset -f adb
  unset ADB_LOG

  [[ "$rc" -eq 0 ]] || return 1
  [[ "$(tail -n 1 <<<"$output")" == 'RESULT PASS' ]] || return 1
  [[ "$(wc -l < "$adb_log")" -eq 6 ]] || return 1
  [[ "$(grep -c '^adb -s demo-serial ' "$adb_log")" -eq 6 ]] || return 1
  grep -Fxq 'adb -s demo-serial shell cat /proc/stat ' "$adb_log" || return 1
  grep -Fxq \
    'adb -s demo-serial logcat -b crash -d -v epoch\,nsec -T 200.000000000 ' \
    "$adb_log"
}

test_sidebar_verifier_real_query_failures() {
  local output rc entry fail_key expected adb_log
  local cases=(
    'boot|FAIL  sys.boot_completed 查询失败'
    'pid|FAIL  system_server 查询失败'
    'btime|FAIL  btime 查询失败'
    'logcat|FAIL  crash buffer 查询失败'
    'service|FAIL  service list 查询失败'
    'package|FAIL  package list 查询失败'
  )

  adb() {
    local key
    printf '%q ' adb "$@" >> "$ADB_LOG"
    printf '\n' >> "$ADB_LOG"
    [[ "$1" == '-s' && "$2" == 'demo-serial' ]] || return 91
    shift 2
    case "$*" in
      'shell getprop sys.boot_completed') key=boot ;;
      'shell pidof system_server') key=pid ;;
      'shell cat /proc/stat') key=btime ;;
      logcat\ -b\ crash\ -d\ -v\ *) key=logcat ;;
      'shell service list') key=service ;;
      'shell pm list packages') key=package ;;
      *) return 92 ;;
    esac
    [[ "$key" != "$ADB_FAIL_KEY" ]] || return 73
    case "$key" in
      boot) printf '%s\n' 1 ;;
      pid) printf '%s\n' 1423 ;;
      btime) printf '%s\n' 'cpu 1 2 3' 'btime 200' ;;
      logcat) ;;
      service) printf '%s\n' '42 sidebar: [android.os.ISidebar]' ;;
      package) printf '%s\n' 'package:com.android.sidebar' ;;
    esac
  }
  export -f adb

  for entry in "${cases[@]}"; do
    IFS='|' read -r fail_key expected <<<"$entry"
    adb_log="$FIXTURE/sidebar-$fail_key-adb.log"
    set +e
    output="$(ADB_LOG="$adb_log" ADB_FAIL_KEY="$fail_key" \
      ANDROID_SERIAL=demo-serial \
      "$ROOT/features/dev-sidebar/verify-sidebar.sh" 2>&1)"
    rc=$?
    set -e
    [[ "$rc" -ne 0 ]] || return 1
    grep -Fxq "$expected" <<<"$output" || return 1
    [[ "$(grep -c '^FAIL  ' <<<"$output")" -eq 1 ]] || return 1
    [[ "$(tail -n 1 <<<"$output")" == 'RESULT FAIL' ]] || return 1
    [[ "$(grep -c '^adb -s demo-serial ' "$adb_log")" \
      -eq "$(wc -l < "$adb_log")" ]] || return 1
  done
  unset -f adb
}

test_sidebar_verifier_requires_serial_before_adb() {
  local adb_log="$FIXTURE/sidebar-no-serial-adb.log"
  local output rc unsafe_output unsafe_rc

  adb() {
    printf '%s\n' called >> "$ADB_LOG"
    return 90
  }
  export -f adb
  export ADB_LOG="$adb_log"

  set +e
  output="$(env -u ANDROID_SERIAL \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --since 200 2>&1)"
  rc=$?
  unsafe_output="$(ANDROID_SERIAL=-s \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --since 200 2>&1)"
  unsafe_rc=$?
  set -e
  unset -f adb
  unset ADB_LOG

  [[ "$rc" -eq 2 ]] || return 1
  grep -Fq 'ANDROID_SERIAL' <<<"$output" || return 1
  [[ "$unsafe_rc" -eq 2 ]] || return 1
  grep -Fq 'ANDROID_SERIAL' <<<"$unsafe_output" || return 1
  [[ ! -e "$adb_log" ]]
}

test_sidebar_verifier_query_and_presence_failures() {
  local output rc env_name env_value expected
  local cases=(
    'DEMO_BOOT_QUERY_FAIL|1|FAIL  sys.boot_completed 查询失败'
    'DEMO_BOOT_COMPLETED|0|FAIL  sys.boot_completed != 1'
    'DEMO_SYSTEM_SERVER_QUERY_FAIL|1|FAIL  system_server 查询失败'
    'DEMO_SYSTEM_SERVER||FAIL  system_server pid 为空'
    'DEMO_BOOT_TIME_QUERY_FAIL|1|FAIL  btime 查询失败'
    'DEMO_BOOT_TIME|invalid|FAIL  btime 解析失败'
    'DEMO_CRASH_QUERY_FAIL|1|FAIL  crash buffer 查询失败'
    'DEMO_SERVICE_QUERY_FAIL|1|FAIL  service list 查询失败'
    'DEMO_SERVICE_REGISTERED|0|FAIL  sidebar 服务未注册'
    'DEMO_PACKAGE_QUERY_FAIL|1|FAIL  package list 查询失败'
  )

  for entry in "${cases[@]}"; do
    IFS='|' read -r env_name env_value expected <<<"$entry"
    set +e
    output="$(env "$env_name=$env_value" \
      "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo 2>&1)"
    rc=$?
    set -e
    [[ "$rc" -ne 0 ]] || return 1
    grep -Fxq "$expected" <<<"$output" || return 1
    [[ "$(tail -n 1 <<<"$output")" == 'RESULT FAIL' ]] || return 1
  done

  set +e
  output="$(DEMO_APP_INSTALLED=0 \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fxq 'SKIP  com.android.sidebar 未安装' <<<"$output" || return 1
  ! grep -Fq 'package list 查询失败' <<<"$output"
}

test_sidebar_verifier_crash_filtering() {
  local output rc crash_log

  crash_log=$'--------- beginning of crash\nunrelated header text without an epoch'
  set +e
  output="$(DEMO_CRASH_LOG="$crash_log" \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo --since 200 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || return 1
  grep -Fxq 'PASS  crash buffer 自 200 起无崩溃' <<<"$output" || return 1

  for crash_log in \
    '300.000000000 1 1 F DEBUG: *** *** *** ***' \
    "300.000000000 1 1 F libc: Abort message: 'terminating'" \
    '300.000000000 1 1 I timestamped crash-buffer record'; do
    set +e
    output="$(DEMO_CRASH_LOG="$crash_log" \
      "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo --since 200 2>&1)"
    rc=$?
    set -e
    [[ "$rc" -ne 0 ]] || return 1
    grep -Fxq 'FAIL  crash buffer 自 200 起发现崩溃' <<<"$output" || return 1
  done

  set +e
  output="$(DEMO_CRASH_LOG='200.not-a-timestamp malformed record' \
    "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo --since 200 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fxq 'FAIL  crash buffer 解析失败' <<<"$output"
}

write_forbidden_command_stubs() {
  local bin_dir="$1"
  local command_name

  mkdir -p "$bin_dir"
  for command_name in codex adb cvd m make ninja soong_ui.bash; do
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'printf '\''%s\n'\'' "${0##*/}" >> "$DEMO_FORBIDDEN_CALLS"' \
      'exit 97' \
      > "$bin_dir/$command_name"
    chmod +x "$bin_dir/$command_name"
  done
}

test_integrated_demo_contract_and_success() {
  local demo="$ROOT/run-demo.sh"
  local command_bin="$FIXTURE/demo-command-bin"
  local forbidden_calls="$FIXTURE/demo-forbidden-calls.log"
  local demo_tmp_parent="$FIXTURE/demo-tmp-parent"
  local original_feature_hash original_agents_target output rc heading
  local headings=(
    '上下文选择'
    '会话分支漂移'
    '涉及仓分支一致性'
    '流程 Skills'
    '严格验证'
  )

  [[ -x "$demo" ]] || return 1
  grep -Fq './.codex/bin/codex-feature --dry-run' "$demo" || return 1
  grep -Fq './.codex/bin/check-process-layer' "$demo" || return 1
  grep -Fq './features/dev-sidebar/verify-sidebar.sh --demo' "$demo" || return 1
  grep -Fq './tests/test-harness.sh' "$demo" || return 1
  if grep -En '(^|[;&|()[:space:]])(codex|adb|cvd|m|make|ninja|soong_ui[.]bash)([[:space:]]|$)' \
      "$demo"; then
    return 1
  fi
  if grep -En '(^|[;&|()[:space:]])(source[[:space:]]+)?build/envsetup[.]sh([[:space:]]|$)|(^|[;&|()[:space:]])lunch([[:space:]]|$)' \
      "$demo"; then
    return 1
  fi

  original_feature_hash="$(sha256sum "$ROOT/CURRENT_FEATURE" | awk '{print $1}')"
  [[ -L "$ROOT/AGENTS.md" ]] || return 1
  original_agents_target="$(readlink "$ROOT/AGENTS.md")"
  write_forbidden_command_stubs "$command_bin" || return 1
  mkdir -p "$demo_tmp_parent"

  set +e
  output="$(cd "$ROOT" && \
    PATH="$command_bin:$PATH" \
    DEMO_FORBIDDEN_CALLS="$forbidden_calls" \
    TMPDIR="$demo_tmp_parent" \
    SKIP_SELF_TESTS=1 ./run-demo.sh 2>&1)"
  rc=$?
  set -e

  [[ "$rc" -eq 0 ]] || return 1
  for heading in "${headings[@]}"; do
    grep -Fq "$heading" <<<"$output" || return 1
  done
  grep -Fq '"continue": false' <<<"$output" || return 1
  grep -Fq "AOSP feature drift: session started on 'dev-sidebar', current feature is 'dev-next'." \
    <<<"$output" || return 1
  grep -Fq '[demo] 已按预期识别样本分支漂移。' <<<"$output" || return 1
  [[ "$(grep -c '^RESULT PASS$' <<<"$output")" -eq 2 ]] || return 1
  [[ "$(tail -n 1 <<<"$output")" == 'Codex 三层 Harness 演示完毕' ]] || return 1
  [[ ! -e "$forbidden_calls" ]] || return 1
  [[ -z "$(find "$demo_tmp_parent" -mindepth 1 -maxdepth 1 -print -quit)" ]] || return 1
  [[ "$(sha256sum "$ROOT/CURRENT_FEATURE" | awk '{print $1}')" == \
    "$original_feature_hash" ]] || return 1
  [[ -L "$ROOT/AGENTS.md" ]] || return 1
  [[ "$(readlink "$ROOT/AGENTS.md")" == "$original_agents_target" ]]
}

test_integrated_demo_restores_state_after_failure() {
  local case_root="$FIXTURE/demo-failure-root"
  local demo
  local fake_bin="$FIXTURE/demo-failure-bin"
  local python_count="$FIXTURE/demo-python-count"
  local demo_tmp_parent="$FIXTURE/demo-failure-tmp"
  local real_python original_feature_hash original_agents_target output rc

  cp -a "$ROOT" "$case_root" || return 1
  demo="$case_root/run-demo.sh"
  [[ -x "$demo" ]] || return 1
  real_python="$(command -v python3)" || return 1
  original_feature_hash="$(sha256sum "$case_root/CURRENT_FEATURE" | awk '{print $1}')"
  [[ -L "$case_root/AGENTS.md" ]] || return 1
  rm -f "$case_root/AGENTS.md"
  original_agents_target='features/original-failure-context/AGENTS.md'
  ln -s "$original_agents_target" "$case_root/AGENTS.md"
  mkdir -p "$fake_bin" "$demo_tmp_parent"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'if [[ "${1:-}" == -c && "${2:-}" == *'\''data["session_id"]'\''* ]]; then' \
    '  count=0' \
    '  [[ ! -f "$DEMO_PYTHON_COUNT" ]] || count="$(cat "$DEMO_PYTHON_COUNT")"' \
    '  count=$((count + 1))' \
    '  printf '\''%s\n'\'' "$count" > "$DEMO_PYTHON_COUNT"' \
    '  if [[ "$count" -eq 3 ]]; then' \
    '    exit 97' \
    '  fi' \
    'fi' \
    'exec "$DEMO_REAL_PYTHON" "$@"' \
    > "$fake_bin/python3"
  chmod +x "$fake_bin/python3"

  set +e
  output="$(cd "$case_root" && \
    PATH="$fake_bin:$PATH" \
    DEMO_PYTHON_COUNT="$python_count" \
    DEMO_REAL_PYTHON="$real_python" \
    TMPDIR="$demo_tmp_parent" \
    SKIP_SELF_TESTS=1 ./run-demo.sh 2>&1)"
  rc=$?
  set -e

  [[ "$rc" -ne 0 ]] || return 1
  grep -Fq 'error: invalid hook input' <<<"$output" || return 1
  [[ "$(cat "$python_count")" -eq 3 ]] || return 1
  [[ "$(sha256sum "$case_root/CURRENT_FEATURE" | awk '{print $1}')" == \
    "$original_feature_hash" ]] || return 1
  [[ -L "$case_root/AGENTS.md" ]] || return 1
  [[ "$(readlink "$case_root/AGENTS.md")" == "$original_agents_target" ]] || return 1
  [[ -z "$(find "$demo_tmp_parent" -mindepth 1 -maxdepth 1 -print -quit)" ]]
}

test_integrated_demo_restores_alternate_link_and_protects_regular_file() {
  local case_root="$FIXTURE/demo-alternate-root"
  local command_bin="$FIXTURE/demo-alternate-bin"
  local forbidden_calls="$FIXTURE/demo-alternate-forbidden.log"
  local demo_tmp_parent="$FIXTURE/demo-alternate-tmp"
  local alternate_target='features/original-success-context/AGENTS.md'
  local protected_hash output rc

  cp -a "$ROOT" "$case_root" || return 1
  rm -f "$case_root/AGENTS.md"
  ln -s "$alternate_target" "$case_root/AGENTS.md"
  write_forbidden_command_stubs "$command_bin" || return 1
  mkdir -p "$demo_tmp_parent"

  set +e
  output="$(cd "$case_root" && \
    PATH="$command_bin:$PATH" \
    DEMO_FORBIDDEN_CALLS="$forbidden_calls" \
    TMPDIR="$demo_tmp_parent" \
    SKIP_SELF_TESTS=1 ./run-demo.sh 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || return 1
  [[ "$(tail -n 1 <<<"$output")" == 'Codex 三层 Harness 演示完毕' ]] || return 1
  [[ -L "$case_root/AGENTS.md" ]] || return 1
  [[ "$(readlink "$case_root/AGENTS.md")" == "$alternate_target" ]] || return 1
  [[ ! -e "$forbidden_calls" ]] || return 1
  [[ -z "$(find "$demo_tmp_parent" -mindepth 1 -maxdepth 1 -print -quit)" ]] || return 1

  rm -f "$case_root/AGENTS.md"
  printf '%s\n' 'protected regular AGENTS file' > "$case_root/AGENTS.md"
  protected_hash="$(sha256sum "$case_root/AGENTS.md" | awk '{print $1}')"
  set +e
  output="$(cd "$case_root" && SKIP_SELF_TESTS=1 ./run-demo.sh 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || return 1
  grep -Fq 'AGENTS.md 是普通文件' <<<"$output" || return 1
  [[ ! -L "$case_root/AGENTS.md" ]] || return 1
  [[ "$(sha256sum "$case_root/AGENTS.md" | awk '{print $1}')" == "$protected_hash" ]]
}

test_integrated_demo_keeps_real_current_feature_read_only() {
  local demo="$ROOT/run-demo.sh"

  [[ -x "$demo" ]] || return 1
  if grep -Fq 'CURRENT_FEATURE_BACKUP' "$demo"; then
    echo 'unsafe: demo still backs up and restores the real CURRENT_FEATURE' >&2
    return 1
  fi
  if grep -Fq '"$ROOT/CURRENT_FEATURE"' "$demo"; then
    echo 'unsafe: private drift state still references the real CURRENT_FEATURE' >&2
    return 1
  fi
  if grep -Eq '>[[:space:]]*CURRENT_FEATURE([[:space:]]|$)' "$demo"; then
    echo 'unsafe: demo still redirects output into the real CURRENT_FEATURE' >&2
    return 1
  fi
  if grep -Eq '(cp|mv|install|tee|truncate)[[:space:]].*[[:space:]]CURRENT_FEATURE([[:space:]]|$)' \
      "$demo"; then
    echo 'unsafe: demo still has a write primitive targeting the real CURRENT_FEATURE' >&2
    return 1
  fi
}

test_current_feature_symlink_replacement_cannot_write_victim() {
  local case_root="$FIXTURE/current-feature-collision-root"
  local fake_bin="$FIXTURE/current-feature-collision-bin"
  local demo_tmp_parent="$FIXTURE/current-feature-collision-tmp"
  local victim="$FIXTURE/current-feature-victim"
  local collision_marker="$FIXTURE/current-feature-collision-fired"
  local forbidden_calls="$FIXTURE/current-feature-collision-forbidden.log"
  local real_python victim_hash original_agents_target output rc

  cp -a "$ROOT" "$case_root" || return 1
  real_python="$(command -v python3)" || return 1
  printf '%s\n' 'unrelated victim sentinel' > "$victim"
  victim_hash="$(sha256sum "$victim" | awk '{print $1}')"
  [[ -L "$case_root/AGENTS.md" ]] || return 1
  original_agents_target="$(readlink "$case_root/AGENTS.md")"
  mkdir -p "$fake_bin" "$demo_tmp_parent"
  write_forbidden_command_stubs "$fake_bin" || return 1
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'if [[ ! -e "$DEMO_COLLISION_MARKER" && "${1:-}" == -c && "${2:-}" == *'\''data["session_id"]'\''* ]]; then' \
    '  rm -f -- "$DEMO_REAL_CURRENT_FEATURE"' \
    '  ln -s -- "$DEMO_COLLISION_VICTIM" "$DEMO_REAL_CURRENT_FEATURE"' \
    '  : > "$DEMO_COLLISION_MARKER"' \
    'fi' \
    'exec "$DEMO_REAL_PYTHON" "$@"' \
    > "$fake_bin/python3"
  chmod +x "$fake_bin/python3"

  set +e
  output="$(cd "$case_root" && \
    PATH="$fake_bin:$PATH" \
    DEMO_COLLISION_MARKER="$collision_marker" \
    DEMO_COLLISION_VICTIM="$victim" \
    DEMO_FORBIDDEN_CALLS="$forbidden_calls" \
    DEMO_REAL_CURRENT_FEATURE="$case_root/CURRENT_FEATURE" \
    DEMO_REAL_PYTHON="$real_python" \
    TMPDIR="$demo_tmp_parent" \
    SKIP_SELF_TESTS=1 ./run-demo.sh 2>&1)"
  rc=$?
  set -e

  [[ -e "$collision_marker" ]] || return 1
  if [[ "$(sha256sum "$victim" | awk '{print $1}')" != "$victim_hash" ]]; then
    echo 'unsafe: CURRENT_FEATURE replacement redirected a demo write into the victim' >&2
    return 1
  fi
  [[ "$rc" -eq 0 ]] || return 1
  [[ -L "$case_root/CURRENT_FEATURE" ]] || return 1
  [[ "$(readlink "$case_root/CURRENT_FEATURE")" == "$victim" ]] || return 1
  [[ -L "$case_root/AGENTS.md" ]] || return 1
  [[ "$(readlink "$case_root/AGENTS.md")" == "$original_agents_target" ]] || return 1
  [[ ! -e "$forbidden_calls" ]] || return 1
  [[ -z "$(find "$demo_tmp_parent" -mindepth 1 -maxdepth 1 -print -quit)" ]] || return 1
  [[ "$(tail -n 1 <<<"$output")" == 'Codex 三层 Harness 演示完毕' ]]
}

test_operational_readme_contract_and_quick_start() {
  local readme="$ROOT/README.md"
  local repo_root
  local command_bin="$FIXTURE/readme-command-bin"
  local forbidden_calls="$FIXTURE/readme-forbidden-calls.log"
  local required_text output rc
  local required_texts=(
    'Codex 原生重写，不是名称替换'
    '## Codex 与 Claude Code 版的关键差异'
    '以下 Claude Code 一栏只描述本仓库的 `claude-code/` demo'
    '根与 feature 的 `AGENTS.md`'
    '根与 feature 的 `CLAUDE.md`'
    'Codex 仓库 skills 位于 `.agents/skills`'
    '显式 `$skill-name`'
    '任务匹配 `description` 时隐式选择'
    '本仓库 Claude demo 的 `.claude/skills` 示例使用 `paths` metadata'
    'Codex demo 用 `.codex/hooks.json`'
    '`.codex/config.toml` 中的 inline `[hooks]` tables'
    'Codex hook schema'
    '本仓库 Claude demo 用 `.claude/settings.json`'
    '项目 hook 信任必须通过 `/hooks` 审查'
    '启动时每次运行建立一次指令链'
    '不是把 `CLAUDE.md` 改名为 `AGENTS.md`'
    'codex/'
    '① 上下文层'
    '② 流程层'
    '③ 验证闭环层'
    './codex/run-demo.sh'
    'cd codex'
    './run-demo.sh'
    './.codex/bin/codex-feature --dry-run'
    './.codex/bin/codex-feature'
    './.codex/hooks/session-start.sh'
    './.codex/hooks/check-branch-drift.sh'
    '"hook_event_name":"UserPromptSubmit"'
    '/hooks'
    './.codex/bin/check-process-layer'
    './features/dev-sidebar/verify-sidebar.sh --demo'
    'AGENTS.md 每次运行只加载一次'
    '非 Git 的 AOSP 树根'
    '.agents/skills'
    '渐进式披露'
    '$build-services-jar'
    'description'
    '没有已文档化的 `paths` 路径触发契约'
    '受信任项目'
    '审查并信任精确的 hook 定义'
    '相对命令依赖 wrapper 固定的工作目录'
    'manifest 之外的独立 Git 仓'
    '树根 `AGENTS.md` 软链'
    '`.codex/` 与 `.agents/`'
    'repos.tsv'
    'ANDROID_SERIAL'
    'CVD_GROUP'
    'RESULT PASS'
    'RESULT FAIL'
    'RESULT INCOMPLETE'
    '--allow-skip'
    '仅用于探索'
    '`rg` + 源码阅读'
    '不需要预先建立索引'
    'AOSP整机源码Codex-Harness工程探索.md'
    'https://learn.chatgpt.com/docs/agent-configuration/agents-md'
    'https://learn.chatgpt.com/docs/build-skills'
    'https://learn.chatgpt.com/docs/hooks'
    'https://learn.chatgpt.com/docs/config-file/config-advanced'
    'https://learn.chatgpt.com/docs/agent-configuration/subagents'
    'https://learn.chatgpt.com/docs/developer-commands'
  )

  [[ -f "$readme" ]] || return 1
  for required_text in "${required_texts[@]}"; do
    grep -Fq -- "$required_text" "$readme" || return 1
  done
  if grep -Eiq 'paths.*(auto|automatic|自动).*(activat|激活|触发)|路径.*自动.*(激活|触发)' "$readme"; then
    return 1
  fi
  if grep -Eiq 'hooks?.*(guaranteed|保证).*AGENTS|AGENTS.*(guaranteed|保证).*hooks?' \
      "$readme"; then
    return 1
  fi

  repo_root="$(cd "$ROOT/.." && pwd)"
  write_forbidden_command_stubs "$command_bin" || return 1
  set +e
  output="$(cd "$repo_root" && \
    PATH="$command_bin:$PATH" \
    DEMO_FORBIDDEN_CALLS="$forbidden_calls" \
    SKIP_SELF_TESTS=1 ./codex/run-demo.sh 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || return 1
  grep -Fxq 'Codex 三层 Harness 演示完毕' <<<"$output" || return 1
  [[ ! -e "$forbidden_calls" ]]
}

test_long_form_article_contract_and_links() {
  local article="$ROOT/AOSP整机源码Codex-Harness工程探索.md"
  local readme="$ROOT/README.md"

  python3 - "$article" "$readme" <<'PY'
from pathlib import Path
import re
import sys
from urllib.parse import unquote

article = Path(sys.argv[1])
readme = Path(sys.argv[2])
assert article.is_file(), f"missing long-form article: {article}"

text = article.read_text(encoding="utf-8")
lines = text.splitlines()
markdown_lines = []
inside_fence = False
for line in lines:
    if line.startswith("```"):
        inside_fence = not inside_fence
        continue
    if not inside_fence:
        markdown_lines.append(line)

h1 = [line for line in markdown_lines if line.startswith("# ")]
assert h1 == ["# AOSP 整机源码 Codex Harness 工程探索"], h1

expected_h2 = [
    "## 一、问题：为什么 Codex 在整机源码树上仍需要 Harness",
    "## 二、官方能力边界：Codex 提供了哪些承载面",
    "## 三、方案总览：Codex 原生三层 Harness",
    "## 四、第①层 上下文：启动前选对 AGENTS.md",
    "## 五、第②层 流程：用 repository skills 渐进披露",
    "## 六、第③层 验证闭环：只有 RESULT PASS 才算完成",
    "## 七、串起来：一个 Codex 会话的完整生命周期",
    "## 八、从 Claude Code 版迁移时不能直接照搬什么",
    "## 九、工程化加固与测试",
    "## 十、边界与下一步",
    "## 结语",
    "## 参考资料",
]
actual_h2 = [line for line in markdown_lines if line.startswith("## ")]
assert actual_h2 == expected_h2, actual_h2

official_links = [
    "https://learn.chatgpt.com/docs/agent-configuration/agents-md",
    "https://learn.chatgpt.com/docs/build-skills",
    "https://learn.chatgpt.com/docs/hooks",
    "https://learn.chatgpt.com/docs/config-file/config-advanced",
    "https://learn.chatgpt.com/docs/agent-configuration/subagents",
    "https://learn.chatgpt.com/docs/developer-commands",
]
for link in official_links:
    assert link in text, f"missing official link: {link}"

required_texts = [
    "once per run",
    "global",
    "project root",
    "current working directory",
    "Git 根",
    "找不到 project root 时只检查当前目录",
    "project_doc_max_bytes",
    "32 KiB",
    "AGENTS.override.md",
    ".codex/config.toml",
    "受信任项目",
    "project_root_markers",
    "wrapper 固定树根 cwd",
    ".agents/skills",
    "渐进式披露",
    "name、description 和文件路径",
    "$build-services-jar",
    "$build-sepolicy",
    "隐式选择",
    "description",
    "没有已文档化的 `paths:` 路径触发契约",
    ".codex/hooks.json",
    "inline `[hooks]`",
    "/hooks",
    "session_id",
    "cwd",
    "hook_event_name",
    "SessionStart 不会追溯性地替换本次运行的 AGENTS.md",
    "UserPromptSubmit",
    '"continue": false',
    "子代理任务卡",
    "不依赖子代理自动继承完整 feature 上下文",
    "任务卡作为稳定输入",
    "不是强制隔离机制",
    "sandbox",
    "approval",
    "指导不是授权",
    ".codex/bin/codex-feature",
    "features/dev-sidebar/verify-sidebar.sh",
    "CURRENT_FEATURE",
    "repos.tsv",
    "manifest 之外的独立 Git 仓",
    "Gerrit",
    "单行 ASCII 单组件",
    "MISSING",
    "DRIFT",
    "DETACHED",
    "INVALID",
    "ANDROID_SERIAL",
    "cvd fleet",
    "cvd --group_name",
    "epoch,nsec",
    "system_server_service",
    "RESULT PASS",
    "RESULT FAIL",
    "RESULT INCOMPLETE",
    "官方文档化行为/能力",
    "Demo 选择",
    "真实 AOSP 建议",
    "本仓库 Claude Code demo",
    "CLAUDE.md",
    ".claude/skills",
    ".claude/settings.json",
    "AGENTS.md",
    "路径假设",
    "任务卡是稳定接口",
    "不要求预建索引",
    "`rg` + live source",
    "build completed successfully",
    "mktemp",
    "同一个 exec session",
    "m services",
    "m selinux_policy",
    "m update-api",
    "五项断言",
    "sys.boot_completed",
    "pidof system_server",
    "service list",
    "pm list packages",
    "crash buffer",
    "查询失败",
    "--allow-skip",
    "btime",
    "纳秒",
    "--demo",
    "路径穿越",
    "NUL",
    "O_NOFOLLOW",
    "证据先于完成声明",
    "same-UID",
    "完整语义索引",
    "plugin",
    "会替换任何已有软链",
    "没有 ownership marker",
    "拒绝覆盖普通文件",
    "编辑器可能原子替换软链本身",
    "直接编辑 `features/<feature>/AGENTS.md`",
    "只比较 active feature token",
    "第一个可用锚点仓",
    "不会持续重跑 `repos.tsv`",
    "不能发现非锚点仓的分支漂移",
    "构建交接或完成前重新运行 `./features/dev-sidebar/check-branch.sh`",
]
for required in required_texts:
    assert required in text, f"article missing required contract text: {required}"

required_table_rows = [
    "| 能力面 | 官方文档化行为/能力 | Demo 选择 | 真实 AOSP 建议 |",
    "| 维度 | 本仓库 Claude Code demo | Codex demo | 迁移动作 |",
]
for row in required_table_rows:
    assert row in text, f"article missing required table: {row}"

assert "官方保证" not in text, "article overstates documented behavior as a guarantee"
assert re.search(
    r"最多占模型上下文的\s*(?:[*]{2})?2%(?:[*]{2})?",
    text,
), "article missing the documented 2% initial skill-list budget"
assert re.search(
    r"上下文窗口未知时最多\s*(?:[*]{2})?8,000 个字符(?:[*]{2})?",
    text,
), "article missing the documented 8,000-character fallback budget"
assert re.search(r"先缩短\s+description", text), (
    "article missing skill-description shortening behavior"
)
assert re.search(r"省略部分\s+skills.*warning", text), (
    "article missing skill omission warning behavior"
)

representative_match = re.search(
    r"### 5[.]2 监督式定向构建.*?```bash\n(.*?)\n```",
    text,
    re.DOTALL,
)
assert representative_match, "missing representative services build block"
representative_build = representative_match.group(1)


def missing_build_guards(build_block):
    required_guards = {
        "explicit child failure branch": 'if [[ "$build_rc" -ne 0 ]]; then',
        "child status exit": 'exit "$build_rc"',
        "success marker guard": (
            'grep -Fq "#### build completed successfully ####" '
            '"$build_log" || exit 1'
        ),
        "artifact guard": '[[ -f "$artifact" ]] || exit 1',
    }
    return [
        label for label, required in required_guards.items()
        if required not in build_block
    ]


assert not missing_build_guards(representative_build), (
    "representative build can mask failure: "
    f"{missing_build_guards(representative_build)}"
)
guard_positions = [
    representative_build.index('wait "$build_pid"'),
    representative_build.index('build_rc=$?'),
    representative_build.index('if [[ "$build_rc" -ne 0 ]]; then'),
    representative_build.index('exit "$build_rc"'),
    representative_build.index(
        'grep -Fq "#### build completed successfully ####" '
        '"$build_log" || exit 1'
    ),
    representative_build.index('[[ -f "$artifact" ]] || exit 1'),
]
assert guard_positions == sorted(guard_positions), (
    "representative build guards are not ordered after wait"
)

build_guard_mutations = {
    "removed child exit": representative_build.replace(
        'exit "$build_rc"', ': # child failure accidentally ignored', 1
    ),
    "unguarded success marker": representative_build.replace(
        '"$build_log" || exit 1', '"$build_log"', 1
    ),
    "unguarded artifact": representative_build.replace(
        '[[ -f "$artifact" ]] || exit 1', '[[ -f "$artifact" ]]', 1
    ),
}
for mutation_name, mutation in build_guard_mutations.items():
    assert missing_build_guards(mutation), (
        f"build-guard detector missed mutation: {mutation_name}"
    )

lifecycle_match = re.search(
    r"```mermaid\nflowchart TD\n(.*?)\n```",
    text,
    re.DOTALL,
)
assert lifecycle_match, "missing lifecycle Mermaid graph"
lifecycle = lifecycle_match.group(1)
for edge in (
    "F --> O",
    "R --> O",
    "P -- 是 --> G",
    "G --> H",
    "M -- 否 --> G",
):
    assert edge in lifecycle, f"lifecycle missing turn-gate edge: {edge}"
assert "G --> O" not in lifecycle, (
    "UserPromptSubmit must gate the turn before exploration/build"
)
assert "M -- 否 --> O" not in lifecycle, (
    "verifier failure does not itself trigger UserPromptSubmit"
)

def forbidden_claims(content):
    findings = []
    prose_parts = []
    inside_fence = False
    for line in content.splitlines():
        if line.startswith("```"):
            inside_fence = not inside_fence
            continue
        if not inside_fence:
            prose_parts.append(line)

    prose = "\n".join(prose_parts)
    statements = re.split(r"(?<=[。！？])\s*|\n", prose)
    for statement in statements:
        statement = statement.strip()
        lowered = statement.lower()
        if not statement:
            continue

        if (
            "paths" in lowered
            and re.search(r"自动|必然|automatic(?:ally)?|always", lowered)
            and re.search(r"激活|触发|选择|activat|trigger|select", lowered)
            and not re.search(
                r"没有已文档化|不能假定|不可假定|不要假定|并非|不是|"
                r"not documented|does not|do not assume|cannot assume",
                lowered,
            )
        ):
            findings.append(("paths auto-trigger", statement))

        if (
            "sessionstart" in lowered
            and "agents.md" in lowered
            and re.search(r"同一|本次|当前.{0,12}(?:运行|run)|same|current run", lowered)
            and re.search(
                r"选择|切换|替换|重载|重新加载|加载|"
                r"select|swap|reload|load",
                lowered,
            )
            and not re.search(
                r"不会|不能|不可|并非|不是|不等于|does not|cannot|will not",
                lowered,
            )
        ):
            findings.append(("SessionStart AGENTS reload", statement))

        if (
            "hook" in lowered
            and re.search(
                r"无需|无须|不需要|未信任|未经信任|不经信任|"
                r"without (?:project )?trust|untrusted",
                lowered,
            )
            and re.search(r"运行|生效|执行|work|run|execute", lowered)
            and not re.search(
                r"不会.{0,8}(?:运行|生效|执行)|不能.{0,8}(?:运行|生效|执行)|"
                r"不可.{0,8}(?:运行|生效|执行)|被跳过|"
                r"will not (?:run|execute)|does not (?:run|execute)|"
                r"cannot (?:run|execute)|skipped",
                lowered,
            )
        ):
            findings.append(("hook without trust", statement))

        if (
            re.search(r"子代理|subagents?", lowered)
            and re.search(r"自动|总是|全部|所有|automatically|always|all", lowered)
            and re.search(r"完整|全部|complete|full", lowered)
            and re.search(r"继承|拿到|inherit|receive", lowered)
            and not re.search(
                r"不会|不能|不可|不假设|不依赖|没有建立|并非|不是|"
                r"does not|cannot|do not assume|not established",
                lowered,
            )
        ):
            findings.append(("subagent full-context inheritance", statement))

        if (
            "codex" in lowered
            and re.search(r"从不|不会|never|does not|doesn't", lowered)
            and re.search(r"索引|index", lowered)
            and not re.search(
                r"不是|并非|不要宣称|不宣称|不能宣称|"
                r"not claim|not a claim|do not claim|does not claim",
                lowered,
            )
        ):
            findings.append(("Codex never indexes", statement))

        claude_artifact = r"[.]claude/|claude[.]md|[.]claude/settings[.]json"
        setup_verb = (
            r"创建|配置|使用|放入|采用|添加|新增|加入|"
            r"create|configure|use|put|add"
        )
        claude_setup_instruction = re.search(
            rf"(?:为|给)\s*codex.{{0,40}}"
            rf"(?:{setup_verb}).*(?:{claude_artifact})|"
            rf"codex(?:\s*(?:项目|用户|配置|工程|tree))?.{{0,30}}"
            rf"(?:应|应该|请|必须|需要|要|should|must|need to|{setup_verb})"
            rf".*(?:{claude_artifact})|"
            rf"(?:{setup_verb}).*(?:{claude_artifact}).{{0,60}}"
            rf"(?:给|用于|供|到|至|作为|for|to|as)\s*(?:the\s+)?codex",
            lowered,
        )
        if (
            claude_setup_instruction
            and not re.search(
                r"不要|不得|不能|不可|do not|don't|must not|never",
                lowered,
            )
        ):
            findings.append(("Codex instructed to use Claude artifacts", statement))

    return findings


findings = forbidden_claims(text)
assert not findings, f"forbidden Codex claims: {findings}"

mutation_cases = {
    "paths alternative": "Codex 会按 `paths` 自动触发对应 skill。",
    "SessionStart alternative": (
        "SessionStart 可以在本次运行里重新加载新的 AGENTS.md。"
    ),
    "SessionStart current-run alternative": (
        "SessionStart 能在当前 run 中加载另一个 AGENTS.md。"
    ),
    "hook trust alternative": "项目 hooks 即使未信任也能正常运行。",
    "hook execution alternative": "项目 hook 不经信任也会执行。",
    "subagent alternative": "所有子代理都会自动继承完整的 feature 上下文。",
    "index alternative": "Codex never uses an index when navigating code.",
    "index negative-grammar alternative": "Codex does not build or use indexes.",
    "Claude setup alternative": (
        "请为 Codex 创建 `.claude/settings.json` 并使用 `CLAUDE.md`。"
    ),
    "Claude add alternative": "为 Codex 添加 CLAUDE.md。",
    "Claude English add alternative": (
        "Add .claude/settings.json to the Codex tree."
    ),
}
for mutation_name, mutation in mutation_cases.items():
    assert forbidden_claims(mutation), (
        f"forbidden-claim detector missed mutation {mutation_name}: {mutation}"
    )

safe_negation_cases = {
    "paths boundary": "当前文档没有已建立的 `paths:` 路径触发契约。",
    "SessionStart boundary": "SessionStart 不会在同一运行中重新加载 AGENTS.md。",
    "hook trust boundary": "项目 hook 未经信任不会运行。",
    "subagent boundary": "子代理不会自动继承完整的 feature 上下文。",
    "index boundary": "本文不宣称 Codex 从不使用索引。",
    "Claude setup boundary": "不要为 Codex 添加 CLAUDE.md。",
}
for safe_name, safe_statement in safe_negation_cases.items():
    assert not forbidden_claims(safe_statement), (
        f"forbidden-claim detector rejected safe negation {safe_name}: "
        f"{safe_statement}"
    )

assert "不要为 Codex 创建 `.claude/`" in text
assert "不要为 Codex 创建 `CLAUDE.md`" in text

markdown_link = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
for source in (readme, article):
    source_text = source.read_text(encoding="utf-8")
    for raw_target in markdown_link.findall(source_text):
        target = raw_target.strip()
        if target.startswith("<") and target.endswith(">"):
            target = target[1:-1]
        target = target.split("#", 1)[0]
        if not target or re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target):
            continue
        resolved = (source.parent / unquote(target)).resolve()
        assert resolved.exists(), f"broken local link in {source}: {raw_target}"
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
run_regression 'repository process skills contain the required AOSP guidance' test_process_skill_artifacts
run_regression 'process layer checker is cwd-independent and reports exact success' test_process_layer_checker
run_regression 'sidebar verifier reports strict demo outcomes and exact counts' \
  test_sidebar_verifier_demo_results
run_regression 'sidebar verifier compares crash timestamps against selected baselines' \
  test_sidebar_verifier_crash_baselines
run_regression 'sidebar verifier rejects malformed CLI usage' \
  test_sidebar_verifier_usage_errors
run_regression 'sidebar verifier pins and normalizes every real ADB query' \
  test_sidebar_verifier_real_mode_pins_adb
run_regression 'sidebar verifier derives a real baseline and normalizes CRLF results' \
  test_sidebar_verifier_real_default_baseline_and_crlf
run_regression 'sidebar verifier fails closed for every real ADB query path' \
  test_sidebar_verifier_real_query_failures
run_regression 'sidebar verifier rejects real mode without a serial before ADB' \
  test_sidebar_verifier_requires_serial_before_adb
run_regression 'sidebar verifier distinguishes query, value, presence, and skip failures' \
  test_sidebar_verifier_query_and_presence_failures
run_regression 'sidebar verifier treats timestamped crash-buffer records as crashes' \
  test_sidebar_verifier_crash_filtering
run_regression 'integrated demo uses public dry-run entry points and restores state' \
  test_integrated_demo_contract_and_success
run_regression 'integrated demo trap restores state after a controlled drift failure' \
  test_integrated_demo_restores_state_after_failure
run_regression 'integrated demo restores alternate links and protects regular AGENTS files' \
  test_integrated_demo_restores_alternate_link_and_protects_regular_file
run_regression 'integrated demo keeps the real CURRENT_FEATURE read-only' \
  test_integrated_demo_keeps_real_current_feature_read_only
run_regression 'CURRENT_FEATURE symlink replacement cannot redirect writes to a victim' \
  test_current_feature_symlink_replacement_cannot_write_victim
run_regression 'operational README covers contracts and its primary quick start runs' \
  test_operational_readme_contract_and_quick_start
run_regression 'long-form article covers Codex contracts and local links resolve' \
  test_long_form_article_contract_and_links
run_regression 'process checker rejects missing update-api guidance' \
  test_process_layer_checker_rejects_fact \
  update-api build-services-jar 'm update-api' 'm refresh-api' \
  'build-services-jar update-api guidance'
run_regression 'process checker rejects a non-Bash services build' \
  test_process_layer_checker_rejects_fact \
  services-bash build-services-jar 'bash -c' 'sh -c' \
  'build-services-jar Bash invocation'
run_regression 'process checker rejects missing services envsetup' \
  test_process_layer_checker_rejects_fact \
  services-envsetup build-services-jar 'source build/envsetup.sh' 'source build/setup.sh' \
  'build-services-jar envsetup command'
run_regression 'process checker rejects the wrong services lunch target' \
  test_process_layer_checker_rejects_fact \
  services-lunch build-services-jar \
  'lunch aosp_cf_x86_64_phone-trunk_staging-userdebug' 'lunch wrong-target' \
  'build-services-jar lunch target'
run_regression 'process checker rejects a non-Bash sepolicy build' \
  test_process_layer_checker_rejects_fact \
  sepolicy-bash build-sepolicy 'bash -c' 'sh -c' \
  'build-sepolicy Bash invocation'
run_regression 'process checker rejects missing sepolicy envsetup' \
  test_process_layer_checker_rejects_fact \
  sepolicy-envsetup build-sepolicy 'source build/envsetup.sh' 'source build/setup.sh' \
  'build-sepolicy envsetup command'
run_regression 'process checker rejects the wrong sepolicy lunch target' \
  test_process_layer_checker_rejects_fact \
  sepolicy-lunch build-sepolicy \
  'lunch aosp_cf_x86_64_phone-trunk_staging-userdebug' 'lunch wrong-target' \
  'build-sepolicy lunch target'
run_regression 'process checker rejects a client without find permission' \
  test_process_layer_checker_rejects_fact \
  sepolicy-client-permission build-sepolicy \
  'allow sidebar_app sidebar_service:service_manager find;' \
  'allow sidebar_app sidebar_service:service_manager read;' \
  'build-sepolicy client service-manager find permission'
run_regression 'process checker rejects missing services device pinning' \
  test_process_layer_checker_rejects_fact \
  services-serial-pin build-services-jar \
  'device_serial="${ANDROID_SERIAL:?Set ANDROID_SERIAL to the explicitly confirmed target serial}"' \
  'adb devices' 'build-services-jar ANDROID_SERIAL pin'
run_regression 'process checker rejects missing services target validation' \
  test_process_layer_checker_rejects_fact \
  services-get-state build-services-jar \
  'adb -s "$device_serial" get-state' 'adb devices' \
  'build-services-jar pinned get-state'
run_regression 'process checker rejects bare state-changing ADB' \
  test_process_layer_checker_rejects_fact \
  services-bare-adb build-services-jar \
  'adb -s "$device_serial" root' 'adb root' \
  'build-services-jar bare ADB command'
run_regression 'process checker rejects missing sepolicy device pinning' \
  test_process_layer_checker_rejects_fact \
  sepolicy-serial-pin build-sepolicy \
  'device_serial="${ANDROID_SERIAL:?Set ANDROID_SERIAL to the explicitly confirmed target serial}"' \
  'After boot, inspect denials and service registration:' \
  'build-sepolicy ANDROID_SERIAL pin'
run_regression 'process checker rejects missing sepolicy target validation' \
  test_process_layer_checker_rejects_fact \
  sepolicy-get-state build-sepolicy \
  'adb -s "$device_serial" get-state' \
  'After boot, inspect denials and service registration:' \
  'build-sepolicy pinned get-state'
run_regression 'process checker rejects bare sepolicy ADB queries' \
  test_process_layer_checker_rejects_fact \
  sepolicy-bare-adb build-sepolicy \
  'adb -s "$device_serial" shell dmesg' 'adb shell dmesg' \
  'build-sepolicy bare ADB command'
run_regression 'process checker rejects unselected services CVD group' \
  test_process_layer_checker_rejects_fact \
  services-bare-cvd build-services-jar \
  'cvd --group_name="$cvd_group" stop' 'cvd stop' \
  'build-services-jar CVD group selector'
run_regression 'process checker rejects unselected sepolicy CVD group' \
  test_process_layer_checker_rejects_fact \
  sepolicy-bare-cvd build-sepolicy \
  'cvd --group_name="$cvd_group" stop' 'cvd stop' \
  'build-sepolicy CVD group selector'
run_regression 'process checker rejects fixed services build logs' \
  test_process_layer_checker_rejects_fact \
  services-fixed-log build-services-jar \
  'build_log="$(mktemp "${TMPDIR:-/tmp}/build-services.XXXXXX.log")"' \
  '/tmp/build-services.log' 'build-services-jar unique build log'
run_regression 'process checker rejects fixed sepolicy build logs' \
  test_process_layer_checker_rejects_fact \
  sepolicy-fixed-log build-sepolicy \
  'build_log="$(mktemp "${TMPDIR:-/tmp}/build-sepolicy.XXXXXX.log")"' \
  '/tmp/build-sepolicy.log' 'build-sepolicy unique build log'
run_regression 'process checker rejects detached services waits' \
  test_process_layer_checker_rejects_fact \
  services-wait build-services-jar 'wait "$build_pid"' 'wait for the build' \
  'build-services-jar retained child wait'
run_regression 'process checker rejects detached sepolicy waits' \
  test_process_layer_checker_rejects_fact \
  sepolicy-wait build-sepolicy 'wait "$build_pid"' 'wait for the background job' \
  'build-sepolicy retained child wait'
run_regression 'process checker rejects services recovery without its own build environment' \
  test_process_layer_checker_rejects_fact \
  services-full-build build-services-jar \
  'full_build_log="$(mktemp "${TMPDIR:-/tmp}/build-full-services.XXXXXX.log")"' \
  "bash -c 'source build/envsetup.sh >/dev/null 2>&1 && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 && m'" \
  'build-services-jar retained full-image build'
run_regression 'process checker rejects sepolicy deployment without its own build environment' \
  test_process_layer_checker_rejects_fact \
  sepolicy-full-build build-sepolicy \
  'full_build_log="$(mktemp "${TMPDIR:-/tmp}/build-full-sepolicy.XXXXXX.log")"' \
  "bash -c 'source build/envsetup.sh >/dev/null 2>&1 && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 && m'" \
  'build-sepolicy retained full-image build'
run_regression 'process checker rejects the obsolete raw SystemServer allow' \
  test_process_layer_checker_rejects_fact \
  sepolicy-raw-system-server build-sepolicy \
  'The system_server_service attribute is consumed by add_service(system_server, system_server_service).' \
  'allow system_server sidebar_service:service_manager { add find };' \
  'build-sepolicy raw system_server allow'
for skill_name in build-services-jar build-sepolicy; do
  if [[ "$skill_name" == build-services-jar ]]; then
    skill_case=services
  else
    skill_case=sepolicy
  fi
  run_regression "process checker binds $skill_case full-build envsetup" \
    test_process_layer_checker_rejects_full_build_line \
    "$skill_case-envsetup" "$skill_name" \
    '  source build/envsetup.sh >/dev/null 2>&1 &&' \
    '  source build/full-setup.sh >/dev/null 2>&1 &&' \
    "$skill_name full-image envsetup"
  run_regression "process checker binds $skill_case full-build lunch" \
    test_process_layer_checker_rejects_full_build_line \
    "$skill_case-lunch" "$skill_name" \
    '  lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 &&' \
    '  lunch wrong-target >/dev/null 2>&1 &&' \
    "$skill_name full-image lunch target"
  run_regression "process checker binds $skill_case full-build m" \
    test_process_layer_checker_rejects_full_build_line \
    "$skill_case-m" "$skill_name" '  m' '  true' \
    "$skill_name full-image compile target"
done

if [[ "$REGRESSION_FAILURES" -ne 0 ]]; then
  echo "FAIL  $REGRESSION_FAILURES Codex harness regression case(s)" >&2
  exit 1
fi

echo 'PASS  Codex feature context selection and branch checks'
