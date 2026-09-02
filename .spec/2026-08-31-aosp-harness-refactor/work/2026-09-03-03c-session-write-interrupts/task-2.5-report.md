# 任务 2.5 报告：验证03d顺序门

零 delta controller 验证任务——implementation worktree 与主仓库零改动、零提交；只按 R8 对下一切片的 spec 目录/work 目录/分支/worktree/ledger/dispatch/execution-base 记录做缺席核验，全部命令双流落盘。`PROJECT` 指向主仓库 `.spec/2026-08-31-aosp-harness-refactor` 绝对路径（worktree 内的 specs/work 副本是提交时旧副本，顺序门核的是主仓库现状）。

## task

- task-id: task-2.5
- 产出: signals-order-gate-v1
- 需求: R8

## base

648fe667396e6273f7d497479f16d7daf4560d18（ACCEPTED_HEAD，任务 2.1 固定；零 delta 任务 base==head）

## head

648fe667396e6273f7d497479f16d7daf4560d18

## files

- 测试 `common/.harness/lib/session-state-signals.sh`（implementation 未改动）
- 测试 `tests/test-session-signals.sh`（implementation 未改动）
- 验收资产: `$WORK/evidence/task-2.5-red.txt` / `$WORK/task-2.5-report.md` / `$WORK/evidence/task-2.5-evidence.tsv` / `$WORK/evidence/task-2.5-logs/*`

## commands

- 红阶段: `test -s "$WORK/task-2.5-report.md"` → rc1（报告缺席），六行 schema + assertion 落 `evidence/task-2.5-red.txt`
- `NEXT=03d-session-remove-prune`（日期无关规范 ID 片段；日期前缀由创建日决定，本片不预知，R8；以下命令一律经 `"$NEXT"` 间接引用）
- nullglob 前提: `shopt nullglob` → `off`；`! shopt -q nullglob` → rc0（未匹配 glob 按字面传给 `ls`，由其 rc2 经 `!` 判缺席）
- spec 目录缺席（implementation worktree 内执行）: `! ls -d "$PROJECT"/specs/*"$NEXT" 2>/dev/null` → rc0
- work 目录缺席（implementation worktree 内执行）: `! ls -d "$PROJECT"/work/*"$NEXT" 2>/dev/null` → rc0
- 分支零匹配（主仓库执行）: `test -z "$(git show-ref | rg "refs/heads/spec/.*$NEXT")"` → rc0；原始匹配转储 `branch-match.stdout` 0B
- worktree 零匹配（主仓库执行，可见全部 worktree）: `test -z "$(git worktree list --porcelain | rg "$NEXT")"` → rc0；原始匹配转储 `worktree-match.stdout` 0B
- scoped rg（主仓库限定域）: `files=$(ls "$PROJECT"/specs/*/ledger.md "$PROJECT"/work/*/dispatch.tsv "$PROJECT"/work/*/execution-base.env 2>/dev/null)`（ls 多参数单列一行，未用 `&&` 链；实收 15 个文件，见 `scoped-files.stdout`），然后 `test -z "$files" || ! rg -q "$NEXT" $files` → rc0；非 `-q` 转储 `scoped-rg.stdout` 0B（rg rc1=零匹配）；不搜 PLAN/requirements 中的合法规划文字
- review 包: worktree 内 `review-package.sh ACCEPTED_HEAD ACCEPTED_HEAD "$WORK" 2026-09-03-03c-session-write-interrupts` → rc0（与 2.1–2.4 同名同内容，重新生成）
- 事后复核: implementation `git rev-parse HEAD` 逐字等于 ACCEPTED_HEAD、`git status --porcelain` 空；主仓库 `git status --porcelain` 与事前逐字一致

## results

- nullglob: `off`，`! shopt -q nullglob` rc0 — PASS
- spec 目录缺席: `! ls -d "$PROJECT"/specs/*"$NEXT"` rc0（无匹配目录）— PASS
- work 目录缺席: `! ls -d "$PROJECT"/work/*"$NEXT"` rc0（无匹配目录）— PASS
- 分支零匹配: `refs/heads/spec/.*$NEXT` 零匹配，`test -z` rc0 — PASS
- worktree 零匹配: `git worktree list --porcelain` 中 `$NEXT` 零匹配，`test -z` rc0 — PASS
- scoped rg 零匹配: 15 个 ledger/dispatch/execution-base 限定域文件中 `$NEXT` 零匹配（rg rc1），gate `test -z "$files" || ! rg -q "$NEXT" $files` rc0 — PASS
- 红阶段: `test -s "$WORK/task-2.5-report.md"` rc1，报告缺席确认，六行 schema + assertion 已落盘 — PASS
- review 包: rc0，`review-648fe667-648fe667.md` 重新生成（106B，内容与 2.1–2.4 一致）— PASS
- git 状态不变: implementation worktree HEAD 仍为 ACCEPTED_HEAD 且 clean；主仓库 status 与事前一致 — PASS
- 本任务不产生 commit；manifest 追加、mark 2.5、ledger 锚点与 sync-ledger 为 controller 职责，本任务不执行

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/evidence/task-2.5-red.txt
