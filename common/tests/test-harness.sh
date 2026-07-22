#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/shared-harness-test.XXXXXX")"
trap 'rm -rf -- "$FIXTURE"' EXIT

failures=0

run_expect_success() {
  local name="$1" rc
  shift
  set +e
  (set -e; "$@")
  rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    return 0
  fi
  printf 'FAIL  %s\n' "$name" >&2
  failures=$((failures + 1))
}

test_contracts_match() {
  local claude codex
  claude="$("$ROOT/.claude/bin/claude-feature" --dry-run --contract)"
  codex="$("$ROOT/.codex/bin/codex-feature" --dry-run --contract)"

  grep -Fq 'client=claude' <<<"$claude"
  grep -Fq 'client=codex' <<<"$codex"
  test "$(sed 's/^client=.*/client=CLIENT/' <<<"$claude")" = \
    "$(sed 's/^client=.*/client=CLIENT/' <<<"$codex")"
  grep -Fq 'feature=dev-sidebar' <<<"$claude"
  grep -Fq 'target_branch=dev-sidebar' <<<"$claude"
  grep -Fq 'manifest=.harness/features/dev-sidebar/repos.tsv' <<<"$claude"
  grep -Fq 'workflow=.harness/features/dev-sidebar/workflow.md' <<<"$claude"
  grep -Fq 'verifier=.harness/features/dev-sidebar/verify-sidebar.sh' <<<"$claude"
  grep -Eq '^contract_sha256=[0-9a-f]{64}$' <<<"$claude"
}

test_parity_passes() {
  local output
  output="$("$ROOT/.harness/bin/check-parity.sh")"
  grep -Fq 'PARITY PASS' <<<"$output"
}

test_shared_source_is_not_duplicated() {
  test -z "$(find "$ROOT/.claude" "$ROOT/.codex" -type f \
    \( -name repos.tsv -o -name 'verify-*.sh' \) -print -quit)"
  test -f "$ROOT/.harness/features/dev-sidebar/repos.tsv"
  test -f "$ROOT/.harness/features/dev-sidebar/workflow.md"
  test -f "$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh"
}

test_manifest_has_canonical_schema() {
  awk -F '\t' '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    NF != 4 { exit 1 }
    $1 == "" || $2 == "" || $3 == "" || $4 == "" { exit 1 }
    END { if (NR == 0) exit 1 }
  ' "$ROOT/.harness/features/dev-sidebar/repos.tsv"
}

test_verifier_strict_states() {
  local pass_output incomplete_output incomplete_rc allowed_output
  pass_output="$("$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh" --demo)"
  grep -Fxq 'RESULT PASS' <<<"$pass_output"

  set +e
  incomplete_output="$(DEMO_SKIP=1 \
    "$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh" --demo 2>&1)"
  incomplete_rc=$?
  set -e
  test "$incomplete_rc" -ne 0
  grep -Fq 'RESULT INCOMPLETE' <<<"$incomplete_output"

  allowed_output="$(DEMO_SKIP=1 \
    "$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh" --demo --allow-skip)"
  grep -Fxq 'RESULT EXPLORATION (SKIP allowed)' <<<"$allowed_output"
  ! grep -Fq 'RESULT PASS' <<<"$allowed_output"

  set +e
  real_skip_output="$(ANDROID_SERIAL=demo \
    "$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh" --allow-skip 2>&1)"
  real_skip_rc=$?
  set -e
  test "$real_skip_rc" -ne 0
  grep -Fq -- '--allow-skip requires --demo' <<<"$real_skip_output"
}

copy_fixture() {
  local destination="$1"
  cp -a "$ROOT" "$destination"
  rm -rf -- "$destination/tests" "$destination/demo-out" 2>/dev/null || true
}

init_repo() {
  local path="$1" branch="$2"
  mkdir -p "$path"
  git -C "$path" init -q -b "$branch"
  git -C "$path" -c user.name=test -c user.email=test@example.com \
    commit --allow-empty -qm init
}

test_invalid_feature_fails_closed() {
  local fixture="$FIXTURE/invalid-feature" output rc
  copy_fixture "$fixture"
  printf '%s\n' '../escape' > "$fixture/CURRENT_FEATURE"
  set +e
  output="$(HARNESS_ROOT="$fixture" \
    "$fixture/.claude/bin/claude-feature" --dry-run --contract 2>&1)"
  rc=$?
  set -e
  test "$rc" -ne 0
  grep -Fq 'INVALID feature' <<<"$output"
}

