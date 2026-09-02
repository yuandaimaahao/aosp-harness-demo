# 任务 2.2 报告：验证完整历史 checkout

零 delta controller 验证任务——不改源码、不产生提交；只在 mktemp 临时目录内 `git clone --no-local` 完整历史 checkout，运行 default 入口与 offline 质量门，核上游七文件 SHA 与 clean，用后删除。

## task

- task-id: task-2.2
- 产出: signals-full-checkout-v1
- 需求: R7

## base

648fe667396e6273f7d497479f16d7daf4560d18（ACCEPTED_HEAD，任务 2.1 固定；零 delta 任务 base==head）

## head

648fe667396e6273f7d497479f16d7daf4560d18

## files

- 测试 `common/.harness/lib/session-state-signals.sh`（未改动）
- 测试 `tests/test-session-signals.sh`（未改动）
- 验收资产: `$WORK/evidence/task-2.2-red.txt` / `$WORK/task-2.2-report.md` / `$WORK/evidence/task-2.2-evidence.tsv` / `$WORK/evidence/task-2.2-logs/*`

## commands

- 红阶段: `test -s "$WORK/task-2.2-report.md"` → rc1（报告缺席），六行 schema + assertion 落 `evidence/task-2.2-red.txt`
- implementation worktree 核对: `git rev-parse HEAD` 逐字等于 ACCEPTED_HEAD，`git status --porcelain` 空
- `tmp=$(mktemp -d)`; `git clone --no-local "$IMPLEMENTATION_WORKTREE" "$tmp/full"` → rc0；full 的 `git rev-parse HEAD` 逐字等于 ACCEPTED_HEAD
- full 内: `sha256sum $UPSTREAM7 >"$tmp/before.sha"`（before SHA 保存）
- full 内: `bash ./tests/test-session-signals.sh` → `full-default.{stdout,stderr}`
- full 内: `bash ./scripts/check.sh --offline` → `full-offline.{stdout,stderr}`
- 断言: `printf 'RESULT PASS  session write interrupts\n' | cmp -s - full-default.stdout`；`test ! -s full-default.stderr`；`test "$(rg -c 'RESULT PASS  session write interrupts' full-offline.stdout)" = 1"`；offline 末行 `RESULT PASS  aosp-harness offline quality gate`（与任务 2.1 同口径）
- `sha256sum -c "$tmp/before.sha"`（after SHA 不变）；`git status --porcelain` 与 `git diff` 均空
- review 包: worktree 内 `review-package.sh ACCEPTED_HEAD ACCEPTED_HEAD "$WORK" 2026-09-03-03c-session-write-interrupts`
- 删除 full checkout 与临时目录后，复核 implementation worktree HEAD 未变且 clean

## results

- clone HEAD: `648fe667396e6273f7d497479f16d7daf4560d18` 逐字等于 ACCEPTED_HEAD — PASS
- default 入口: rc0、stderr 0B、stdout 逐字 `RESULT PASS  session write interrupts\n`（cmp -s）— PASS
- offline: rc0、stderr 0B、本入口摘要 `RESULT PASS  session write interrupts` 恰出现 1 次（自动发现恰一次）、末行 `RESULT PASS  aosp-harness offline quality gate` — PASS
- 上游七 tracked 文件 SHA-256 测试前后不变（`sha256sum -c` 全 OK）— PASS
- full checkout `git status --porcelain` 与 `git diff` 均空 — PASS
- 测试运行后 full 内无残留；full checkout 与临时目录已删除
- implementation worktree 复核: HEAD 仍为 ACCEPTED_HEAD、clean — PASS
- 本任务不产生 commit；manifest/mark/ledger 为 controller 职责，本任务不执行

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/evidence/task-2.2-red.txt
