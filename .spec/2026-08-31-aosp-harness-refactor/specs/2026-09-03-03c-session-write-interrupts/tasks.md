# 2026-09-03-03c-session-write-interrupts 实现计划

03b 三轮 tasks review 证明逐函数拼装中间代码会制造假红；本片两个交付文件均为新写完整文件，无 prototype blob——design sizing 节明确 facade 本体极小（无外部命令、无分支矩阵），不需要 runnable prototype 作为 sizing 依据，候选文件以 design「组件与接口」节为唯一权威结构。熔断裁定：任务 1.1 一次性交付完整 signals 模块（≤45 行小文件，单任务落地）、任务 1.2 一次性交付完整测试文件（≤345 行，含红阶段 mutant 自反证），禁止逐段拼装；随后 candidate/full/depth-1/rollback/order/terminal 六个零 delta controller 验证任务；共八个任务严格串行。实现提交使用普通 Conventional Commit。每个任务均保存 red 记录、green 报告和 evidence package，交全新独立 agent review；Blocking/Important 修复后必须由另一全新 agent re-review。

固定变量与工具门：

```bash
PROJECT=.spec/2026-08-31-aosp-harness-refactor
SPEC=$PROJECT/specs/2026-09-03-03c-session-write-interrupts
WORK=$PROJECT/work/2026-09-03-03c-session-write-interrupts
TASKS=$SPEC/tasks.md
LEDGER=$SPEC/ledger.md
MANIFEST=$WORK/review-manifest.tsv
TOOLS=/tmp/claude-1000/-home-zzh0838-CareerDevelop-AI2D-aosp-harness-demo/bdc6e669-9154-4030-a9db-78dc599ab491/scratchpad/tools/bin
UPSTREAM7="common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh tests/lib/session-path-race-driver.py tests/test-session-path-races.sh common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh tests/test-session-snapshot-assurance.sh"
test "$("$TOOLS/shfmt" --version)" = "v3.14.0"
"$TOOLS/shellcheck" --version | rg -q '^version: 0.11.0$'
```

controller 在门④通过后固定 `IMPLEMENTATION_WORKTREE` 与 `TASK_BASE`（execution BASE，即任务 1.1 提交前的 clean HEAD），并令 `BASE_SHA=$TASK_BASE`；任务 1.2 开始时重取 `TASK_BASE=$(git rev-parse HEAD)` 为任务 1.1 的 `TASK_HEAD`，保证 manifest 相邻连续。

red记录固定六行：`task=`、`command=`、`expected=`、`rc=`、`stdout_sha256=`、`stderr_sha256=`，末加`assertion=`；green报告固定含task/base/head/files/commands/results。evidence package为TSV三列`path<TAB>sha256<TAB>bytes`，列出brief、report和全部日志；reviewer拿这三个路径，而不是依赖base=head的空diff。

manifest固定六列`seq<TAB>task-id<TAB>base<TAB>head<TAB>reviewer<TAB>PASS`。每个任务独立review PASS后先追加本行，再分别执行：

```bash
python3 /home/zzh0838/.agents/skills/spec/scripts/mark-task-done.py "$TASKS" TASK_ID
# controller用apply_patch向ledger增加：- 任务 TASK_ID: 完成 commits=[TASK_HEAD]
python3 /home/zzh0838/.agents/skills/spec/scripts/sync-ledger.py "$LEDGER" --repo "$IMPLEMENTATION_WORKTREE"
```

裁定（定死，依据随条给出）：

