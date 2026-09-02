# 03a2 tasks review（PLAN v5.6 round 1）

Reviewer: `review_plan_v5_2`

Verdict: **NEEDS_CHANGES** — blocker 0 / important 3 / minor 1

审查范围：独立复核`specs/2026-09-02-03a2-session-path-race-matrix/{requirements.md,design.md,tasks.md}`，交叉PLAN v5.6的03a2 owner/依赖/回滚/顺序边界与`work/2026-09-02-03a2-session-path-race-matrix/sizing-report.md`及其证据。未修改规格正文、production、STATE或ledger；本报告是本轮唯一新增文件。

## Findings

### Important 1 — 三个实现纵切都只有prose，没有tasks门禁要求的最小代码骨架

- 位置：`tasks.md:14-16`（Task 1）、`:28-30`（Task 2）、`:42-43`（Task 3）；全文fenced code block计数为0。
- 依据：spec tasks细则明确把“描述做什么但不给怎么做的步骤（代码步骤必须给代码块）”列为缺陷；执行agent可能只拿到本任务brief，不能在执行阶段重新设计纵切。`design.md:64-94`虽固定最终结构，prototype也有137行蓝图，但tasks只写“提取prototype”及行为清单，没有锁定每片保留/新增/暂不实现的实际结构。
- 影响：Task 1实现者可能直接复制完整137行而提前闭合Task 2/3；也可能自行发明另一套matrix/capture/inert结构。Task 2/3同样要临场决定双流捕获、classifier收口和CASE_LOG门，导致三条独立diff的scope、唯一红因和`<10分钟`review边界无法仅由tasks机械复现。
- 可执行修复：为每个任务加入一个精简、可直接落地的fenced Bash骨架。Task 1骨架应止于provider-present的唯一`dependency classifier incomplete`；Task 2在固定provider→anchor→driver type/protocol→flag/foundation/core顺序后止于唯一`race adapter incomplete`；Task 3只删除该红灯、加入一次run-matrix双流捕获、expected-log `cmp`和post-check。骨架从已验证prototype逐段提取，不复制尚属后续任务的分支，也不得含`...`/TODO。

### Important 2 — Task 2的“driver零调用”优先级证据不可观察，过渡红仍可能掩盖提前调用

- 位置：`tasks.md:16,27,29-30`。
- 证据：Task 2步骤1在真实dependency-present repo只检查精确`dependency classifier incomplete`、stdout0/no-PASS和dependency SHA不变，却声称“记录driver未被调用”。真实driver没有argv log；SHA不变只能证明文件未修改，不能证明没有执行。步骤4对18个anchor组合同样要求driver零调用，但只明确给flag/foundation/core inert使用fake argv log，没有规定anchor fixture也替换为可记录driver。于是实现可以错误地在anchor gate前调用driver，最后仍打印相同过渡诊断或anchor失败，现有红/绿文字仍可假绿。
- 影响：provider damage必须优先于driver/core是R4/R7承重边界；提前触碰driver会让损坏provider与损坏driver组合产生错误优先级，甚至把本应确定的provider fail-closed变成driver侧错误。
- 可执行修复：Task 2红阶段增加一个healthy-provider + fake-driver隔离root，要求精确过渡诊断且argv log物理缺席/0B；18个anchor组合全部使用同一fake-driver log并逐项断言0行。再为driver absent与flag/foundation/core分别固定期望调用序列：absent为0行，后三者精确一行`protocol`且无`run-matrix/self-test`。Task 1步骤4也应明确是在同一个provider-absent root分别运行无参数、`all`和`--dependency-absent`，避免“no-arg/all/provider-absent”被误读为provider-present也应绿。

### Important 3 — accepted-HEAD、三行manifest与03b顺序门没有可直接执行且会失败的controller命令

