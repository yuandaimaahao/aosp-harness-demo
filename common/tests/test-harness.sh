#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/shared-harness-test.XXXXXX")"
trap 'rm -rf -- "$FIXTURE"' EXIT

failures=0

run_expect_success() {
  local name="$1"
  shift
  if "$@"; then
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
  grep -Fq 'manifest=.harness/features/dev-sidebar/repos.tsv' <<<"$claude"
  grep -Fq 'verifier=.harness/features/dev-sidebar/verify-sidebar.sh' <<<"$claude"
  grep -Eq '^contract_sha256=[0-9a-f]{64}$' <<<"$claude"
}

test_parity_passes() {
  local output
  output="$("$ROOT/.harness/bin/check-parity.sh")"
  grep -Fq 'PARITY PASS' <<<"$output"
}

test_shared_source_is_not_duplicated() {
  test ! -e "$ROOT/.claude/repos.tsv"
  test ! -e "$ROOT/.codex/repos.tsv"
  test -f "$ROOT/.harness/features/dev-sidebar/repos.tsv"
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
  grep -Fq 'RESULT PASS' <<<"$pass_output"

  set +e
  incomplete_output="$(DEMO_SKIP=1 \
    "$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh" --demo 2>&1)"
  incomplete_rc=$?
  set -e
  test "$incomplete_rc" -ne 0
  grep -Fq 'RESULT INCOMPLETE' <<<"$incomplete_output"

  allowed_output="$(DEMO_SKIP=1 \
    "$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh" --demo --allow-skip)"
  grep -Fq 'RESULT PASS (SKIP allowed)' <<<"$allowed_output"
}

copy_fixture() {
  local destination="$1"
  cp -a "$ROOT" "$destination"
  rm -rf -- "$destination/tests" "$destination/demo-out" 2>/dev/null || true
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

run_expect_success 'Claude/Codex public contracts match' test_contracts_match
run_expect_success 'Parity checker passes' test_parity_passes
run_expect_success 'Public facts are not duplicated' test_shared_source_is_not_duplicated
run_expect_success 'Manifest follows canonical four-column schema' test_manifest_has_canonical_schema
run_expect_success 'Verifier has strict PASS/INCOMPLETE semantics' test_verifier_strict_states
run_expect_success 'Invalid feature fails closed' test_invalid_feature_fails_closed
run_expect_success 'Missing verifier fails closed' test_missing_public_file_fails_closed
run_expect_success 'Parity detects adapter drift' test_parity_detects_adapter_drift

if ((failures > 0)); then
  printf 'RESULT FAIL (%d regression failures)\n' "$failures" >&2
  exit 1
fi
printf 'RESULT PASS  shared Harness regression suite\n'