1. 落地策略：任务 1.1/1.2 各以单任务一次性交付完整候选文件，禁止逐段拼装。依据：03b 教训——拼装中间代码制造未定义引用、截断 builder 与假红；本片无 prototype blob，design 明确 facade 本体极小不需 runnable prototype 作 sizing 依据，两个候选文件以 design「组件与接口」节为唯一权威结构。sizing 预算：模块 ≤45 行、测试 ≤345 行，合计 ≤390，对 exact2/400 门保留 ≥10 行余量。
2. 探针字面量前提：测试文件中 `printf 'RESULT PASS  session write interrupts\n'` 调用字面量恰 2 处——依赖缺席 inert 出口（第 1 处）与 active 出口（末行，第 2 处）。dependency-present 实跑用 rindex 定位末处、在其前插入 `printf 'checks=%d\n' "$checks" >&2` 探针；inert 实跑用 index 定位首处、插入 `printf 'checks=%d\n' "${checks:-0}" >&2` 探针——inert 流程在计数器初始化前即 `exit 0`，末行探针不可达、提前引用 `"$checks"` 会 unbound 崩溃（03b1 步骤 5 同款约束）。结构注释只写摘要文字，不得逐字包含该 printf 调用字面量，否则 rindex/index 定位失效（03b1 M1 教训）。
3. mutant 设计：任务 1.2 红阶段含两个 mutant 自反证。(a) spawn-gap 无补转发 mutant：在 mktemp 副本上删除 spawn 后补转发行；该 mutant 不靠 rc 区分——worker 收不到补转发会被 barrier 封闭为 hang，由 `timeout` 判 FAIL、rc1 无 PASS。（执行期修订：review round1 F1 实证补转发可落入 child pre-exec 窗口被吞（SIGINT 遇异步 subshell SIG_IGN），hang 与 mutant 不可区分构成假红；oracle 改为 facade probe 副本包装补转发语句落前向观测日志、mutant 删行则日志缺席确定性判 FAIL，driver 轮询放行存活 child，timeout 降为纯兜底，详见 design.md 四处执行期修订与 task-1.2-review-round-{1,2}.md。）(b) 锁存被第二信号覆盖 mutant：trap 体去掉 `[[ -n $pending_signal ]] ||` 守卫；由信号矩阵每行附带的第二信号核对判 FAIL、rc1 无 PASS。两 mutant 均经 `SIGNALS_MODULE` 环境变量覆盖注入（照 03b `SNAPSHOT_CORE` 先例），不改动已提交模块。
4. `setsid` 仅测试侧：生产模块零外部命令、零文件读写、只用 bash 内建 `trap`/`kill`（正 PID）/`wait`/`declare`，永不含 `setsid` 与负 PID 组转发；process-group 三行用 `setsid --wait` 隔离 pgroup 只出现在测试文件。依据：design 概述决策——spawn-only 单进程下正 PID 即完整覆盖 R4 转发义务，负 PID 会命中 facade 自身组。
5. 终交付锚点 `session-signals-facade-v1` 记入本文、ledger 完成锚点与 acceptance 报告；任务 2.6 的「产出」字段写 `tests/test-session-signals.sh`。依据：check-tasks 的孤儿产出检查只认 requirements 验收标准节正文，该路径在「主验证命令」行逐字出现，而锚点名只出现在 requirements frontmatter（03b1 裁定 5 同款）。
6. `03d-session-remove-prune` 字面全名的硬禁令只覆盖 scoped rg 实际搜索的文件——`$PROJECT/specs/*/ledger.md`、`$PROJECT/work/*/dispatch.tsv`、`$PROJECT/work/*/execution-base.env`；这些文件只写「03d 顺序门」字样，本片自身 ledger 若含该字面全名，任务 2.6 终门重跑顺序门会自命中制造假红。green/red 报告与运行日志不在 rg 域内、不受硬禁令约束，但任务 2.5 的报告与日志中命令一律以步骤 2 已定义的 `"$NEXT"` 间接形式记录、不内联字面全名，以降低误写扩散风险。
7. inert PASS 不作为本片验收证据，也不解除 03d 顺序门；只有 dependency-present active 证据、exact2/400 与全 PASS manifest 入 ledger 后才可创建 03d 的 spec 目录/分支/worktree/ledger BASE/dispatch 记录（R8）。

### 任务 1.1: 一次性交付完整signals facade模块

文件: 创建 `common/.harness/lib/session-state-signals.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/evidence/task-1.1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/task-1.1-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/review-manifest.tsv`
消费: 无
产出: session-signals-facade-runtime-v1
需求: R1, R2, R3, R4, R5
必需: 是
状态: 完成

