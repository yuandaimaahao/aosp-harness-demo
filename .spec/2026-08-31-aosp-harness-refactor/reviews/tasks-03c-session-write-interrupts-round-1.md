# Review: 03c-session-write-interrupts tasks.md (round 1)

## Verdict: NEEDS_CHANGES

- 阻断: 1 / 重要: 1 / 次要: 3

---

## 阻断

### B1. 任务 1.2 步骤 7 累计断言用错 diff 范围 —— 用 `$TASK_BASE..$TASK_HEAD` 会把 1.1 的模块文件也算进"恰两文件"，断言必然失败

`specs/2026-09-03-03c-session-write-interrupts/tasks.md` 行 107（步骤 7）：

> 累计断言（恰两个文件/总 ≤400 行）在任务 2.2 步骤 2 通过 `"$TASK_BASE" "$TASK_HEAD"` 复核……

问题：任务 1.2 的 `$TASK_BASE` 是 1.1 完成后的 HEAD，而 1.2 的累计断言本意是验"本切片 **1.1+1.2 累计** 恰两文件 ≤400 行"（design sizing 45+345）。用 `$TASK_BASE..$TASK_HEAD` 只含 1.2 自己的 diff，恰两文件断言必然失败（只有 1 个文件）；反之若意图是单任务 diff，则"累计"措辞错误。无论哪种解读，当前文本是自相矛盾的。

复核命令：
```bash
sed -n '100,115p' specs/2026-09-03-03c-session-write-interrupts/tasks.md
```

修复方向：步骤 7 的累计断言改为对 `"$BASE_SHA" "$TASK_HEAD"`（execution-base 基准）执行；`"$TASK_BASE" "$TASK_HEAD"` 仅用于 manifest 相邻连续核验（03b/03b1 同构惯例）。

---

## 重要

### I1. 裁定 6 的禁令范围与任务 2.5 报告/日志的 `commands` 字段冲突

`tasks.md` 行 129（裁定 6）：

> 顺序门 NEXT 值、设计稿、requirements、ledger、本文件与 dispatch/执行计划正文中不得逐字出现 `03d-session-remove-prune`……

但行 88（任务 2.5 报告契约）要求 commands 字段记录实跑命令，而步骤 2 的顺序门命令若逐字记录就必然含 `03d-session-remove-prune` 字面量；同时步骤 2 又要求命令串里不得出现该字面量（用 `"$NEXT"` 间接形式）——这条已在步骤内化解，但裁定 6 的"ledger"也在禁令清单里，而任务 2.5/2.6 的 ledger 锚点行按惯例要记"顺序门通过"的依据，若照抄命令也会踩禁令。

风险：实现者在「记录证据」与「遵守裁定 6」之间无所适从，容易二选一踩坑。

复核命令：
```bash
sed -n '80,95p;125,135p' specs/2026-09-03-03c-session-write-interrupts/tasks.md
```

修复方向：裁定 6 澄清「报告/日志/ledger 中的命令记录一律用 `"$NEXT"` 间接形式（与步骤 2 一致）；禁令仅针对会被任务 2.6 终门 scoped rg 扫描的文本面（tasks/design/requirements/ledger/dispatch/execution-base）」。

---

## 次要

### M1. 顺序门命令的 `ls` 非匹配行为依赖执行 shell 未开 nullglob，前提未写明

`tasks.md` 行 84：`ls -d "$PROJECT"/specs/*"$NEXT"` 在 zsh 默认（NOMATCH）下直接报错，在 bash 默认下原样回显未展开的 glob —— 两种行为都导致命令输出非空/非零，但脚本风格指南假设 bash 默认。若执行者 shell 开了 nullglob，`ls` 无参数列当前目录，输出非空，门误判不通过（假红，方向安全但浪费循环）。建议补一句「执行者 shell 须为 bash 默认（无 nullglob）」或改用 `compgen -G` / `find` 写法。

### M2. 任务 2.5 步骤 2 的 `! ls -d ...` 与 `&&` 链组合在 `set -e` 下有陷阱

`! ls -d ... && test -z ...`：`!` 前缀使 `ls` 失败时整体成功，但 `ls` 成功（glob 命中）时 `!` 使其失败，`&&` 短路、整个命令以非零结束 —— 在 `set -e` 的 evidence 脚本里会直接退出，日志里看不到是哪一环命中。建议每环单独一行并显式 `echo` 判定结果。

### M3. 任务 1.2 步骤 5-6 的 mktemp 创建与覆盖注入写法可更明确

步骤 5「在 mktemp 目录放 mutant 副本」未写 `mktemp -d` 的具体变量名，与步骤 6 的 `$tmp` 衔接靠读者推断；建议统一为「`tmp=$(mktemp -d)`，mutant 副本放 `$tmp/`」。纯清晰度建议，不影响执行。

---

## 范围确认

- tasks.md 与 requirements.md R1–R8 逐条映射：8 条全覆盖（1.1→R1/R2/R6，1.2→R1-R6/R8 实跑，2.3→R7，2.5→R8，2.2/2.4/2.6 门与终任务）。
- 与 design.md 锁定项一致：正 PID 单点、两分支、exact 两文件、sizing 45+345、探针逐字串、mutant 双设计、SIGNALS_MODULE 覆盖注入、顺序门 NEXT。
- 与 03b1 tasks 同构性：父/2.1-2.6 结构、报告六节契约、红证据六行 schema、reviewer 硬门、fix 循环 r1-2/r3 均一致。
- 切片极简：唯一新模块 ≤45 行 + 唯一新测试 ≤345 行，无 README/CI 等范围外项。

## 复核命令汇总

```bash
cd /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo
sed -n '1,140p' .spec/2026-08-31-aosp-harness-refactor/specs/2026-09-03-03c-session-write-interrupts/tasks.md
python3 /home/zzh0838/.agents/skills/spec/scripts/check-tasks.py .spec/2026-08-31-aosp-harness-refactor/specs/2026-09-03-03c-session-write-interrupts/tasks.md
```