- 位置：`tasks.md:41,44-46`。
- 证据：Task 3把controller protocol/self-test写成“均绿”，full/depth-1也只写“验证protocol/self-test/default/offline”，没有固定各命令的rc/stdout/stderr字节；37/37与九类计数被称为“证据齐全”，但entrypoint唯一stdout只有41B且CASE_LOG随temp清理，tasks没有规定controller保存什么可审计证据。最终步骤只用prose要求manifest恰好3行、首尾/相邻连续及03b spec/worktree/branch/base/dispatch缺席，没有AWK/拒绝命令、精确artifact路径，也没有区分拥有accepted HEAD的implementation worktree与拥有`.spec`/ledger的controller主仓。
- 影响：controller可在self-test有额外输出、checkout指向旧HEAD、manifest不连续或03b已提前创建时仍把“命令rc0/人工看过”记为PASS；也可能从controller仓取错HEAD，或从implementation worktree检查错误的`.spec`副本。inert PASS仍可能被误记为dependency-present 37/37并错误解除03b门。
- 可执行修复：在Task 3加入完整fenced controller shell门并显式传入、校验absolute `CONTROL_REPO_ROOT`与`IMPLEMENTATION_WORKTREE`：
  1. 用`git -C "$IMPLEMENTATION_WORKTREE"`绑定candidate/final HEAD，逐条捕获protocol 28B/0B、self-test 38B/0B、default 41B/0B及offline精确末摘要；保存accepted default、fake argv、37-row/count与CASE_LOG oracle结果到固定验收资产。
  2. 对full和真实file-URL depth-1逐字重复上述命令，比较各checkout当前tracked provider/driver测试前后SHA，断言depth commit-count=1、`.git/shallow`非空和worktree clean；rollback checkout给出删除唯一entrypoint后的精确命令和discovery=0断言。
  3. 给三行六列manifest一个可执行AWK，验证`seq==NR`、task精确1..3、首base=`BASE_SHA`、相邻连续、末head=`git -C "$IMPLEMENTATION_WORKTREE" rev-parse HEAD`、reviewer非空、status全PASS。
  4. 紧邻ledger write前从`CONTROL_REPO_ROOT`以glob-free路径、`git worktree list`和`git show-ref`检查03b spec/worktree/branch/execution-base/dispatch；路径缺席必须同时拒绝`-e`与`-L`。只有该命令rc0且dependency-present证据非空才允许写ledger，写成功后才可选中03b。

### Minor 1 — Task 3主验证步骤有一个文本笔误

- 位置：`tasks.md:44`。
- 证据：`跑真实no-arg/all址得rc0`中的“址得”不是有效术语。
- 影响：不改变当前语义，但会被原样带入brief/报告并降低命令描述清晰度。
- 可执行修复：改为“跑真实no-arg/all，均得rc0”。

## 已确认成立的部分

- 三任务五个必填字段齐全、单层编号无重复；消费/产出链`matrix-gate-v1 → dependency-classifier-v1 → session-path-race-matrix-v1`连续，无孤儿中间产出。
- 需求并集精确为`R1..R10`，没有漏项或范围外R。
- Task 1初始红因真实且唯一：当前实跑`bash tests/test-session-path-races.sh`为rc127、stdout 0B、stderr为目标文件不存在，且目标既非现存对象也非symlink。Task 1明确留下`dependency classifier incomplete`，Task 2明确把它替换为`race adapter incomplete`；两片在真实dependency-present repo均rc1/no-PASS，不会把未完成入口冒充整体验收绿。I2仅针对“driver未调用”这一额外优先级断言缺少机械观察。
- scope正确：三个任务的implementation文件始终只有`tests/test-session-path-races.sh`；foundation/provider/driver、03b、public API与capability均未被带入源码diff。各任务先commit、独立diff review PASS后才串行派下一任务，fix后要求重跑最终HEAD。
- 137/400 prototype、exact1/137临时候选、18个anchor组合、driver损坏、fake exact argv、full/depth-1、rollback和offline已有可运行设计证据。总实现只有137行，prototype完整controller实跑约一分钟；按三个连续小diff审阅并复用限定fixture，每次review保持`<10分钟`是可信的，无需因粒度再拆spec。
- Task 3先本地green再commit，之后从candidate HEAD建full/depth-1；review产生fix commit时对新最终HEAD重跑，顺序本体正确。修复I3只需把当前正确意图固化成可执行双仓门。

## Mechanical checks

- `check-tasks.py`: rc0
- `check-req.py`: rc0
- `check-criteria.py`: rc0
- `check-analyze.py`: rc0
- `check-plan.py`: rc0
- `git diff --check`: rc0
- 任务数/必需任务数：3/3
- requirements并集：精确`R1,R2,R3,R4,R5,R6,R7,R8,R9,R10`
- tasks fenced code blocks：0

机械脚本不覆盖上述代码骨架、调用可观察性及controller双仓/顺序语义缺口。
