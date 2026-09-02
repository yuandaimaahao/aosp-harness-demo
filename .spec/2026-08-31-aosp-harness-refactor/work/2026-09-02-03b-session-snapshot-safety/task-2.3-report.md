# 任务 2.3 报告: 验证真实depth-1 checkout

## task

- 任务: task-2.3（spec 2026-09-02-03b-session-snapshot-safety，需求 R8）
- 范围: 只执行步骤 1–4 的实现者部分（红证据 → `git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE"` depth-1 checkout 并核 HEAD/depth/shallow → 保存四上游 SHA before、跑 default/offline 并核摘要、比较 after SHA 与 clean → green 报告与 evidence package、删除 depth-1 checkout）；步骤 4 的独立 review/manifest 行追加与步骤 5 的 mark/ledger/sync 由控制器执行
- 本任务不创建 commit、不改变 implementation worktree 的 HEAD

## base

- execution BASE: `3d15a0d76c2a2e6c8541c5d47001a55f0ca18649`（execution-base.env 的 BASE_SHA）

## head

- ACCEPTED_HEAD: `ab1e870ece16bbc24e1a86f84110366f84aae0d9`（任务 2.1 固定；implementation worktree 审计前后 HEAD 逐字等于该值且 clean）
- depth-1 checkout HEAD: `ab1e870ece16bbc24e1a86f84110366f84aae0d9`（clone 后与测试后均逐字等于 ACCEPTED_HEAD）
- depth-1 形态: `git rev-list --count HEAD` = 1，`.git/shallow` 非空（含 ACCEPTED_HEAD 一行）

## files

验证对象（depth-1 checkout 中的 tracked 文件，本任务不修改）:

- `common/.harness/lib/session-state-snapshot.sh`
- `tests/test-session-snapshot.sh`

四上游 SHA 监控文件（测试前后不变）:

- `common/.harness/lib/session-state-foundation.sh`
- `common/.harness/lib/session-state-path.sh`
- `tests/lib/session-path-race-driver.py`
- `tests/test-session-path-races.sh`

验收资产（不纳入源码文件清单）:

- 创建 `evidence/task-2.3-red.txt`
- 创建 `task-2.3-report.md`（本文件）
- 创建 `evidence/task-2.3-evidence.tsv`
- 创建 `evidence/task-2.3-logs/`（每次运行分离保存 rc/stdout/stderr）
- `review-manifest.tsv` 由控制器在独立 review PASS 后修改

## commands

红阶段证据: `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-2.3-red.txt`

步骤 1（红，日志在 `evidence/task-2.3-logs/red.*`）:
- `test -s $WORK/task-2.3-report.md` → rc1，双流空（报告缺席，红成立）
- 前置: implementation worktree HEAD = ACCEPTED_HEAD 且 `git status --porcelain` 0 行

步骤 2（depth-1 checkout，日志 `clone.*` / `depth1-head.txt` / `depth1-count.txt` / `depth1-shallow.txt`）:
- `tmp=$(mktemp -d /tmp/task-2.3-depth1.XXXXXX)`
- `git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" "$tmp/depth1"` → rc0
- `git -C "$tmp/depth1" rev-parse HEAD` 逐字等于 ACCEPTED_HEAD
- `git -C "$tmp/depth1" rev-list --count HEAD` = 1
- `test -s "$tmp/depth1/.git/shallow"` 成立（shallow marker 非空）

步骤 3（在 depth-1 中验证，日志 `default.*` / `offline.*` / `upstream-sha-{before,after}.txt` / `clean.txt` / `depth1-head-after.txt`）:
- `sha256sum` 四上游文件 → before 清单
- `bash ./tests/test-session-snapshot.sh`（default）→ rc0、stderr 0B、stdout 逐字 `RESULT PASS  session snapshot safety\n` 且摘要恰 1 次
- `bash ./scripts/check.sh --offline` → rc0、stderr 0B、stdout 中 `RESULT PASS  session snapshot safety` 恰 1 次、末行 `RESULT PASS  aosp-harness offline quality gate`
- `sha256sum` 四上游文件 → after 清单，`cmp` before/after 一致
- `git status --porcelain` 与 `git diff --stat` 均空（clean），HEAD 不变

步骤 4（本实现者部分）:
- 写本 green 报告与 `evidence/task-2.3-evidence.tsv`，删除 `$tmp`（含 depth-1 checkout）

## results

全部通过:

| 检查 | 结果 |
|---|---|
| 红: report 缺席 | rc1，双流空 ✓ |
| 前置: implementation HEAD=ACCEPTED_HEAD + clean | ✓ |
| clone --depth 1 file:// | rc0 ✓ |
| depth-1 HEAD 逐字=ACCEPTED_HEAD | ✓ |
| depth-1 `git rev-list --count HEAD` | 1 ✓ |
| depth-1 `.git/shallow` 非空 | ✓ |
| 四上游文件存在 | 4/4 ✓ |
| default | rc0，stdout 逐字 `RESULT PASS  session snapshot safety\n`（恰 1 次），stderr 0B ✓ |
| offline | rc0，snapshot 摘要恰 1 次，末行 `RESULT PASS  aosp-harness offline quality gate`，stderr 0B ✓ |
| 四上游 SHA-256 before/after | `cmp` 一致 ✓ |
| depth-1 checkout clean（status/diff） | 0B ✓ |
| depth-1 HEAD 测试后不变 | ✓ |
| depth-1 checkout 已删除 | ✓ |

测试摘要: 真实 depth-1 checkout（HEAD=ACCEPTED_HEAD、commit-count=1、shallow 非空）default rc0（固定摘要逐字）与 offline rc0（snapshot 摘要恰 1 次、末行 offline PASS）全绿，四上游 SHA 测试前后不变，checkout clean 且已删除。
