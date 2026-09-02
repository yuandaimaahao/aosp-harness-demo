---
id: 2026-09-03-03c-session-write-interrupts
依赖: [2026-09-02-03b-session-snapshot-safety, 2026-09-02-03b1-session-snapshot-assurance]
消费: "session-snapshot-core-v2的spawn-only _harness_session_snapshot_worker write|read ...与signal-aware _harness_session_snapshot_write_core/_harness_session_snapshot_read_core私有协议（worker write双流空0|1|2|3|129|130|143，worker read成功feature+LF/0、失败双流空1|2|3，最终exec Python且PID稳定）；session-snapshot-assurance-v1的03b1 accepted ledger中dependency-present完整矩阵checks=241与全PASS门（无运行时API）"
产出: "session-signals-facade-v1 —— 唯一私有export _harness_session_write_with_signals <project-id> <session-id> <feature>（常规沿用snapshot write的0|1|2|3，HUP/INT/TERM返回129|130|143）plus tests/test-session-signals.sh默认发现测试固定摘要`RESULT PASS  session write interrupts`；无public API/provider marker"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户已授权后续按autopilot执行；03b验收记录（DECISIONS.md 2026-09-02 03b行）确认spawn-only worker、signal-aware协议、八anchor与exact2/400已入ledger；03b1验收记录（DECISIONS.md 2026-09-03 03b1行）确认dependency-present完整矩阵checks=241、exact1/400、full/depth-1/offline与回滚证据已入ledger，PLAN v5.7与03b1 requirements R10规定的03c启动门由该记录满足
---

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并确认后续按 autopilot 执行。PLAN v5.7要求03c只在已由03b/03b1验收的signal-aware snapshot worker上增加可组合的Bash信号转发facade，不复制temp/publish逻辑、不修改snapshot模块。

## 目标

只新增私有模块`common/.harness/lib/session-state-signals.sh`与默认发现测试`tests/test-session-signals.sh`：在已由03b/03b1验收的signal-aware snapshot worker上增加Bash `pending_signal/child_pid/child_rc` facade、spawn-gap补转发、facade first-signal-wins与facade/process-group HUP/INT/TERM转发，交付唯一私有接口`_harness_session_write_with_signals <project-id> <session-id> <feature>`。owned temp、publish提交点与child信号handler全部留在03b worker内，本片不复制这些逻辑、不修改snapshot模块。本片继续不设置`HARNESS_SESSION_STATE_PROVIDER_VERSION`、不发布public path/write/read/remove或任何运行时API；dependency-present active证据入ledger后才可启动03d，inert PASS不能解除该顺序门。

## 需求

R1. [计划] 当`_harness_session_snapshot_worker`、`_harness_session_snapshot_write_core`与`_harness_session_snapshot_read_core`三个export均已定义时，系统必须使source `common/.harness/lib/session-state-signals.sh`返回0、双流空，且只新增唯一私有export `_harness_session_write_with_signals`；source不得读写文件、覆写依赖、定义四个状态public API或设置`HARNESS_SESSION_STATE_PROVIDER_VERSION`。

R2. [计划] 当source的依赖检查中三个snapshot export任一缺席时，系统必须静默返回0、双流空，并保持signals export、四个状态public API与provider marker全缺席。

R3. [计划] 当常规调用`_harness_session_write_with_signals <project-id> <session-id> <feature>`时，系统必须沿用snapshot write的双流与返回协议：首次/同值返回0、OS错返回1、安全/协议错返回2、异值冲突返回3，全部双流空；facade不得复制temp/publish逻辑，不得修改snapshot模块。

R4. [计划] 在facade执行期间，系统必须只以`pending_signal/child_pid/child_rc`状态机直接background spawn-only worker取得真实child PID，spawn与trap安装之间的spawn-gap收到信号必须补转发，facade锁存首信号（first-signal-wins），并向child PID及其process-group转发HUP/INT/TERM。

R5. [计划] 如果发生facade自身或其process-group收到HUP/INT/TERM任一信号，系统必须使`_harness_session_write_with_signals`返回恰为129/130/143的首信号码，后续信号不改变已锁存码，facade不得让cleanup或wait错误遮蔽信号码。

R6. [计划] 系统必须提供默认发现且shfmt-clean的`tests/test-session-signals.sh`，只接受无参数、`all`或唯一`--dependency-absent`；dependency-present默认/all必须逐个覆盖worker/write/read三export各自缺席的inert fixture，以及facade HUP/INT/TERM、process-group HUP/INT/TERM、spawn-gap补转发与facade first-signal-wins矩阵；真实snapshot provider缺席或任一export缺席时，默认与flag运行同一inert surface并零active case；成功唯一摘要为`RESULT PASS  session write interrupts\n`，unknown/extra/flag带值rc1且不打印PASS。

R7. [计划] 当03c进入验收时，系统必须在candidate、完整历史checkout和真实`git clone --depth 1 file://...`中分别运行默认signals测试与`bash ./scripts/check.sh --offline`，自动发现本入口恰好一次，且每个checkout的当前tracked上游七文件（common/.harness/lib/session-state-foundation.sh、common/.harness/lib/session-state-path.sh、tests/lib/session-path-race-driver.py、tests/test-session-path-races.sh、common/.harness/lib/session-state-snapshot.sh、tests/test-session-snapshot.sh、tests/test-session-snapshot-assurance.sh）SHA-256在测试前后不变。controller必须先逐字验证shfmt `v3.14.0`与ShellCheck version field `0.11.0`，再只对本片exact两文件运行`shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`与`bash -n`；execution BASE到accepted HEAD必须exact只新增`common/.harness/lib/session-state-signals.sh`与`tests/test-session-signals.sh`、numstat总和`<=400`，六列review manifest必须与tasks一一对应、首尾/相邻连续、reviewer非空且全PASS，`git diff --check`与worktree clean必须通过。

