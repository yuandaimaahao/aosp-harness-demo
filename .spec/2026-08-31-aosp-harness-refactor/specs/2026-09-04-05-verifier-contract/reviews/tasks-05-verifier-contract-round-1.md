# 05 verifier contract tasks review — round 1

## 结论

- 规格符合性：**NEEDS_CHANGES**
- 任务质量：**NEEDS_CHANGES**
- Findings：**B=2 / I=1 / M=0**

三任务的源码粒度本身合理：严格按 test → provider → doc 排序，每任务只创建一个 exact3 文件并单独提交、独立 review；需求并集为 R1–R10，红因也都是真实的目标物理缺席。`202+67+102=371/400` 与 design/prototype 一致。但任务 3 有两个机械上无法成立的门，并把 task diff review 与 controller 最终验收编排得过于混杂，当前不能进入 execute。

## Findings

### [阻断 B1] 文档提交前要求 `BASE..HEAD` 得到 exact3/371，机械上不可能成立

- 定位：`tasks.md:44-46`
- 现状：任务 3 步骤 2 复制 doc 后，`HEAD` 仍明确是任务 2 HEAD；doc 只是未跟踪工作树文件。此时 `git diff BASE_SHA..HEAD` 只能包含任务 1/2 的 test+provider，即两文件、304 行，不可能得到 exact3 name-only 和 numstat 371。普通 `git diff` 也不会计入未跟踪 doc。
- 影响：按文档逐步执行必然在步骤 2 失败，无法到达任务 3 单提交、review和验收。
- 建议：步骤 2 只做 doc 的 prototype `cmp`、行数和内容准备；步骤 3 提交 doc 后，再在已前移的 HEAD 上机械核 `BASE_SHA..HEAD` exact3 name-only与 additions+deletions总和371。把这项核验与 candidate gates放在同一 post-commit 阶段。

### [阻断 B2] NEXT 五类资产缺席门放在 rollback clone 内，无法观察 controller 的真实资产

- 定位：`tasks.md:47-49`；`requirements.md:43`；`PLAN.md` 的 05/05a 顺序门
- 现状：步骤 5 把“05a源码与05a/06/07/08/09/10执行资产五类均缺席”写在隔离 rollback clone 的动作中。clone 无法证明原项目/controller 中不存在 `spec/05a` branch、另一个 worktree、ledger execution BASE 或 dispatch 记录；本地 branch/worktree 尤其不属于 rollback checkout 的文件视图。文字也没有逐项钉死 requirements 的 `spec directory / branch / worktree / execution BASE / dispatch` 五类 05a 资产。
- 影响：即使 05a 已被提前创建，rollback clone 内检查仍可能为绿，R9 的顺序门可被假通过。
- 建议：rollback clone 只验证 exact3 删除和旧回归。另在 controller 原项目上下文以五个独立、可失败的检查核 05a spec/ref/worktree/ledger BASE/dispatch 物理缺席，并核 05a source及06/07/08/09/10执行资产缺席；应在 acceptance 前执行并记录真实命令/rc，05 ledger 的 dependency-present accepted 证据落库前不得创建05a。

### [重要 I1] 任务 3 将单文件 diff review 与整片 controller 验收混成一个任务尾部

- 定位：`tasks.md:35-49`，尤其步骤 3–6
- 现状：任务 3 同时承担 67 行 doc 安装、candidate、full、depth-1、rollback、NEXT、acceptance草案、独立diff review、三行manifest、ledger、converge和accept。完整四路证据在任务 3 独立 diff review 之前生成，而 task 开头又承诺每个 review 不超过10分钟；reviewer究竟只审 doc delta，还是还要背书 controller 全部验收，没有清晰边界。
- 影响：若 task review要求修订doc/HEAD，先生成的四路证据全部失效；若 reviewer只看doc，则 acceptance草案易被误当成已独立review。任务源码大小不大，但验收职责过载且证据绑定顺序含混。
- 建议：保持三次源码提交与三行 manifest 不变：任务 3 先安装/提交doc、跑focused candidate、写task report并完成独立diff review，PASS后追加manifest第3行；随后用明确标注为 controller finalization、非第四个实现task的段落，在固定 accepted candidate HEAD 上运行 exact3/371、candidate/full/depth-1/rollback/NEXT/converge，最后写 acceptance report并进入accept。任何review修订必须重新生成后续证据。

## 其余复核

- 三任务粒度：test 102、provider 202、doc 67，各自单文件单提交，源码 review 规模合理。
- 顺序：任务 1 test 红于入口缺席；安装后红于provider缺席；任务 2再装provider并转绿；任务 3最后装doc，依赖顺序正确。
- 红因真实性：缺失test执行rc127、缺失provider导致base专属`FAIL provider`、缺失provider/doc的`cmp`非零均是真红，不依赖恒真断言。
- 需求覆盖：任务1 R7/R10，任务2 R1–R6，任务3 R8–R10，并集恰覆盖R1–R10。
- commit/review：每个源码文件各一提交且声明独立diff review；manifest预期三行六列。除 I1 的最终编排外，边界清楚。
- rollback回归集合包含01、02、04/04a及三个旧verifier demo，符合R9；exact3物理删除方向正确。
- 05a source不应在本片创建，tasks没有创建动作；但其五类提前资产缺席证明须按B2移回真实controller上下文。

## 机械检查

- `python3 .../spec/scripts/check-tasks.py tasks.md`：rc `0`。
- `git diff --check`：rc `0`。

上述检查只证明结构与空白合法，不能发现 B1 的 Git 时间点错误或 B2 的观察域错误。修复 B1、B2 并澄清 I1 后再复审。
