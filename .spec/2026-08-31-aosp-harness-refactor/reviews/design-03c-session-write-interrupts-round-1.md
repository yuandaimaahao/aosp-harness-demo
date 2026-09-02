# design review: 2026-09-03-03c-session-write-interrupts round 1

- 审查人： 独立文档审查 agent（全新上下文，与起草者/控制器无关）
- 日期： 2026-09-03
- 对象： `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-03-03c-session-write-interrupts/design.md`（工作树 M 状态，184 行）
- 对照： 同目录 `requirements.md`（R1–R8）、`specs/2026-09-02-03b1-session-snapshot-assurance/design.md`（格式/口径先例）、`common/.harness/lib/session-state-snapshot.sh`（实际代码）、`tests/test-session-snapshot.sh`（barrier/信号先例）、PLAN v5.7 03c 专节（PLAN.md:124-126）与依赖边表（:184-186）、门② review（`reviews/requirements-03c-session-write-interrupts-round-1.md`）、DECISIONS.md 03b1 验收行

## 结论

**PASS**。阻断 0 / 重要 0 / 次要 4（均为措辞级备注，不阻断门③通过）。

机制正确性（本门重点）经实际代码逐行核对 + mktemp 隔离目录内 7 组 bash 语义实测，未发现死锁、丢信号、信号打回 facade 自身或假绿路径；setsid 与 set -m 两条「实测」声明均独立复跑证实；R1–R8 映射 8/8；frontmatter 消费/产出与 design 两处接口声明经脚本逐字比对一致；sizing 预算闭合（45+345=390≤400）；三个 check 脚本 rc=0、`git diff --check` rc=0。

## 逐项审查

### 1. 结构、映射、逐字一致性、sizing（静态核对）

- 九节齐全（概述/需求映射/架构/组件与接口/数据模型/数据流/错误处理/测试策略/文件清单），与 03b1 design 同构。需求映射表 R1,R2 / R3,R4,R5 / R6 / R7 / R8 = 8/8，无孤儿 R、无未映射组件。
- frontmatter 逐字：用脚本提取 requirements `消费`/`产出` 字段与 design.md:57（消费接口）、:49（对外接口）的 inline code 比对，两者均 `True`（逐字相等）。
- mermaid：三个图 node id（B/G/I/F/W/T/K 与 sequence participant C/F/W/T）均为合法标识符，edge label、`-.->`、`alt/else/end`、`Note over` 语法人工核对合法；环境无 mermaid-cli 且离线约束不下载，未经渲染器验证（见次要 4）。
- sizing：模块分解 6+5+6+7+8+13=45、测试分解逐项相加=345，合计 390≤400，余量 ≥10 行，预算闭合。文件清单恰为 exact2 两文件 + 验收资产段（红阶段 mutant、manifest、candidate/full/depth-1/rollback 日志、ledger 证据），与 R7/R8 字段闭合；当前 `common/.harness/lib/session-state-signals.sh` 与 `tests/test-session-signals.sh` 均不存在（exact2 前提成立）。
- 八 anchor 先例核对：snapshot.sh 中八个 `HARNESS_TEST_MARKER_*` 各精确一次、`renameat2` 精确一次（实测 grep）；design 新增的两个 anchor 名（`SIGNALS_BEFORE_SPAWN/AFTER_WAIT`）在 `common/`、`tests/` 零命中，无冲突。

### 2. 机制正确性（重点：实际代码 + bash 语义实测）

