# 任务 2.1 报告：审计 candidate 并固定 accepted HEAD

## task

- task-2.1：审计 candidate worktree（`WORK/worktree`，分支 `spec/2026-09-02-03b1-session-snapshot-assurance`），在任务 1.1 的 accepted head `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a` 上跑 R9 candidate 验证；零 delta——本任务不产生任何 commit，TASK_HEAD 保持不变。
- 红阶段证据: .spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/evidence/task-2.1-red.txt
  - 红阶段记录内容：`test -s "$WORK/task-2.1-report.md"` 在报告缺席时 rc=1，双流为空。

## base

- BASE_SHA（execution BASE）= `8a164f212c398a95703a38fb919af2b31c6e1662`（`WORK/execution-base.env`，任务 1.1 提交前的 clean HEAD）。

## head

- TASK_HEAD = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`（任务 1.1 提交 `test(session): add snapshot assurance matrix`）。
- 验证前后 `git rev-parse HEAD` 均为该值，`git status --porcelain` 为空——零 delta 成立。

## files

- 验证对象：`tests/test-session-snapshot-assurance.sh`（BASE..HEAD exact 唯一新增文件，numstat 总和 346 ≤ 400）。
- 本任务产出（验收资产，不纳入源码）：
  - `task-2.1-report.md`（本报告）
  - `evidence/task-2.1-red.txt`（红阶段证据，六行 schema + assertion）
  - `evidence/task-2.1-logs/`（全部运行日志）
  - `evidence/task-2.1-evidence.tsv`（三列 evidence 清单）

## commands

均在 candidate worktree 内执行；固定工具目录 `…/scratchpad/tools/bin` 前置 PATH：

1. 红阶段：`test -s "$WORK/task-2.1-report.md"` → rc=1（报告缺席），写 red 文件并核 `test -s` 通过。
2. `git rev-parse HEAD` = TASK_HEAD；`git status --porcelain` 为空（implementation clean）。
3. 六上游文件 before SHA：`sha256sum common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh tests/lib/session-path-race-driver.py tests/test-session-path-races.sh common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh` → `upstream-before.sha256`。
4. 固定工具版本：`test "$(shfmt --version)" = "v3.14.0"` 通过；`shellcheck --version | rg -q '^version: 0.11.0$'` 通过（日志 `tool-versions.log`）。
5. exact 单文件静态检查：`shfmt -d -i 2 -ci -bn tests/test-session-snapshot-assurance.sh`（rc=0，输出 0 字节）、`shellcheck -x --severity=warning`（rc=0）、`bash -n`（rc=0）。
6. 主验证命令：`bash ./tests/test-session-snapshot-assurance.sh >default.out 2>default.err` → rc=0；`printf 'RESULT PASS  session snapshot assurance\n' | cmp -s - default.out` 逐字节一致；stderr 0 字节。
7. `bash ./scripts/check.sh --offline >offline.log 2>offline.err` → rc=0，stderr 0 字节；`rg -c 'RESULT PASS  session snapshot assurance' offline.log` = 1（自动发现本入口恰好一次）；offline.log 末行 `RESULT PASS  aosp-harness offline quality gate`（PASS）。
8. after SHA：`sha256sum -c upstream-before.sha256` → 六文件全部 OK（测试前后不变，见 `upstream-after-check.log`）。
9. `git diff --name-only "$BASE_SHA" HEAD` 恰为 `tests/test-session-snapshot-assurance.sh`；`git diff --numstat` 总和 346 ≤ 400；`git diff --check` rc=0；`git status --porcelain` 为空。

## results

- default 入口：rc=0，stdout 逐字 `RESULT PASS  session snapshot assurance\n`，stderr 空 —— PASS。
- offline：rc=0，本入口自动发现恰好 1 次，末行 PASS —— PASS。
- 静态：shfmt v3.14.0 `-d -i 2 -ci -bn` 无 diff、ShellCheck 0.11.0 rc0、`bash -n` rc0、`git diff --check` rc0 —— 全绿。
- 六上游 tracked 文件 SHA-256 测试前后不变 —— 不变量保持。
- BASE..HEAD exact 只新增 `tests/test-session-snapshot-assurance.sh`（346 行 ≤ 400），worktree clean，HEAD=c7a18ed 未变 —— 零 delta。
- 建议固定 ACCEPTED_HEAD = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`（待独立 review PASS 后由控制器固定并写 manifest/ledger）。
