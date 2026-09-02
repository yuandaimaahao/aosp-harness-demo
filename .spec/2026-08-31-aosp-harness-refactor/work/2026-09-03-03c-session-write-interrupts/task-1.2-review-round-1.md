# Review 报告： 03c-session-write-interrupts 任务 1.2（tests/test-session-signals.sh）

**结论： NEEDS_CHANGES**（阻断 1 / 重要 0 / 次要 0）

- TASK_BASE=`a8d3859f639eed64b0d1e74eb1461c8e32e64a45` → TASK_HEAD=`f6f8eb60976718fe09b642f7033d9eade1312262`；execution BASE=`c9c82264b3f819a6a6449a0242e102e97b35c3b0`
- 审查对象： worktree HEAD==TASK_HEAD，`git status --porcelain` 为空

## Findings

### F1 [阻断] spawn-gap 三行对正确模块间歇性 hang（约 17% 失败率），default/all 入口不是可靠绿灯

- **位置**: `tests/test-session-signals.sh:214-281`（`run_signal_row` gap 模式，行 219 `gap) mod=$gap_signals`、行 235 行外 `timeout 20`）；根因涉及 `common/.harness/lib/session-state-signals.sh:31`（spawn 后立即补转发）。
- **问题**: gap 行的补转发在 child（bash subshell）`exec python3` 完成信号处置设置之前即送达，存在一个竞态窗口：转发的信号被静默吞掉，child 未锁存信号继续走到 probe 注入的 barrier 自旋循环（`while barrier and os.path.exists(barrier): sleep(.01)`，该循环不检查 `first_signal`），永久挂起；只能被行外 `timeout 20` 封闭为 `wrapper rc=124` FAIL。这与裁定 3(a) mutant-a（删补转发行）的失败签名**完全相同**——测试无法区分「无补转发」与「补转发被竞态吞掉」，对正确代码产生假红。
- **实测证据**（独立重跑，非报告转述）:
  - 真实模块完整运行 18 次，失败 3 次（≈17%）：`bash ./tests/test-session-signals.sh all` 首次即 FAIL（`FAIL gap HUP wrapper rc want=0 got=124`）；10 连跑中第 2 次同样 FAIL；strace 下 1 次 `FAIL gap INT wrapper rc want=0 got=124`。每次失败单行 hang 20 秒。
  - strace（`strace -f -tt -e trace=kill,rt_sigaction`）实证 SIGINT 竞态： facade（PID 2000682）`kill(2000683, SIGINT)=0` 于 `29.353570` 送达；同一时刻 child bash subshell 正在做异步命令信号设置——`29.353283` 将 SIGINT 重置为 SIG_DFL，`29.353589` 又设为 **SIG_IGN**（无 job control 的异步 subshell 忽略 SIGINT/SIGQUIT 的 bash 语义）——转发恰好落入该窗口被丢弃；child 随后 `exec python3`、安装 handler、进入 barrier 自旋，挂起 20 秒。对 SIGHUP，bash 不忽略，但抓到的 hang 现场（python3 存活、SigCgt=0x4003 三 handler 已装、SigPnd=0、barrier 文件陈旧）表明转发落入 subshell fork 后、trap 复位前的继承 trap-handler 窗口被当作 no-op 消费（subshell 中 `pending_signal` 副本已非空）。两种窗口都导致「child 永远收不到补转发」。
  - design 数据流 mermaid 的假设「handler安装前默认终止或锁存清理」对 SIGINT 不成立（bash 异步 subshell 的 SIG_IGN），gap 行因此不是 design 声称的「窗口锁死」确定性注入；facade/group 行无此问题（driver 等 barrier 文件出现才送信号，barrier 由 python 在 handler 安装后创建，天然同步），wait 行也是确定性的——**flake 仅集中在 gap 三行**。
