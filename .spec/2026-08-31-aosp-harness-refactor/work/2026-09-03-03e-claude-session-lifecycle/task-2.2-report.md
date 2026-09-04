# 任务 2.2 报告：验证完整历史与 depth-1 checkout

## 摘要

`ACCEPTED_HEAD=5b2e66b3be9079aa31b4b6eba2da88888a3aaeba` 在 `git clone --no-local`（完整历史）与真实 `git clone --depth 1 file://...`（浅克隆）两个独立 `mktemp` checkout 中均验证：HEAD 逐字等于 `ACCEPTED_HEAD`；default 入口（`bash ./tests/test-claude-session-lifecycle.sh`）固定摘要逐字节等于 `RESULT PASS  claude session lifecycle\n`；`bash ./scripts/check.sh --offline` rc0，本入口自动发现恰 1 次且末行 `RESULT PASS  aosp-harness offline quality gate`；上游十二 tracked 文件 SHA-256 测试前后不变；两 checkout 测试后 `git status --porcelain` 均为空、`git diff --stat` 均为空。depth-1 额外核 `git rev-list --count HEAD`=1 且 `.git/shallow` 非空（内容即 `ACCEPTED_HEAD` 一行）。implementation worktree 全程未被写入，`git status --porcelain` 前后均为空，HEAD 未变。零源码 delta。

## files

- 无源码文件改动（本任务不修改 worktree 源码、不改 HEAD）。
- 验收资产：
  - `evidence/task-2.2-red.txt`（新建）
  - `task-2.2-report.md`（本文件，新建）

## commands

- 步骤1 红阶段: `test -s "$WORK/task-2.2-report.md"` → rc1（报告缺席，双流空）；`git -C "$IMPLEMENTATION_WORKTREE" rev-parse HEAD` 逐字核对 `ACCEPTED_HEAD`。
- 步骤2: `tmp=$(mktemp -d)`；`git clone --no-local "$IMPLEMENTATION_WORKTREE" "$tmp/full"`；`git -C "$tmp/full" rev-parse HEAD` 核对 `ACCEPTED_HEAD`。
- 步骤3（full 内）: `sha256sum $UPSTREAM12 > "$tmp/full-before.sha"`；`bash ./tests/test-claude-session-lifecycle.sh >"$tmp/full-default.log" 2>"$tmp/full-default.err"`；`bash ./scripts/check.sh --offline >"$tmp/full-offline.log" 2>"$tmp/full-offline.err"`；`cmp -s "$tmp/full-default.log" <(printf 'RESULT PASS  claude session lifecycle\n')`；`rg -c 'RESULT PASS  claude session lifecycle$' "$tmp/full-offline.log"`；`tail -n1 "$tmp/full-offline.log"`；`sha256sum $UPSTREAM12 > "$tmp/full-after.sha"`；`sha256sum -c "$tmp/full-before.sha"`；`git status --porcelain`；`git diff --stat`。
- 步骤4: `git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" "$tmp/depth1"`；`git -C "$tmp/depth1" rev-parse HEAD` 核对 `ACCEPTED_HEAD`；`git rev-list --count HEAD` = `1`；`test -s .git/shallow`。
- 步骤5（depth1 内）: 同步骤3 的 SHA before/default/offline/SHA after/status/diff 全套动作，日志落 `$tmp/depth1-default.log`、`$tmp/depth1-default.err`、`$tmp/depth1-offline.log`、`$tmp/depth1-offline.err`。
- 步骤6: 删除 `$tmp/full`、`$tmp/depth1` 与整个 `$tmp`（`rm -rf "$tmp"`），核实 `test -d "$tmp"` 失败（已移除）；核实 implementation worktree `git status --porcelain` 仍为空、HEAD 未变。

UPSTREAM12（十二上游 tracked 文件，逐字照抄任务契约）:
```
common/.harness/lib/session-state-foundation.sh
common/.harness/lib/session-state-path.sh
tests/lib/session-path-race-driver.py
tests/test-session-path-races.sh
common/.harness/lib/session-state-snapshot.sh
tests/test-session-snapshot.sh
tests/test-session-snapshot-assurance.sh
common/.harness/lib/session-state-signals.sh
tests/test-session-signals.sh
common/.harness/lib/session-state-remove.sh
common/.harness/lib/session-state.sh
tests/test-session-state.sh
```

## results

- 红阶段: `test -s`→rc1（报告缺席）；implementation HEAD=`5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`=`ACCEPTED_HEAD`，逐字相等，通过。
- full clone（`git clone --no-local`）:
  - HEAD=`5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`=`ACCEPTED_HEAD`，逐字相等，通过。
  - default 入口: rc=`0`，stdout 与 `printf 'RESULT PASS  claude session lifecycle\n'` `cmp -s` 逐字节相等（`CMP_MATCH=OK`），stderr 0 字节。
  - offline: rc=`0`，stderr 0 字节，`rg -c 'RESULT PASS  claude session lifecycle$'`=`1`（自动发现恰一次），末行=`RESULT PASS  aosp-harness offline quality gate`。
  - 上游十二文件: `sha256sum -c` 测试后全部 `OK`（12/12，测试前后不变）。
  - `git status --porcelain` 空、`git diff --stat` 空。
  - 日志路径: `$tmp/full-default.log`、`$tmp/full-offline.log`（`$tmp` 为本次运行时 mktemp 临时目录，已在步骤6随 `rm -rf` 删除，如需复现按步骤2-3重跑）。
- depth1 clone（真实 `git clone --depth 1 file://...`）:
  - HEAD=`5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`=`ACCEPTED_HEAD`，逐字相等，通过。
  - `git rev-list --count HEAD`=`1`，通过。
  - `.git/shallow` 非空（内容为 `ACCEPTED_HEAD` 一行），通过。
  - default 入口: rc=`0`，stdout `cmp -s` 逐字节等于固定摘要（`CMP_MATCH=OK`），stderr 0 字节。
  - offline: rc=`0`，stderr 0 字节，`rg -c`=`1`（自动发现恰一次），末行=`RESULT PASS  aosp-harness offline quality gate`。
  - 上游十二文件: `sha256sum -c` 测试后全部 `OK`（12/12，测试前后不变）。
  - `git status --porcelain` 空、`git diff --stat` 空。
  - 日志路径: `$tmp/depth1-default.log`、`$tmp/depth1-offline.log`（同上，已随 `rm -rf` 删除）。
- 两 clone 各自四份日志（`full-default.log`/`full-offline.log`/`depth1-default.log`/`depth1-offline.log`）分别独立落盘、互不顶替，均已核对完毕后随 `$tmp` 一并清理。
- 清理: `$tmp/full`、`$tmp/depth1` 与 `$tmp` 本身已 `rm -rf` 删除（`test -d "$tmp"` 失败，确认移除）。implementation worktree 全程零写入：`git status --porcelain` 前后均为空、HEAD 全程为 `5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`，未被本任务修改。

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03e-claude-session-lifecycle/evidence/task-2.2-red.txt

## Status

DONE
