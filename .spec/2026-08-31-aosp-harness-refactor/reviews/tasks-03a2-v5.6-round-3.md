# 03a2 tasks review（PLAN v5.6 round 3）

Reviewer: `review_plan_v5_2`

Verdict: **PASS** — blocker 0 / important 0 / minor 0

审查范围：最终只读复核当前`tasks.md`，对照requirements/design、PLAN v5.6、137/400 sizing evidence及spec tasks细则；逐项验证round2 B1/I1/I2并检查修订后的BASE传递、accepted clean、rollback与03b fail-closed门。未修改规格正文、production、STATE或ledger；本文为本轮唯一新增文件。

## Round 2 findings closure

| finding | 状态 | 精确证据 |
|---|---|---|
| B1 未创建的`execution-base.env`使终门不可运行 | ✅ 闭合 | `tasks.md:13,99,113-115`不再读取或推导当前spec的execution-base资产。controller在Task 1派发前从implementation HEAD锁定40hex commit，并把同一immutable `BASE_SHA`显式传入三个brief/report及最终命令；终门重新验证其40hex grammar和commit对象。全文只剩`:217`检查未来03b的execution-base路径必须物理缺席。 |
| I1 Task 1 provider-absent三种调用澄清错放Task 2 | ✅ 闭合 | Task 1自身`tasks.md:27`现在逐字要求在同一个provider物理缺席root分别运行无参数、`all`、`--dependency-absent`，三者均rc0/stdout41B/stderr0，并明确不得把provider-present误解为inert。Task 1 brief不再依赖未来任务。 |
| I2 Git absence错误被`!`掩盖且accepted main未复验clean | ✅ 闭合 | accepted main在真实测试/hash后`:147`检查clean，并在BASE..HEAD exact1/400后`:200`再次检查clean。`:208-211`先要求`git worktree list`成功赋值，再只对grep命中返回失败；`:212-216`显式捕获`show-ref`并只接受精确rc1，其他Git错误不再被negation转成成功。 |
| I2 rollback证据补强 | ✅ 闭合 | `tasks.md:187-195`要求private self-test精确38B/0B、offline rc受`set -e`约束且stderr0、race摘要0次、offline末摘要精确，并同时证明03b provider与test均非存在对象/非symlink，最后rollback checkout clean。 |

## Final consistency check

- 三任务各有可直接落地且无占位符的Bash纵切：Task 1只到`dependency classifier incomplete`，Task 2以固定provider→anchor→driver type/protocol→flag/foundation/core顺序到`race adapter incomplete`，Task 3只闭合run-matrix/双流/ordered CASE_LOG和最终摘要。三条红因真实、唯一且不会把未完成的dependency-present入口假报绿。
- Task 2的调用优先级可机械观察：healthy过渡态、provider absent和18个anchor组合各自使用独立fake argv log并要求0调用；driver absent为0行；flag/foundation/core精确一行`protocol`且无run-matrix/self-test。
- Task 3固定accepted-default、fake argv、matrix、expected log、acceptance report和三行manifest资产。主worktree、full、真实file-URL depth-1分别验证protocol 28B、self-test 38B、default 41B、offline discovery/末摘要、dependency SHA与clean；depth-1另检查commit-count=1和非空shallow文件。
- fake evidence机械证明只有`protocol,run-matrix`两行且没有self-test，matrix为37行/37唯一ID/九类连续计数，case-log与第一列逐字一致。accepted real default的精确41B PASS来自同一受review入口，inert摘要不能单独满足该组合门。
- 三行六列manifest AWK绑定显式immutable BASE与implementation accepted HEAD，验证task-1..3、40hex、首base、相邻连续、reviewer非空和全PASS；BASE..HEAD exact只含`tests/test-session-path-races.sh`且numstat不超过400。
- 双仓角色闭合：implementation提供accepted HEAD/clean/diff，controller主仓提供`.spec`、manifest、acceptance与ledger；两者absolute root及Git common-dir必须一致。03b worktree/ref/spec/work/BASE/manifest/brief均在ledger前以会失败的命令和`! -e && ! -L`物理缺席判据检查，ledger成功后才允许选中03b。
- 需求并集精确`R1..R10`，消费/产出链连续，无孤儿产出；implementation scope始终exact1，不修改03/03a/03a1、03b、public API或capability。review fix后对新最终HEAD重跑步骤4/5及终门。
- 137行总蓝图与已实跑约一分钟的完整controller支持三个连续小diff各自单上下文、失败独立回滚、独立review`<10分钟`，无需继续拆任务或拆spec。

## Mechanical evidence

- controller fenced Bash：`bash -n` rc0
- `check-tasks.py`: rc0
- `check-req.py`: rc0
- `check-criteria.py`: rc0
- `check-analyze.py`: rc0
- `check-plan.py`: rc0
- `git diff --check`: rc0
- manifest合法连续三行：rc0；空reviewer负例：rc1
- 当前03b branch的`show-ref --verify --quiet`：rc1，符合终门唯一允许的absence分类
- 真实linked implementation worktree的file-URL `--depth 1` clone：rc0、commit-count 1、`.git/shallow` 41B
- 当前spec execution-base资产引用：0；仅未来03b absence列表保留1处
- tasks/必需任务：3/3；fenced Bash blocks：4；需求并集：精确R1–R10

未发现新的scope、依赖、回滚、400行、manifest或顺序门承重问题。
