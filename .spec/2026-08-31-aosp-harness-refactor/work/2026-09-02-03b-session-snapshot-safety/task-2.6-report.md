# 任务 2.6 报告: 收敛manifest、ledger与终交付

## task

- 任务: task-2.6（spec 2026-09-02-03b-session-snapshot-safety，需求 R8、R9）
- 范围: 只执行步骤 1–2（红证据 → 汇总 candidate/full/depth-1/rollback/order 五个验证任务的日志与结论，写 green 报告与验收报告，生成 evidence package）；步骤 3–6（manifest 追加、awk 全量核验、mark/ledger/sync、终门重跑）由控制器执行
- 本任务不创建任何 commit、不改变 implementation worktree

## base

- execution BASE: `3d15a0d76c2a2e6c8541c5d47001a55f0ca18649`（execution-base.env 的 BASE_SHA）

## head

- ACCEPTED_HEAD: `ab1e870ece16bbc24e1a86f84110366f84aae0d9`（任务 2.1 固定；implementation worktree 当前 HEAD 逐字等于该值且 `git status --porcelain` 0 行，日志 `evidence/task-2.6-logs/impl-head.txt` / `impl-clean.txt`）

## files

验证对象（implementation worktree 中的 tracked 文件，本任务不修改）:

- `common/.harness/lib/session-state-snapshot.sh`
- `tests/test-session-snapshot.sh`

验收资产（不纳入源码文件清单）:

- 创建 `evidence/task-2.6-red.txt`
- 创建 `task-2.6-report.md`（本文件）
- 创建 `acceptance/acceptance-report.md`
- 创建 `evidence/task-2.6-evidence.tsv`
- 创建 `evidence/task-2.6-logs/`（红命令与前置核对日志）
- `review-manifest.tsv` 由控制器在独立 review PASS 后修改（步骤 3）

## commands

红阶段证据: `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-2.6-red.txt`

步骤 1（红，日志在 `evidence/task-2.6-logs/red.*`）:
- `test -s "$WORK/acceptance/acceptance-report.md"` → rc1，双流空（验收报告缺席，红成立）
- 前置: implementation worktree HEAD = ACCEPTED_HEAD 且 clean（`impl-head.txt` / `impl-clean.txt`）

步骤 2（汇总与报告，只读提取）:
- 逐一读取 `task-1.1-report.md`、`task-1.2-report.md`、`task-2.1-report.md`…`task-2.5-report.md` 与 `evidence/task-{1.2,2.1,2.2,2.3,2.4,2.5}-logs/`，提取各自关键证据与结论
- 读取 `review-manifest.tsv` 当前 7 行（逐字快照保存为 `evidence/task-2.6-logs/manifest-rows.txt`），核全部为 PASS
- 写本 green 报告、`acceptance/acceptance-report.md` 与 `evidence/task-2.6-evidence.tsv`

## results

全部通过:

| 检查 | 结果 |
|---|---|
| 红: acceptance 报告缺席 | rc1，双流空 ✓ |
| 前置: implementation HEAD=ACCEPTED_HEAD + clean | ✓ |
| candidate（任务 2.1） | 静态工具/版本/default/all/offline/exact2/numstat400/anchor/surface/clean 全 PASS ✓ |
| full checkout（任务 2.2） | default/offline 全绿，四上游 SHA 不变，checkout clean 且已删除 ✓ |
| depth-1 checkout（任务 2.3） | HEAD=ACCEPTED_HEAD、count=1、shallow 非空，default/offline 全绿 ✓ |
| rollback（任务 2.4） | exact 两个 D 的 rollback commit 下 03a/03a1/03a2/offline 全绿，snapshot 摘要 0 次 ✓ |
| order 顺序门（任务 2.5） | 03b1/03c 的 spec/work 目录、分支、worktree、ledger/dispatch/BASE 记录全部机械核对缺席 ✓ |
| review-manifest 当前 7 行 | 六列、seq 1–7 连续、reviewer 非空、全部 PASS ✓ |
| green 报告 / 验收报告 / evidence package | 已生成 ✓ |

测试摘要: 五个验证任务（2.1–2.5）的结论与日志汇总一致且无矛盾，验收报告 `acceptance/acceptance-report.md` 已落盘，evidence package `evidence/task-2.6-evidence.tsv` 覆盖 brief、report、验收报告与全部新日志；本任务不产生 commit，步骤 3–6 交控制器。

## fix round 1

独立 reviewer（`task-2.6-review-round-1.md`）给出 NEEDS_CHANGES（阻断 0 / 重要 1 / 次要 2）。修复范围只限 `acceptance/acceptance-report.md` 一个文件，未创建 commit、未改 implementation worktree、未碰 manifest/ledger：

1. 重要 finding（fallback 核验次数失真）: 原第 14 行声称字面 `rg -i fallback` 零匹配经 task-1.1/1.2/2.1「三次独立核验一致」。实测 task-2.1 报告全文无 `fallback` 提及、step3 无对应日志，task-1.1 做的是 `os.rename/replace/link/shutil` 模式核对而非字面 rg。已改为：字面 `rg -i fallback` 零匹配只归功 `task-1.2-report.md` 步骤 4，「无 fallback」结论另由 `task-1.1-report.md` 的模式核对支持；八 anchor 的三处核验归属保留（reviewer 实测确认 task-1.1 grep -c 表、task-1.2 rg -c、task-2.1 步骤 3 均成立）。
2. 次要 finding 1（R2/R3/R5 映射行粒度超源报告字面）: R2 行的「arity/非法 feature/path rc 表与 held capture 结构 case」、R3 行的「固定九类损坏内容、leaf 缺席 3」、R5 行的「同值 0、异值 3、并行异值恰一 0 余 3」均超出 `task-1.2-report.md` 字面粒度（该报告只泛称 case 类别编译在单次运行内并 PASS）。已改写为与源报告字面一致（「编译在单次测试运行内、3 次重复全 rc0」），并标注「具体粒度以测试 blob 为准，源报告未逐项列举」。
3. 次要 finding 2（signal 段机制句与实证句混排）: 原第 15 行把仅 design 出处的机制句（handler 先于 temp 安装、first_signal 锁存、ownership 转移、cleanup 不遮蔽 129/130/143）与测试实证句连排。已拆为「机制约定（design 契约）」与「本片基础测试实证（覆盖 PID 与首信号锁存子集）」两段显式区分。

修复后重新生成 `evidence/task-2.6-evidence.tsv`，三列 sha256/bytes 与当前文件逐行一致。
