# 00a tasks review — round 2

结论：**FAIL**

- 规格符合性：**FAIL**。R1–R18 并集、七源码文件、725 行预算、no-AOSP 边界、真实 red 与门④前零实现均闭合；但任务 3.2 使用执行协议不存在的 `READY_FOR_REVIEW` 报告状态，并且失败重建 merge 时没有维持 ledger 中“唯一有效 merge SHA”的规则，R16 生命周期仍不能严格调度。
- 任务质量：**FAIL**。七任务均有五字段、最多两级编号、无孤儿产出；2.2/2.3 已拆到 80/75 行且 capability 链逐字一致。但 post-merge rollback 命令在 isolated worktree 中引用相对 ledger 路径，且若干 green oracle 仍以“匹配 requirements”代替任务内 exact 输出，尚未完整自包含。
- findings：**1 blocker / 1 important / 0 minor**。
- 机械检查：`check-tasks.py` exit 0；`git diff --check -- tasks.md` exit 0；任务编号为 `1.1, 1.2, 2.1, 2.2, 2.3, 3.1, 3.2`；任务需求 token 并集与 requirements 均精确为 R1–R18。
- 审查边界：完整阅读 spec `SKILL.md`、`references/05-tasks.md`、`references/06-execute.md`、`references/07-review.md`、当前 00a requirements/design/tasks、round-1 tasks review 与 ledger。未运行 AOSP/envsetup/lunch/build/sync/download/fetch/clone 命令，未修改 tasks 或源码；唯一写入是本审查报告。

## Round 1 findings closure

| Round 1 finding | Round 2 | 依据 |
|---|---|---|
| B1 final-task review/merge cycle | **FAIL** | pre-merge→commit→review→merge→post-merge 的依赖方向已拉直，但 `READY_FOR_REVIEW` 不属于 execute 细则的四种报告状态，且重建 merge 会留下多个未定义优先级的 ledger SHA。 |
| B2 task 2.2 review 粒度 | **PASS** | 已拆为 2.2 locked resolver/evidence closure（80 行）与 2.3 atomic publication（75 行）；分别只有一个稳定 public API、独立 red/green、独立 commit，审查面可控制在 10 分钟内。 |
| I1 capability 签名逐字一致 | **PASS** | `artifact-validation/v1 capability`、`object-store/v1 capability`、`locked-resolver/v1 capability`、`stable-runtime/v1 complete API` 均能在更早任务的产出中逐字找到。 |
| I2 final green commands | **FAIL** | 命令名已全部展开，但 isolated worktree 中的 ledger 定位和 exact stdout oracle 仍未写成可直接执行、无需外部拼装的合同。 |

## Findings

### B1 — 任务 3.2 的 report/merge/ledger 生命周期仍不符合 execute 协议

位置：`tasks.md:123`–`126`。

`references/06-execute.md` 只定义 `DONE`、`DONE_WITH_CONCERNS`、`NEEDS_CONTEXT`、`BLOCKED` 四种实现者报告状态，并且明确规定收到 `DONE` 后才打 diff package、派 fresh independent reviewer。步骤 4 新增的 `READY_FOR_REVIEW` 没有路由语义：控制器不能按细则把它当作触发 review 的报告，也不能自行扩展第五种状态。因此当前链条在 commit 后仍会停住。

此外，步骤 5 要求先把 candidate delivery merge SHA 写 ledger，post-merge gate 失败后再生成 `new merge`。ledger 是追加式执行记录，而 requirements/design/rollback 要求从 ledger 取得唯一 exact two-parent merge SHA；tasks 没有定义旧 candidate 的 supersession/active-marker 规则。第二轮 candidate 出现后，rollback 无法无歧义选 SHA。

必需修复：把步骤 4 改成 execute 已定义的实现者 `report=DONE`（明确这只代表 task diff 已可审，不等于 `任务 3.2: 完成`）；review PASS 后由控制器继续 post-merge gates。再固定一个可机器判定的 active-candidate ledger 协议：任一时刻 rollback 只能解析一个 active merge SHA，失败 candidate 必须在新 candidate 写入前显式 supersede，任务完成锚点仍只在全部 post-merge gates PASS 后写入。

如果不修，代价是控制器遇到未知报告状态无法依法派 review，或修复轮次让 rollback 选中旧 merge，从而把 R16 证明建立在错误提交上。

### I1 — green 命令仍未在 isolated worktree 语境中完整自包含

位置：`tasks.md:108`、`122`、`125`。

步骤 6 明说“在 isolated worktree”运行，却给 rollback 传相对路径 `.spec/.../ledger.md`。该 ledger 是控制器在主工作区持续更新的执行资产，不是 delivery merge 的源码；从 isolated worktree 根执行时，相对路径不会自动指向主工作区的 live ledger。命令因而可能在代码正确时仍报 `exact merge SHA unavailable`。

同时，步骤 3/6 只统称“匹配各自 exact PASS/channel”或“匹配 requirements 的 ... oracle”。主命令和三个旧回归有可逐字抄入的 stdout；六个 Python case、四个 named case 与 rollback 的 stdout 仍未在任务内列明。`references/05-tasks.md` 要求任务验证给出命令和期望输出，不能让 executor 再从 requirements/design 拼装。

必需修复：声明 post-merge 每条命令的确切 cwd；给 rollback 使用控制器 live ledger 的绝对路径（或在步骤中先定义并验证一个绝对 `LEDGER` 路径）；逐条写明 exit、完整 stdout、完整 stderr。把步骤 3/6 的多命令批次拆成一命令一动作，保留原顺序与 failure stop。

## 其余审计项

| 审计项 | 结论 | 依据 |
|---|---|---|
| 七任务五字段 | **PASS** | 七任务均有 `文件/消费/产出/需求/必需`，全部必需；编号最多两级且无重复。 |
| 真实红灯 | **PASS** | 每任务先增加当前缺失能力的 case；1.1–3.1 以 missing API/module/CLI 非零，3.2 在 merge SHA 尚未发布时以 exact unavailable 非零；证据路径均不进入源码清单。 |
| R1–R18 并集 | **PASS** | tasks 与 requirements 的 R token 集合完全相同，无漏做或扩张。 |
| 无孤儿产出 | **PASS** | 1.1→1.2→2.1→2.2→2.3→3.1→3.2 全链消费；3.2 的 main/named/rollback 产出均是 requirements 的终验收物。 |
| 七源码文件 | **PASS** | tasks 文件路径并集与 design 清单精确一致，无第八个源码文件；evidence/ledger/rollback worktree 均明确为验收资产。 |
| 行预算 | **PASS** | `145+155+145+80+75+80+45=725`，等于 design high estimate，低于 730 ceiling；actual cap 与 140 行 summary cap保留。 |
| no-AOSP | **PASS** | tasks 中没有 AOSP envsetup/lunch/build/package/flash/repo sync/fetch/clone/download 执行命令。 |
| 门④前无实现 | **PASS** | STATE 仍为 `spec_stage: tasks`；七个计划源码/测试文件均不存在。 |
| 占位符与静态门禁 | **PASS** | 无禁用占位符；`check-tasks.py` 与 whitespace check 均通过。 |

## 最终裁定

当前 tasks 仍不能过门④。修复 B1/I1 后应再派全新上下文 reviewer 回审；不得在门④通过前创建实现 worktree、task commit 或 delivery merge。