test_nul_feature_fails_closed() {
  local fixture="$FIXTURE/nul-feature" output rc
  copy_fixture "$fixture"
  printf 'dev-sidebar\0ignored\n' > "$fixture/CURRENT_FEATURE"
  set +e
  output="$(HARNESS_ROOT="$fixture" \
    "$fixture/.codex/bin/codex-feature" --dry-run --contract 2>&1)"
  rc=$?
  set -e
  test "$rc" -ne 0
  grep -Fq 'INVALID feature' <<<"$output"
}

test_unsafe_manifest_path_fails_closed() {
  local fixture="$FIXTURE/unsafe-manifest" output rc
  copy_fixture "$fixture"
  printf '%s\n' $'../escape\tsource\ttest\tunsafe path' \
    > "$fixture/.harness/features/dev-sidebar/repos.tsv"
  set +e
  output="$(HARNESS_ROOT="$fixture" \
    "$fixture/.claude/bin/claude-feature" --dry-run --contract 2>&1)"
  rc=$?
  set -e
  test "$rc" -ne 0
  grep -Fq 'unsafe repository path' <<<"$output"
}

test_malformed_manifest_fails_closed() {
  local fixture="$FIXTURE/malformed-manifest" output rc
  copy_fixture "$fixture"
  printf '%s\n' $'frameworks/base\tsource\t\tdescription\textra' \
    > "$fixture/.harness/features/dev-sidebar/repos.tsv"
  set +e
  output="$(HARNESS_ROOT="$fixture" \
    "$fixture/.codex/bin/codex-feature" --dry-run --contract 2>&1)"
  rc=$?
  set -e
  test "$rc" -ne 0
  grep -Fq 'four nonempty tab-separated fields' <<<"$output"
}

test_feature_specific_verifier_is_discovered() {
  local fixture="$FIXTURE/feature-verifier" output
  copy_fixture "$fixture"
  mkdir -p "$fixture/.harness/features/dev-next"
  printf '%s\n' 'dev-next' > "$fixture/CURRENT_FEATURE"
  printf '%s\n' $'frameworks/base\tsource\ttest\tnext feature' \
    > "$fixture/.harness/features/dev-next/repos.tsv"
  printf '%s\n' '# next workflow' > "$fixture/.harness/features/dev-next/workflow.md"
  printf '%s\n' '#!/usr/bin/env bash' 'echo RESULT PASS' \
    > "$fixture/.harness/features/dev-next/verify-next.sh"
  chmod +x "$fixture/.harness/features/dev-next/verify-next.sh"
  output="$(HARNESS_ROOT="$fixture" \
    "$fixture/.claude/bin/claude-feature" --dry-run --contract)"
  grep -Fq 'feature=dev-next' <<<"$output"
  grep -Fq 'verifier=.harness/features/dev-next/verify-next.sh' <<<"$output"
}

test_missing_workflow_fails_closed() {
  local fixture="$FIXTURE/missing-workflow" output rc
  copy_fixture "$fixture"
  rm "$fixture/.harness/features/dev-sidebar/workflow.md"
  set +e
  output="$(HARNESS_ROOT="$fixture" \
    "$fixture/.codex/bin/codex-feature" --dry-run --contract 2>&1)"
  rc=$?
  set -e
  test "$rc" -ne 0
  grep -Fq 'workflow' <<<"$output"
}

test_missing_public_file_fails_closed() {
  local fixture="$FIXTURE/missing-public" output rc
  copy_fixture "$fixture"
  rm "$fixture/.harness/features/dev-sidebar/verify-sidebar.sh"
  set +e
  output="$(HARNESS_ROOT="$fixture" \
    "$fixture/.codex/bin/codex-feature" --dry-run --contract 2>&1)"
  rc=$?
  set -e
  test "$rc" -ne 0
  grep -Fq 'verifier' <<<"$output"
}

test_shared_branch_checker() {
  local fixture="$FIXTURE/branch-check" repo output rc
  copy_fixture "$fixture"
  mkdir -p "$fixture/.repo"
  for repo in frameworks/base frameworks/native packages/apps/SidebarApp \
    build/make system/sepolicy; do
    init_repo "$fixture/$repo" dev-sidebar
  done
  HARNESS_ROOT="$fixture" "$fixture/.harness/bin/check-branches.sh" >/dev/null

  git -C "$fixture/frameworks/native" switch -qc dev-other
  set +e
  output="$(HARNESS_ROOT="$fixture" \
    "$fixture/.codex/bin/codex-feature" --dry-run --contract 2>&1)"
  rc=$?
  set -e
  test "$rc" -ne 0
  grep -Fq 'DRIFT   frameworks/native @ dev-other' <<<"$output"
}

