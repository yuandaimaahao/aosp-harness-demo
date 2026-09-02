# 00a tasks review — round 3

结论：**FAIL**

- 规格符合性：**PASS**。round 2 的核心 B 已闭合：任务 3.2 的 implementer `report=DONE` 只触发 fresh independent task-diff review，不等于恢复锚点；two-parent delivery merge、post-merge gates、accepted candidate 与 `任务 3.2: 完成` 的顺序没有循环。R1–R18、七源码文件、725 行预算、no-AOSP、R16 descendant rollback 拓扑均保持闭合。
- 任务质量：**FAIL**。append-only candidate fold 本身能保证最多一个有效 SHA，post-merge rollback 也使用了 live ledger 的绝对路径；但 pre-merge red 仍使用相对 ledger，且多个步骤仍不是“一步一动作/一条命令”，若干验证事实没有 exact command/output。三个承重任务也仍未通过“人 review <10 分钟”的粒度判据。
- findings：**0 blocker / 4 important / 0 minor**。
- 机械检查：`check-tasks.py` exit 0；`git diff --check -- tasks.md` exit 0；任务编号精确为 `1.1, 1.2, 2.1, 2.2, 2.3, 3.1, 3.2`，无三级或重复；任务 `需求` token 并集精确为 R1–R18。
- 审查边界：完整阅读 spec `SKILL.md`、`references/05-tasks.md`、`references/06-execute.md`、`references/07-review.md`、当前 00a requirements/design/tasks、tasks round 1/2 reports、ledger、STATE/config/mode/workflow 与 pre-implementation evidence。未运行 AOSP/envsetup/lunch/build/sync/download/fetch/clone 命令，未修改 tasks 或源码；唯一写入是本审查报告。

## Round 2 findings closure

| Round 2 finding | Round 3 | 依据 |
|---|---|---|
| B1 `DONE`/completion-anchor 生命周期 | **PASS** | `tasks.md:131` 明确 `DONE` 仅表示 task diff 可审并禁止写完成锚点；`:132` 要求 fresh independent review；`:133` review PASS 后才 merge；`:134`–`:142` 才执行 post-merge gates；`:143` accepted 且唯一后才 mark-task-done。该语义与 execute 的 `DONE → review` 路由兼容。 |
| B1 append-only candidate 唯一性 | **PASS（fail-closed 空窗）** | 同 SHA 按时间折叠；失败时先把旧 active 追加为 superseded，再经过 fix/新 commit/fresh review 后发布新 active，因此任何已记录状态都不会同时留下两个 final `active|accepted` SHA。修复窗口会有 0 个而不是 1 个 active，此时 parser 的“恰有一个”检查应拒绝 rollback；这不会选错 SHA。最终只把当前 active 同 SHA 折叠为 accepted。 |
| I1 isolated cwd 的 live ledger | **FAIL** | post-merge `:139` 已使用主工作区 ledger 的绝对路径；但 pre-merge red `:121` 仍用相对 `.spec/.../ledger.md` 且未固定 cwd，在 isolated task worktree 中不能证明它读取的是控制器持续追加的 live ledger。 |
| I1 steps 4–24 exact commands/actions | **FAIL** | `:123`–`:130` 与 `:134`–`:142` 的验证命令、cwd/channel oracle已展开；但 `:131`–`:133`、`:143` 仍各包含多个控制动作，未满足“一步一个动作”。 |

## Findings

### I1 — task 3.2 的 red 仍未读取绝对 live ledger

位置：`tasks.md:121`，对照已修正的 `tasks.md:139`。

任务在 `isolation: worktree` 下执行。步骤 2 传入相对路径：

`--ledger .spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/ledger.md`

但 live ledger 是控制器在主工作区持续追加的执行资产，不保证存在于 task worktree。若从 task worktree root 执行，该 red 可能只是因为 ledger 文件不存在而得到 `exact merge SHA unavailable`，并没有证明“live ledger 存在但尚无 active delivery candidate”。这会形成假红灯。

