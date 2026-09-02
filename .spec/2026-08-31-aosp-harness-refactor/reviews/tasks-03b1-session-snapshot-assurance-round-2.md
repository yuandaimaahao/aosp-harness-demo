# tasks review: 2026-09-02-03b1-session-snapshot-assurance round 2（范围受限 re-review）

审查人：独立文档审查 agent（全新上下文，与起草者/控制器/round 1 reviewer 无关）
日期：2026-09-02
对象：`.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-02-03b1-session-snapshot-assurance/tasks.md`（fix round 1 后稿）
范围：仅复核 round 1 的 B1/B2/S1/S2 是否闭合及修复是否引入新问题；round 1 已通过的项（需求并集、消费链、编号、manifest awk、顺序门等）未重审。
对照：同目录 requirements.md、design.md；prototype `cbdbdde:.../prototype/snapshot-assurance-r1.sh`（308 行）；provider `main:common/.harness/lib/session-state-snapshot.sh`。

## 结论

**NEEDS_CHANGES** —— 阻断 0 / 重要 1 / 次要 0

B1、B2、S1、S2 四项原 finding 本身均已闭合（逐条 grep -cF 独立复核，证据见下）；但 S2 的修法在 E1 注释块内逐字写入了探针定位字面量本身，使整合后候选文件的该字面量从「恰 3 处」变为 4 处，步骤 4 的前提句与步骤 5 的 index 定位说明随之成为对产物的错误陈述，且该注释自相违反其内嵌约束。机械命令按文仍可侥幸通过（rindex 不受影响、探针落在注释行前顶层位置仍输出 checks=0），故不定阻断；但这是字节级规格文档对其自身产物的错误事实陈述，必须修复。

## 逐项复核

### 1. B1（E6(a) 锚文本连字符）——闭合

- `git show cbdbdde:.../snapshot-assurance-r1.sh | grep -cF 'cleanup_log=$tmp/cleanup-log'` = **1**；下划线写法 `cleanup_log=$tmp/cleanup_log` = **0**。tasks.md:108 的锚文本与替换后文本均为连字符，并显式注明「下划线写法在 308 行全文中出现 0 次」。✔
- 其余锚文本/替换键抽查（全部 grep -cF，要求各精确一次）：
  - E1 锚 `repo=$(git -C "$here" rev-parse --show-toplevel)`：prototype 1 次（第 4 行）✔
  - E2 锚 `provider=${SNAPSHOT_CORE:-$here/snapshot-core-r2.sh}`：1 次（第 5 行）✔
  - E4 锚 `python3 - "$provider" "$copy" <<'PY'`：1 次（第 10 行）✔
  - E6(b) 锚 `  : >"$cleanup_log"`：1 次（循环内）✔
  - E6(c) 锚 `    publish-success) ASSURANCE_PUBLISH=signal-success run_rc 143 _harness_session_snapshot_write_core project session alpha ;;`：1 次 ✔
  - E6(d) 锚 `  [[ $action != cleanup-close ]] || check_eq "$action all close attempts" 5 "$(wc -l <"$cleanup_log" | xargs)"`：1 次 ✔
  - E5 插入位键 `"    raise Interrupted"`：prototype heredoc replacements 字典内 1 次（第 80 行）✔
  - E5 新条目键（16 空格 `try: os.unlink(temp, dir_fd=dir_fd)` 行）：provider 原文 1 次（第 148 行）✔；provider 第 7 行已 `import ctypes, errno, ...`，`errno.errorcode` 可用 ✔

### 2. B2（步骤 5 探针可达性）——闭合

- 控制流：provider-absent 克隆中 E3 首分支 `[[ ! -e $provider && ! -L $provider ]]` 命中即打印 inert 摘要 `exit 0`（tasks.md:74-77），第一处 inert printf 前插探针真实可达。✔
- `set -u` 问题：prototype 第 2 行 `set -u`，`checks=0` 在第 97 行才初始化（实测），位于 E3（插入在第 5 行后）之后；探针改用 `${checks:-0}` 可规避 unbound。✔
- 步骤文字（tasks.md:114）已写明不能复用步骤 4 的 rindex/`"$checks"` 探针的两条原因（inert 流程在 E3 即 exit 0 致末行探针不可达；提前引用 `"$checks"` 在 set -u 下崩溃）。✔
- 但步骤 5 的 index 定位说明受下方重要 finding 影响（「第一处即 E3 inert 分支」当前不成立）。

### 3. 次要项修复——均闭合