候选文件权威结构（design「组件与接口」节，唯一 export、不新增辅助函数）：source 守卫逐一 `declare -F` 验证 `_harness_session_snapshot_worker`/`_harness_session_snapshot_write_core`/`_harness_session_snapshot_read_core`，任一缺席则静默返回 0、双流空，不定义 signals export、四个状态 public API 与 `HARNESS_SESSION_STATE_PROVIDER_VERSION`；齐全则定义 `_harness_session_write_with_signals <project-id> <session-id> <feature>`——`pending_signal/child_pid/child_rc` 三 local 状态机，三条 inline trap 各自 `[[ -n $pending_signal ]] || { pending_signal=<SIG>; [[ -n $child_pid ]] && kill -<SIG> "$child_pid" 2>/dev/null; }`，`: # HARNESS_TEST_MARKER_SIGNALS_BEFORE_SPAWN` 位于 trap 安装与 spawn 之间，background spawn-only `_harness_session_snapshot_worker write`（不经 write_core）后 `child_pid=$!` 并立即补转发 spawn-gap 锁存信号，wait 循环 `wait "$child_pid"` 后 rc>128 且 `kill -0 "$child_pid"` 成立则重 wait，`: # HARNESS_TEST_MARKER_SIGNALS_AFTER_WAIT` 位于 wait 循环与 trap 摘除之间，摘除 trap 后 `pending_signal` 非空按 HUP/INT/TERM 恰返回 129/130/143，否则 `return "$child_rc"` 透传 0/1/2/3；全程双流空、零外部命令、零文件读写、正 PID 单点转发。worker 组合的正确性（R3–R5 行为矩阵）由任务 1.2 封闭，本任务只做 source 契约与静态门，避免在无矩阵覆盖下制造假绿。

- [ ] 步骤 1: 运行`test ! -e common/.harness/lib/session-state-signals.sh && bash -c 'source common/.harness/lib/session-state-signals.sh'`，确认红阶段失败为文件缺席 rc1、stdout 无 PASS；按固定六行 schema 写`$WORK/evidence/task-1.1-red.txt`并核`test -s "$WORK/evidence/task-1.1-red.txt"`。
- [ ] 步骤 2: 核`git rev-parse HEAD`逐字等于门④固定的 execution BASE 并设`TASK_BASE=$(git rev-parse HEAD)`；用 apply_patch 一次性创建`common/.harness/lib/session-state-signals.sh`完整候选（禁止逐段拼装），核`test "$(wc -l <common/.harness/lib/session-state-signals.sh)" -le 45`、`test "$(rg -c ': # HARNESS_TEST_MARKER_SIGNALS_BEFORE_SPAWN' common/.harness/lib/session-state-signals.sh)" = 1"`、`test "$(rg -c ': # HARNESS_TEST_MARKER_SIGNALS_AFTER_WAIT' common/.harness/lib/session-state-signals.sh)" = 1"`、`test "$(rg -c '^[a-z_0-9]+\(\)' common/.harness/lib/session-state-signals.sh)" = 1"`（唯一函数定义）、`! rg -q 'setsid' common/.harness/lib/session-state-signals.sh`、`! rg -q -- '-- -' common/.harness/lib/session-state-signals.sh`（无负 PID 组转发）。
- [ ] 步骤 3: 逐字核固定工具版本`test "$("$TOOLS/shfmt" --version)" = "v3.14.0"`与`"$TOOLS/shellcheck" --version | rg -q '^version: 0.11.0$'`；对该单文件跑`"$TOOLS/shfmt" -d -i 2 -ci -bn common/.harness/lib/session-state-signals.sh`（无输出）、`"$TOOLS/shellcheck" -x --severity=warning common/.harness/lib/session-state-signals.sh`（rc0）、`bash -n common/.harness/lib/session-state-signals.sh`与`git diff --check`，全部通过。
- [ ] 步骤 4: source 契约实跑——依赖齐全态运行`bash -c 'source common/.harness/lib/session-state-foundation.sh && source common/.harness/lib/session-state-path.sh && source common/.harness/lib/session-state-snapshot.sh && source common/.harness/lib/session-state-signals.sh' >out 2>err`核 rc0、`test ! -s out`、`test ! -s err`；export inventory 核`declare -F _harness_session_write_with_signals`在场、`harness_session_path`/`harness_session_write`/`harness_session_read`/`harness_session_remove`逐个缺席、`declare -p HARNESS_SESSION_STATE_PROVIDER_VERSION`非 0；export 缺席抽查态在`mktemp -d`中复制 snapshot 模块并把`_harness_session_snapshot_read_core`全局改名，source foundation/path/改名副本/signals 四文件核 rc0、双流空且`declare -F _harness_session_write_with_signals`缺席，结束后删除临时目录；完整逐 export 缺席 fixture 矩阵由任务 1.2 封闭，本步只做单点抽查。
- [ ] 步骤 5: 提交——`git add -N common/.harness/lib/session-state-signals.sh`后核 working-tree `git diff --name-only`恰为该单文件、`git diff --numstat | awk '{s+=$1} END {print s+0}'`≤45；`git commit -m "feat(session): add write signal-forwarding facade"`；设`TASK_HEAD=$(git rev-parse HEAD)`并核`git diff --name-only "$TASK_BASE" "$TASK_HEAD"`恰为该单文件、`git diff --numstat "$TASK_BASE" "$TASK_HEAD" | awk '{s+=$1} END {print s+0}'`≤45、`git diff --name-only "$TASK_BASE" "$TASK_HEAD" -- $UPSTREAM7`为空、`git status --porcelain`为空。
- [ ] 步骤 6: 生成 task brief/report、`review-package.sh TASK_BASE TASK_HEAD`及 evidence package，取得独立 diff review PASS；有 fix 则更新`TASK_HEAD`、重跑步骤 3–5 并交全新 reviewer。PASS 后运行`printf '1\ttask-1.1\t%s\t%s\t%s\tPASS\n' "$TASK_BASE" "$TASK_HEAD" "$REVIEWER" >>"$MANIFEST"`；随后分别 mark 1.1、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 1.2: 一次性交付完整默认发现信号矩阵测试

