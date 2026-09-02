# 任务 2.3 报告：验证真实 depth-1 checkout

## task

- task-2.3：从 implementation worktree（`WORK/worktree`，分支 `spec/2026-09-02-03b1-session-snapshot-assurance`）以 `git clone --depth 1 "file://$WORK/worktree"`（真实 file:// URL、非 --no-local 完整 clone）克隆出 depth-1 checkout，在 accepted head `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a` 上跑 R9 depth-1 验证；零 delta——本任务不产生任何 commit，ACCEPTED_HEAD 保持不变；depth-1 checkout 用后已删除。
- 红阶段证据:
.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/evidence/task-2.3-red.txt
  - 红阶段记录内容：`test -s "$WORK/task-2.3-report.md"` 在报告缺席时 rc=1，双流为空。

## base

- ACCEPTED_HEAD = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`（任务 2.1 固定；execution BASE 为 `8a164f212c398a95703a38fb919af2b31c6e1662`，见 `WORK/execution-base.env`）。

## head

- HEAD = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`。
- 验证前 implementation `git rev-parse HEAD` 逐字等于 ACCEPTED_HEAD 且 clean；depth-1 checkout 的 `git rev-parse HEAD` 亦逐字相等，`git rev-list --count HEAD` = 1 且 `.git/shallow` 非空（真实 shallow，内容即 ACCEPTED_HEAD 一行）。零 delta 成立。

## files

- 验证对象：`tests/test-session-snapshot-assurance.sh`（clone 内默认发现的 assurance 入口）。
- 本任务产出（验收资产，不纳入源码）：
  - `task-2.3-report.md`（本报告）
  - `evidence/task-2.3-red.txt`（红阶段证据，六行 schema + assertion）
  - `evidence/task-2.3-logs/`（全部运行日志）
  - `evidence/task-2.3-evidence.tsv`（三列 evidence 清单）

## commands

固定工具目录 `…/scratchpad/tools/bin` 前置 PATH；clone 目标为 `mktemp -d` 下的 `depth1/`，验证后整体删除：

1. 红阶段：`test -s "$WORK/task-2.3-report.md"` → rc=1（报告缺席），写 red 文件并核 `test -s` 通过。
2. `git -C "$WORK/worktree" rev-parse HEAD` = ACCEPTED_HEAD；`git status --porcelain` 为空（implementation clean）。
3. `git clone --depth 1 "file://$WORK/worktree" "$tmp/depth1"` → rc=0（日志 `clone.log`）；depth1 的 `git rev-parse HEAD` 逐字等于 ACCEPTED_HEAD、`git rev-list --count HEAD` = 1、`test -s .git/shallow` 通过。
4. 六上游文件 before SHA：`sha256sum common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh tests/lib/session-path-race-driver.py tests/test-session-path-races.sh common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh` → `upstream-before.sha256`。
5. 主验证命令：`bash ./tests/test-session-snapshot-assurance.sh >default.out 2>default.err` → rc=0；`printf 'RESULT PASS  session snapshot assurance\n' | cmp -s - default.out` 逐字节一致；stderr 0 字节。
6. `bash ./scripts/check.sh --offline >offline.log 2>offline.err` → rc=0，stderr 0 字节；`rg -c 'RESULT PASS  session snapshot assurance' offline.log` = 1（自动发现本入口恰好一次）；offline.log 末行 `RESULT PASS  aosp-harness offline quality gate`（PASS）。
7. after SHA：`sha256sum -c upstream-before.sha256` → 六文件全部 OK（测试前后不变，见 `upstream-after-check.log`）。
8. `git status --porcelain` 为空、`git diff` 为空、`git diff --check` rc=0（depth-1 checkout clean）。
9. 删除临时目录（含 depth-1 checkout）：`rm -rf "$tmp"`，核 `test ! -e "$tmp"` 通过。

## results

- depth-1 checkout HEAD：逐字 `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`，commit-count=1，`.git/shallow` 非空 —— PASS。
- default 入口：rc=0，stdout 逐字 `RESULT PASS  session snapshot assurance\n`，stderr 空 —— PASS。
- offline：rc=0，本入口自动发现恰好 1 次，末行 PASS —— PASS。
- 六上游 tracked 文件 SHA-256 测试前后不变 —— 不变量保持。
- depth-1 checkout 测试后 status/diff 均 clean，`git diff --check` rc0 —— 零 delta。
- depth-1 checkout 临时目录已删除 —— 无残留。
- 本任务零 commit；待独立 review PASS 后由控制器追加 manifest 第 4 行并 mark 2.3。
