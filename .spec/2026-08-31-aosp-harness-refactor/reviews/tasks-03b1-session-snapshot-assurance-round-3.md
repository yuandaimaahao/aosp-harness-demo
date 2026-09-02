# tasks review: 2026-09-02-03b1-session-snapshot-assurance round 3（范围受限 re-review）

审查人：独立文档审查 agent（全新上下文，与起草者/控制器/round 1/round 2 reviewer 无关）
日期：2026-09-02
对象：`.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-02-03b1-session-snapshot-assurance/tasks.md`（fix round 2 后当前工作区版本，未提交，`git status` 显示 `M`）
范围：仅复核 round 2 唯一重要 finding M1 是否闭合及本次修复是否引入新问题；round 2 已闭合项（B1/B2/S1/S2）与 round 1 已通过项（需求并集、消费链、编号、manifest awk、顺序门等）未重审。
对照：同目录 requirements.md、design.md；prototype git 对象 `cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e:.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/prototype/snapshot-assurance-r1.sh`（实测 308 行）。

## 结论

**PASS** —— 阻断 0 / 重要 0 / 次要 0

M1 已按 round 2 指定修法闭合：E1 注释行改写为不含探针定位字面量的非逐字形式，约束语义保留；整合后候选文件该字面量恢复恰 3 处（E3 ×2 + prototype 末行 ×1），步骤 4 前提句与步骤 5 的 index 定位说明重新成立。修复未引入新问题，`check-tasks.py` rc=0。

## 逐项复核

### 1. M1（E1 注释逐字含探针字面量）——闭合

**(a) E1 注释行不再逐字含该字面量。** `grep -nF "printf 'RESULT PASS  session snapshot assurance\n'" tasks.md` 实测输出：

````
75:  printf 'RESULT PASS  session snapshot assurance\n'
91:  printf 'RESULT PASS  session snapshot assurance\n'
113:- [ ] 步骤 4: …（指令行，含该字面量作为 python 定位键）
114:- [ ] 步骤 5: …（同上）
````

round 2 的命中行 56（E1 注释）已不再命中。现 tasks.md:56 原文为：

````
# 注意: 注释只写摘要文字，不得包含固定摘要的 printf 调用（步骤 4/5 探针按该调用字面量的出现次数定位）。
````

——非逐字形式（无 `printf '...'` 调用串、无引号与 `\n`），且完整保留了「注释不得包含成功摘要 printf 调用」的约束语义，并附了该约束存在的理由（步骤 4/5 探针按出现次数定位）。✔

说明：113/114 两处的命中位于步骤 4/5 的**执行指令**文本中（该字面量是 python 探针的定位键），这两行不进入候选文件；候选文件内容只来自 E1–E6 整合块。round 2 附录只列 56/75/91 亦是按「候选文件归属」口径的摘列，两处指令行命中不影响 M1 的判定口径。

**(b) 整合后候选文件该字面量恰 3 处，重新核算：**

- E1–E6 整合内容区域（tasks.md 48–108 行）内 `grep -nF` 仅命中相对行 28、44，即绝对行 75、91——恰为 E3 的 provider-absent inert 分支（tasks.md:74-77）与 mode-absent inert 分支（tasks.md:90-93）两处。E1（50-63）、E2（65-69）、E4（96）、E5（98-106）、E6（108）的锚文本与替换/插入文本均不含、也不消除该字面量。✔
- prototype blob：`git show cbdbdde…:…/snapshot-assurance-r1.sh | wc -l` = **308**；`grep -nF` 全文仅命中 **308**（末行 active 出口）。E1–E6 的改动点均不在第 308 行（E6 四处替换均在信号窗口循环区域，round 2 已核锚各精确一次），末行字面量保留。✔
- 合计：候选文件 = prototype（1 处，末行）+ E3（2 处）+ E1/E2/E4/E5/E6（0 处）= **恰 3 处**。✔

**(c) 步骤 4 前提句与步骤 5 index 定位说明重新成立：**

