# 任务 2.3 报告：验证 exact rollback

## 摘要

从 `ACCEPTED_HEAD=5b2e66b3be9079aa31b4b6eba2da88888a3aaeba` 在隔离临时 `git clone --no-local` checkout（`$tmp/rollback`，未使用 `--local`，物理独立于 implementation worktree）中构造 exact rollback commit：`git rm` 两个新增交付文件（`session-end.sh`、`tests/test-claude-session-lifecycle.sh`），`git checkout "$BASE_SHA" --` 恢复四个修改交付文件到 execution BASE（`cc04996e1e405c00e16be3b57d3ef62d90cd7fd1`）版本，提交单个普通 revert commit `6a737f489c98e0c8fdbe0d380e9846a2908ac6df`。核对：`git diff --name-status HEAD~1 HEAD` 恰六行（两 `D`、四 `M`），路径逐字等于 `EXACT6`；`git diff "$BASE_SHA" HEAD` 为空（rollback 后六文件状态与 execution BASE 逐字节一致）。在该 clean checkout 中运行 03b 基础测试、03b1 assurance、03c signals、03d provider 四入口与 `scripts/check.sh --offline`，全部固定摘要逐字 PASS；offline 中本入口（`claude session lifecycle`）发现 0 次；两新增交付文件在 rollback 后物理缺席；checkout `git status --porcelain` 为空。验证完毕后删除整个 `$tmp`（含 rollback checkout）。全程未修改 implementation worktree 源码或 HEAD：`git -C worktree rev-parse HEAD` 前后均为 `ACCEPTED_HEAD`，`git status --porcelain` 前后均为空。candidate/full/depth-1（任务 2.1/2.2 使用的临时 checkout）未被触碰、也未新建。

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03e-claude-session-lifecycle/evidence/task-2.3-red.txt

## task

- task-id: task-2.3
- 消费: claude-lifecycle-checkout-v1（任务 2.2 产出）
- 产出: claude-lifecycle-rollback-v1
- 需求: R10
- 本任务不修改 implementation worktree 源码、不改变其 HEAD；rollback 只发生在隔离临时 clone 内

## base / head

- ACCEPTED_HEAD（implementation worktree HEAD，全程未变）: `5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`
- BASE_SHA（execution BASE，rollback 目标版本）: `cc04996e1e405c00e16be3b57d3ef62d90cd7fd1`
- rollback checkout 的 clone HEAD（回退前）: `5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`（逐字等于 ACCEPTED_HEAD）
- rollback commit SHA（回退后，仅存在于已删除的临时 clone 中）: `6a737f489c98e0c8fdbe0d380e9846a2908ac6df`

## files

验证对象（EXACT6，本片交付六文件，rollback 只在临时 clone 内回退，不改动 implementation worktree）:

```
claude-code/features/.harness/hooks/check-branch-drift.sh
claude-code/features/.harness/hooks/load-feature.sh
claude-code/features/.harness/hooks/session-end.sh
claude-code/features/.harness/settings.json
claude-code/run-demo.sh
tests/test-claude-session-lifecycle.sh
```

验收资产（不纳入源码文件清单）:

- 创建 `evidence/task-2.3-red.txt`
- 创建 `task-2.3-report.md`（本文件）
- `review-manifest.tsv` 由 controller 在独立 review PASS 后追加第 6 行（本任务不执行）

## commands

步骤 1（红，bash）:

- `test -s "$WORK/task-2.3-report.md"` → rc=1（报告缺席，双流空），红成立。
- 前置核对：`git -C "$IMPLEMENTATION_WORKTREE" rev-parse HEAD` 逐字等于 `ACCEPTED_HEAD`；`git status --porcelain` 0 行（clean）。

步骤 2（构造隔离 rollback commit，bash）:

- `tmp=$(mktemp -d)`；`git clone --no-local "$IMPLEMENTATION_WORKTREE" "$tmp/rollback"` → rc0。
- `git -C "$tmp/rollback" rev-parse HEAD` 逐字等于 `ACCEPTED_HEAD`。
- 在 `$tmp/rollback` 内：
  - `git rm claude-code/features/.harness/hooks/session-end.sh tests/test-claude-session-lifecycle.sh`（删两新增）。
  - `git checkout "$BASE_SHA" -- claude-code/features/.harness/hooks/load-feature.sh claude-code/features/.harness/hooks/check-branch-drift.sh claude-code/features/.harness/settings.json claude-code/run-demo.sh`（恢复四修改文件到 execution BASE 版本）。
  - `git commit -m "revert: roll back 03e claude session lifecycle to execution BASE"` → 普通 rollback commit `6a737f489c98e0c8fdbe0d380e9846a2908ac6df`（parent = `5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`）。
- 核对：`git diff --name-status HEAD~1 HEAD` 恰六行（`M check-branch-drift.sh` / `M load-feature.sh` / `D session-end.sh` / `M settings.json` / `M run-demo.sh` / `D test-claude-session-lifecycle.sh`），排序后路径集合逐字等于 `EXACT6`。
- 核对：`git diff "$BASE_SHA" HEAD` 输出 0 字节（rollback 后六文件与 execution BASE 逐字节一致；本片非 03d「全 D」口径）。