文件: 创建 `tests/test-session-signals.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/evidence/task-1.2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/task-1.2-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/review-manifest.tsv`
消费: session-signals-facade-runtime-v1
产出: session-signals-matrix-v1
需求: R1, R2, R3, R4, R5, R6
必需: 是
状态: 完成

候选文件权威结构（design「默认发现测试」与「测试策略」节）：CLI 只接受无参数、`all` 或唯一 `--dependency-absent`，unknown/extra/flag 带值 rc1 且不打印 PASS；依赖探测要求 signals 模块文件在场且三个 snapshot export 在隔离 shell 逐一 `declare -F` 齐全，真实 provider 缺席或任一 export 缺席时默认与 flag 走同一零 active case inert surface，打印 inert 出口摘要（printf 调用字面量第 1 处）；active 路径覆盖：三 export 各自缺席的 inert fixture 逐字比较 rc/双流/export inventory/四 public API/marker 全缺席，齐全 fixture 恰好新增唯一 export，facade 双 anchor 各 exact-once，生产文本无 temp/publish 逻辑副本且测试前后 snapshot 模块 SHA-256 不变；常规 0/1/2/3 透传行全部双流空；facade HUP/INT/TERM 三窗口——运行中（snapshot probe 副本 barrier 持有 owned temp、`ps -o comm=` 证实该 PID 为 python3 后送信号，照 03b 先例）、spawn-gap（facade probe 副本 BEFORE_SPAWN anchor 同步注入，行外包 `timeout` 防挂死）、已退出后（AFTER_WAIT anchor 同步注入）——每行附第二不同信号核对锁存，逐行核恰 129/130/143、无 winner、本调用 owned temp=0、winner 指纹不变；process-group HUP/INT/TERM 三行用 `setsid --wait` 隔离 pgroup、inner 写 PID 文件、`kill -SIG -- -pgid`；模块经 `signals=${SIGNALS_MODULE:-$repo/common/.harness/lib/session-state-signals.sh}` 定位以支持 mutant 注入；stdout/stderr 一律落文件按字节比较，禁止用吞尾随 LF 的 command substitution 验证成功流；active 出口打印末行摘要（printf 调用字面量第 2 处），全文恰 2 处（裁定 2）。

