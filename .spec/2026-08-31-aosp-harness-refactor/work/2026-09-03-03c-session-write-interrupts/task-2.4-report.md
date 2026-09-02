# 任务 2.4 报告：验证 exact rollback

零 delta controller 验证任务——implementation worktree 零改动、零提交；只在 mktemp 临时目录内 `git clone --no-local "$IMPLEMENTATION_WORKTREE"` 的一次性 rollback clone 上提交一个 exact 只删本片两文件的 rollback commit，验证删除后 03b/03b1 测试与 offline 质量门全绿、本入口发现 0 次，用后删除；rollback commit 不 push、不落任何真实分支。

## task

- task-id: task-2.4
- 产出: signals-rollback-v1
- 需求: R8

## base

648fe667396e6273f7d497479f16d7daf4560d18（ACCEPTED_HEAD，任务 2.1 固定；零 delta 任务 base==head）

## head

648fe667396e6273f7d497479f16d7daf4560d18

## files

- 测试 `common/.harness/lib/session-state-signals.sh`（implementation 未改动；rollback clone 内删除）
- 测试 `tests/test-session-signals.sh`（implementation 未改动；rollback clone 内删除）
- 验收资产: `$WORK/evidence/task-2.4-red.txt` / `$WORK/task-2.4-report.md` / `$WORK/evidence/task-2.4-evidence.tsv` / `$WORK/evidence/task-2.4-logs/*`

## commands

- 红阶段: `test -s "$WORK/task-2.4-report.md"` → rc1（报告缺席），六行 schema + assertion 落 `evidence/task-2.4-red.txt`
- implementation worktree 核对: `git rev-parse HEAD` 逐字等于 ACCEPTED_HEAD，`git status --porcelain` 空
- `tmp=$(mktemp -d)`; `git clone --no-local "$IMPLEMENTATION_WORKTREE" "$tmp/rollback"` → rc0；rollback 的 `git rev-parse HEAD` 逐字等于 ACCEPTED_HEAD
- rollback 内: `git rm common/.harness/lib/session-state-signals.sh tests/test-session-signals.sh` → rc0；`git commit -m "revert(session): remove write interrupt signal slice"` → 普通 rollback commit（b6ecfddfa63ba105439d5b471e643102268eb068，仅存在于 mktemp clone 内）
- 断言: `printf 'D\tcommon/.harness/lib/session-state-signals.sh\nD\ttests/test-session-signals.sh\n' | cmp -s - <(git diff --name-status HEAD~1 HEAD)`（exact 只删本片两文件）
- rollback 内: `bash tests/test-session-snapshot.sh` → `snapshot.{stdout,stderr}`（03b 基础测试）
- rollback 内: `bash tests/test-session-snapshot-assurance.sh` → `assurance.{stdout,stderr}`（03b1 assurance 入口）
- rollback 内: `bash ./scripts/check.sh --offline` → `offline.{stdout,stderr}`
- 断言: `printf 'RESULT PASS  session snapshot safety\n' | cmp -s - snapshot.stdout`；`printf 'RESULT PASS  session snapshot assurance\n' | cmp -s - assurance.stdout`；offline `! rg -q 'session write interrupts'`（本入口发现 0 次）、末行 `RESULT PASS  aosp-harness offline quality gate`
- 断言: `test ! -e common/.harness/lib/session-state-signals.sh`、`test ! -e tests/test-session-signals.sh`、`git status --porcelain` 空
- review 包: worktree 内 `review-package.sh ACCEPTED_HEAD ACCEPTED_HEAD "$WORK" 2026-09-03-03c-session-write-interrupts`（与 2.1/2.2/2.3 同名同内容，重新生成）
- 删除 rollback clone 与临时目录后，复核 implementation worktree HEAD 未变且 clean；candidate/full/depth-1 checkout 不被触碰

## results

- clone: rc0；rollback HEAD `648fe667396e6273f7d497479f16d7daf4560d18` 逐字等于 ACCEPTED_HEAD — PASS
- rollback commit: `git rm` rc0、commit rc0；`git diff --name-status HEAD~1 HEAD` 恰为两行 `D	common/.harness/lib/session-state-signals.sh` 与 `D	tests/test-session-signals.sh`（cmp -s，exact 只删本片两文件）— PASS
- 03b 基础测试: rc0、stderr 0B、stdout 逐字 `RESULT PASS  session snapshot safety\n`（cmp -s）— PASS
- 03b1 assurance 入口: rc0、stderr 0B、stdout 逐字 `RESULT PASS  session snapshot assurance\n`（cmp -s）— PASS
- offline: rc0、stderr 0B、`session write interrupts` 出现 0 次（本入口发现 0 次）、末行 `RESULT PASS  aosp-harness offline quality gate` — PASS
- 两文件缺席: `test ! -e common/.harness/lib/session-state-signals.sh` 与 `test ! -e tests/test-session-signals.sh` 均成立 — PASS
- rollback checkout `git status --porcelain` 空 — PASS
- rollback clone 与临时目录已删除；rollback commit 未 push、未落任何真实分支
- implementation worktree 复核: HEAD 仍为 ACCEPTED_HEAD、clean — PASS
- 本任务不产生 commit；manifest/mark/ledger 为 controller 职责，本任务不执行

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/evidence/task-2.4-red.txt
