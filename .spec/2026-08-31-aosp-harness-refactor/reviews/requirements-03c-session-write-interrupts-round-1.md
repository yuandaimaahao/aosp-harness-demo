# requirements review: 2026-09-03-03c-session-write-interrupts round 1

- 审查人： 独立文档审查 agent（全新上下文，非起草者/控制器）
- 日期： 2026-09-03
- 对象： `.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-03-03c-session-write-interrupts/requirements.md`（仓库 `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo`，工作树中该文件为 M 状态）
- 对照： PLAN v5.7（第 52 行表格行、03c 专节、依赖边表、第 28 行 inert 通用口径）、DECISIONS.md（03b/03b1 验收行、03b1 上游六文件裁定）、03b requirements+design、03b1 requirements、`common/.harness/lib/session-state-snapshot.sh` 与两个已合入测试的实际文本

## 结论

**PASS**。阻断 0 / 重要 0 / 次要 2（均为措辞级备注，不阻断门②通过；其中 1 条建议在门③ design 时正面回答）。

## 逐项审查

### 1. R 条目机械可验证性、编号、来源标记、与 PLAN 03c 专节逐字口径

- 编号 R1–R8 连续无跳号；全部标记 `[计划]`，无 `[推断]`/`[默认]`，不存在未确认项。frontmatter `已由用户确认: true`，`确认依据` 引用的 DECISIONS 两行（2026-09-02 03b 验收、2026-09-03 03b1 验收 checks=241）经逐字核对存在且内容相符。
- facade 三状态变量：R4 `pending_signal/child_pid/child_rc` 与 PLAN 03c 专节逐字一致。
- spawn-gap 补转发：R4「spawn与trap安装之间的spawn-gap收到信号必须补转发」= PLAN「spawn-gap补转发」，且 R6/验收清单第 3 条把它落成可执行测试矩阵行。
- first-signal-wins：R4「facade锁存首信号（first-signal-wins）」+ R5「后续信号不改变已锁存码」= PLAN 口径。
- facade/process-group：R4「向child PID及其process-group转发HUP/INT/TERM」、R5「facade自身或其process-group收到」= PLAN「facade/process-group HUP/INT/TERM」。
- 不复制 temp/publish、不修改 snapshot：R3「facade不得复制temp/publish逻辑，不得修改snapshot模块」+ 超出范围第 2 条 = PLAN 逐字口径。
- 三 export 验证：R1 列出的 `_harness_session_snapshot_worker` / `_harness_session_snapshot_write_core` / `_harness_session_snapshot_read_core` 经实际代码核对（`session-state-snapshot.sh:4,206,207`）正是现存的全部三个 export 名，与 03b design.md:53 精确调用签名一致。
- inert 不定义 export/API/marker：R2「保持signals export、四个状态public API与provider marker全缺席」= PLAN「任一缺席都静默inert且不定义signals export/public API/marker」，且符合 PLAN 第 28 行 inert 通用口径（固定 PASS 摘要退 0）。
- 精确接口 `_harness_session_write_with_signals <project-id> <session-id> <feature>`、常规沿用 write `0|1|2|3`、信号 `129|130|143`：frontmatter 产出、R3、R5 与 PLAN 专节及 `03c -> 03d` 依赖边逐字一致。

### 2. 验收清单 ↔ R 映射、主验证命令、不变量

- 映射无遗漏：清单 1→R1+R2；2→R3；3→R4+R5；4→R6；5→R7；6→R8；7→R7+R8。无孤儿清单项、无未被清单覆盖的 R。
- 主验证命令 `bash ./tests/test-session-signals.sh`，期望输出「dependency-present时退出码`0`、stderr空，stdout逐字节精确为`RESULT PASS  session write interrupts\n`」——与 PLAN 第 52 行判据逐字一致（PASS 后两空格，与仓库既有 `RESULT PASS  session snapshot safety` 等摘要同一格式约定）。inert 与 active 同摘要的歧义由清单第 4 条「只有dependency-present active证据计入本片验收」封闭，与 03b/03b1 已验收模式相同。
- 不变量恰 4 项（2–4 区间内），第 4 项含上游七文件 BASE..HEAD 零变更且给出完整 `git diff --name-only` 机械命令；七文件 = 03b1 裁定的六文件 + 03b1 自身交付的 assurance 测试，符合 DECISIONS 2026-09-02「后序片在此基础上累加各自前序交付」。
- R7 的 SHA-256 校验集与不变量 4 的 diff 集同集（七文件两处逐一比对一致），满足「SHA 校验集与 BASE..HEAD 零变更 diff 集必须同集」裁定。

### 3. R 间矛盾/可执行性