- [ ] 步骤 1: 运行`test ! -e tests/test-session-signals.sh && bash tests/test-session-signals.sh`，确认红阶段失败为文件缺席 rc127、stdout 无 PASS；按固定六行 schema 写`$WORK/evidence/task-1.2-red.txt`并核`test -s "$WORK/evidence/task-1.2-red.txt"`。
- [ ] 步骤 2: 设`TASK_BASE=$(git rev-parse HEAD)`并核其逐字等于任务 1.1 的`TASK_HEAD`（manifest 相邻连续）；用 apply_patch 一次性创建`tests/test-session-signals.sh`完整候选（禁止逐段拼装），核`test "$(wc -l <tests/test-session-signals.sh)" -le 345`、`test "$(rg -cF "printf 'RESULT PASS  session write interrupts\n'" tests/test-session-signals.sh)" = 2"`（裁定 2 前提）。
- [ ] 步骤 3: 逐字核固定工具版本`test "$("$TOOLS/shfmt" --version)" = "v3.14.0"`与`"$TOOLS/shellcheck" --version | rg -q '^version: 0.11.0$'`；对该单文件跑`"$TOOLS/shfmt" -d -i 2 -ci -bn tests/test-session-signals.sh`（无输出）、`"$TOOLS/shellcheck" -x --severity=warning tests/test-session-signals.sh`（rc0）、`bash -n tests/test-session-signals.sh`与`git diff --check`，全部通过。
- [ ] 步骤 4: dependency-present 实跑——分别运行`bash ./tests/test-session-signals.sh`与`bash ./tests/test-session-signals.sh all`，各自`>out 2>err`落盘后核 rc0、`printf 'RESULT PASS  session write interrupts\n' | cmp -s - out`、`test ! -s err`；断言计数：在仓库内`mktemp -d "$PWD/.count.XXXXXX"`中放目标副本，用 python3 以 rindex 定位最后一处`printf 'RESULT PASS  session write interrupts\n'`并在其前插入`printf 'checks=%d\n' "$checks" >&2`，跑 default 与 all 各一次，核两次`err`逐字一致且为`checks=N`（N>0），把 N 记入 green 报告作为本片 dependency-present 完整矩阵口径，随后删除临时目录；argv 非法表`bash ./tests/test-session-signals.sh --bogus`、`bash ./tests/test-session-signals.sh all extra`、`bash ./tests/test-session-signals.sh --dependency-absent=x`逐行核 rc1 且 stdout 不含 PASS。
- [ ] 步骤 5: mutant 自反证（裁定 3）——(a) 在`mktemp -d`中复制 signals 模块并删除 spawn 后补转发行，`SIGNALS_MODULE=$tmp/mutant-a bash ./tests/test-session-signals.sh`核 spawn-gap 行被 barrier 封闭为 hang、`timeout` 判 FAIL、整体 rc1 且 stdout 无 PASS（执行期修订：实际 oracle 为前向观测日志缺席——mutant-a 核 gap 行 reforward 观测 missing 确定性 FAIL、无 hang 依赖，timeout 纯兜底）；(b) 复制模块并把 trap 体的`[[ -n $pending_signal ]] ||`守卫去掉，`SIGNALS_MODULE=$tmp/mutant-b bash ./tests/test-session-signals.sh`核第二信号核对行 FAIL、整体 rc1 且无 PASS；两 mutant 的 rc/双流落入日志并写入 green 报告，结束后删除临时目录。
- [ ] 步骤 6: provider-absent 隔离实跑——`git clone --no-local . "$tmp/r"`后`rm "$tmp/r/common/.harness/lib/session-state-signals.sh"`，在`$tmp/r`分别跑无参数、`all`、`--dependency-absent`，核三者 rc0、stdout 逐字同一`RESULT PASS  session write interrupts\n`、stderr 0B；零 active case 机械核验：对该副本用 python3 以 index 在第一处`printf 'RESULT PASS  session write interrupts\n'`（inert 出口）前插入`  printf 'checks=%d\n' "${checks:-0}" >&2`（两空格缩进与该分支一致，裁定 2），跑 default 核 rc0、stdout 逐字 inert 摘要、`test "$(<err)" = "checks=0"`；再另起`git clone --no-local . "$tmp/e"`，把`$tmp/e`中 snapshot 模块的`_harness_session_snapshot_read_core`全局改名，跑 default 核同样 rc0、同一 inert 摘要、stderr 0B；结束后删除两个临时 clone。
- [ ] 步骤 7: 提交——`git add -N tests/test-session-signals.sh`后核 working-tree `git diff --name-only`恰为该单文件、`git diff --numstat | awk '{s+=$1} END {print s+0}'`≤345；`git commit -m "test(session): add write interrupt signal matrix"`；设`TASK_HEAD=$(git rev-parse HEAD)`并核`git diff --name-only "$BASE_SHA" "$TASK_HEAD"`恰为`common/.harness/lib/session-state-signals.sh`与`tests/test-session-signals.sh`两文件、`git diff --numstat "$BASE_SHA" "$TASK_HEAD" | awk '{s+=$1} END {print s+0}'`≤400、`git diff --name-only "$BASE_SHA" "$TASK_HEAD" -- $UPSTREAM7`为空、`git status --porcelain`为空（两文件/≤400 断言必须用 execution BASE `$BASE_SHA`——`$TASK_BASE` 是任务 1.1 的 HEAD，该范围只含本任务单提交，name-only 必缺一文件；`$TASK_BASE` 仅保留给步骤 8 的 manifest 行与相邻连续性，与任务 2.1 步骤 3 口径一致）。
- [ ] 步骤 8: 生成 task brief/report、`review-package.sh TASK_BASE TASK_HEAD`及 evidence package，取得独立 diff review PASS；有 fix 则更新`TASK_HEAD`、重跑步骤 3–7 并交全新 reviewer。PASS 后运行`printf '2\ttask-1.2\t%s\t%s\t%s\tPASS\n' "$TASK_BASE" "$TASK_HEAD" "$REVIEWER" >>"$MANIFEST"`；随后分别 mark 1.2、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.1: 审计candidate并固定accepted HEAD

