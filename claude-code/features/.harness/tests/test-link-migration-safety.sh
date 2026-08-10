#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -L)"
source "$SCRIPT_DIR/../hooks/feature-common.sh"
ROOT="$(harness_project_root "$SCRIPT_DIR")"
COMMON="$ROOT/.claude/hooks/feature-common.sh"

fail() { echo "FAIL  $1" >&2; exit 1; }

T1="$(mktemp -d)"
T2=""
T3=""
trap 'rm -rf "$T1" "$T2" "$T3"' EXIT

mkdir -p "$T1/features/dev-test"
printf '%s\n' '# feature: dev-test' > "$T1/features/dev-test/CLAUDE.md"
printf '%s\n' 'ORIGINAL PRECIOUS CONTENT' > "$T1/CLAUDE.md"

set +e
backup_output="$(bash -c "
  source '$COMMON'
  cp() { return 1; }
  sync_feature_link '$T1' 'features/dev-test/CLAUDE.md'
" 2>&1)"
backup_rc=$?
set -e
test "$backup_rc" -ne 0 || fail "备份失败时仍返回成功"
test ! -L "$T1/CLAUDE.md" || fail "备份失败后原文件被换成软链"
grep -Fq 'ORIGINAL PRECIOUS CONTENT' "$T1/CLAUDE.md" \
  || fail "备份失败后原文件内容丢失"
grep -Fq '备份' <<<"$backup_output" || fail "备份失败没有可见错误"

T2="$(mktemp -d)"
mkdir -p "$T2/features/dev-test"
printf '%s\n' '# feature: dev-test' > "$T2/features/dev-test/CLAUDE.md"
printf '%s\n' 'ORIGINAL PRECIOUS CONTENT' > "$T2/CLAUDE.md"

set +e
link_output="$(bash -c "
  source '$COMMON'
  ln() { return 1; }
  sync_feature_link '$T2' 'features/dev-test/CLAUDE.md'
" 2>&1)"
link_rc=$?
set -e
test "$link_rc" -ne 0 || fail "软链创建失败时仍返回成功"
test -e "$T2/CLAUDE.md" || fail "软链创建失败后根 CLAUDE.md 消失"
grep -Fq 'ORIGINAL PRECIOUS CONTENT' "$T2/CLAUDE.md" \
  || fail "软链失败后没有恢复原内容"
grep -Fq '回滚' <<<"$link_output" || fail "软链失败没有报告回滚"

T3="$(mktemp -d)"
mkdir -p "$T3/features/dev-test"
printf '%s\n' '# feature: dev-test' > "$T3/features/dev-test/CLAUDE.md"
printf '%s\n' 'ORIGINAL PRECIOUS CONTENT' > "$T3/CLAUDE.md"
bash -c "source '$COMMON'; sync_feature_link '$T3' 'features/dev-test/CLAUDE.md'"
test -L "$T3/CLAUDE.md" || fail "正常迁移没有创建软链"
test "$(readlink "$T3/CLAUDE.md")" = "features/dev-test/CLAUDE.md" \
  || fail "正常迁移软链目标错误"
grep -Fq 'ORIGINAL PRECIOUS CONTENT' "$T3"/CLAUDE.md.bak.* \
  || fail "正常迁移没有留下正确备份"

echo "PASS  demo root CLAUDE.md migration is rollback-safe"
