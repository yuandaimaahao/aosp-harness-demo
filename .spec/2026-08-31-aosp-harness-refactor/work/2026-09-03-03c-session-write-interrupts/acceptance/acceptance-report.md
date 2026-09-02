# 03c session-write-interrupts 验收报告

- spec: 2026-09-03-03c-session-write-interrupts
- 终交付锚点: `session-signals-facade-v1`
- execution BASE: `c9c82264b3f819a6a6449a0242e102e97b35c3b0`
- accepted HEAD: `648fe667396e6273f7d497479f16d7daf4560d18`（任务 1.2 交付、任务 2.1 审计后固定）

## 交付物

- `common/.harness/lib/session-state-signals.sh`（45 行，任务 1.1，commit `a8d3859f639eed64b0d1e74eb1461c8e32e64a45`）：source-inert 的信号转发 facade，唯一私有 export `_harness_session_write_with_signals`；依赖三 snapshot export 任一缺席时静默 rc0、双流空、signals export 缺席。
- `tests/test-session-signals.sh`（325 行，任务 1.2，commit `648fe667396e6273f7d497479f16d7daf4560d18`，amend 单提交）：默认发现信号矩阵测试，只接受无参数/`all`/`--dependency-absent`。

## active 摘要与 checks 口径

- dependency-present default：rc0、stdout 逐字节等于固定摘要 `RESULT PASS  session write interrupts\n`（`cmp -s` 通过）、stderr 0B。
- dependency-present all：同上，stdout 与 default 逐字一致。
- checks 计数口径：计数探针（末处 printf 前插 `checks=%d`）default 与 all 的 err 逐字一致，均为 `checks=139`（N=139>0）；本片 dependency-present 完整矩阵口径 checks=139。
- provider-absent 三态（无参数/all/`--dependency-absent`）：同一 inert 摘要、checks=0；export 缺席抽查同为 inert。
- argv 非法表：`--bogus` / `all extra` / `--dependency-absent=x` 均 rc1 且不打印 PASS。

## 双 anchor 注入机制

- 测试经 `SIGNALS_MODULE` 环境变量注入 facade probe 副本（照 03b `SNAPSHOT_CORE` 先例），不改已提交模块；probe 在模块两个测试 marker（spawn 前 `HARNESS_TEST_MARKER_SIGNALS_BEFORE_SPAWN` 与 wait 后 `HARNESS_TEST_MARKER_SIGNALS_AFTER_WAIT`）处包装，构成 BEFORE_SPAWN/AFTER_WAIT 双 anchor 观测面。
- 任务 1.2 review round1 F1 修复后：gap probe 副本把模块行 31 spawn-gap 补转发语句文本包装落前向观测日志（`HARNESS_REFORWARD_LOG`，与双 anchor 注入同模式）；gap 行 driver 轮询放行存活 child，timeout 降为纯兜底，消除对正确模块的间歇 hang 假红。flake 实证：修复后 default 连跑 10 次、all 连跑 10 次，20 次全部 rc0、stdout 逐字固定摘要、stderr 0B。

## 两 mutant 自反证（红阶段活性证明）

- mutant-a（删 spawn-gap 补转发行）：确定性 rc1 无 PASS；失败签名为 3 个 gap 行各 2 项前向观测 FAIL（reforward 观测缺失：signal want=HUP|INT|TERM got=missing、pid numeric want=yes got=no），无 hang、无 timeout 124。
- mutant-b（trap 体去 first-signal-wins 守卫，锁存被第二信号覆盖）：确定性 rc1 无 PASS；12 行第二信号锁存核对全 FAIL（HUP→143、INT→143、TERM→129）。
- 两 mutant 均 mktemp 副本注入，未改已提交模块。

## exact2/400

- `git diff --name-only $BASE_SHA $ACCEPTED_HEAD` 恰为 `common/.harness/lib/session-state-signals.sh` 与 `tests/test-session-signals.sh` 两文件。
- `git diff --numstat $BASE_SHA $ACCEPTED_HEAD` 总和 370 ≤ 400。
- 上游七文件范围 diff 为空；`git diff --check` rc0；worktree clean。

## 五路验证结论

1. candidate（任务 2.1）：工具版本逐字核 shfmt `v3.14.0` / ShellCheck version field `0.11.0` 后，只对 exact 两文件跑 shfmt/shellcheck/bash -n/`git diff --check` 全过；default 摘要逐字 `RESULT PASS  session write interrupts\n`；offline 本入口自动发现恰 1 次、末行 PASS；上游七 tracked 文件 SHA-256 测试前后不变。PASS。
2. full checkout（任务 2.2）：`git clone --no-local` 完整历史 checkout，HEAD 逐字等于 ACCEPTED_HEAD；default 摘要逐字一致、offline 发现恰 1 次末行 PASS、上游七文件 SHA 不变、status/diff clean。PASS。
3. depth-1 checkout（任务 2.3）：`git clone --depth 1 file://...` 真实浅克隆，`git rev-list --count HEAD`=1、`.git/shallow` 非空；default 摘要逐字一致、offline 发现恰 1 次末行 PASS、上游七文件 SHA 不变、clean。PASS。
4. exact rollback（任务 2.4）：一次性 clone 内 rollback commit 恰为两行 `D`（只删本片两文件）；03b 基础测试逐字 `RESULT PASS  session snapshot safety`、03b1 assurance 入口逐字 `RESULT PASS  session snapshot assurance`、offline 本入口发现 0 次且末行 PASS；rollback commit 不 push、不落真实分支；candidate/full/depth-1 checkout 不被触碰。PASS。
5. 03d 顺序门（任务 2.5）：nullglob off 前提下，下一切片 spec 目录/work 目录缺席、spec 分支零匹配、worktree 零匹配、ledger/dispatch/execution-base 共 15 个限定域文件 scoped rg 零匹配——dependency-present active 证据、exact2/400 与全 PASS manifest 入 ledger 前下一切片资产物理缺席成立。PASS。

## 逐任务 review

- review manifest 七行（task-1.1、1.2、2.1–2.5）全部 reviewer 非空且 PASS；任务 1.2 经两轮独立 review（round1 F1 修复后全新 reviewer re-review PASS）。
- 本报告与 evidence package 交全新独立 agent review；PASS 后由 controller 追加 manifest 第 8 行（task-2.6）、awk 全量核验、mark 2.6、写 ledger 完成锚点并重跑终门（含 03d 顺序门复核）。

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/evidence/task-2.6-red.txt