文件: 测试 `common/.harness/lib/session-state-signals.sh` / 测试 `tests/test-session-signals.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/evidence/task-2.1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/task-2.1-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/review-manifest.tsv`
消费: session-signals-matrix-v1
产出: signals-accepted-head-v1
需求: R7
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.1-report.md"`确认红阶段失败为报告缺席，按固定六行 schema 写 red 文件并核`test -s`；核 implementation clean 且`git rev-parse HEAD`为任务 1.2 的`TASK_HEAD`。
- [ ] 步骤 2: 创建临时目录`tmp=$(mktemp -d)`；保存七上游文件 before SHA（`sha256sum $UPSTREAM7 >"$tmp/before.sha"`）；核`test "$("$TOOLS/shfmt" --version)" = "v3.14.0"`与`"$TOOLS/shellcheck" --version | rg -q '^version: 0.11.0$'`；只对 exact 两文件跑`"$TOOLS/shfmt" -d -i 2 -ci -bn common/.harness/lib/session-state-signals.sh tests/test-session-signals.sh`、`"$TOOLS/shellcheck" -x --severity=warning common/.harness/lib/session-state-signals.sh tests/test-session-signals.sh`、`bash -n common/.harness/lib/session-state-signals.sh`与`bash -n tests/test-session-signals.sh`；分别运行 default 入口与`bash ./scripts/check.sh --offline`到独立日志，核 default 摘要逐字`RESULT PASS  session write interrupts\n`、`test "$(rg -c 'RESULT PASS  session write interrupts' offline.log)" = 1"`（offline 发现恰一次）且 offline 末行 PASS；再`sha256sum -c "$tmp/before.sha"`比较 after SHA，结束后删除临时目录。
- [ ] 步骤 3: 核`git diff --name-only "$BASE_SHA" HEAD`恰为`common/.harness/lib/session-state-signals.sh`与`tests/test-session-signals.sh`两文件、`git diff --numstat "$BASE_SHA" HEAD | awk '{s+=$1} END {print s+0}'`≤400、`git diff --name-only "$BASE_SHA" HEAD -- $UPSTREAM7`为空、`git diff --check`、clean，生成 green 报告和 evidence package；若发现源码缺陷则回流任务 1.1 或 1.2 修复并重 review，不在本任务改变 HEAD。
- [ ] 步骤 4: 交独立 reviewer 审 brief/report/evidence package 并取得 PASS，把当前 40 位 clean HEAD 固定为`ACCEPTED_HEAD`。
- [ ] 步骤 5: 运行`printf '3\ttask-2.1\t%s\t%s\t%s\tPASS\n' "$TASK_HEAD" "$TASK_HEAD" "$REVIEWER" >>"$MANIFEST"`；随后分别 mark 2.1、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.2: 验证完整历史checkout