- **违反任务书**: brief 步骤 4「`bash ./tests/test-session-signals.sh` 与 `... all` 各自 rc0」（我独立重跑 `all` 即 rc1）；R6（默认发现矩阵须为可靠验收面）；R7 后续任务 2.1/2.2/2.3 将在 candidate/full/depth-1 三个 checkout 重跑本入口，每次均有约 15–20% 概率假红。
- **可复现命令**:

  ```bash
  cd <worktree>
  for i in $(seq 1 10); do bash ./tests/test-session-signals.sh all >/dev/null 2>e || { cat e; break; }; done
  # 期望若干次内出现: FAIL gap HUP|INT wrapper rc want=0 got=124
  ```

- **处置建议（供 controller 裁定，非本 review 越权定案）**: 修复点可选在测试侧（gap 行区分「补转发被吞」与「无补转发」：被吞时 wrapper rc0+winner=present，mutant 时 wrapper rc124 hang，两者可机器区分）或模块侧（补转发与 child 就绪同步，但属任务 1.1 已验收范围，回流需走修复流程）；无论选哪边，都需要消除「正确代码间歇 124」这一假红。

## 逐项复核结果（1–7）

**1. diff 审查 — 通过。** `git diff TASK_BASE TASK_HEAD` 恰 `tests/test-session-signals.sh` 单文件；`diff BASE_SHA TASK_HEAD` 恰 signals 模块+本测试两文件；numstat 45+293=**338 ≤400**；UPSTREAM7 七文件 diff 为空。通读 293 行全文对照 brief/design 逐项核对： CLI 四态（`case ${1-}` + `$# -le 1`）只接受无参数/all/`--dependency-absent`；依赖探测（模块在场+三 export 隔离 shell `declare -F` 逐一，`|| inert`）；inert() 出口（printf 字面量第 1 处，line 20）；三 export 各自全局改名 fixture 逐字比较 rc/双流/inventory/四 public API/marker 全缺席（line 70-100）；齐全 fixture `comm -13` 恰新增唯一 export（line 102-120）；双 anchor `rg -c` exact-once（line 45-46）；生产文本无 `renameat2|\.snapshot-` 副本（line 48）；snapshot 模块 SHA-256 前后不变（line 44/288）；0/1/2/3 透传行全走 `run_rc` 双流空断言（含 EIO rc1、`../bad` rc2、异值 rc3）；三窗口（facade/gap/wait）×HUP/INT/TERM 每行附第二不同信号（`HUP:129:TERM INT:130:TERM TERM:143:HUP`）、逐行核恰 129/130/143、target winner、bystander 指纹、owned temp=0；process-group 三行 `setsid --wait` 隔离 + `kill -s SIG -- -pgid`（line 223/249/258）；模块经 `signals=${SIGNALS_MODULE:-...}` 定位（line 17）；成功流一律落文件 `cmp -s` 按字节比较，无吞 LF 的 command substitution（line 62-68）。**唯一不符即 F1 的 gap 行非确定性**。

**2. 探针字面量门 — 通过。** `rg -cF "printf 'RESULT PASS  session write interrupts\n'"` = **2**（line 20 inert 出口、line 293 active 末行）。变体检查： line 6 注释仅写摘要文字、line 62 为 `printf '%s\n' '...'` 不同调用形式，无第三次字面量出现，rindex/index 定位前提成立。

**3. 静态门 — 通过。** 工具版本逐字核： shfmt `v3.14.0`、ShellCheck `version: 0.11.0`。`shfmt -d -i 2 -ci -bn` 无输出 rc0；`shellcheck -x --severity=warning` rc0；`bash -n` rc0；`git diff --check` rc0。

