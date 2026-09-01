# 03a1 tasks review（PLAN v5.6 round 2）

Reviewer: `review_plan_v5_2`

Verdict: **NEEDS_CHANGES** — blocker 1 / important 2 / minor 0

审查范围：独立复核当前`tasks.md`，对照同目录requirements/design、PLAN v5.6与spec tasks细则；逐项验证round1 B1/I1–I5的声称修复，并检查新scope、红绿、400行、current/untracked diff、五行manifest和03a2顺序门。未修改规格、STATE或ledger，本文为唯一新增文件。

## Round 1 findings复核

| finding | 状态 | 精确证据 |
|---|---|---|
| B1 最终任务在commit前克隆旧HEAD | ✅ 闭合 | Task 5 `tasks.md:125-127`现明确先完成本地green并提交、确认clean，再从candidate HEAD建full/depth-1 checkout；review产生fix commit时对最终HEAD重跑步骤3/4，最后才生成manifest行。 |
| I1 四任务复杂度断崖/self-test红因不实 | ✅ 闭合 | 已拆为五个串行纵切：CLI；preflight+EIO；swap/wrong-EUID/EEXIST；五managed+完整37及唯一`self-disproof incomplete`红；14项+acceptance。Task 4 `:88-105`要求37-row run-matrix先绿，并证明self-test只剩单一确定性红因。 |
| I2 无代码骨架 | ❌ 未完全闭合 | 五任务均新增fenced code block，但终任务最关键的14项仍保留`...`和“其余13项”占位，且缺可执行反证命令，见I1。 |
| I3 Task 2另造逐祖先walker | ✅ 闭合 | Task 2 `:40-52`逐字采用round7的`parent.lstat()`、strict resolve、absolute/absent/direct-child和held-fd结构，明确禁止新增walker；与当前design的Path词法语义一致。 |
| I4 预提交Git门漏untracked/current diff | ✅ 闭合 | Task 1 `:28`先`git add -N`再跑BASE到working tree name/numstat；Tasks 2–5均跑无range`git diff --check`及BASE..working-tree exact1/400，Task 3另在review package跑`TASK_BASE..TASK_HEAD`。 |
| I5 ledger前缺03a2最终顺序门 | ❌ 部分闭合 | Task 5 `:127`已把五行manifest和ledger-before-03a2放到最终步骤，但变量校验自相矛盾且absence检查没有可执行拒绝表达式，见B1/I2。 |

五任务的五个必填字段、单层编号和严格消费/产出链均正确；需求并集精确为R1–R9，无孤儿中间产出。源码scope始终只有`tests/lib/session-path-race-driver.py`，没有把03a2入口、public API或consumer带回03a1。五行manifest AWK本体用合法样本实跑rc0，能验证六列、seq/task、40位base/head、首尾连续、reviewer非空和全PASS。

## Blocker

### B1 — Task 5把commit SHA误要求为绝对存在文件，最终manifest/ledger门不可满足

- 位置：`tasks.md:127`。
- 证据：步骤先要求“`BASE_SHA`与`REVIEW_MANIFEST`均为非空绝对路径且文件存在”，随后同一AWK又要求manifest首base等于`BASE_SHA`且base匹配`^[0-9a-f]{40}$`。`BASE_SHA`按`tasks.md:3`和R8定义是execution base commit ID，不可能同时是绝对文件路径；因此严格执行该步骤必然在AWK之前失败，或跳过前置断言后违反tasks文本。
- 影响：即使五个实现/review全部PASS，也无法生成符合任务定义的终态证据、写ledger或合法解除03a2 gate；这是确定性的不可完成任务。
- 可执行修复：拆开两类校验：`BASE_SHA`必须非空、匹配40位hex并由`git cat-file -e "$BASE_SHA^{commit}"`验证为commit；只有`REVIEW_MANIFEST`要求非空absolute regular file。然后运行现有五行AWK，保持首base/相邻/末HEAD约束不变。

## Important

### I1 — Task 5的14项核心实现仍是占位代码，green反证也没有可执行方法

- 位置：`tasks.md:116-125`。
- 证据：所谓代码骨架仅给`must_reject(lambda: assert_delta(...), "protected signature")`，其中`...`不是可落地的真实oracle参数；下一行用注释“其余13项逐一调用”代替其余全部实现。步骤3又要求“主动破坏14项中的任一项均rc1且无PASS”，却没有给mutation fixture、调用命令、预期诊断或如何在不污染最终源码的情况下完成。它仍要求实现者从可变的未固定SHA prototype自行重新设计/挑选承重代码，未真正闭合round1 I2和tasks细则的“禁止占位符/代码步骤必须给代码块”。
- 影响：这是R7唯一实现任务；缺少真实骨架和机械green oracle时，14项可能被统一假callback、少项或只比较名称列表而假绿，独立review也无法由任务brief快速复现。
- 可执行修复：把round7 prototype中`must_reject`和14个真实callback按精确顺序给出可执行骨架，至少列明每项消费的probe/字段及expected exception；删除literal `...`/“其余13项”。为步骤3提供一个确定性隔离mutation harness或14项表驱动命令，逐项记录rc1、stdout0、无PASS，并证明未计入正常self-test之外的动态case。

### I2 — 03a2 absence门仍没有能失败的命令，artifact范围也未解析成精确路径

- 位置：`tasks.md:13,127`；对应`requirements.md:35,53`与PLAN `:246-250,268`。
- 证据：最终步骤只写“机械确认`git worktree list --porcelain`、`refs/heads/...`、03a2 spec/work目录及execution-base/dispatch/brief均不存在”。`git worktree list`本身无论是否出现03a2通常都rc0；裸写ref名和泛称`execution-base/dispatch/brief`不是检查命令或精确路径，也没有把任一命中转换为非零。起点证据不能代替五任务后的终态检查。
- 影响：round1 I5的文字位置虽已移到ledger前，但仍可在03a2 branch/worktree/brief已提前创建时假绿，破坏R8/R9串行门。
- 可执行修复：在Task 5给出单一fail-closed shell门：用`git worktree list --porcelain | grep -F`拒绝03a2 path/branch，用`git show-ref --verify --quiet refs/heads/spec/...`的反条件拒绝branch，并为03a2 spec目录、work目录、execution-base、dispatch与brief列出全部绝对或repo-relative glob-free路径，以`[[ ! -e ... ]]`逐项断言。保存该命令的stdout/stderr/rc并紧邻ledger write执行。

## Mechanical evidence

- `check-tasks.py`: rc0
- `check-req.py`: rc0
- `check-criteria.py`: rc0
- `check-analyze.py`: rc0
- `check-plan.py`: rc0
- `git diff --check`（tasks/requirements/design）: rc0
- 需求并集：精确R1–R9。
- 五行合法manifest样本运行当前AWK：rc0。

## 最终判定

**NEEDS_CHANGES**。五任务纵切、candidate/final HEAD复验、working-tree diff覆盖与五行AWK主体已经成立；修复B1并把R7/03a2顺序门改成可直接执行、可失败的机械步骤后，再做round3复审。
