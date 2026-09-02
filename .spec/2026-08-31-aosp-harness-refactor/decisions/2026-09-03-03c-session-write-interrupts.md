# 2026-09-03-03c-session-write-interrupts 验收归档

## 改了什么

新增 exact 两文件（BASE `c9c82264b3f819a6a6449a0242e102e97b35c3b0` → accepted HEAD `648fe667396e6273f7d497479f16d7daf4560d18`，45+325=370 行 ≤400）：

- `common/.harness/lib/session-state-signals.sh`（45 行）：source-inert 的信号转发 facade。source 守卫逐一 `declare -F` 验证 03b 三个 snapshot export，任一缺席静默返回 0、零定义、双流空；齐全则定义唯一私有 export `_harness_session_write_with_signals <project-id> <session-id> <feature>`——`pending_signal/child_pid/child_rc` 三 local 状态机，三条 inline trap 各自 first-signal-wins 守卫，trap 先于 spawn 安装、spawn-only background `_harness_session_snapshot_worker write` 后 `child_pid=$!` 立即补转发 spawn-gap 锁存信号，wait 循环 rc>128 且 `kill -0` 成立则重 wait，trap 摘除后 pending 非空按 HUP/INT/TERM 恰返回 129/130/143、否则透传 child_rc 0/1/2/3；全程双流空、零外部命令、零文件读写、正 PID 单点转发、无 setsid/负 PID。两个 exact-once 无副作用 anchor（`HARNESS_TEST_MARKER_SIGNALS_BEFORE_SPAWN`/`AFTER_WAIT`）供测试同步注入。
- `tests/test-session-signals.sh`（325 行）：默认发现、shfmt-clean 的信号矩阵，固定摘要 `RESULT PASS  session write interrupts`（PASS 后两空格逐字，全文字面量恰 2 处），只接受无参数/`all`/唯一 `--dependency-absent`。依赖探测要求模块在场且三 export 齐全，否则三态走同一零 active case inert 面；active 覆盖：三 export 各自缺席 fixture 逐字比较、齐全 fixture 恰新增唯一 export、双 anchor exact-once、snapshot 模块 SHA-256 前后不变、0/1/2/3 透传行双流空、facade HUP/INT/TERM 三窗口（运行中 barrier 持有 owned temp、spawn-gap BEFORE_SPAWN 同步注入、已退出后 AFTER_WAIT 同步注入）每行附第二信号核对锁存、逐行核恰 129/130/143 与 owned temp=0、bystander winner 指纹不变；process-group 三行 `setsid --wait` 隔离 pgroup + `kill -SIG -- -pgid`；模块经 `SIGNALS_MODULE` 覆盖注入支持 mutant。断言计数 checks=139（default==all 逐字一致，inert 探针 checks=0）。

八任务全部完成，review manifest 八行六列连续（awk 全量核验 rc=0，首行 base=execution BASE、末行 head=ACCEPTED_HEAD）。candidate（2.1）/full 完整历史（2.2）/真实 `git clone --depth 1 file://`（2.3，count=1 且 .git/shallow）/隔离 rollback（2.4，恰两行 D、03b/03b1 逐字 PASS、offline 本入口发现 0 次）/03d 顺序门（2.5，目录/分支/worktree/scoped rg 15 文件全缺席零匹配）零 delta 验证全 PASS；实现以 fast-forward `648fe66` 合入 main，post-merge 回归（default 逐字 + offline 发现恰一次 + 03b/03b1 入口）全绿；worktree 与分支已清理零残留。

执行期 spec 修订记录（03b1 E3 先例，均已随验收同批提交）：

1. 任务 1.2 review round1 阻断 F1：spawn-gap 行对正确模块间歇 hang（≈17%，strace 实证补转发落入 child pre-exec 窗口——SIGINT 遇异步 subshell SIG_IGN 被吞），失败签名与 mutant-a 不可区分构成假红。controller 裁定测试侧修复（模块不动）：gap 行 oracle 改为 facade probe 副本包装补转发语句落前向观测日志（mutant 删行则日志缺席确定性 FAIL）、driver 轮询放行存活 child（结局 don't-care）、timeout 降为纯兜底、gap 行 target winner 断言改 absent/beta 析取。修复后 reviewer 独立 20 连跑全绿、双 mutant 确定性 rc1。
2. design.md 四处「执行期修订」标注（mermaid note、错误处理表 spawn-gap 行、测试策略集成行、性能行）与 tasks.md 两处（裁定 3(a)、步骤 5）同步上述机制变更；门②时 ledger 一行 03d 字面全名（早于裁定 6）在门④落盘期自查发现并已修为间接形式。

## 验收证据路径

- 验收报告：`.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/acceptance/acceptance-report.md`
- 任务报告/日志/review：`.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/`（task-*-report.md、task-*-review-round-*.md、evidence/、review-manifest.tsv）
- ledger：`.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-03-03c-session-write-interrupts/ledger.md`

## 适用范围

本片只交付 signals facade 模块与其默认发现测试，不修改 03b snapshot provider 及任何前序模块/测试（上游七文件 BASE..HEAD 零变更），不设置 `HARNESS_SESSION_STATE_PROVIDER_VERSION`、不发布状态 public API。03d（remove 模块与 complete-provider aggregator）启动门——dependency-present active 证据（checks=139）、exact2/400（370）、full/depth-1/rollback/offline 与 03d 顺序门证据入 ledger——已由本验收满足并记录于 DECISIONS.md；inert PASS 未作为本片任何验收证据，也未解除 03d 顺序门。
