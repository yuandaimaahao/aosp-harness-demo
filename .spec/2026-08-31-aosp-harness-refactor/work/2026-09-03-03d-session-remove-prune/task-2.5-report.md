# task-2.5 报告：验证03e顺序门

task: task-2.5
base: 388a83d5816659428e510bd9540d2a88cc2613e7（ACCEPTED_HEAD，零 delta 任务不改变 HEAD）
head: 388a83d5816659428e510bd9540d2a88cc2613e7
files: 无源码改动（零 delta controller 验证任务）

红阶段证据: .spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-2.5-red.txt

## commands

NEXT 按步骤 2 定义为 PLAN 第 54 行 03e 片的日期无关规范 ID 片段（日期前缀由创建日决定，本片不预知，R11）；本报告与日志一律以 `"$NEXT"` 间接形式记录、不内联字面全名（裁定 6）。

1. `test ! -s task-2.5-report.md` → rc0（红：报告缺席）。
2. 前提 `shopt -u nullglob`（nullglob off）；`! ls -d "$PROJECT"/specs/*"$NEXT" 2>/dev/null` → spec 目录缺席；`! ls -d "$PROJECT"/work/*"$NEXT" 2>/dev/null` → work 目录缺席。
3. `test -z "$(git show-ref | rg "refs/heads/spec/.*$NEXT")"` → 分支零匹配；`test -z "$(git worktree list --porcelain | rg "$NEXT")"` → worktree 零匹配。
4. scoped rg：`files=$(ls "$PROJECT"/specs/*/ledger.md "$PROJECT"/work/*/dispatch.tsv "$PROJECT"/work/*/execution-base.env 2>/dev/null)`（多参数单列，未用 `&&` 链——ls 部分 glob 无匹配 rc2 属预期，首次执行曾误用 && 链断链，已按 tasks 警告分步重跑）；scoped 文件 17 个（10 份 ledger.md + 7 份 execution-base.env，dispatch.tsv 类零个）；`rg -l "$NEXT" $files` rc=1 零匹配。
5. PLAN/requirements/design/tasks/brief 中的合法规划文字不在搜索域内（裁定 6 豁免）。

日志：evidence/task-2.5-logs/order-gate.log（五门逐条记录，间接形式）。

## results

03e 顺序门五门机械核对全过：spec 目录/work 目录/分支/worktree/ledger+dispatch+execution-base 记录五类资产全部缺席或零匹配。03e 全部资产在本片验收前物理缺席，顺序边界成立。未改变任何 checkout 的 HEAD。
