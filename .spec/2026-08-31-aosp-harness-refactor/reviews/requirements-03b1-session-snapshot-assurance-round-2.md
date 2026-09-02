# requirements review — 2026-09-02-03b1-session-snapshot-assurance round 2（范围受限 re-review）

- 审查对象：`.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-02-03b1-session-snapshot-assurance/requirements.md`（fix round 1 后，70 行）
- 对照材料：round-1 review 报告（PASS，重要 F1 + 次要 F2/F3/F4）、PLAN.md v5.7（03b1 节 line 122、依赖契约表、回滚矩阵）、03b requirements 契约
- 审查人：独立文档审查（全新上下文，与起草者/控制器/上一轮 reviewer 无关）
- 审查范围：仅核对 F1 闭合、三条次要修复情况、改动区域及周边是否引入新问题；未改动的 R1/R3–R8 沿用 round-1 结论。

## 结论

**PASS** —— 阻断 0 / 重要 0 / 次要 1

F1 已闭合；F2、F4 已修复；F3（R10 的 03c 启动门枚举缺「full/depth-1/offline 与回滚证据入ledger」字样）未修复，仍为次要，不阻断进入 design。

## ① F1（重要）闭合核对

- R9 现钉「当前tracked上游六文件（session-state-foundation.sh、session-state-path.sh、tests/lib/session-path-race-driver.py、tests/test-session-path-races.sh、session-state-snapshot.sh、tests/test-session-snapshot.sh）SHA-256 在测试前后不变」。
- 不变量 4 现钉「上游六tracked文件在 execution BASE..HEAD 的变更数 ≤ 0」，`git diff --name-only` 验证命令列出同一六文件全集。
- 验收清单第 9 条同步改为「每个checkout的上游六文件SHA-256测试前后不变且clean」。
- 三处机械判据覆盖集完全一致，且包含 03a1-driver 与 03a2-entrypoint，相对 03b 不变量 4 无倒退；全文无残留「五文件/四文件」字样。**闭合。**

## ② 三条次要修复核对

- F2（inert 摘要逐字）：✅ 已修。R2 现写「以同一固定摘要`RESULT PASS  session snapshot assurance\n`逐字退出0」，inert 分支的期望 stdout 自包含逐字给出；清单第 1 条「逐字同一inert摘要」可回溯到该定义。
- F3（R10 的 depth-1 字样）：❌ 未修。R10 的 03c 启动门枚举仍为「03b1 accepted HEAD、dependency-present完整矩阵、exact1/400与全PASS manifest入ledger」，缺 PLAN 03b1 节原文的「full/depth-1/offline与回滚证据入ledger」；清单末条同样只写「dependency-present完整矩阵入ledger」。沿用 round-1 判级：由 accepted HEAD 隐含（R9/R10 本身是验收前置），且 PLAN 依赖契约表 `03b1 -> 03c` 行同样未枚举 full/depth-1/offline，仍属次要，见 Findings N1。
- F4（协议损坏机械定义）：✅ 已修。R2 fail-closed 条件删除兜底词「协议损坏」，枚举为机械可核条件：非普通文件、symlink、`bash -n`语法失败、source 非零、三 export 缺席、任一 anchor 非精确一次、`renameat2` 非精确一次；rename/link fallback 缺席由 R3 注入前核对承担，无覆盖缺口。清单第 2 条同步一致。

## ③ 新引入问题排查

- EARS 句式：R2（当…时，系统必须…fail closed）、R9（当03b1进入验收时，系统必须…）、R10（当验证独立回滚与顺序时，系统必须…）改动后仍成句，[计划] 来源标记保留。✅
- 与 PLAN 03b1 节契约：不修改 provider、provider-copy 穷举、inert/fail-closed 分流、顺序门「inert PASS 不能解除」均保持；R9 六文件集合与 PLAN 文件边界表（03b1 只新增 assurance 入口、不修改前序文件）一致。✅
- 与 03b requirements 契约：R2 的「预期三个snapshot export」、anchor/`renameat2` 精确一次判据与 03b 产出口径一致；六文件全集覆盖 03b 不变量 4 的全部四个文件并补回 driver/entrypoint。✅
- 验收清单联动：第 1/2/9 条与 R2/R9 逐条对应、措辞一致；第 9 条的「depth-1 commit-count=1且shallow marker非空」「上游六文件SHA-256」「clean」均可机械执行；不变量 4 的 `git diff --name-only "$BASE" "$HEAD" -- <六路径>` 为单条可执行命令。✅
- 内部一致性：R9（candidate/full/depth-1 每 checkout 前后 SHA）与不变量 4（BASE..HEAD diff）钉同一集合，两处语义互补不矛盾；全文无第二处文件集合定义，controller 验收有唯一权威集合。✅

## Findings

### 阻断（0）

无。

### 重要（0）

无（F1 已闭合）。

### 次要（1）

- N1（沿用 F3，与 PLAN 逐字对齐）：R10 与验收清单末条的 03c 启动门枚举缺 PLAN 03b1 节原文的「full/depth-1/offline与回滚证据入ledger」；建议显式枚举以免门禁复核口径漂移。不阻断，可在 design 前顺手补齐。