**4. 完整实跑独立复验 — a/b/c/d/e 中除 flake 外全部通过。**
- a. default rc0、stdout 与 `printf 'RESULT PASS  session write interrupts\n'` `cmp -s` 逐字一致、stderr 0B；all **首次 rc1（F1）**，其后 3+9 次 rc0 且逐字一致；default==all 输出相同。
- b. rindex 探针： default 与 all 的 err 逐字一致，均 `checks=133`（N>0），与报告声明 N=133 一致。
- c. `--bogus`/`all extra`/`--dependency-absent=x` 各 rc1、stdout 0B 无 PASS。
- d. mutant 自反证（自构）：（a） 删补转发行 → gap HUP/INT/TERM 三行确定性 hang、wrapper rc 124 FAIL、整体 rc1、stdout 为 `RESULT FAIL ... checks=133 failures=3` 无 PASS；（b） 去 `[[ -n $pending_signal ]] ||` 守卫 → 12 行第二信号核对全 FAIL（HUP→143、INT→143、TERM→129）、整体 rc1 无 PASS。两 mutant 均符合裁定 3，红阶段设计本身有效。
- e. provider-absent: `git clone --no-local` + rm signals 模块后，无参数/all/`--dependency-absent` 三态均 rc0、stdout 逐字同一 inert 摘要、stderr 0B；clone 内 index 探针（两空格缩进 `${checks:-0}`）rc0、inert 摘要逐字、stderr 恰 `checks=0`；另 clone 将 `_harness_session_snapshot_read_core` 全局改名后 default 同 inert 面（rc0/逐字/0B）。

**5. 证据一致性 — 通过。** red 文件六行 schema+assertion、rc127，stdout_sha256=e3b0c442…（空文件标准 hash），stderr_sha256 与 `bash: tests/test-session-signals.sh: No such file or directory\n` 实算一致；evidence.tsv 48 行逐行实算 path/sha256/bytes 全部一致（44 日志+brief+report+red+review 包）；report 六节（task/base/head/files/commands/results）齐全，「红阶段证据： 」行路径独占行尾无尾随字符（`cat -A` 核）；review 包内嵌 diff 与 `git diff TASK_BASE TASK_HEAD` 逐字节一致（python 比较 `embedded == real: True`）；抽查日志（default/all/count/mutant-a/mutant-b/absent）内容与报告声明一致。

**6. 过程修正合理性判断。**
- (1) 信号行改写无 winner session 走 temp 路径、bystander 承载 winner 指纹：**合理且不削弱**。每行 `reset` 后 target session 本就没有 winner，若在 target 上核「指纹不变」是空断言；bystander（`project bystander alpha`）承载了实质的 winner 不变量，而 target 的「无 winner」（facade/gap/group）与 wait 行「winner==beta 发布完好」反而使 owned temp=0 与「信号不打断发布」断言真正走 temp/publish 路径（probe barrier 位于 TEMP_BEFORE_PUBLISH，只有 temp 路径可达）。design 每行不变量（恰 129/130/143、无 winner、temp=0、指纹不变）均仍有对应断言。
- (2) after-wait 行清 barrier/caught 环境变量：**必要且不削弱**。wait 模式信号在 AFTER_WAIT anchor 由 facade probe 同步自注（确定性），child 必须正常跑完；若不清 barrier，无人释放 barrier 文件（driver 只在 facade/group 模式参与），child 必挂。该行仍核恰 129/130/143、winner=beta、temp=0，断言有效。
- (3) `git add -N` 后补 `git add`、clone 后 `cp` 未提交文件：**纯机械必要**，不影响已提交交付物（本 review 针对 committed TASK_HEAD 验证，clone 实验均基于提交后内容重做）。

**7. 范围 — 通过。** worktree `git status --porcelain` 为空，HEAD==`f6f8eb6…`==TASK_HEAD，两段 diff 范围精确无夹带；我运行测试后亦无残留（无孤儿 worker、无 `.count.*` 遗留）。

## 备注

- F1 的修复归属（测试侧 vs 模块侧回流任务 1.1）建议交 controller 裁定；若回流模块，按 tasks.md 需重跑 1.1/1.2 步骤并交全新 reviewer。
- 我未改动任何仓库/worktree 文件；所有探针、mutant、clone 均在 mktemp 目录内构造并已清理。
