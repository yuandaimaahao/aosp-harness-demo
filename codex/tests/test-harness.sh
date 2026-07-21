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

echo 'PASS  Codex feature context selection and branch checks'