步骤 3（在 rollback checkout 内运行五入口，日志落 `$tmp/rollback-*.log`）:

- `bash tests/test-session-snapshot.sh >"$tmp/rollback-snapshot.log" 2>"$tmp/rollback-snapshot.err"` → rc0，stdout 逐字 `RESULT PASS  session snapshot safety`，stderr 0 字节。
- `bash tests/test-session-snapshot-assurance.sh >"$tmp/rollback-assurance.log" 2>"$tmp/rollback-assurance.err"` → rc0，stdout 逐字 `RESULT PASS  session snapshot assurance`，stderr 0 字节。
- `bash tests/test-session-signals.sh >"$tmp/rollback-signals.log" 2>"$tmp/rollback-signals.err"` → rc0，stdout 逐字 `RESULT PASS  session write interrupts`，stderr 0 字节。
- `bash tests/test-session-state.sh >"$tmp/rollback-state.log" 2>"$tmp/rollback-state.err"` → rc0，stdout 逐字 `RESULT PASS  session state`，stderr 0 字节。
- `bash ./scripts/check.sh --offline >"$tmp/rollback-offline.log" 2>"$tmp/rollback-offline.err"` → rc0，stderr 0 字节；末行 `RESULT PASS  aosp-harness offline quality gate`；`rg -c 'RESULT PASS  claude session lifecycle$' "$tmp/rollback-offline.log"` 结果为 0（本入口发现 0 次，rg 无匹配返回非零，等价空计数）。
- `test ! -e claude-code/features/.harness/hooks/session-end.sh` → 通过（新增文件缺席）。
- `test ! -e tests/test-claude-session-lifecycle.sh` → 通过（新增文件缺席）。
- `git status --porcelain` → 0 行（clean）。
- candidate/full/depth-1（任务 2.1/2.2 使用的临时 checkout）本任务全程未创建、未触碰。

步骤 4（收尾）:

- 写本 green 报告；`rm -rf "$tmp"`（含 rollback checkout 与其余日志的所在临时目录已在写报告前完成读取归档，随后一并删除，`$tmp` 不再存在）。
- implementation worktree 复核：`git -C "$IMPLEMENTATION_WORKTREE" rev-parse HEAD` 仍为 `5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`（未变）；`git status --porcelain` 仍为 0 行（clean）。

## results

| 检查 | 结果 |
|---|---|
| 红：report 缺席 | rc1，双流空 ✓ |
| 前置：implementation HEAD=ACCEPTED_HEAD + clean | ✓ |
| clone --no-local，clone HEAD 逐字=ACCEPTED_HEAD | ✓ |
| `git rm` 两新增 + `git checkout BASE_SHA --` 四修改 + 单 rollback commit | ✓（commit `6a737f489c98e0c8fdbe0d380e9846a2908ac6df`） |
| `git diff --name-status HEAD~1 HEAD` 恰六行（2 D + 4 M），路径=EXACT6 | ✓ |
| `git diff "$BASE_SHA" HEAD` 为空 | ✓（0 字节） |
| `tests/test-session-snapshot.sh` | rc0，逐字 `RESULT PASS  session snapshot safety`，stderr 0B ✓ |
| `tests/test-session-snapshot-assurance.sh` | rc0，逐字 `RESULT PASS  session snapshot assurance`，stderr 0B ✓ |
| `tests/test-session-signals.sh` | rc0，逐字 `RESULT PASS  session write interrupts`，stderr 0B ✓ |
| `tests/test-session-state.sh` | rc0，逐字 `RESULT PASS  session state`，stderr 0B ✓ |
| `scripts/check.sh --offline` | rc0，stderr 0B，末行 offline PASS，本入口发现 0 次 ✓ |
| 两新增文件缺席 | `session-end.sh` 与 `test-claude-session-lifecycle.sh` 均 `test ! -e` 通过 ✓ |
| rollback checkout clean | `git status --porcelain` 0 行 ✓ |
| candidate/full/depth-1 未被触碰 | 本任务未创建/未访问该三类 checkout ✓ |
| rollback checkout 与 `$tmp` 已删除 | `rm -rf "$tmp"` 后确认不存在 ✓ |
| implementation worktree HEAD/porcelain 前后不变 | HEAD=`5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`，porcelain 0 行，全程未写入 ✓ |

测试摘要: rollback checkout 中 03b/03b1/03c/03d 四入口固定摘要逐字 PASS、stderr 均 0 字节，`scripts/check.sh --offline` rc0 且本入口（`claude session lifecycle`）发现 0 次、末行 offline PASS；exact rollback name-status 六行（2D+4M=EXACT6）且对 BASE_SHA 的 diff 为空；两新增文件缺席、checkout clean；rollback checkout 用后已删除；implementation worktree 全程未被写入、HEAD 未变。

## Status

DONE