- **worker 真无孙进程（稳态）**：snapshot.sh Python 体 imports 仅 `ctypes/errno/os/re/secrets/signal/stat/sys`，无 fork/subprocess/threading；`_harness_snapshot_exec` 最终 `exec python3`（:6），PID 稳定，03b 测试先例（test-session-snapshot.sh:172-175）正是 background 后直接 `ps -o comm=` 证实同一 PID 为 python3。「child 及其 pgroup 中由本调用产生的部分 = 单一 PID」成立，正号转发覆盖 R4 转发义务。pre-exec 窗口存在瞬态外部命令（mktemp/rm，:192-197），但此时 `.snapshot-*` owned temp 尚未创建、capture 文件已 unlink，转发落在该窗口只会让 child subshell 按默认处置死亡（rc 恰 128+n、零残留），机制结论不变（见次要 3）。
- **不经 write_core 的 PID 错位论证（design.md:58）实测证实**：write_core 是 `( )` 体函数（snapshot.sh:206），background 它得到的 `$!` 是中间 bash（comm=bash），exec 后的程序是其子进程（实测：`core-bg $!=1800393 comm=bash / children: 1800395 sleep`）；直接 background `{ }` 体 worker 则 `$!` 即 exec 后进程本身（`comm=sleep`）。facade 直接 background worker 的选择正确。
- **trap 先于 spawn + pending 锁存 + 补转发无窗**：trap 体 `[[ -n $pending_signal ]] || { pending_signal=<SIG>; [[ -n $child_pid ]] && kill ... }` 在 child_pid 空时只锁存；bash trap 只在命令边界执行，spawn/赋值/补转发检查之间的任何到达点都被「锁存→spawn 后补转发」或「child_pid 已置→直接转发」覆盖，无丢失窗口。实测（模拟 BEFORE_SPAWN 注入，trap 已装、child_pid 未赋值时 `kill -TERM $$`）：rc=143、双流空，补转发生效。
- **first-signal-wins 双侧锁存**：facade 侧 `[[ -n $pending_signal ]] ||` 只写首值；child 侧 Python handler `if first_signal[0] is not None: return` 后锁存并把三种信号置 SIG_IGN（snapshot.sh:171-175），重入只返回。两侧均幂等，重复投递（group 直送 + facade 补转发）无害——与 03b1 已验收的 early-second latch 用例互证。
- **wait 循环 `rc>128 && kill -0` 重 wait**：bash 语义为「wait 被已设 trap 的信号打断立即返回 128+signo 并先执行 trap」；此时 child 未被 reap，`kill -0` 为真则重 wait 取真实退出码。实测（按 design.md:51 结构忠实实现 mini facade）：wait 期间打 facade 单 PID TERM/INT/HUP，分别得 rc=143/130/129、stderr 空、无挂死。边界分析：child 已 reap 时 `kill -0` 失败、`child_rc` 取中断值，但此时 `pending_signal` 必非空，锁存码优先遮蔽该值，结果仍正确；zombie 未 reap 时 `kill -0` 为真、重 wait 立即返回真实码，无死锁。child 对转发信号必然终止（handler `raise Interrupted` 或 handler 安装前默认杀死），重 wait 必然返回，无丢信号/死锁路径。
- **129/130/143 映射**：HUP=128+1、INT=128+2、TERM=128+15，与 03b R4 及 Python `SystemExit(128 + first_signal[0])`（:181）一致；摘除 trap 后 pending 非空优先于 `child_rc`，满足 R5「cleanup/wait 不遮蔽信号码」。
- **不打回自身**：全部转发为正号单 PID，design 明文禁用负 PID；非 job-control 下 child 与 facade/调用方同组，负 PID 组转发确会命中 facade 自身与父 shell——弃用论证成立。
- **门② 次要 1（process-group 机制）正面回答**：design.md:7 与 :36 给出两条确定性路径的合取（group 投递内核直送 + facade 补转发幂等 / 单 PID 由 trap 转发），并界定「pgroup 中由本调用产生的部分」恰为单 PID。回答成立。
- **spawn-gap 测试不假绿**：mutant（无补转发）下 facade 仍因锁存返回 143，rc 无法区分——design 用 barrier 封闭（snapshot probe 副本 barrier 持有，无补转发则 child 挂起、timeout 判 FAIL，错误处理表与 mermaid 注一致），不存在 mutant 伪装 PASS 的路径。
- **AFTER_WAIT 窗口**：child 已 reap 后信号到达，trap 锁存、`kill` 目标不存在被 `2>/dev/null` 静默，信号码不被遮蔽，恰 129/130/143。trap 摘除后到 return 的残余窗口信号按默认处置杀死 facade，观察值同为 128+n，语义等价。

### 3. 双 anchor 注入与 group 行测试机制（「实测」声明独立复跑）