R8. [计划] 当验证独立回滚与顺序时，系统必须从accepted HEAD建立隔离临时分支，提交一个exact只删除signals module/test的rollback commit，在该clean checkout运行03b基础测试、03b1 assurance入口与offline并要求全绿、本入口发现0次；验收后丢弃临时checkout，不改变candidate/full/depth-1 checkout。controller只有在03c accepted HEAD、dependency-present active证据、exact2/400与全PASS manifest入ledger后，才可创建规范ID `03d-session-remove-prune`（日期前缀由创建日决定，本片不预知）的spec目录、同名`spec/`分支/worktree、ledger execution BASE或dispatch记录；此前这四类资产必须物理缺席，以nullglob下`ls -d "$PROJECT"/specs/*03d-session-remove-prune`缺席、`git show-ref | rg 'refs/heads/spec/.*03d-session-remove-prune'`零匹配、`git worktree list --porcelain | rg 03d-session-remove-prune`零匹配与`rg 03d-session-remove-prune`对ledger/dispatch/execution-base记录零匹配机械核对；任何inert PASS不得作为本片验收证据或解除该顺序门。

## 验收标准

主验证命令: bash ./tests/test-session-signals.sh
期望输出: dependency-present时退出码为`0`、stderr空，stdout逐字节精确为`RESULT PASS  session write interrupts\n`

验收清单:

- [ ] source功能fixture返回0、双流空且只新增`_harness_session_write_with_signals`一个export；worker/write/read三export逐个缺席的fixture逐字比较rc/双流、export inventory、四public API与provider marker全缺席，证明inert零副作用。
- [ ] 常规首次/同值write返回0、OS错1、安全/协议错2、异值冲突3且全部双流空，与snapshot write协议逐字一致；生产文本不含temp/publish逻辑副本，snapshot模块SHA-256在测试前后不变。
- [ ] facade HUP/INT/TERM三行各自返回恰为129/130/143、无winner、本调用owned temp清零；process-group HUP/INT/TERM三行同样核对首信号码；第二信号不改变已锁存码；spawn-gap窗口收到的信号被补转发且不丢失。
- [ ] 真实dependency-present默认/all与隔离provider-absent默认/flag均得唯一固定摘要`RESULT PASS  session write interrupts\n`，但只有dependency-present active证据计入本片验收；unknown/extra/flag带值rc1且无PASS。
- [ ] candidate/full/depth-1的默认入口与offline全PASS，offline发现本入口恰好一次，depth-1 commit-count=1且shallow marker非空；每个checkout的上游七文件SHA-256测试前后不变且clean。
- [ ] 隔离rollback commit exact只删除signals module/test后，clean checkout中03b基础测试、03b1 assurance入口与offline全PASS且本入口发现0次；03d的spec/ref/worktree/BASE/dispatch按R8机械查缺席。
- [ ] review manifest六列、任务序号、execution BASE、相邻base/head、accepted HEAD和全PASS一次机械验证通过；BASE..HEAD exact name-only为上述两文件、numstat总和`<=400`，固定版本断言后对exact两文件运行shfmt/ShellCheck/bash-n全绿，`git diff --check`和clean通过；只有dependency-present active证据入ledger后才可创建03d。

不变量（不许劣化，2-4项）:

- 已发布安全winner被facade/group信号矩阵改变的次数 ≤ `0`，验证: 每case前后比较winner dev/inode/uid/mode/nlink/size/hash指纹。
- 任一信号分支返回后本调用未发布owned temp残留数 ≤ `0`，验证: 每case前后在临时session根下find `.snapshot-*`计数。
- facade/group HUP/INT/TERM返回非首信号码或第二信号改码的次数 ≤ `0`，验证: 信号矩阵逐case核对锁存rc与`child_rc`恰为129/130/143。
- 上游七tracked文件在execution BASE..HEAD的变更数 ≤ `0`，验证: `git diff --name-only "$BASE" "$HEAD" -- common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh tests/lib/session-path-race-driver.py tests/test-session-path-races.sh common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh tests/test-session-snapshot-assurance.sh`。

## 超出范围

- 不修改03b snapshot provider、03b1 assurance入口及03/03a/03a1/03a2任何模块或测试；不设置`HARNESS_SESSION_STATE_PROVIDER_VERSION`，不发布public path/write/read/remove或任何运行时API。
- 不复制snapshot worker的owned-temp/publish逻辑或Python child信号处理；facade只组合已由03b/03b1验收的signal-aware spawn-only worker，read路径不新增信号契约。
- 不实现remove/prune/final aggregator/coverage fragment（属03d）；03d的全部资产（spec目录、`spec/`分支、worktree、ledger execution BASE、dispatch记录）在本片dependency-present active证据入ledger前继续物理缺席。
- inert PASS不替代dependency-present证据；不调用设备、网络、AOSP build、Claude/Codex客户端，不push、不清理已有spec/prototype/implementation分支或worktree。