- S1：tasks.md:34（裁定 2）已标注 sizing 证据文档所记 293 行/236 断言为修复旧 close 顺序 mutant 前的早期测量、已过期，现行口径 308/400 行、240 断言；与 design.md sizing 节（第 202 行同口径标注）一致。✔
- S2：步骤 4（tasks.md:113）已显式化「全文恰 3 处」前提与三处位置分解，E1 块（tasks.md:56）已加注释约束。前提显式化动作本身完成，但约束的实现方式引入了下述新问题。✔（动作）/✘（实现，见重要 finding）

### 4. 修复区域与 requirements/design 一致性

- E6 系列替换产出与 design 的 `ASSURANCE_UNLINK_LOG` 机制（design.md:90）一致：注入值在 unlink 成功时追加 `success\n`、失败时追加 `errno.errorcode` 名；原 except 体第三行（`if not isinstance(exc, FileNotFoundError) ... raise`，20 空格）不在替换键内，替换后自然续接在新增日志行之后，语义保留。E6(d) 仅在 publish-success 迭代执行一次 `check_eq`（`[[ $action != publish-success ]] ||` 短路），241 = 240 + 1 口径不变。新 E5 条目进入 replacements 字典后自动获得 prototype 第 87 行 `assert text.count(old) == 1` 的 exact-once 保障，注入失败经 E4 的 `|| exit 1` 转 rc1，与 design「替换要求原文精确一次、否则注入自身 rc1」一致。✔
- E6(d) 用 `$(<"$unlink_log")` 比对该日志，与 prototype 既有 cleanup_log 计数同行模式一致；design「禁止 command substitution 验证成功流」针对 stdout/stderr 成功流（步骤 4/5 均用 `cmp`/`test ! -s` 字节比较），不冲突。✔
- `check-tasks.py` 重跑 rc=0；改动未触碰 requirements 需求并集与消费链；无新占位符或不可执行步骤。✔

## Findings

### 阻断

无。

### 重要

- **M1. E1 新增注释自身逐字包含探针定位字面量，使「恰 3 处」前提与两处定位说明全部失真。** tasks.md:56 插入候选文件的注释行原文为「`# 注意: 注释只写摘要文字，不得包含 printf 'RESULT PASS  session snapshot assurance\n' 字面量（…）`」——它与步骤 4/5 的 python 定位键 `printf 'RESULT PASS  session snapshot assurance\n'` 逐字节相同（grep -nF 实测 tasks.md:56 命中）。整合后候选文件该字面量将是 **4 处**（E1 注释、E3 ×2、prototype 末行）而非步骤 4 所述「恰 3 处」；步骤 4 的「E1 注释按 E1 内嵌约束只含摘要文字、不含此 printf 字面量」成为假陈述，注释自相违反其内嵌约束；步骤 5 的「第一处（index，即 E3 provider-absent inert 分支）」也不成立——`str.index()` 会命中 E1 注释行（候选文件前部），探针被插到注释行前的顶层位置、对一切调用提前执行（default absent 实跑三项断言仍会侥幸通过：顶层探针输出 checks=0、不影响 stdout、rc0）。命令按文不至于必失败，故不定阻断；但执行 subagent 若按步骤 4 的明示前提做 `grep -c == 3` 核对即得 4，必然卡壳或自行改写——这正是 B1 被定阻断的同类风险。修法（一行）：把 E1 注释改写为不含该逐字串的形式（如「不得包含成功摘要的 printf 调用字面量」或对引号/反斜杠做非逐字转述），使候选文件恢复恰 3 处，步骤 4 前提与步骤 5 的 index 说明随之自动成立。

### 次要

无。

## 附：本次独立复核命令（可复现）

```bash
R=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo
P=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/prototype/snapshot-assurance-r1.sh
git -C "$R" show "cbdbdde:$P" | grep -cF 'cleanup_log=$tmp/cleanup-log'   # =1（下划线版=0）
git -C "$R" show "cbdbdde:$P" | grep -nF 'checks=0'                       # 第 97 行
git -C "$R" show main:common/.harness/lib/session-state-snapshot.sh \
  | grep -cF '                try: os.unlink(temp, dir_fd=dir_fd)'        # =1（第 148 行）
grep -nF "printf 'RESULT PASS  session snapshot assurance\n'" \
  "$R/.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-02-03b1-session-snapshot-assurance/tasks.md"
# 命中 56（E1 注释，新问题）、75/91（E3 ×2）；prototype 全文仅末行 1 处
```
（只读操作，对仓库零改动。）