- 双 anchor（`: # HARNESS_TEST_MARKER_SIGNALS_BEFORE_SPAWN/AFTER_WAIT`，exact-once 无副作用行、生产不读测试环境变量、注入只在 mktemp 副本）与 03b 八 anchor、03b1 provider-copy 注入先例同构；03b 基础测试的 barrier/caught 替换文本先例实际存在（test-session-snapshot.sh:30-35）。
- **`setsid --wait` 声明「当前环境实测 util-linux setsid 2.39.3 可用且离线」**：复跑 `setsid --version` → `setsid from util-linux 2.39.3`，证实。group 机制复跑：inner 脚本 setsid 后自写 PID 文件，`ps` 证实 PID=PGID（新 session 组长），driver `kill -TERM -- -pgid` 命中整组，`setsid --wait` 透传 rc=143、stdout/stderr 均空。机制成立。
- **`set -m` 声明「实测会向 stderr 泄漏 `[1]+ Terminated` job 通知」**：复跑证实——`set -m` 下后台 job 被 TERM/INT 杀死，`wait` 时 stderr 实得 `[1]+  Terminated              sleep 30` / `[1]+  Interrupt               sleep 30`（无显式 wait 时同样泄漏，且连 `Done` 通知也泄漏），确破坏双流空 oracle。弃用论证成立。（审查中首次复跑因测试命令自带 `2>/dev/null` 未复现，纠正后按无重定向形态复现，声明属实。）
- 仓库 grep `setsid` 除本 design 外零命中，与 design「仓库 grep 零先例」自述一致；setsid 限测试侧、本地二进制、不触网，与离线约束及 03b1 引入 `od` 等测试侧工具的先例不冲突。

### 4. 与 requirements 的一致性

- inert 三 export 缺席 fixture、四 public API + marker 全缺席、export inventory 逐字比较（R1/R2/R6）→ design.md:42、:63、:168 覆盖；与实际代码核对三 export 名（snapshot.sh:4,206,207）正是现存的全部 export。
- CLI 四态（无参数/all/`--dependency-absent` 接受，unknown/extra/flag 带值 rc1 无 PASS）、固定摘要 `RESULT PASS  session write interrupts`（两空格）逐字、inert/active 同摘要但 inert 不计验收证据 → design.md:64、:170 与 R6、验收清单、PLAN:52 逐字一致。
- R7 七文件 SHA-256 集、版本钉（shfmt v3.14.0 / ShellCheck 0.11.0）、exact2/numstat≤400、六列 manifest → design.md:70 逐条有着落；七文件清单与 requirements R7 及不变量 4 同集。
- R8 rollback（03b 基础 + 03b1 assurance + offline 全绿、本入口发现 0 次）与 03d 四类资产机械查缺席（`ls -d`/`git show-ref`/`git worktree list --porcelain`/`rg` 四命令）→ design.md:70 覆盖，与 requirements 同口径。
- 不新增运行时依赖：facade 只用 bash 内建（实测 mini facade 全部路径零外部命令、双流空），setsid 仅测试侧并已声明。

### 5. sizing 口径：checks=241 与 03b1 正文「240 项断言」

- design.md:57 引用 `checks=241`（与 requirements frontmatter 逐字一致）；03b1 design 正文写「240 项断言」。DECISIONS.md:43 与 `decisions/2026-09-02-03b1-session-snapshot-assurance.md:7` 明文：「断言 241=prototype 240+`ASSURANCE_UNLINK_LOG` rename 已提交窗口旧名 ENOENT oracle 1」。二者口径不同（241 为整合后最终口径，240 为 prototype 口径），均有出处，非矛盾。

### 6. 机械检查实测

- `check-req.py` / `check-criteria.py` / `check-analyze.py` 对 requirements.md 均 rc=0 无输出（design 未破坏 requirements 合规性）。
- `git diff --check -- requirements.md design.md` rc=0；design.md 行尾空白/tab 扫描零命中。
- 审查全程对仓库零改动（mktemp 目录已清理；一次 pkill 模式匹配误伤自身 shell，未波及仓库与他人进程，复核命令已改用 `pgrep -x` 形态）。

## Findings

### 阻断（0）

无。机制按文可实现，实测无死锁/丢信号/打回自身/假绿路径。

### 重要（0）

无。R1–R8 映射 8/8、frontmatter 逐字一致、sizing 闭合、checks=241 口径有 DECISIONS 出处、门②次要 1 已正面回答。

### 次要（4）

