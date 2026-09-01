# 03a1 tasks review（PLAN v5.6 round 1）

## 结论

**NEEDS_CHANGES**

统计：**blocker 1 / important 5 / minor 0**。

机械检查：

- `python3 /home/zzh0838/.agents/skills/spec/scripts/check-tasks.py <tasks.md>`：rc0。
- `python3 /home/zzh0838/.agents/skills/spec/scripts/check-req.py <requirements.md>`：rc0。
- `git diff --check -- <tasks.md> <requirements.md> <design.md>`：rc0。
- 四任务`需求`并集精确为`R1..R9`，无范围外R。
- 以四行合法样本实际运行`tasks.md:59`的六列manifest AWK：rc0；六列、首尾、相邻、reviewer非空和全PASS表达式本身正确。

## Findings

### Blocker

#### B1. Task 4在提交前克隆`HEAD`并要求clean，必然验不到Task 4且无法转绿

- 位置：`tasks.md:55-59`，尤其步骤4与步骤5的先后顺序。
- 违反依据：`requirements.md` R8/R9（35-37行）及验收清单（54-55行）要求在accepted HEAD的full/depth-1 checkout验证最终self-test，并要求最终worktree clean；`design.md`测试策略（196-200行）同样绑定accepted HEAD；tasks四条粒度判据要求每任务有可执行的独立green oracle。
- 证据：Task 4的源码变化在步骤2产生，直到步骤5才提交。步骤4却要求“以当前HEAD”创建full/depth-1 checkout并运行主self-test；此时`HEAD`仍是Task 3，克隆不会包含Task 4新增的内建rows/14项self-disproof。步骤4同时要求主worktree clean，而Task 4的预提交修改按定义使其不clean。故无论实现是否正确，步骤4都不能成为步骤5之前的green gate。
- 具体修法：把流程改为“本地green → Conventional Commit → clean检查 → 从该candidate HEAD建立full与真实file-URL depth-1 checkout并跑protocol/self-test/offline → 独立review”；若review产生fix commit，必须对新的最终HEAD重跑两种checkout与R8/R9，再生成manifest和写ledger。不要用复制未提交文件到checkout冒充accepted-HEAD验收。

### Important

#### I1. Task 3存在明显复杂度断崖，且Task 4的红因不是其声明的14项自反证

- 位置：`tasks.md:33-45`（Task 3），`tasks.md:47-56`（Task 4步骤1-2）。
- 违反依据：tasks细则四条粒度判据中的“review <10分钟”和“相邻任务不许复杂度跳跃”；`design.md:74-110`的三anchor、八个剩余family、hook字段、完整delta表与self-disproof边界。
- 证据：Task 2只交付`real-eio`纵切，Task 3一次加入其余八family、三层/variant、MANAGED与EXPECTED_EUID hook、EEXIST双hook、全部stream/signature/inventory/delta、subtree rekey与runtime-original。round7 400行蓝图中这些承重实现跨越多个密集代码区，无法可信地在10分钟内逐项review R4-R6；相邻任务也从单family直接跳到剩余36 case。与此同时Task 3只green外部`run-matrix`，没有要求把同一37 rows接入`self-test`，所以Task 4步骤1看到的只能是先前保留的通用rc1，并不能证明“因14项self-disproof未全部执行”而红。
- 具体修法：拆成5个线性任务最清楚：CLI；preflight+EIO；swap/wrong-EUID/EEXIST及共享oracle；五个managed lifecycle family+完整37 rows，并在该片把内建rows接入self-test、留下精确“self-disproof incomplete”红；最后14项self-disproof+acceptance。相应把manifest改为5行。若坚持4任务，至少必须给出每片实际蓝图行区间和<10分钟review预算，并在Task 3结束时让self-test真实执行37 rows后只因缺14项而失败。

#### I2. 所有实现步骤仍是纯prose，未满足tasks门禁要求的代码块

- 位置：代表性为`tasks.md:15,29,43,56`；实际覆盖四任务的实现步骤和关键fixture/oracle步骤。全文没有fenced code block。
- 违反依据：`references/05-tasks.md`“禁止占位符”明确规定“描述做什么但不给怎么做的步骤”是缺陷，且“代码步骤必须给代码块”；执行者可能只收到单任务brief。
- 证据：当前文字虽详细，但实现者仍需自行发明dispatcher rc分流、Path preflight、held-fd log、single-anchor replacement、family dispatch、delta比较和14项异常捕获的实际结构。exact 400/400没有试错余量，这种二次设计会直接引入返工或删oracle风险。
- 具体修法：每个任务至少为红fixture/最小实现/green oracle各给一个可直接落地的精简代码块或固定argv骨架；代码块应从round7原型提取该纵切所需结构，不复制整文件，也不得要求实现者“参考前一任务”自行补齐。

