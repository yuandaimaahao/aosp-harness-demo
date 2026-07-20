#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$(mktemp -d)"
BRANCH_FIXTURE=""

cleanup() {
  rm -f "$FIXTURE/CLAUDE.md" \
    "$FIXTURE/CURRENT_FEATURE" \
    "$FIXTURE/features/dev-test/CLAUDE.md" \
    "$FIXTURE/features/dev-test/check-branch.sh" \
    "$FIXTURE/features/dev-test/repos.tsv"
  rmdir "$FIXTURE/.repo" "$FIXTURE/features/dev-test" "$FIXTURE/features" "$FIXTURE" 2>/dev/null || true
  if [ -n "$BRANCH_FIXTURE" ] && [ -d "$BRANCH_FIXTURE" ]; then
    rm -r "$BRANCH_FIXTURE"
  fi
}
trap cleanup EXIT

mkdir -p "$FIXTURE/features/dev-test"
printf '%s\n' 'dev-test' > "$FIXTURE/CURRENT_FEATURE"
printf '%s\n' '# feature: dev-test' > "$FIXTURE/features/dev-test/CLAUDE.md"

HARNESS_ROOT="$FIXTURE" "$ROOT/.claude/bin/claude-feature" --dry-run >/dev/null
test -L "$FIXTURE/CLAUDE.md"
test "$(readlink "$FIXTURE/CLAUDE.md")" = "features/dev-test/CLAUDE.md"

rm -f "$FIXTURE/CLAUDE.md"
mkdir "$FIXTURE/.repo"
printf '%s\n' 'missing/repo - - expected missing repo' > "$FIXTURE/features/dev-test/repos.tsv"
ln -s "$ROOT/features/dev-sidebar/check-branch.sh" "$FIXTURE/features/dev-test/check-branch.sh"
set +e
HARNESS_ROOT="$FIXTURE" "$ROOT/.claude/bin/claude-feature" --dry-run >/dev/null 2>&1
wrapper_rc=$?
set -e
test "$wrapper_rc" -ne 0
test ! -e "$FIXTURE/CLAUDE.md"

set +e
strict_output="$(DEMO_APP_INSTALLED=0 "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo 2>&1)"
strict_rc=$?
set -e
test "$strict_rc" -ne 0
grep -Fq 'RESULT INCOMPLETE' <<<"$strict_output"

allow_output="$(DEMO_APP_INSTALLED=0 "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo --allow-skip)"
grep -Fq 'RESULT PASS (SKIP allowed)' <<<"$allow_output"

BRANCH_FIXTURE="$(mktemp -d)"
mkdir -p "$BRANCH_FIXTURE/features/dev-test" "$BRANCH_FIXTURE/repos/one"
printf '%s\n' \
  'repos/one - - first repo' \
  'repos/two - - second repo' \
  > "$BRANCH_FIXTURE/features/dev-test/repos.tsv"
git -C "$BRANCH_FIXTURE/repos/one" init -q -b dev-test
git -C "$BRANCH_FIXTURE/repos/one" -c user.name=test -c user.email=test@example.com \
  commit --allow-empty -qm init

set +e
branch_output="$(HARNESS_ROOT="$BRANCH_FIXTURE" FEATURE_NAME=dev-test \
  "$ROOT/features/dev-sidebar/check-branch.sh" 2>&1)"
branch_rc=$?
set -e
test "$branch_rc" -ne 0
grep -Fq 'MISSING repos/two' <<<"$branch_output"

mkdir -p "$BRANCH_FIXTURE/repos/two"
git -C "$BRANCH_FIXTURE/repos/two" init -q -b dev-test
git -C "$BRANCH_FIXTURE/repos/two" -c user.name=test -c user.email=test@example.com \
  commit --allow-empty -qm init
HARNESS_ROOT="$BRANCH_FIXTURE" FEATURE_NAME=dev-test \
  "$ROOT/features/dev-sidebar/check-branch.sh" >/dev/null

echo "PASS  demo harness startup and strict verification"