必需修复：步骤 2 像步骤 20 一样固定 `cwd=task worktree root`，并使用 `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/ledger.md`；red evidence 必须区分“ledger missing/invalid”和“存在但 exact active merge SHA unavailable”。

如果不修，代价是 R16 的红阶段可由错误文件位置伪造，无法证明 merge-SHA gate 真正关闭。

### I2 — task 3.2 步骤 12–14、24 仍不是“一步一个动作”

位置：`tasks.md:131`–`:133`、`:143`。

- 步骤 12 同时提交 task commit 与报告 `DONE`。
- 步骤 13 同时生成 diff package、派 reviewer，并隐含等待/分流 PASS。
- 步骤 14 同时创建并验证 two-parent merge、追加 active event、验证 fold cardinality，并塞入整条失败后的 supersede→fix→review→new merge 分支。
- 步骤 24 同时记录多类 SHA/output、统计两个 cap、追加 accepted、验证唯一 accepted、执行 mark-task-done，并处理超限返回 PLAN。

这些不是一条命令或一个 2–5 分钟动作。尤其步骤 14/24 把候选状态机的多个 commit point 压进一个 checkbox，执行中断后无法仅凭勾选状态知道应从何处恢复。

必需修复：逐动作拆开，至少分别给出 task commit、DONE report、review package、review dispatch/result、merge creation/parent-count check、active append/fold check、各 cap measurement、accepted append/fold check、mark-task-done。失败分支应作为独立的全局执行规则，或拆成可恢复步骤，不要与成功动作共用一个 checkbox。

如果不修，代价是压缩/中断恢复时可能重复 merge、漏记 supersession、提前 accepted 或提前写完成锚点。

### I3 — 其余任务也存在 compound step 和无 exact command 的验证事实

位置：`tasks.md:19`–`:20`、`:36`–`:37`、`:55`–`:56`、`:72`–`:73`、`:89`–`:90`、`:108`–`:109`。

这不是仅限 final task 的问题：

- 1.1 步骤 4 在同一步运行 Python case 和 `git diff --check`；步骤 5 又同时 commit 与写 ledger。
- 1.2 步骤 4 在 suite 命令之外要求“核对 run-evidence mutation”，却不给该核对的命令或 exact 输出。
- 2.1 步骤 4 的 stale-temp oracle、2.2 步骤 4 的 byte-change oracle、2.3 步骤 4 的 dangling-ref/temp oracle都没有独立命令或明确说明已由哪一个 case 的 exact PASS 承载。
- 3.1 步骤 4 连跑两个命令，且只写“核对旧 harness PASS”，未在任务内给该命令的 exact exit/channel oracle；步骤 5仍同时 commit 与记 ledger。

`check-tasks.py` 不会检测一个 checkbox 内的第二个动作或散文 oracle，因此 exit 0 不消除此 finding。

必需修复：每条 shell/Python/git 命令各占一步；若某项状态断言已经包含在 named case 内，明确写成该 case 的 exact oracle，不再另挂无法执行的“另核对”；commit 与 ledger append 分步，并给每个命令 exit/stdout/stderr 或无输出条件。

如果不修，代价是实现者可只跑前半条命令仍把步骤勾完，红/绿证据与 ledger 记录无法逐动作审计。

### I4 — 任务 1.1、1.2、2.1 未通过“人 review <10 分钟”粒度

位置：`tasks.md:7`–`:56`。

- 1.1 的 145 行 high estimate 同时承载 JSON parser、recursive scalar guard、canonicalizer、九域的一部分、四个 closed evidence validator 与 table-driven tests。
- 1.2 的 155 行同时承载六 artifact/two internal-payload validator、request/content/identity reconstruction、success invariant、terminal/public predicate、golden 与 digest dispatch。
- 2.1 的 145 行同时承载 no-follow state confinement 和具备 temp/fsync/chmod/link/collision/fault matrix 的 immutable object publication。