- inert 与 active 分流机械可分：判据是「三个 snapshot export 是否全部定义」（R1/R2），fixture 逐个移除 export 即可；03c 不像 03a2/03b1 承担 anchor/provider-copy 反证，因此无 fail-closed 分支是合理的，与 03b 基础测试 R7 的已验收先例完全一致。
- rollback/顺序门可执行：R8 的回滚验证只跑已存在的 03b 基础测试、03b1 assurance 与 offline（PLAN 回滚矩阵中 03c 行引用的 03d/03e/08 测试尚不存在，不可执行，此处取可执行子集，与 03b R9/03b1 R10 的先例一致）；03d 缺席核对用 nullglob `ls -d`、`git show-ref | rg`、`git worktree list --porcelain | rg`、`rg` 四种机械命令，且「日期前缀由创建日决定，本片不预知」使规范 ID `03d-session-remove-prune` 日期无关，形式可机械执行（`rg` 在 DECISIONS 02 行已列为 offline 必需依赖）。
- sizing：R7「numstat总和`<=400`」与 PLAN 全局 400 行门一致；exact 两文件（`session-state-signals.sh` + `test-session-signals.sh`）与 PLAN 第 79 行 03c 独占边界一致。
- shfmt `v3.14.0` / ShellCheck `0.11.0` 版本钉与 DECISIONS 02 行及 03b/03b1 R8/R9 先例一致。

### 4. 与 03b/03b1 已验收契约的一致性

- 129/130/143：HUP/INT/TERM = 128+1/2/15，与 03b R4、03b design.md:59/190、DECISIONS 03b 验收行一致。
- 双流纪律：R3「全部双流空」与 03b write core/worker write 双流空协议一致；消费字段「worker read成功feature+LF/0、失败双流空1|2|3」逐字符合 03b 产出。
- worker 接口签名：消费字段与实际代码、03b design.md:53 一致；R4「直接background spawn-only worker取得真实child PID」= PLAN `03b -> 03c` 边「直接background worker取得真实child PID」。
- `HARNESS_SESSION_STATE_PROVIDER_VERSION` 不设置：R1、目标节、超出范围第 1 条三处一致，与 03b/03b1 相同口径。
- inert 摘要格式：与 PLAN 第 28 行及 03b/03b1 的「同一固定摘要退出0」一致；`--dependency-absent` flag 满足 PLAN 回滚命令表对 `test-session-signals.sh --dependency-absent` 的引用。

### 5. 机械检查实测

```
$ python3 ~/.agents/skills/spec/scripts/check-req.py <文件>        → rc=0（无输出）
$ python3 ~/.agents/skills/spec/scripts/check-criteria.py <文件>   → rc=0（无输出）
$ python3 ~/.agents/skills/spec/scripts/check-analyze.py <文件>    → rc=0（无输出）
$ python3 ~/.agents/skills/spec/scripts/check-plan.py .spec/2026-08-31-aosp-harness-refactor/PLAN.md → rc=0（无输出）
$ git diff --check -- <文件>                                       → rc=0（无输出）
```

全部通过，无 whitespace 错误。

## Findings

### 阻断（0）

无。

### 重要（0）

无。PLAN 03c 专节全部承诺（facade 三变量、spawn-gap、first-signal-wins、facade/process-group、不复制 temp/publish、不改 snapshot、三 export 验证、inert 口径、精确接口与摘要、exact2/400、顺序门）均在 R 或验收清单中有着落，未发现口径漂移或不可机械验证条款。

### 次要（2）

1. R4「向child PID及其process-group转发」：非 job-control shell 中 `&` 后台子进程默认与 facade 同 process group，「child 的 process-group」如何建立/转发而不把信号打回 facade 自身，是实现机制问题。与 PLAN 措辞一致、不构成 requirements 矛盾，但建议门③ design 正面回答（如 worker 是否放入独立 pgroup、forward 目标如何界定）。
2. R6「默认与flag运行同一inert surface」中「flag」是 `--dependency-absent` 的缩写指代，上下文无歧义，仅措辞紧凑；不改亦可。

## 附：复核命令

````bash
cd /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo
F=.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-03-03c-session-write-interrupts/requirements.md

# 结构/口径检查器（均期望 rc=0、无输出）
python3 /home/zzh0838/.agents/skills/spec/scripts/check-req.py "$F"
python3 /home/zzh0838/.agents/skills/spec/scripts/check-criteria.py "$F"
python3 /home/zzh0838/.agents/skills/spec/scripts/check-analyze.py "$F"
python3 /home/zzh0838/.agents/skills/spec/scripts/check-plan.py .spec/2026-08-31-aosp-harness-refactor/PLAN.md

# whitespace
git diff --check -- "$F"

# 三 export 名实际核对（期望命中 worker/write_core/read_core 三处）
grep -nE '^[[:space:]]*_harness_session_snapshot_(worker|write_core|read_core)\s*\(\)' \
  common/.harness/lib/session-state-snapshot.sh

# PLAN 对照点
grep -n '03c-session-write-interrupts' .spec/2026-08-31-aosp-harness-refactor/PLAN.md
grep -n 'RESULT PASS  session write interrupts' .spec/2026-08-31-aosp-harness-refactor/PLAN.md "$F"

# DECISIONS 验收行对照
grep -n '03b-session-snapshot-safety 验收\|03b1-session-snapshot-assurance 验收\|上游集合裁定' \
  .spec/2026-08-31-aosp-harness-refactor/DECISIONS.md
````
