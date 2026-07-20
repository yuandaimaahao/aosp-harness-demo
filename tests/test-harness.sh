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

# 当前方案是“树根单文件软链”，demo 不得继续描述已废弃的仓内 CLAUDE.md 物化方案。
if rg -n 'frameworks-(base|native)\.md|物化.*CLAUDE\.md|同目录下的 CLAUDE\.md' \
    "$ROOT/frameworks/base/PLACEHOLDER.java" \
    "$ROOT/frameworks/native/PLACEHOLDER.cpp" \
    "$ROOT/.claude/skills/build-services-jar/SKILL.md"; then
  echo "FAIL  demo 仍含已废弃的仓内 CLAUDE.md 物化说明" >&2
  exit 1
fi

# run-demo 必须覆盖第②层；离线 demo 通过独立检查入口验证流程 skill 工件。
test -x "$ROOT/.claude/bin/check-process-layer"
grep -Fq './.claude/bin/check-process-layer' "$ROOT/run-demo.sh"
process_output="$("$ROOT/.claude/bin/check-process-layer")"
grep -Fq 'PASS  build-services-jar skill 工件完整' <<<"$process_output"
grep -Fq 'PASS  build-sepolicy skill 工件完整' <<<"$process_output"
grep -Fq 'RESULT PASS' <<<"$process_output"

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

echo "PASS  demo harness startup, process layer, and strict verification"