1. **trap 摘除不恢复调用方原有 trap**：`trap - HUP INT TERM` 将三者重置为默认而非恢复调用方（如未来 03d 消费链）可能已安装的 trap。R4/R5 未约束此行为，当前消费方无此类 trap，不构成矛盾；建议 03d design 时留意，不改亦可。
2. **sizing 无 runnable prototype 实证**：03b/03b1 均以 runnable prototype 行数/断言作 sizing 证据，本片改为纯分解预算（≤45+≤345=390，余量 ≥10 行）。design 已正面声明理由（facade 本体极小、无外部命令、无分支矩阵），且 numstat≤400 门在执行期兜底，属可接受的方法偏离。
3. **「无孙进程」严格为稳态事实**：worker 在 `exec python3` 前有瞬态外部命令（mktemp/rm）子进程；转发落在该窗口时 child subshell 按默认处置死亡、rc 恰 128+n 且零 temp 残留，机制结论不变。design 措辞「Python 侧不 fork 也无孙进程」本身准确，仅建议（非必须）注明「稳态」以免误读为全程单进程。
4. **mermaid 未经渲染器验证**：环境无 mermaid-cli，离线约束不下载；三个图仅人工核对语法（node id 合法、结构完整），未发现不可渲染构造。

## 附：复核命令

````bash
cd /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo
S=.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-03-03c-session-write-interrupts

# 结构检查器（均期望 rc=0 无输出）
python3 /home/zzh0838/.agents/skills/spec/scripts/check-req.py "$S/requirements.md"
python3 /home/zzh0838/.agents/skills/spec/scripts/check-criteria.py "$S/requirements.md"
python3 /home/zzh0838/.agents/skills/spec/scripts/check-analyze.py "$S/requirements.md"
git diff --check -- "$S/requirements.md" "$S/design.md"

# frontmatter 消费/产出 vs design 接口声明逐字比对（期望两行 True）
python3 - <<'PY'
import re
req = open('.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-03-03c-session-write-interrupts/requirements.md').read()
des = open('.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-03-03c-session-write-interrupts/design.md').read()
fm = lambda k: re.search(rf'^{k}: "(.*)"$', req, re.M).group(1)
cd = pd = None
for line in des.splitlines():
    if '消费接口（与 frontmatter 逐字一致）' in line: cd = line.split('：`',1)[1][:-1]
    if '对外接口（产出，与 frontmatter 逐字一致）' in line: pd = line.split('：`',1)[1][:-1]
print('消费一致:', fm('消费') == cd); print('产出一致:', fm('产出') == pd)
PY

# 运行时事实核对
grep -nE '^\s+_harness_session_snapshot_(worker|write_core|read_core)\s*\(\)' common/.harness/lib/session-state-snapshot.sh
grep -o 'HARNESS_TEST_MARKER_[A-Z_]*' common/.harness/lib/session-state-snapshot.sh | sort | uniq -c   # 八 anchor 各 1
grep -c 'renameat2' common/.harness/lib/session-state-snapshot.sh                                        # 期望 1
grep -n 'first_signal\[0\] is not None' common/.harness/lib/session-state-snapshot.sh                    # child 锁存
grep -rn 'setsid' common/ tests/ scripts/ 2>/dev/null; echo "生产/测试源码 setsid 先例 rc=$?（期望 1，零命中）"

# checks=241 口径出处
grep -n '241' .spec/2026-08-31-aosp-harness-refactor/DECISIONS.md \
  .spec/2026-08-31-aosp-harness-refactor/decisions/2026-09-02-03b1-session-snapshot-assurance.md

# setsid/set -m「实测」声明复跑（只在 mktemp 目录操作）
T=$(mktemp -d) && cd "$T"
setsid --version                          # 期望 util-linux 2.39.3
bash -c 'set -m; sleep 30 & p=$!; sleep 0.3; kill -TERM $p; wait $p; echo rc=$?' 2> setm.err; cat setm.err   # 期望泄漏 [1]+  Terminated
cat > inner.sh <<'EOF'
#!/usr/bin/env bash
echo $$ > "$PIDF"; trap 'exit 143' TERM; sleep 30 & c=$!; wait $c; exit 143
EOF
chmod +x inner.sh; export PIDF="$T/pidfile"
setsid --wait ./inner.sh & sp=$!
for i in $(seq 1 100); do [[ -s $PIDF ]] && break; sleep 0.05; done
pg=$(cat "$PIDF"); ps -o pid=,pgid=,comm= -p "$pg"    # 期望 PID=PGID
kill -TERM -- "-$pg"; wait $sp; echo "setsid --wait rc=$?"   # 期望 143
cd / && rm -rf "$T"

# facade wait 循环/spawn-gap 语义复跑脚本见本报告「逐项审查」第 2 节（mktemp 内执行，已验证 rc 129/130/143、双流空、无挂死）
````