- 步骤 4（tasks.md:113）「该定位的前提是全文恰 3 处此字面量：E3 的 provider-absent inert 分支（第 1 处）与 mode-absent inert 分支（第 2 处）、prototype 末行 active 出口（第 3 处）」——E3 紧随 prototype 第 5 行后插入，其两处均位于文件前部，prototype 自有的一处在末行，三处位置分解与「rindex 即末行 active 出口」成立；「E1 注释按 E1 内嵌约束只含摘要文字、不含此 printf 字面量」从假陈述变为真陈述。✔
- 步骤 5（tasks.md:114）「第一处`printf '…'`（`index`，即 E3 provider-absent inert 分支）」——E1 注释不再含该字面量后，候选文件中第一处确为 E3 provider-absent inert 分支（tasks.md:75 对应的插入代码），`str.index()` 定位正确。✔

### 2. 修复是否引入新问题——未发现

- **改动区域**：E1 代码块现为 4 行注释 + `case ${1-} in … esac` + `[[ $# -le 1 ]] || exit 1`（tasks.md:53-62），CLI 分流逻辑与 round 2 一致，仅注释行 56 措辞变化；注释变化不进入任何锚文本/替换键。tasks.md:55 `# 成功唯一摘要: RESULT PASS  session snapshot assurance` 只含裸摘要文字（无 printf 调用），与 design.md:5「成功唯一输出 `RESULT PASS  session snapshot assurance`」一致，且不与任何探针键冲突（步骤 4/5 探针键是全 printf 字面量；任务 2.1–2.3 的 `rg -c 'RESULT PASS  session snapshot assurance'` 作用于 offline.log 运行时输出而非候选文件）。✔
- **requirements/design 一致性**：R2（requirements.md:21）要求 provider-absent 时 inert 分支以固定摘要逐字 rc0、provider 损坏 fail-closed——E3 两处 printf 与该注释约束均无冲突；design.md:49 active/inert 成功 stdout 逐字、stderr 空、rc0 的调用面描述不变。需求映射（R1–R10 分工）与消费链未被本次修复触碰。✔
- **锚文本/替换键抽查**（grep -cF 对 prototype blob，要求各精确一次）：E1 锚 `repo=$(git -C "$here" rev-parse --show-toplevel)` = 1（第 4 行）；E2 锚 `provider=${SNAPSHOT_CORE:-$here/snapshot-core-r2.sh}` = 1（第 5 行）；E6(c) 锚 `    publish-success) ASSURANCE_PUBLISH=signal-success run_rc 143 … ;;` = 1。✔
- **占位符/可执行性**：未产生新占位符；步骤 4/5 的探针指令随前提修复恢复可机械执行。✔
- **check-tasks.py**：从仓库根运行 `python3 /home/zzh0838/.agents/skills/spec/scripts/check-tasks.py <tasks.md>`，无输出，**rc=0**。✔

## Findings

### 阻断

无。

### 重要

无。

### 次要

无。

## 附：本次独立复核命令（可复现）

```bash
R=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo
T=$R/.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-02-03b1-session-snapshot-assurance/tasks.md
P=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/prototype/snapshot-assurance-r1.sh
B="cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e:$P"

# M1(a)：E1 注释行不再命中；75/91 为 E3 ×2（候选归属），113/114 为步骤指令行（不入候选）
grep -nF "printf 'RESULT PASS  session snapshot assurance\n'" "$T"
sed -n '52,57p' "$T"          # E1 注释块现行文本（非逐字约束）
sed -n '48,108p' "$T" | grep -nF "printf 'RESULT PASS  session snapshot assurance\n'"   # 仅 28/44（=75/91）

# M1(b)：prototype 308 行、字面量仅末行 1 处
git -C "$R" show "$B" | wc -l                                                        # =308
git -C "$R" show "$B" | grep -nF "printf 'RESULT PASS  session snapshot assurance\n'" # =308

# 锚文本抽查（各 =1）
git -C "$R" show "$B" | grep -cF 'repo=$(git -C "$here" rev-parse --show-toplevel)'
git -C "$R" show "$B" | grep -cF 'provider=${SNAPSHOT_CORE:-$here/snapshot-core-r2.sh}'
git -C "$R" show "$B" | grep -cF '    publish-success) ASSURANCE_PUBLISH=signal-success run_rc 143 _harness_session_snapshot_write_core project session alpha ;;'

# 校验器
python3 /home/zzh0838/.agents/skills/spec/scripts/check-tasks.py "$T"; echo "rc=$?"   # rc=0
```

（只读操作，对仓库零改动。）