它们都能由一个 subagent 在一次上下文中实现，但人工 reviewer 需要把多组独立承重不变量逐条与 requirements 对照，无法合理地在 10 分钟内完成。round 1 对原 2.2 的 155 行三状态机使用了同一判据；把 2.2/2.3 拆开后，不应对上述等量或更密集的任务放宽。

必需修复：沿稳定接口继续拆分，例如 canonical/parser core 与 evidence validators 分开，seed identity/public 与 terminal/golden 分开，state path confinement 与 object publisher 分开。只重分配现有 725 行 estimate；若拆分引入的实际源码使 estimate >730，按 R17 返回 PLAN。

如果不修，代价是 schema、path 或 durability 缺陷会被一次过宽 review 掩盖，并在最终 fault/rollback gate 才暴露。

## 完整审计结果

| 审计项 | 结论 | 依据 |
|---|---|---|
| 七任务与五字段 | **PASS** | 七任务均有 `文件/消费/产出/需求/必需`；全部必需；编号最多两级且无重复。 |
| 四条粒度判据 | **FAIL** | I4；另外 task 3.2 的控制步骤因 I2 不具备逐步独立恢复性。 |
| 真实 red | **FAIL（1 项路径缺陷）** | 1.1–3.1 都以当前缺失 API/module/CLI 取得真实非零；3.2 的 merge-SHA gate 意图正确，但 I1 的相对 ledger 可产生假红。 |
| 单步命令与 exact oracle | **FAIL** | task 3.2 的实际验证步骤 4–11、15–23 已逐命令展开且 exact；I2/I3 所列控制与辅助验证仍不合规。 |
| capability/签名链 | **PASS** | 1.1 exact API→1.2；`artifact-validation/v1`→2.1/2.2；`object-store/v1`→2.2/2.3；`locked-resolver/v1`→2.3；`stable-runtime/v1 complete API` 与 golden→3.1；3.1 两项 deliverable→3.2，均能在更早产出中逐字找到。 |
| R1–R18 并集 | **PASS** | tasks 的 R token 并集与 requirements 全集精确相等，无漏做或扩张。 |
| 无孤儿产出 | **PASS** | capability 串行消费；3.2 的 main/named/rollback 产出均是 requirements 的终验收物。 |
| 七源码文件 | **PASS** | tasks 的源码路径并集与 design 文件清单精确相同；evidence/ledger/rollback worktree 都列为验收资产，没有第八个源码文件。 |
| 725/730/140 预算 | **PASS** | `145+155+145+80+75+80+45=725`，等于 design high estimate且低于 730；actual ≤730 与 summary ≤140 均保留为 accepted 前 gate。 |
| no-AOSP | **PASS** | tasks 只规划 Python/Bash fixture、Git/review/rollback 命令；明确禁止 AOSP 命令，没有 sync/download/fetch/clone。 |
| 门④前无实现 | **PASS** | STATE 仍是 `spec_stage: tasks`；七个计划源码/测试文件全部不存在；pre-implementation evidence 是入口缺失 exit 127。 |
| completion anchor | **PASS** | `report=DONE`、review、merge、post-merge gate、accepted、mark-task-done 顺序明确；只有最后一步可产生 `任务 3.2: 完成`。 |
| candidate fold | **PASS** | supersede-before-new-active 保证不会出现两个 final valid candidates；0-active repair window fail closed；accepted 只折叠当前 active SHA。 |
| live ledger / isolated cwd | **FAIL（red only）** | post-merge rollback 使用绝对 live ledger且 cwd 明确；pre-merge red 仍是相对路径，见 I1。 |

## 最终裁定

当前 tasks 仍不能过门④。修复 I1–I4 后，按 `review=both` 再派一个全新上下文 reviewer 回审；不得在门④通过前创建 implementation worktree、task commit 或 delivery merge。
