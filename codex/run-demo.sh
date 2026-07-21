#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

section() {
  printf '\n============================================================\n'
  printf '%s\n' "$1"
  printf '============================================================\n'
}

DEMO_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-harness-demo.XXXXXX")"
CURRENT_FEATURE_BACKUP="$DEMO_TMP_DIR/CURRENT_FEATURE.original"
ORIGINAL_CURRENT_SAVED=0
ORIGINAL_AGENTS_KIND='missing'
ORIGINAL_AGENTS_TARGET=''

cleanup() {
  local rc=$?
  local cleanup_rc=0

  trap - EXIT
  set +e

  if [[ "$ORIGINAL_CURRENT_SAVED" -eq 1 ]]; then
    if ! cp -- "$CURRENT_FEATURE_BACKUP" CURRENT_FEATURE; then
      echo 'error: 无法还原 CURRENT_FEATURE' >&2
      cleanup_rc=1
    fi
  fi

  case "$ORIGINAL_AGENTS_KIND" in
    symlink)
      if [[ -L AGENTS.md ]]; then
        if [[ "$(readlink AGENTS.md)" != "$ORIGINAL_AGENTS_TARGET" ]]; then
          rm -f -- AGENTS.md
          ln -s -- "$ORIGINAL_AGENTS_TARGET" AGENTS.md || cleanup_rc=1
        fi
      elif [[ -e AGENTS.md ]]; then
        echo 'error: AGENTS.md 已变成普通文件，拒绝覆盖' >&2
        cleanup_rc=1
      else
        ln -s -- "$ORIGINAL_AGENTS_TARGET" AGENTS.md || cleanup_rc=1
      fi
      ;;
    missing)
      if [[ -L AGENTS.md ]]; then
        rm -f -- AGENTS.md || cleanup_rc=1
      elif [[ -e AGENTS.md ]]; then
        echo 'error: AGENTS.md 已变成普通文件，拒绝删除' >&2
        cleanup_rc=1
      fi
      ;;
    regular)
      ;;
  esac

  if [[ -n "$DEMO_TMP_DIR" && -d "$DEMO_TMP_DIR" ]]; then
    rm -rf -- "$DEMO_TMP_DIR" || cleanup_rc=1
  fi

  if [[ "$cleanup_rc" -ne 0 && "$rc" -eq 0 ]]; then
    rc=$cleanup_rc
  fi
  exit "$rc"
}
trap cleanup EXIT

if [[ ! -f CURRENT_FEATURE ]]; then
  echo 'error: 缺少 CURRENT_FEATURE，无法演示 feature 切换' >&2
  exit 1
fi
cp -- CURRENT_FEATURE "$CURRENT_FEATURE_BACKUP"
ORIGINAL_CURRENT_SAVED=1
ORIGINAL_FEATURE="$(<CURRENT_FEATURE)"
if [[ "$ORIGINAL_FEATURE" != 'dev-sidebar' ]]; then
  echo "error: demo 期待 CURRENT_FEATURE=dev-sidebar，当前为 '$ORIGINAL_FEATURE'" >&2
  exit 1
fi

if [[ -L AGENTS.md ]]; then
  ORIGINAL_AGENTS_KIND='symlink'
  ORIGINAL_AGENTS_TARGET="$(readlink AGENTS.md)"
elif [[ -e AGENTS.md ]]; then
  ORIGINAL_AGENTS_KIND='regular'
  echo 'error: AGENTS.md 是普通文件，demo 拒绝覆盖' >&2
  exit 1
fi

section '1. 上下文选择（Context selection）'
./.codex/bin/codex-feature --dry-run
printf 'AGENTS.md -> %s\n' "$(readlink AGENTS.md)"
printf '选中上下文标题: %s\n' "$(grep -m1 '^# ' AGENTS.md)"

section '2. 会话分支漂移（Branch drift）'
DEMO_ROOT="$DEMO_TMP_DIR/harness-root"
STATE_DIR="$DEMO_TMP_DIR/state"
mkdir -p \
  "$DEMO_ROOT/features/dev-sidebar" \
  "$DEMO_ROOT/features/dev-next"
ln -s "$ROOT/CURRENT_FEATURE" "$DEMO_ROOT/CURRENT_FEATURE"
ln -s "$ROOT/features/dev-sidebar/AGENTS.md" \
  "$DEMO_ROOT/features/dev-sidebar/AGENTS.md"
ln -s "$ROOT/features/dev-sidebar/AGENTS.md" \
  "$DEMO_ROOT/features/dev-next/AGENTS.md"

session_payload='{"session_id":"demo-session","cwd":".","hook_event_name":"SessionStart"}'
prompt_payload='{"session_id":"demo-session","cwd":".","hook_event_name":"UserPromptSubmit"}'
printf '%s\n' "$session_payload" | \
  HARNESS_ROOT="$DEMO_ROOT" CODEX_HARNESS_STATE_DIR="$STATE_DIR" \
  ./.codex/hooks/session-start.sh
echo '[demo] 已记录 demo-session 的 dev-sidebar 快照。'

no_drift_output="$(printf '%s\n' "$prompt_payload" | \
  HARNESS_ROOT="$DEMO_ROOT" CODEX_HARNESS_STATE_DIR="$STATE_DIR" \
  ./.codex/hooks/check-branch-drift.sh)"
if [[ -n "$no_drift_output" ]]; then
  echo 'error: 无漂移检查本应零输出' >&2
  exit 1
fi
echo '[demo] 无漂移：零输出。'

printf '%s\n' 'dev-next' > CURRENT_FEATURE
drift_output="$(printf '%s\n' "$prompt_payload" | \
  HARNESS_ROOT="$DEMO_ROOT" CODEX_HARNESS_STATE_DIR="$STATE_DIR" \
  ./.codex/hooks/check-branch-drift.sh)"
if [[ "$drift_output" != *'"continue": false'* || \
      "$drift_output" != *"current feature is 'dev-next'"* ]]; then
  echo 'error: 漂移 hook 未返回预期的结构化阻断块' >&2
  exit 1
fi
echo '[demo] 切换到 dev-next 后的 hook 输出：'
printf '%s\n' "$drift_output"
cp -- "$CURRENT_FEATURE_BACKUP" CURRENT_FEATURE
echo '[demo] 已在继续前还原 CURRENT_FEATURE=dev-sidebar。'

section '3. 涉及仓分支一致性（Branch consistency）'
if ./features/dev-sidebar/check-branch.sh --demo; then
  echo 'error: 确定性漂移样本意外返回成功' >&2
  exit 1
else
  branch_rc=$?
fi
if [[ "$branch_rc" -ne 1 ]]; then
  echo "error: 分支一致性 demo 返回了非预期状态 $branch_rc" >&2
  exit 1
fi
echo '[demo] 已按预期识别样本分支漂移。'

section '4. 流程 Skills（Process skills）'
./.codex/bin/check-process-layer

section '5. 严格验证（Strict verification）'
./features/dev-sidebar/verify-sidebar.sh --demo

section '6. 回归测试（Regression）'
if [[ "${SKIP_SELF_TESTS:-0}" == 1 ]]; then
  echo '[demo] SKIP_SELF_TESTS=1，跳过自身回归测试。'
else
  ./tests/test-harness.sh
fi

echo 'Codex 三层 Harness 演示完毕'