test_parity_detects_adapter_drift() {
  local fixture="$FIXTURE/parity-drift" output rc
  copy_fixture "$fixture"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "%s\n" "client=codex" "feature=dev-sidebar" "manifest=.harness/features/dev-sidebar/repos.tsv" "verifier=.harness/features/dev-sidebar/other.sh" "contract_sha256=0000000000000000000000000000000000000000000000000000000000000000"' \
    > "$fixture/.codex/bin/codex-feature"
  chmod +x "$fixture/.codex/bin/codex-feature"
  set +e
  output="$(HARNESS_ROOT="$fixture" "$fixture/.harness/bin/check-parity.sh" 2>&1)"
  rc=$?
  set -e
  test "$rc" -ne 0
  grep -Fq 'PARITY FAIL' <<<"$output"
}

test_parity_detects_synchronized_adapter_drift() {
  local fixture="$FIXTURE/parity-synchronized-drift" output rc client adapter
  copy_fixture "$fixture"
  for client in claude codex; do
    adapter="$fixture/.$client/bin/${client}-feature"
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      "printf '%s\\n' 'client=$client' 'feature=stale' 'target_branch=stale' 'manifest=.harness/features/stale/repos.tsv' 'workflow=.harness/features/stale/workflow.md' 'verifier=.harness/features/stale/verify-stale.sh' 'repositories=frameworks/base' 'contract_sha256=0000000000000000000000000000000000000000000000000000000000000000'" \
      > "$adapter"
    chmod +x "$adapter"
  done
  set +e
  output="$(HARNESS_ROOT="$fixture" "$fixture/.harness/bin/check-parity.sh" 2>&1)"
  rc=$?
  set -e
  test "$rc" -ne 0
  grep -Fq 'PARITY FAIL' <<<"$output"
}

test_parity_detects_nested_fact_copy() {
  local fixture="$FIXTURE/parity-duplicate" output rc
  copy_fixture "$fixture"
  mkdir -p "$fixture/.claude/cache"
  cp "$fixture/.harness/features/dev-sidebar/repos.tsv" \
    "$fixture/.claude/cache/repos.tsv"
  set +e
  output="$(HARNESS_ROOT="$fixture" "$fixture/.harness/bin/check-parity.sh" 2>&1)"
  rc=$?
  set -e
  test "$rc" -ne 0
  grep -Fq 'duplicated public facts' <<<"$output"
}

run_expect_success 'Claude/Codex public contracts match' test_contracts_match
run_expect_success 'Parity checker passes' test_parity_passes
run_expect_success 'Public facts are not duplicated' test_shared_source_is_not_duplicated
run_expect_success 'Manifest follows canonical four-column schema' test_manifest_has_canonical_schema
run_expect_success 'Verifier has strict PASS/INCOMPLETE semantics' test_verifier_strict_states
run_expect_success 'Invalid feature fails closed' test_invalid_feature_fails_closed
run_expect_success 'NUL feature fails closed' test_nul_feature_fails_closed
run_expect_success 'Unsafe manifest path fails closed' test_unsafe_manifest_path_fails_closed
run_expect_success 'Malformed manifest fails closed' test_malformed_manifest_fails_closed
run_expect_success 'Feature-specific verifier is discovered' test_feature_specific_verifier_is_discovered
run_expect_success 'Missing workflow fails closed' test_missing_workflow_fails_closed
run_expect_success 'Missing verifier fails closed' test_missing_public_file_fails_closed
run_expect_success 'Shared branch checker gates both adapters' test_shared_branch_checker
run_expect_success 'Parity detects adapter drift' test_parity_detects_adapter_drift
run_expect_success 'Parity detects synchronized adapter drift' test_parity_detects_synchronized_adapter_drift
run_expect_success 'Parity detects nested public-fact copies' test_parity_detects_nested_fact_copy

if ((failures > 0)); then
  printf 'RESULT FAIL (%d regression failures)\n' "$failures" >&2
  exit 1
fi
printf 'RESULT PASS  shared Harness regression suite\n'
