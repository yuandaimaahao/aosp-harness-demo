# Review 报告： 03c-session-write-interrupts 任务 1.2 round 2（修复后复审）

**结论： PASS**（阻断 0 / 重要 0 / 次要 1）

- TASK_BASE=`a8d3859f639eed64b0d1e74eb1461c8e32e64a45` → TASK_HEAD=`648fe667396e6273f7d497479f16d7daf4560d18`（amend 单提交）；execution BASE=`c9c82264b3f819a6a6449a0242e102e97b35c3b0`
- worktree HEAD==TASK_HEAD、`git status --porcelain` 为空；与实现者、round 1 reviewer 无共享上下文，全部结论基于独立实跑

## Findings

### F2 [次要] tasks.md 与 brief 中 mutant-a 旧表述未随 controller 裁定同步

- **位置**: `tasks.md:36`（裁定 3(a)）、`tasks.md:77`（步骤 5）；`task-1.2-brief.md:292`、`:333`、`:466`
- **问题**: 上述位置仍写 mutant-a「worker 收不到补转发会被 barrier 封闭为 hang，由 `timeout` 判 FAIL」，与 controller F1 修复裁定（前向观测日志缺席判 FAIL、timeout 纯兜底）及已交付实现直接矛盾。design.md 四处已带「执行期修订」标注同步，但这五处没有。
- **影响评估**: 不影响交付物正确性与任何验收门——controller 裁定本身权威且 report 的 task/files/results 节明确记录了修复依据；任务 2.1–2.3 只重跑测试入口、不重跑 mutant 步骤。仅属 spec 文档同步遗漏，建议 controller 补注，不需要实现者改代码。违反任务书条目： 无（验收权威已由 controller 执行期裁定修订，实现符合修订后口径）。
- **可复现命令**: `grep -n "封闭为 hang" tasks.md task-1.2-brief.md`
- **controller 处置（落盘时补记）**: tasks.md 裁定 3(a) 与步骤 5 已加「执行期修订」标注；brief 为 task-brief.py 生成的时点产物、不重生成，以 tasks.md 标注为准。

## 逐项复核结果（1–6）

**1. F1 闭合 — 通过（核心）。** 通读修复后 `tests/test-session-signals.sh` 全文（325 行）：

- (a) **正确模块下无残留 hang/竞态路径**：
  - probe 包装（`tests/test-session-signals.sh:155-158`）把补转发行文本包装为 `{ 落日志; kill; }`，**日志写在 kill 之前**——oracle 是「补转发已执行」，kill 失败（child 已死）仍记日志，不会被误判；mutant-a 删整行则包装目标缺席（`assert text.count(reforward) <= 1` 对 0 次静默通过）、日志确定性缺席。方向安全：模块若改动该行文本只会假红、不会假绿。
  - driver gap 轮询（:277-281）`while [[ ! -e $barrier ]] && kill -0 "$wrapper"`：child 被杀死则 wrapper 很快退出使 `kill -0` 失败；被吞则 barrier 必然出现（probe 在 TEMP_BEFORE_PUBLISH 无条件落 barrier）；**两条路径都必然退出循环**。wrapper 整体外包 `timeout 20`，即使出现未预见病理，driver 循环也被 wrapper 死亡封顶在 20s 内，结局是 rc124 FAIL 而非测试挂死——timeout 确为纯兜底。
  - 放行后处理： 删 barrier → child 正常发布 beta → facade 因 pending_signal 已在 BEFORE_SPAWN anchor 锁存而返回恰 129/130/143（与 child 结局无关）；`wait "$wrapper"` 保证 rcfile 写完后才读。target winner 断言（:289-296）为 absent/beta 析取，送达（absent）与被吞（beta）两结局均证；temp=0 两结局下都成立（child handler 自清或发布改名）。第二信号与首信号在同一 anchor 注入块内顺序 `kill`，bash 在第一条 kill 内建返回后即运行 trap 锁存，第二信号被守卫吞掉，确定性。
- (b) **mutant-a 确定性 FAIL（自构实跑）**: python 删模块行 31 补转发行 → `SIGNALS_MODULE=$d/mutant-a bash ./tests/test-session-signals.sh` → **rc1，2.8s 完成无 hang**，stdout `RESULT FAIL session write interrupts checks=139 failures=6` 无 PASS，stderr 恰 6 行 `FAIL gap HUP|INT|TERM reforward signal want=… got=missing` + `reforward pid numeric want=yes got=no`，无 124。与正确模块失败签名完全可区分，F1 假红机制消除。
- (c) **mutant-b（自构实跑）**: 三处 trap 去 `[[ -n $pending_signal ]] ||` 守卫 → rc1 无 PASS，15 行 FAIL（12 行 latched rc 被第二信号覆盖 HUP→143/INT→143/TERM→129 + 3 行 gap 日志记下被覆盖信号），签名与 round 1 一致并多出 3 行观测（report 第 42 行已如实记载）。

