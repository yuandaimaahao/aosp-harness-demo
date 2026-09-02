# 00a tasks review — round 1

结论：**FAIL**

- 规格符合性：**FAIL**。R1–R18 的并集、七文件范围、725 行预算、no-AOSP 边界和 two-parent/descendant rollback 的 Git 拓扑均闭合；但任务 3.2 没有给出可按执行细则完成的 task commit → independent diff review → delivery merge → ledger merge SHA → rollback green 生命周期，因此 R16 目前不能由这份 tasks 严格执行。
- 任务质量：**FAIL**。六任务都有五个必填字段、真实红阶段、验证命令和独立 task commit，静态 `check-tasks.py` exit 0；但任务 2.2 的审查面超过 `<10 分钟` 粒度，另有消费/产出逐字签名和任务 3.2 绿阶段命令不完整的问题。
- findings：**2 blocker / 2 important / 0 minor**。
- 机械检查：`check-tasks.py` exit 0；`git diff --no-index --check /dev/null tasks.md` 无 whitespace error；任务编号为 `1.1, 1.2, 2.1, 2.2, 3.1, 3.2`，无三级或重复；需求 token 并集精确为 R1–R18。
- 审查边界：完整阅读 spec `SKILL.md`、`references/05-tasks.md`、`references/06-execute.md`、`references/07-review.md`、PLAN v6、DECISIONS、当前 00a requirements/design/tasks、design round 2 PASS、requirements reopen round 3 PASS、ledger、STATE/config/mode/workflow 与 pre-implementation evidence。未修改 tasks 或其他草稿，未运行任何 AOSP/envsetup/lunch/build/sync/download/fetch/clone 命令；唯一写入是本审查报告。

## Findings

### B1 — 任务 3.2 的 commit/merge/review/rollback 生命周期不可执行

位置：`tasks.md:99`–`103`，尤其步骤 4–5。

任务 3.2 的 red 本身是有效的：步骤 2 明确在 ledger 尚无 merge SHA 时运行 rollback case，期望 `exact merge SHA unavailable` 且不改主工作树；这确实证明 R16 gate 在 delivery merge 前保持关闭。

问题出在 red 之后的严格时序：

1. 步骤 4 要求“task commit 后”由控制器创建 two-parent merge、写 ledger merge SHA，再跑主命令、named cases、rollback 和旧回归。
2. 步骤 5 才要求“提交本任务两文件变化”。若按编号执行，步骤 4 创建的 merge 不包含任务 3.2；若提前执行步骤 5，则文档顺序失真。
3. `references/06-execute.md` 又要求 task commit/report 后先生成 task diff 包并派 fresh independent reviewer。当前步骤没有给出 review 在 merge 前的落点；控制器若为了让 implementer 完成步骤 4 而先 merge，就会把尚未独立 review 的 task 3.2 合入 delivery merge。
4. implementer 也无法在一次普通 task dispatch 内等待控制器完成 merge：控制器通常要先收 task report 才能 review，而 task report 又不能在 rollback green 前宣称完整 DONE，形成循环依赖。

这不是 two-parent 拓扑本身的问题。`parent1=base, parent2=reviewed task tip`，再从 merge 创建只新增 executable recovery wrapper 的 descendant commit，然后 `git revert -m 1 MERGE_SHA`，该拓扑可执行且与 requirements/design 一致。缺陷是 tasks 没有把拓扑拆成可调度的两个控制阶段。

必需修复：把生命周期逐字固定为：任务 3.2 写 red/实现并完成所有 **pre-merge** 命令 → 提交 task 3.2 → implementer 报告 → fresh independent task-diff review PASS → 控制器从 reviewed task tip 创建 two-parent merge并把 exact SHA 写 ledger → 控制器执行 **post-merge** main/named/rollback/三旧回归验收。若 post-merge 失败，必须明确回到 task fix/re-review 并重建新的 delivery merge，而不是修补已审 merge。任务完成锚点只能在这些 gate 全 PASS 后写入。

如果不修，代价是 merge 可能漏掉最后一个任务、未审代码可能先进入 delivery merge，或执行器永远等不到产生自身绿灯所需的 merge SHA。

### B2 — 任务 2.2 未满足“人 review <10 分钟”的硬粒度

位置：`tasks.md:54`–`69`。

该任务在一个 155 行 high estimate 中同时交付并验证三块独立承重状态机：

- lock leaf owner/mode/no-follow 与 nonblocking contention、lock-before-observation；
- primary/ref 加四 evidence object 的 schema/digest/cross-field/public gate resolution；
- object-first/ref-second atomic publish、rename/fsync commit points、temp cleanup 与 dangling-ref oracle。

这三块分别有不同的错误优先级、并发/持久化不变量和 fault matrix。即使总 diff 只有 155 行，reviewer 也必须把实现与负例逐条交叉核对，不能在 `<10 分钟` 内完成有意义的人工审查。该任务因此没有通过四条粒度判据的第四条；`check-tasks.py` 不测 review 时间，所以 exit 0 不消除此 finding。

必需修复：至少沿稳定接口拆成“locked resolve + evidence closure（产出 exact `resolve_ref(...) -> dict`）”与“atomic ref publication（消费前者及 object publisher，产出 exact `publish(...) -> PublishResult`）”两个串行任务；原 155 行 high estimate可拆分但总预算仍须保持 725、不得超过 730。每个新任务保留自己的 red、green、task commit 和 diff review。