#### I3. Task 2要求“逐祖先lstat”，与当前design/round7 exact400蓝图不一致

- 位置：`tasks.md:29`。
- 违反依据：`requirements.md` R3（25行）要求的是可观察条件；`design.md:66`定义Path语义和全物理ancestor条件；`design.md:200,206`把round7 exact400作为不可删oracle的硬蓝图。
- 证据：已验证的round7蓝图使用`parent.lstat()`配合`parent.resolve(strict=True) == parent`、workspace absolute/absent和`case_log.parent == workspace`实现当前Path契约，并没有实现显式逐组件lstat循环。Task 2的文字会迫使实现者偏离唯一400行蓝图，既增加行数又创造新的路径语义。
- 具体修法：把步骤3逐字改成当前蓝图：对workspace parent执行`lstat`，要求workspace absolute且`parent.resolve(strict=True) == parent`、parent为directory；要求workspace/log不含解析后仍保留的`..`，并以`case_log.parent == workspace`保证absolute direct-child。不要另造逐祖先walker。

#### I4. Task 1与Task 3的预提交Git门会漏掉本任务改动

- 位置：`tasks.md:17`、`tasks.md:45`。
- 违反依据：R8/R9的exact1/400、零越界diff与`git diff --check`硬门；tasks细则要求每个任务的验证命令能真实判定成败。
- 证据：Task 1创建的driver在未stage时是untracked，`git diff --name-only "$BASE_SHA"`和numstat不会看到它，因而“只含driver/<=400”可假绿。Task 3在提交前运行`git diff --check "$BASE_SHA"..HEAD`只检查已经提交的Task 1-2，不包含Task 3的index/worktree变化，正好漏掉本任务最大的一片。
- 具体修法：在隔离实现worktree对新文件先`git add -N`（或正式stage后用`--cached`），然后用覆盖BASE到当前index/worktree的name-only/numstat；Task 3至少运行无range的`git diff --check`检查当前worktree，并在提交后由review package再跑`git diff --check "$TASK_BASE" "$TASK_HEAD"`。最终accepted HEAD仍须单独跑`BASE..HEAD` exact1/400。

#### I5. 03a2顺序门只有起点证据和口头约束，缺少写ledger前的最终机械检查

- 位置：`tasks.md:13`、`tasks.md:59`。
- 违反依据：R8（35行）和验收清单（55行）要求03a1 accepted HEAD与全PASS manifest先入ledger，之前不得存在03a2 worktree/base/dispatch；PLAN v5.6依赖图与固定顺序（`PLAN.md:246-250,268`）。
- 证据：Task 1只在执行起点保存一次03a2不存在证据；Task 4最终只写“之后才允许创建”，没有在写ledger前重查worktree、branch、execution-base或dispatch artifacts。长达四个任务后，起点快照不能证明最终顺序。manifest AWK本身机械有效，但`BASE_SHA`/`REVIEW_MANIFEST`也没有在命令中做非空初始化检查。
- 具体修法：最终门先用明确路径初始化并断言`BASE_SHA`与`REVIEW_MANIFEST`非空，再紧邻ledger写入前机械检查03a2 worktree、branch/ref、work目录、execution-base和dispatch/brief均不存在；随后验证最终HEAD的manifest并写ledger，ledger写成功后才允许创建03a2。把这组证据保存到03a1 acceptance report。

## 覆盖与质量核对

- R全集：通过；四任务需求并集精确为R1-R9。
- 五字段/编号：通过；四任务均有`文件/消费/产出/需求/必需`，编号单层且无重复。
- 签名链与孤儿产出：通过；`race-cli-v1 → race-matrix-boundary-v1 → race-matrix-37-v1 → session-path-race-driver-v1`逐字连续，最终产出与requirements frontmatter/终交付物一致。
- R1-R7功能覆盖：文字覆盖完整，但I1/I2/I3使其尚不能成为可信可派发纵切。
- R8/R9验收与顺序：未闭合，受B1、I4、I5影响。
- 独立回滚：在“每片review PASS后才派下一片”的串行前提下成立；本片不发布capability，任一失败可回滚当前commit而不修改03/03a或03a2。
- Conventional Commits：通过；四个提交名均为普通个人项目`test(session): ...`，没有引入公司五段式模板。
- Scope/YAGNI：通过；源码清单始终只含`tests/lib/session-path-race-driver.py`，没有把03a2 entrypoint、public API或consumer带回本片。

修复以上finding后，应重新运行`check-tasks.py`、requirements机械检查与`git diff --check`，并派全新上下文reviewer做round 2。