**2. flake 独立复验 — 通过。** worktree 内实跑 **default ×10 + all ×10 = 20 次**（mktemp 目录落盘）：全部 rc0；20 份 stdout 与 `printf 'RESULT PASS  session write interrupts\n'` `cmp -s` 逐字一致；20 份 stderr 全部 0B。单次运行约 2.7s，gap 行不再有 20s 挂起。F1 的 ≈17% 假红未复现。

**3. 全量门（新 HEAD 下全部重跑）— 通过。**
- `git diff TASK_BASE TASK_HEAD --name-only` 恰 `tests/test-session-signals.sh` 单文件；`BASE_SHA..TASK_HEAD` 恰 signals 模块+测试两文件；numstat 总和 **370 ≤400**；UPSTREAM7 diff 空。
- printf 探针字面量 `rg -cF` = **2**（inert 出口 line 20、active 末行 line 325）。
- 工具版本逐字核： shfmt `v3.14.0`、ShellCheck `version: 0.11.0`；`shfmt -d -i 2 -ci -bn` 无输出 rc0；`shellcheck -x --severity=warning` rc0；`bash -n` rc0；`git diff --check` rc0。
- rindex 计数探针（末处字面量前插 `printf 'checks=%d\n' "$checks" >&2`，用后 `git checkout` 恢复并核 clean）：default 与 all 均 rc0、stderr 逐字同为 `checks=139`，default==all 双流逐字一致。
- argv 表： `--bogus` / `all extra` / `--dependency-absent=x` 各 rc1、stdout 0B 无 PASS。
- provider-absent 三态： `git clone --no-local` + rm 模块后无参数/all/`--dependency-absent` 均 rc0、同一 inert 摘要、stderr 0B；index 探针（两空格缩进 `${checks:-0}`）rc0、stderr 恰 `checks=0`；另 clone 全局改名 `_harness_session_snapshot_read_core` 后 default 同 inert 面（rc0/逐字/0B）。

**4. 修复与 design 修订一致性 — 通过。** design.md 四处「执行期修订」与实现逐一对应： mermaid note（:138 driver 放行/hang 不作 oracle ↔ :277-281）、错误处理表 spawn-gap 行（:155 前向观测日志+absent/beta 析取 ↔ :155-158、:289-311）、集成行（:169 facade/wait/group 无 winner、gap 析取）、性能行（:173 timeout 纯兜底 ↔ :221、:248）。搜「挂起/hang/无 winner」：design 内残留「hang」仅出现在修订注记自身；:123「无winner」属运行中窗口图（facade 行仍核无 winner，正确）。design 无未同步旧表述。tasks.md/brief 的旧表述见 F2（次要）。

**5. 证据一致性 — 通过。** evidence.tsv **88 行逐行实算 path/sha256/bytes 全部一致**；red 文件未变（rc127、stdout_sha256=e3b0c442…、stderr_sha256 与实算 `bash: tests/test-session-signals.sh: No such file or directory\n` 的 d8c5bc9d… 一致）；report 六节齐全、第 47 行红阶段证据路径独占行（`cat -A` 核行尾 `$`）；review 包 `review-a8d3859f-648fe667.md` 内嵌 diff 与真实 `git diff TASK_BASE TASK_HEAD` **逐字节一致**（python 比较 True）；84 个日志抽查：flake 20 组 stdout 全部逐字摘要、stderr 全 0B，count 日志 checks=139 双一致，mutant-a/b 日志与实跑输出一致，absent 三态+inert 探针 checks=0 一致。

**6. 范围 — 通过。** worktree HEAD==`648fe667…`==TASK_HEAD，clean；diff 只含测试文件；`git diff TASK_BASE TASK_HEAD -- common/` 为 0 字节，模块与 TASK_BASE 逐字未变；全部运行后无孤儿进程、无 `.count.*` 残留，探针改动已 `git checkout` 恢复并复核 clean。manifest 目前仅 task-1.1 行，task-1.2 行按流程待本 review PASS 后追加，符合预期。

## 备注

- reviewer 未改动任何仓库/worktree/spec 文件；所有 mutant、clone、flake 输出均在 mktemp 目录内构造并已清理。
- controller 已按建议在 tasks.md 裁定 3(a)/步骤 5 补「执行期修订」标注闭合 F2，check-tasks.py 复跑 rc0。
