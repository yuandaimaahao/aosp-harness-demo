# 任务 2.5 报告：验证 03c 顺序门

## task

- task-2.5：对规范 ID `2026-09-02-03c-session-write-interrupts`（NEXT）机械核对 R10 顺序门——在 03b1 accepted 且 dependency-present 完整矩阵入 ledger 之前，03c 的四类资产（spec 目录、`spec/$NEXT` 分支、worktree、ledger execution BASE / dispatch 记录）必须物理缺席；本任务只做零 delta 验证，implementation worktree 与主仓库零提交，不触碰 manifest、ledger 与 tasks。
- 红阶段证据:
.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/evidence/task-2.5-red.txt
  - 红阶段记录内容：`test -s "$WORK/task-2.5-report.md"` 在报告缺席时 rc=1，双流为空。

## base

- ACCEPTED_HEAD = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`（任务 2.1 固定；execution BASE 为 `8a164f212c398a95703a38fb919af2b31c6e1662`，见 `WORK/execution-base.env`）。

## head

- implementation HEAD = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`（`impl-head.txt`），验证前后不变且 clean（`impl-status.log` 0 字节）。
- 零 delta 成立：本任务只做只读核对，implementation worktree 与主仓库零提交、HEAD 不变。

## files

- 验证对象：03c 顺序门四类资产的物理缺席（`$PROJECT/specs/$NEXT`、`$PROJECT/work/$NEXT`、`refs/heads/spec/$NEXT`、全仓 ledger/dispatch/execution-base 中的 `$NEXT` 记录）。
- 本任务产出（验收资产，不纳入源码）：
  - `task-2.5-report.md`（本报告）
  - `evidence/task-2.5-red.txt`（红阶段证据，六行 schema + assertion）
  - `evidence/task-2.5-logs/`（全部运行日志）
  - `evidence/task-2.5-evidence.tsv`（三列 evidence 清单）

## commands

固定变量：`NEXT=2026-09-02-03c-session-write-interrupts`，git 命令在 implementation worktree（`WORK/worktree`）运行。

1. 红阶段：`test -s "$WORK/task-2.5-report.md"` → rc=1（报告缺席），写 red 文件并核 `test -s` 通过（`red.stdout`/`red.stderr` 均 0 字节）。
2. `test ! -e "$PROJECT/specs/$NEXT"` 与 `test ! -e "$PROJECT/work/$NEXT"` → rc=0；补核 `test ! -L`（dangling symlink 亦缺席）→ rc=0。
3. `git show-ref --verify --quiet "refs/heads/spec/$NEXT"` → rc=1（分支 ref 缺席）。
4. `git worktree list --porcelain >worktree-list.log`；`rg -c "branch refs/heads/spec/$NEXT" worktree-list.log` → rc=1（无匹配）；`rg -c "$PROJECT/work/$NEXT" worktree-list.log` → rc=1（约定 worktree 绝对路径无匹配）。
5. `files=$(ls "$PROJECT"/specs/*/ledger.md "$PROJECT"/work/*/dispatch.tsv "$PROJECT"/work/*/execution-base.env 2>/dev/null)` 收集存在文件 13 个（8 个 ledger.md + 5 个 execution-base.env，无 dispatch.tsv，`rg-file-list.txt`），`ls` 未与后续命令 `&&` 链接；`rg -n "dispatch.*$NEXT|execution BASE.*$NEXT|spec/$NEXT" $files` → rc=1（零匹配，`rg-forbidden.log` 0 字节）；未搜索 PLAN/requirements 中的合法规划文字。
6. 基线复核：`git -C "$WORK/worktree" rev-parse HEAD` = ACCEPTED_HEAD；`git status --porcelain` 0 字节（`impl-status.log`）。

## results

- `$PROJECT/specs/$NEXT` 与 `$PROJECT/work/$NEXT` 物理缺席（`test ! -e` 与 `test ! -L` 均通过）—— PASS。
- `refs/heads/spec/$NEXT` 缺席（`show-ref --verify --quiet` rc=1）—— PASS。
- `git worktree list --porcelain` 不含 `branch refs/heads/spec/$NEXT` 及约定 worktree 绝对路径 `$PROJECT/work/$NEXT` —— PASS。
- 全仓 13 个存在的 ledger/dispatch/execution-base 文件中，`dispatch.*$NEXT`、`execution BASE.*$NEXT`、`spec/$NEXT` 三类记录零匹配 —— PASS；03c 的 ledger execution BASE 与 dispatch 记录自然缺席。
- implementation worktree 与主仓库零提交、HEAD 不变且 clean —— 零 delta 成立。
- 03c 顺序门四类资产全部机械核对缺席 —— PASS。
- 本任务零 commit；待独立 review PASS 后由控制器追加 manifest 第 6 行并 mark 2.5。
