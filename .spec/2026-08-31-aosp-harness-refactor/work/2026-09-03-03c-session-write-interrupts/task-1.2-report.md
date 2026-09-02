# task-1.2 report: 一次性交付完整默认发现信号矩阵测试

## task

task-1.2 — 创建 `tests/test-session-signals.sh`（默认发现信号矩阵测试），提交信息逐字 `test(session): add write interrupt signal matrix`。fix round 1：按 controller 裁定修复 review round-1 阻断 finding F1（spawn-gap 三行对正确模块间歇 hang 假红），只改测试文件、模块不动。

## base

- TASK_BASE（任务 1.1 HEAD，manifest 相邻连续）: `a8d3859f639eed64b0d1e74eb1461c8e32e64a45`
- execution BASE（步骤 7 提交门断言口径）: `c9c82264b3f819a6a6449a0242e102e97b35c3b0`

## head

- TASK_HEAD: `648fe667396e6273f7d497479f16d7daf4560d18`（amend 保持单提交，commit `test(session): add write interrupt signal matrix`，1 file changed, 325 insertions）

## files

- 创建 `tests/test-session-signals.sh`（325 行 ≤345；`printf 'RESULT PASS  session write interrupts\n'` 调用字面量恰 2 处：inert() 出口与 active 末行）
- `git diff --name-only $BASE_SHA $TASK_HEAD` 恰为 `common/.harness/lib/session-state-signals.sh` + `tests/test-session-signals.sh` 两文件；numstat 总和 370 ≤400；UPSTREAM7 为空；`git status --porcelain` 为空
- F1 修复（测试侧，机制 a）：gap probe 副本把模块行 31 补转发语句文本包装落前向观测日志（`HARNESS_REFORWARD_LOG`，与双 anchor 注入同模式；mutant-a 删该行则包装目标缺席、日志缺席判 FAIL）；gap 行 driver 轮询「child 死亡 或 barrier 出现」，barrier 出现即删除放行，child 结局（被信号杀死 vs 跑完发布 beta）为 don't-care，行外 timeout 降为纯兜底；gap 行 target winner 断言改为「absent（送达）或 beta（被吞后正常发布）均可证」，facade rc 恰 129/130/143、双流空、owned temp=0、bystander 指纹、第二信号锁存核对全部保留

## commands

- 红阶段（round 0）: `test ! -e tests/test-session-signals.sh && bash tests/test-session-signals.sh` → rc127、stdout 无 PASS
- 静态门（版本逐字断言 shfmt v3.14.0 / ShellCheck 0.11.0 后）: `shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`、`bash -n`、`git diff --check`（只对本文件）
- dependency-present: `bash ./tests/test-session-signals.sh` 与 `... all`，各自 >out 2>err，`printf 'RESULT PASS  session write interrupts\n' | cmp -s - out`、`test ! -s err`
- 计数探针: 仓库内 `mktemp -d "$PWD/.count.XXXXXX"` 副本，python3 rindex 定位末处 printf 字面量、其前插入 `printf 'checks=%d\n' "$checks" >&2`，default 与 all 各跑一次（后删临时目录）
- argv 非法表: `--bogus` / `all extra` / `--dependency-absent=x` 逐行核 rc1 且 stdout 无 PASS
- mutant 自反证: `SIGNALS_MODULE=$tmp/mutant-a bash ./tests/test-session-signals.sh`（删 spawn 后补转发行）与 `SIGNALS_MODULE=$tmp/mutant-b ...`（trap 体去 `[[ -n $pending_signal ]] ||` 守卫），mktemp 副本注入、未改已提交模块
- provider-absent: `git clone --no-local . "$iso/r"` + 删 signals 模块跑无参数/all/`--dependency-absent`；index 定位首处 printf 字面量插入 `  printf 'checks=%d\n' "${checks:-0}" >&2` 后跑 default 核 `checks=0`；另起 clone `$iso/e` 将 `_harness_session_snapshot_read_core` 全局改名跑 default（两 clone 用后删除；提交前以 `cp` 把候选测试文件放入 clone）
- flake 实证: 修复后 default 连跑 10 次、all 连跑 10 次，逐次核 rc0、stdout 与固定摘要 `cmp -s` 逐字一致、stderr 0B（日志 `flake-default-01..10.*` / `flake-all-01..10.*`）
- 提交门: `git add -N` 后 working-tree 单文件断言，`git add` + `git commit --amend`，再对 `"$BASE_SHA" "$TASK_HEAD"` 累计断言两文件/≤400/UPSTREAM7 空/clean

## results

- 红阶段: rc127、stdout 0B 无 PASS（证据见下）
- 静态门: shfmt rc0 无输出、shellcheck rc0 无输出、bash -n rc0、`git diff --check` rc0
- dependency-present default: rc0、stdout 逐字节等于固定摘要、stderr 0B；all: 同上
- 计数探针: default 与 all 的 err 逐字一致，均为 `checks=139`（N=139>0，较 round 0 的 133 多 6：3 个 gap 行各新增补转发信号名与 PID 两项前向观测断言）——本片 dependency-present 完整矩阵口径 checks=139
- argv 非法表: `--bogus` rc1 无 PASS、`all extra` rc1 无 PASS、`--dependency-absent=x` rc1 无 PASS
- mutant-a（无补转发）: 确定性 rc1 无 PASS，失败签名为 3 个 gap 行各 2 项前向观测 FAIL（`reforward signal want=HUP|INT|TERM got=missing`、`reforward pid numeric want=yes got=no`），无 hang、无 timeout 124
- mutant-b（锁存无守卫）: 确定性 rc1 无 PASS，12 行第二信号锁存核对全 FAIL（HUP→143、INT→143、TERM→129），另 3 个 gap 行补转发日志记下被覆盖的第二信号（`reforward signal want=HUP|INT got=TERM`、`want=TERM got=HUP`）
- provider-absent 三态（无参数/all/`--dependency-absent`）: 均 rc0、stdout 逐字同一 inert 摘要、stderr 0B；inert 计数探针: rc0、stdout 逐字 inert 摘要、`$(<err)` = `checks=0`；export 缺席 clone default: rc0、同一 inert 摘要、stderr 0B
- flake 实证: default 10/10 rc0、all 10/10 rc0，20 次 stdout 全部与固定摘要逐字一致、stderr 全部 0B
- 提交门: working-tree 恰单文件（本轮净增 43 行）；BASE..HEAD 恰两文件、numstat 370 ≤400、UPSTREAM7 为空、worktree clean

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/evidence/task-1.2-red.txt
