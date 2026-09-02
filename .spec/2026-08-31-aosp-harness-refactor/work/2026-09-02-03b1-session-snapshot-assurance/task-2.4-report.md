# 任务 2.4 报告：验证 exact rollback

## task

- task-2.4：从 implementation worktree（`WORK/worktree`，HEAD = accepted head `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`）以 `git clone --no-local` 克隆出隔离 rollback checkout，提交一个 exact 只删除 `tests/test-session-snapshot-assurance.sh` 的 rollback commit，在该 clean checkout 中运行 03b 基础测试与 offline 验证 R10 回滚语义；rollback clone 用后已删除，implementation worktree 与主仓库零提交，candidate/full/depth-1 checkout 不被触碰。
- 红阶段证据:
.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/evidence/task-2.4-red.txt
  - 红阶段记录内容：`test -s "$WORK/task-2.4-report.md"` 在报告缺席时 rc=1，双流为空。

## base

- ACCEPTED_HEAD = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`（任务 2.1 固定；execution BASE 为 `8a164f212c398a95703a38fb919af2b31c6e1662`，见 `WORK/execution-base.env`）。

## head

- implementation HEAD = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`，验证前后不变且 clean（`impl-status.log` 0 字节）。
- rollback clone 克隆时 HEAD 逐字等于 ACCEPTED_HEAD；rollback commit `cf9828f28c6bc847e1737c353752cdcddfc2fd09`（已随临时目录删除），`git diff --name-status HEAD~1 HEAD` 恰为一行 `D\ttests/test-session-snapshot-assurance.sh`。
- 零 delta 成立：本任务对 implementation worktree 与主仓库零提交，rollback clone 删除后无残留。

## files

- 验证对象：`tests/test-session-snapshot-assurance.sh`（rollback commit 唯一删除的文件）。
- 本任务产出（验收资产，不纳入源码）：
  - `task-2.4-report.md`（本报告）
  - `evidence/task-2.4-red.txt`（红阶段证据，六行 schema + assertion）
  - `evidence/task-2.4-logs/`（全部运行日志）
  - `evidence/task-2.4-evidence.tsv`（三列 evidence 清单）

## commands

clone 目标为 `mktemp -d` 下的 `rollback/`，验证后整体删除：

1. 红阶段：`test -s "$WORK/task-2.4-report.md"` → rc=1（报告缺席），写 red 文件并核 `test -s` 通过（`red.stdout`/`red.stderr` 均 0 字节）。
2. `git -C "$WORK/worktree" rev-parse HEAD` = ACCEPTED_HEAD；`git status --porcelain` 0 字节（implementation clean，`impl-status.log`）。
3. `git clone --no-local "$WORK/worktree" "$tmp/rollback"` → rc=0（`clone.log`）；rollback 的 `git rev-parse HEAD` 逐字等于 ACCEPTED_HEAD。
4. `git rm tests/test-session-snapshot-assurance.sh`（`git-rm.log`）后 `git commit -m "test(session): rollback snapshot assurance"`（`commit.log`）→ rc=0，commit `cf9828f28c6bc847e1737c353752cdcddfc2fd09`（`rollback-head.txt`）；`git diff --name-status HEAD~1 HEAD` 恰为一行 `D\ttests/test-session-snapshot-assurance.sh`（`rollback-diff.log`）。
5. 03b 基础测试：`bash tests/test-session-snapshot.sh >base.out 2>base.err` → rc=0；`printf 'RESULT PASS  session snapshot safety\n' | cmp -s - base.out` 逐字节一致；stderr 0 字节。
6. `bash ./scripts/check.sh --offline >offline.log 2>offline.err` → rc=0，stderr 0 字节；offline.log 末行 `RESULT PASS  aosp-harness offline quality gate`（PASS）；`rg -q 'session snapshot assurance' offline.log` 无匹配（assurance 摘要与发现 0 次）。
7. `test ! -e tests/test-session-snapshot-assurance.sh` 通过；`git status --porcelain` 0 字节（rollback checkout clean，`rb-status.log`）。
8. 删除临时目录（含 rollback clone）：`rm -rf "$tmp"`，核 `test ! -e "$tmp"` 通过；复核 implementation `git rev-parse HEAD` 仍为 ACCEPTED_HEAD、`status --porcelain` 0 字节。

## results

- rollback commit：`cf9828f28c6bc847e1737c353752cdcddfc2fd09`，exact 只删除本入口（name-status 恰一行 `D`）—— PASS；该 commit 仅存在于临时 rollback clone，已随目录删除。
- 03b 基础测试：rc=0，stdout 逐字 `RESULT PASS  session snapshot safety\n`，stderr 空 —— PASS。
- offline：rc=0，末行 PASS，`session snapshot assurance` 0 次匹配（入口发现 0 次）—— PASS。
- rollback checkout 中 `tests/test-session-snapshot-assurance.sh` 物理缺席且 clean —— PASS。
- implementation worktree 与主仓库零提交、HEAD 不变；candidate/full/depth-1 checkout 不被触碰 —— 零 delta 成立。
- rollback 临时目录已删除 —— 无残留。
- 本任务零 commit；待独立 review PASS 后由控制器追加 manifest 第 5 行并 mark 2.4。
