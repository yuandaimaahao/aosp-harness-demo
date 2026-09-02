# Review: 03c-session-write-interrupts tasks.md (round 2)

## Verdict: PASS

- 阻断: 0 / 重要: 0 / 次要: 0

round 1 裁定 NEEDS_CHANGES（阻断 1 / 重要 1 / 次要 3），本轮逐条复核修复闭合情况，并全量重读 tasks.md 确认无新增问题。

---

## round 1 findings 闭合复核

### B1（阻断）任务 1.2 步骤 7 累计断言 diff 范围错误 —— 已闭合

现 tasks.md 步骤 7（行 79）改为：恰两文件 / ≤400 行 / 上游七文件为空三项累计断言一律对 `"$BASE_SHA" "$TASK_HEAD"`（execution BASE）执行，并内联写明理由——`$TASK_BASE` 是任务 1.1 的 HEAD，该范围只含本任务单提交，name-only 必缺一文件；`$TASK_BASE` 仅保留给步骤 8 的 manifest 行与相邻连续性，与任务 2.1 步骤 3 口径一致（任务 2.1 步骤 3 同样使用 `"$BASE_SHA" HEAD`，行 94，交叉一致）。

复核：`sed -n '79p;94p' specs/2026-09-03-03c-session-write-interrupts/tasks.md`

### I1（重要）裁定 6 禁令范围与报告 commands 字段冲突 —— 已闭合

裁定 6（行 39）重写为：硬禁令只覆盖 scoped rg 实际搜索的三类文件（`specs/*/ledger.md`、`work/*/dispatch.tsv`、`work/*/execution-base.env`）；green/red 报告与运行日志不在 rg 域内、不受硬禁令约束，但任务 2.5 的报告与日志中命令一律以步骤 2 已定义的 `"$NEXT"` 间接形式记录。任务 2.5 步骤 2（行 157）确实先定义 `NEXT=03d-session-remove-prune` 后全部经 `"$NEXT"` 间接引用，步骤 4（行 159）scoped rg 文件收集与裁定 6 的域逐字一致。证据记录义务与禁令不再冲突。

复核：`sed -n '39p;157,159p' specs/2026-09-03-03c-session-write-interrupts/tasks.md`

### M1（次要）顺序门 ls 行为依赖未开 nullglob、前提未写明 —— 已闭合

任务 2.5 步骤 2（行 157）新增前提：「执行 shell 不得开 nullglob——未匹配 glob 需按字面传给 `ls`、由其 rc2 经 `!` 判缺席」。

### M2（次要）`! ls -d ... && test -z ...` 在 set -e 下短路陷阱 —— 已闭合

任务 2.5 拆为步骤 2（spec/work 目录缺席，两条独立 `! ls -d`）、步骤 3（分支零匹配、worktree 零匹配，各自独立 `test -z`）、步骤 4（scoped rg 单独一行，且显式禁止 `&&` 链 ls）。无任何 `! cmd && cmd` 组合。

### M3（次要）mktemp 变量衔接不明 —— 已闭合

任务 1.2 步骤 5（行 77）统一为 `mktemp -d` 配合 `$tmp/mutant-a`、`$tmp/mutant-b`；步骤 6（行 78）用 `$tmp/r`、`$tmp/e`；任务 2.1 步骤 2（行 93）显式 `tmp=$(mktemp -d)`。衔接无推断成本。

---

## 全量重读确认（无新增 findings）

- requirements R1–R8 映射保持完整：1.1→R1–R5，1.2→R1–R6，2.1/2.2/2.3→R7，2.4/2.5→R8，2.6→R7/R8。
- 与 design 锁定项一致：正 PID 单点转发、双分支（pending 锁存/透传）、exact 两文件、sizing 45+345≤390、探针逐字串恰 2 处、mutant 双设计经 `SIGNALS_MODULE` 覆盖注入、双 anchor marker、顺序门 NEXT 日期无关。
- 与 03b/03b1 tasks 同构：报告六节契约、红证据六行 schema+`assertion=`、evidence TSV 三列、manifest 六列与八行 awk 全量核验（任务 2.6 步骤 4，含 `prev != head` 终值断言）、fix 循环 r1-2 唤回/r3 换新、inert PASS 不解除后序门（裁定 7）。
- check-tasks.py 结构校验通过（controller 实跑 rc0）。

## 范围外观察（非 finding，备查不阻断）

1. requirements.md R8「以 nullglob 下 ls -d 缺席」措辞与 tasks 前提（不得开 nullglob）方向相反，是 R8 描述验收思路的松散措辞，tasks 层面已钉死正确前提，本片无需改 requirements；后续切片若重述 R8 可顺手澄清。
2. 任务 1.2 步骤 5–6 与任务 2.2 步骤 2 的 `$tmp` 在各自步骤内由 `mktemp -d` 赋值但赋值语句写在与使用不同的子句，属既有文本风格，执行者按顺序读无歧义。

## 复核命令汇总

```bash
cd /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo
sed -n '1,190p' .spec/2026-08-31-aosp-harness-refactor/specs/2026-09-03-03c-session-write-interrupts/tasks.md
python3 /home/zzh0838/.agents/skills/spec/scripts/check-tasks.py .spec/2026-08-31-aosp-harness-refactor/specs/2026-09-03-03c-session-write-interrupts/tasks.md
```
