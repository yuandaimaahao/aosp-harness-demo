# Review 报告：03c-session-write-interrupts 任务 1.1

**结论：PASS**（阻断 0 / 重要 0 / 次要 0）

审查范围：`c9c82264b3f819a6a6449a0242e102e97b35c3b0` → `a8d3859f639eed64b0d1e74eb1461c8e32e64a45`，全部复核项独立实跑，未依赖报告转述。

## 1. diff 审查（候选全文逐行对照权威结构）

`git diff --name-only BASE HEAD` 恰为 `common/.harness/lib/session-state-signals.sh` 单文件，numstat=45，`-- $UPSTREAM7` 为空。候选 45 行全文已读，与 brief「候选文件权威结构」及 design「组件与接口」节逐项相符：

- source 守卫（行 16–20）：三条 `declare -F` 逐一验 `_harness_session_snapshot_worker`/`_write_core`/`_read_core`，任一缺席 `return 0 2>/dev/null || exit 0`，静默、零定义、双流空（§4 实测证实）。
- 唯一 export `_harness_session_write_with_signals`（行 22），`pending_signal/child_pid/child_rc` 三 local 状态机（行 24）。
- 三条 inline trap（行 25–27）逐字为 `[[ -n $pending_signal ]] || { pending_signal=<SIG>; [[ -n $child_pid ]] && kill -<SIG> "$child_pid" 2>/dev/null; }`，first-signal-wins 守卫齐全。
- 锚点位置正确：`BEFORE_SPAWN`（行 28）在 trap 安装（25–27）与 spawn（29）之间；`AFTER_WAIT`（行 37）在 wait 循环（32–36）与 trap 摘除（38）之间。
- 行 29 spawn-only 后台 `_harness_session_snapshot_worker write`（不经 write_core）；行 30 `child_pid=$!` 后行 31 立即补转发锁存信号（spawn-gap 覆盖：trap 只在命令间触发，故 `&` 与 `$!` 之间锁存必然走行 31，无遗漏窗口）。
- wait 循环（行 32–36）：`wait` 被 trap 打断返回 >128 且 `kill -0` 成立则重 wait；child 已 reap 时 `wait` 返回 127≯128 立即 break，无死锁（§5 实测 re-wait 路径证实）。
- 摘除 trap 后 `pending_signal` 非空按 HUP/INT/TERM 恰 129/130/143（行 39–43），否则 `return "$child_rc"` 透传（行 44）。
- 零外部命令（仅 bash 内建 `declare/trap/kill/wait/:/((`）、零文件读写、全部 kill 用正 PID `"$child_pid"` 单点、无 `setsid`、无负 PID。

## 2. 计数门实跑复验

- `wc -l` = **45** ≤ 45
- `rg -c` 两 marker 各 **1**；`rg -c '^[a-z_0-9]+\(\)'` = **1**（唯一函数定义）
- `rg -n 'setsid'` rc1、`rg -n -- '-- -'` rc1、`rg -nF "printf 'RESULT PASS  session write interrupts\n'"` rc1，全无匹配

## 3. 静态门独立重跑（worktree 内）

- `$TOOLS/shfmt --version` = `v3.14.0`；`shellcheck --version` 含 `version: 0.11.0`
- `shfmt -d -i 2 -ci -bn` 无输出 rc0；`shellcheck -x --severity=warning` rc0；`bash -n` rc0；`git diff --check` rc0

## 4. source 契约独立重跑（mktemp 内，自设计等价命令）

- 齐全态 source foundation→path→snapshot→signals：rc0，stdout/stderr 各 0B
- `declare -F _harness_session_write_with_signals` rc0；四个 public API（path/write/read/remove）逐个 `declare -F` rc1；`declare -p HARNESS_SESSION_STATE_PROVIDER_VERSION` rc1
- 缺席抽查态（mktemp 副本将 `_harness_session_snapshot_read_core` 全局改名，改后原文定义 grep 计数 0）：source 四文件 rc0、双流各 0B、signals export `declare -F` rc1

## 5. 语义抽查（bash 实测，mktemp 内）

- (a) 运行中送 TERM：假 worker 模拟 03b 语义（trap TERM 后以 143 正常 exit），facade 后台调用后 0.5s 送 TERM → **facade_rc=143，双流各 0B，child 进程死亡**（补转发送达）。
- (b) pending 锁存：mktemp 副本在 `AFTER_WAIT` 锚点后注入 `sleep 1`（即任务 1.2 将使用的同步注入方式），worker 立即 return 0，child 已退出后送 INT → **facade_rc=130**，双流 0B。
- (b2) first-signal-wins 附加验证：运行中先 TERM 后 INT → rc 保持 **143** 不被覆盖。
- re-wait 无死锁附加验证：worker trap TERM 后继续运行 2s 再 return 0 → facade 在 wait 被打断后重 wait 至 child 正常退出，rc=143（pending 码不被 child_rc=0 遮蔽），worker 跑完全程，双流 0B，无 hang（外包 timeout 10 未触发）。
- (c) inert 路径：无 export 时 source 后 `declare -F _harness_session_write_with_signals` rc1。

## 6. 证据一致性

- red 文件：六行 schema（task/command/expected/rc/stdout_sha256/stderr_sha256）+ assertion 齐全；rc=1；stdout_sha256=`e3b0c442…`、stderr_sha256=`c37899f8…` 与 `task-1.1-logs/red.stdout.log`（0B）/`red.stderr.log`（86B）实算逐字一致；stderr 内容确为「No such file or directory」。
- evidence.tsv 14 行全部实算核对：sha256 与 bytes 与磁盘文件逐一相符（brief 888e…/69350、report 159d…/2758、red e78d…/505、review 包 0f18…/2813、10 个日志全对）。
- report 六节齐全（task/base/head/files/commands/results）；第 37 行 `红阶段证据: <path>`，`cat -A` 核行尾为 `.txt$`，无尾随字符。
- review 包：fenced diff 块抽出后与 `git diff BASE HEAD` `cmp` **逐字节一致**；commit 列表与实际 `git log`（单 commit `a8d3859`）一致；包内 blob index `89961a5` 与 `git rev-parse HEAD:<file>` 前缀一致。

## 7. 范围与偏差判断

- BASE..HEAD 恰一个 commit、恰一个新文件；`git status --porcelain` 为空；worktree HEAD = TASK_HEAD。
- 偏差 1（`git add -N` → `git add`）：`git add -N` 只登记 intent-to-add，`git commit` 不收录其内容，照 brief 字面执行不可能产生含文件的 commit；改为 `git add` 后所有提交后门（name-only/numstat≤45/UPSTREAM7 空/clean）均按原样核过且本 reviewer 独立复跑通过。**不影响交付正确性**。
- 偏差 2（review-package.sh 实为 4 参数签名）：产物 review 包存在且与真实 diff 逐字节一致，签名差异不影响包内容。**不影响交付正确性**。
- 观察（非 finding）：`review-manifest.tsv` 尚未创建——按 tasks.md 步骤 6，manifest 行须在本 review PASS 后由 controller 追加，当前缺席符合流程。

**复核中发现的唯一疑点已自证清白**：首轮语义抽查 (a) 曾出现 stderr 71B，定位为测试 fixture 自身 bug（`WPIDF` 误指向目录导致重定向报错），修正 fixture 后重跑双流 0B，与模块无关。