如果不修，代价是 lock/evidence/publish 任一交互缺陷会被压在一次过宽 review 中，最可能在 post-merge fault/rollback 验收才暴露。

### I1 — 两处消费接口不能在更早任务的“产出”中逐字找到

位置：`tasks.md:27,43,58`。

- 任务 2.1 消费 `domain dispatch`，但任务 1.2 的“产出”没有这段签名；它只在步骤 3 写了“九个 domain dispatch”。
- 任务 2.2 消费 `六 artifact validator`，而任务 1.2 的“产出”写的是 `六 artifact/two internal-payload validator`，不是逐字相同接口。

`check-tasks.py` 之所以通过，是 anchor 匹配把 `domain dispatch` 缩成了 `domain`，并把 `六 artifact validator` 缩成了 `六`；这满足脚本的启发式，不满足 `references/05-tasks.md` 的“消费签名能在更早产出逐字找到”。

必需修复：为非 public 的 validator/domain capability 定义一个确切、稳定的任务间能力名（或列出确切函数/类型），在任务 1.2 的“产出”和后序任务“消费”中逐字复用。不要依赖步骤正文补接口。

### I2 — 任务 3.2 只有 rollback 红命令，没有可直接执行的完整绿命令集

位置：`tasks.md:99`–`103`。

步骤 4 只写“跑主命令、四 named cases、rollback、旧 harness/parity/sidebar oracle”，没有逐条给出命令；executor 需要从 requirements 和其他字段拼出至少八条调用。这违反“描述做什么但不给怎么做的步骤”禁令，也使 post-merge gate 的 stdout/stderr oracle和执行顺序不够自包含。

必需修复：在 pre-merge/post-merge 两个阶段分别列出完整命令。post-merge 至少逐字列出主命令、四个 `--case`、带 exact ledger 路径的 rollback，以及 `test-harness.sh`、`check-parity.sh`、`verify-sidebar.sh --demo`；同时写明每条的 exit/channel/PASS oracle，不能只写“跑四个 case”。

## 已通过的审计项

| 审计项 | 结论 | 依据 |
|---|---|---|
| 五字段与编号 | **PASS** | 六任务均有 `文件/消费/产出/需求/必需`；均为必需；编号最多两级且无重复。 |
| 真实红阶段 | **PASS** | 1.1–3.1 都先增加当前缺失能力的 case，再以 missing API/module/CLI 取得非零；3.2 在 merge SHA 未写 ledger 前以 exact unavailable 取得红灯。红证据路径均与源码清单分离。 |
| 机器判定 | **PASS（除 I2 的绿命令展开）** | 每任务至少有一条具体命令和 exact exit/stdout/stderr 预期；失败不是“看起来不对”。 |
| 全局严格顺序 | **PASS** | schema core → seed/terminal → state/object → locked ref → CLI → final invariant/rollback，核心 schema/path 假设先于最贵的 CLI/rollback；没有先建孤立组件再最后接线。 |
| 独立 task rollback | **PASS（受 B1 限制）** | 1.1–3.1 各自只提交声明文件的本任务增量且严格串行，失败可在进入下一任务前撤销最新 task commit；最终 spec rollback 拓扑本身成立。3.2 的控制时序需按 B1 修复。 |
| 需求并集 | **PASS** | 六任务 `需求` 并集精确为 requirements 的 R1–R18，无漏做、无额外 R。 |
| 无孤儿产出 | **PASS** | 1.1→1.2→2.1→2.2→3.1→3.2 形成消费链；3.2 的 main/named/rollback 产出均出现在 requirements 验收判据。 |
| 七文件清单 | **PASS** | tasks 的源码路径并集与 design 文件清单完全一致：dispatcher、direct command、marker、runtime、golden、Python driver、Bash entry；无第八个源码文件，evidence/ledger/rollback worktree 均列为验收资产。 |
| 行预算 | **PASS** | 145+155+145+155+80+45=725，等于 design 七文件 high estimate，低于 730；每任务和最终 actual cap 都被要求写 ledger。 |
| two-parent/descendant 拓扑 | **PASS（调度 FAIL）** | exact merge → isolated descendant wrapper-only commit → `revert -m 1` 可保留 wrapper并移除 00a；B1 只否定当前 task lifecycle，不否定 Git 拓扑。 |
| 门④前无实现 | **PASS** | 七个计划源码/测试文件当前全部不存在；`evidence/pre-implementation.txt` 记录主测试因入口不存在 exit 127；STATE 仍为 `spec/tasks`。 |
| no-AOSP / YAGNI | **PASS** | 任务只运行 fixture/runtime/harness/parity/sidebar 命令；没有 envsetup/lunch/m/mm/mmm/ninja/package/flash/repo sync/fetch/clone/download，也未触碰 LK7K AOSP tree。 |

## 最终裁定

当前 tasks 不能过门④。先修复 B1/B2/I1/I2，再按 `review=both` 派一个**全新上下文** reviewer 做 round 2；不得在门④通过前创建实现 worktree、task commit 或 delivery merge。静态 `check-tasks.py` 仍应作为必要门禁，但不能替代本轮发现的生命周期和 review 粒度检查。