文件: 测试 `common/.harness/lib/session-state-signals.sh` / 测试 `tests/test-session-signals.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/evidence/task-2.2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/task-2.2-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/review-manifest.tsv`
消费: signals-accepted-head-v1
产出: signals-full-checkout-v1
需求: R7
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.2-report.md"`确认红阶段失败为报告缺席并写 red 文件；核 implementation `git rev-parse HEAD`逐字等于`ACCEPTED_HEAD`。
- [ ] 步骤 2: 创建临时目录，运行`git clone --no-local "$IMPLEMENTATION_WORKTREE" "$tmp/full"`并核 full 的`git rev-parse HEAD`逐字等于`ACCEPTED_HEAD`。
- [ ] 步骤 3: 在 full 中保存七上游文件 before SHA，分别运行 default 入口与`bash ./scripts/check.sh --offline`到独立日志；核 default 固定摘要逐字`RESULT PASS  session write interrupts\n`、`test "$(rg -c 'RESULT PASS  session write interrupts' offline.log)" = 1"`且 offline 末行 PASS，再`sha256sum -c`比较 after SHA、`git status --porcelain`与`git diff` clean。
- [ ] 步骤 4: 写 green 报告/evidence package 并删除 full checkout；独立 review PASS 后运行`printf '4\ttask-2.2\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 5: 分别 mark 2.2、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.3: 验证真实depth-1 checkout

文件: 测试 `common/.harness/lib/session-state-signals.sh` / 测试 `tests/test-session-signals.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/evidence/task-2.3-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/task-2.3-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/review-manifest.tsv`
消费: signals-full-checkout-v1
产出: signals-depth1-checkout-v1
需求: R7
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.3-report.md"`确认红阶段失败为报告缺席并写 red 文件。
- [ ] 步骤 2: 运行`git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" "$tmp/depth1"`，核`git rev-parse HEAD`逐字等于`ACCEPTED_HEAD`、`test "$(git rev-list --count HEAD)" = 1`及`test -s .git/shallow`。
- [ ] 步骤 3: 保存七上游文件 before SHA，分别运行 default 入口与`bash ./scripts/check.sh --offline`到独立日志，核 default 固定摘要逐字`RESULT PASS  session write interrupts\n`、`test "$(rg -c 'RESULT PASS  session write interrupts' offline.log)" = 1"`且 offline 末行 PASS；比较 after SHA、diff/status clean。
- [ ] 步骤 4: 写 green 报告/evidence package 并删除 depth checkout；独立 review PASS 后运行`printf '5\ttask-2.3\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 5: 分别 mark 2.3、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.4: 验证exact rollback

文件: 测试 `common/.harness/lib/session-state-signals.sh` / 测试 `tests/test-session-signals.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/evidence/task-2.4-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/task-2.4-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/review-manifest.tsv`
消费: signals-depth1-checkout-v1
产出: signals-rollback-v1
需求: R8
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.4-report.md"`确认红阶段失败为报告缺席并写 red 文件。
- [ ] 步骤 2: 从 implementation `git clone --no-local "$IMPLEMENTATION_WORKTREE" "$tmp/rollback"`并核 HEAD=`ACCEPTED_HEAD`；运行`git rm common/.harness/lib/session-state-signals.sh tests/test-session-signals.sh`后提交普通 rollback commit，核`git diff --name-status HEAD~1 HEAD`恰为两行`D	common/.harness/lib/session-state-signals.sh`与`D	tests/test-session-signals.sh`。
- [ ] 步骤 3: 在 rollback 运行`bash tests/test-session-snapshot.sh`（03b 基础测试，核逐字`RESULT PASS  session snapshot safety`）、`bash tests/test-session-snapshot-assurance.sh`（03b1 assurance 入口，核逐字`RESULT PASS  session snapshot assurance`）与`bash ./scripts/check.sh --offline`；核全绿、`! rg -q 'session write interrupts' offline.log`（本入口发现 0 次）、`test ! -e common/.harness/lib/session-state-signals.sh`、`test ! -e tests/test-session-signals.sh`且 clean；candidate/full/depth-1 checkout 不被触碰。
- [ ] 步骤 4: 写 green 报告/evidence package 并删除 rollback checkout；独立 review PASS 后运行`printf '6\ttask-2.4\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 5: 分别 mark 2.4、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.5: 验证03d顺序门

文件: 测试 `common/.harness/lib/session-state-signals.sh` / 测试 `tests/test-session-signals.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/evidence/task-2.5-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/task-2.5-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/review-manifest.tsv`
消费: signals-rollback-v1
产出: signals-order-gate-v1
需求: R8
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.5-report.md"`确认红阶段失败为报告缺席并写 red 文件。
- [ ] 步骤 2: 定义日期无关规范 ID 片段`NEXT=03d-session-remove-prune`（日期前缀由创建日决定，本片不预知，R8）；前提：执行 shell 不得开 nullglob——未匹配 glob 需按字面传给 `ls`、由其 rc2 经 `!` 判缺席；在 implementation worktree 运行`! ls -d "$PROJECT"/specs/*"$NEXT" 2>/dev/null`与`! ls -d "$PROJECT"/work/*"$NEXT" 2>/dev/null`核 spec/work 目录缺席。
- [ ] 步骤 3: 运行`test -z "$(git show-ref | rg "refs/heads/spec/.*$NEXT")"`核分支零匹配；运行`test -z "$(git worktree list --porcelain | rg "$NEXT")"`核 worktree 零匹配。
- [ ] 步骤 4: 收集限定域文件后跑 scoped rg——`files=$(ls "$PROJECT"/specs/*/ledger.md "$PROJECT"/work/*/dispatch.tsv "$PROJECT"/work/*/execution-base.env 2>/dev/null)`（ls 多参数单列一行，禁止 `&&` 链 ls），然后`test -z "$files" || ! rg -q "$NEXT" $files`核 ledger/dispatch/execution-base 记录零匹配；不得搜索 PLAN/requirements 中的合法规划文字。
- [ ] 步骤 5: 写 green 报告/evidence package 并取得独立 review PASS；运行`printf '7\ttask-2.5\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 6: 分别 mark 2.5、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.6: 收敛manifest、ledger与终交付

文件: 测试 `common/.harness/lib/session-state-signals.sh` / 测试 `tests/test-session-signals.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/evidence/task-2.6-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/task-2.6-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/review-manifest.tsv` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts/acceptance/acceptance-report.md`
消费: signals-order-gate-v1
产出: tests/test-session-signals.sh（终交付锚点 session-signals-facade-v1 记入 ledger 完成锚点与 acceptance 报告）
需求: R7, R8
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/acceptance/acceptance-report.md"`确认红阶段失败为报告缺席并写 red 文件；核`git rev-parse HEAD`=`ACCEPTED_HEAD`与 clean。
- [ ] 步骤 2: 汇总 candidate/full/depth/rollback/order 日志到 green 与 acceptance 报告（含 accepted HEAD、active 摘要、双 anchor 注入、两 mutant 自反证、checks 计数口径、exact2/400），生成 evidence package 并取得独立 review PASS。
- [ ] 步骤 3: 运行`printf '8\ttask-2.6\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 4: 运行以下完整 manifest 核验（八行、六列、相邻连续、reviewer 非空、全 PASS）：

  ```bash
  awk -F '\t' -v base="$BASE_SHA" -v head="$ACCEPTED_HEAD" '
    BEGIN { split("task-1.1 task-1.2 task-2.1 task-2.2 task-2.3 task-2.4 task-2.5 task-2.6", ids, " ") }
    NF != 6 || $1 != NR || $2 != ids[NR] || $3 !~ /^[0-9a-f]{40}$/ || $4 !~ /^[0-9a-f]{40}$/ || $5 == "" || $6 != "PASS" { bad=1 }
    NR == 1 && $3 != base { bad=1 }
    NR > 1 && $3 != prev { bad=1 }
    { prev=$4 }
    END { exit bad || NR != 8 || prev != head }
  ' "$MANIFEST"
  ```

- [ ] 步骤 5: mark 任务 2.6 完成；用 apply_patch 写 ledger 完成锚点及 accepted HEAD、active 摘要、双 anchor、mutant 证据、checks 计数、exact2/400、full/depth/rollback/order 证据（遵守裁定 6，不逐字包含 03d 规范 ID 全名），再运行 sync-ledger。
- [ ] 步骤 6: 重跑`python3 /home/zzh0838/.agents/skills/spec/scripts/check-tasks.py "$TASKS"`、`python3 /home/zzh0838/.agents/skills/spec/scripts/check-req.py "$SPEC/requirements.md"`、`python3 /home/zzh0838/.agents/skills/spec/scripts/check-criteria.py "$SPEC/requirements.md"`、`python3 /home/zzh0838/.agents/skills/spec/scripts/check-analyze.py "$SPEC/requirements.md"`、candidate default/offline、`git diff --check`、clean 与任务 2.5 的 03d 顺序门；全部通过才进入 accept，任何 inert PASS 不得作为本片验收证据或解除后序门。
