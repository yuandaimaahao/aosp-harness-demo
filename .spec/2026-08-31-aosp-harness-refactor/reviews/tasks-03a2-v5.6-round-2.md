# 03a2 tasks review（PLAN v5.6 round 2）

Reviewer: `review_plan_v5_2`

Verdict: **NEEDS_CHANGES** — blocker 1 / important 2 / minor 0

审查范围：只读复核当前`tasks.md`，对照同目录requirements/design、PLAN v5.6、137/400 sizing prototype及spec tasks细则；逐项验证round1 I1–I3/M1，并检查新增Bash骨架、验收资产、manifest与双仓顺序门。未修改规格正文、production、STATE或ledger；本文为本轮唯一新增文件。

## Round 1 findings复核

| finding | 状态 | 精确证据 |
|---|---|---|
| I1 三任务没有代码骨架 | ✅ 闭合 | Task 1 `tasks.md:17-26`、Task 2 `:41-63`、Task 3 `:81-94`均有无省略号的fenced Bash纵切；收口依次精确停在`dependency classifier incomplete`、`race adapter incomplete`和终态run-matrix/log gate，没有把后序片提前带入。 |
| I2 driver零调用不可观察 | ⚠️ 主体闭合，Task 1文字仍错位 | Task 2 `:64-65`现要求healthy/provider-absent/18 anchor各用独立fake argv log并断言0调用，driver absent为0行，flag/foundation/core精确只有`protocol`。但Task 1自己的步骤4仍含混，见I1。 |
| I3 accepted-HEAD/manifest/03b门只有prose | ⚠️ 大体闭合但新增确定性缺口 | Task 3 `:75,95,99-212`固定验收资产、exact streams、fake matrix/log、full/depth-1/rollback、三行AWK、双仓common-dir与物理absence；但execution-base无owner导致脚本不能启动，且两个最终拒绝条件仍会假绿，见B1/I2。 |
| M1 `址得`笔误 | ✅ 闭合 | `tasks.md:95`已改为“跑真实no-arg/all，均得rc0”。 |

## Blocker

### B1 — 最终controller读取一个从未创建或声明的`execution-base.env`

- 位置：`tasks.md:13,75,109-116`。
- 证据：Task 3骨架把`BASE_FILE`固定为`$WORK/execution-base.env`并立即用`sed`读取；但Task 1步骤1只说“记录`BASE_SHA=$(git rev-parse HEAD)`”，没有把它以唯一`BASE_SHA=<40hex>`行写到该路径。三个任务的`文件`/`验收资产`/`产出`也都没有创建`execution-base.env`。当前work目录实查只有prototype/report/evidence/controller资产，不存在该文件。`set -euo pipefail`下，严格执行最终骨架会在`:114`读取时退出，无法到达manifest、checkout、rollback或ledger gate。
- 影响：即使三项实现及独立review全部PASS，最终accepted-HEAD门仍确定性不可完成；controller若临时手工造文件则又绕过了tasks的落盘产出与immutable BASE来源。
- 可执行修复：二选一并在Task 1/Task 3逐字统一：
  1. 推荐由controller在派Task 1前创建并声明验收资产`work/.../execution-base.env`，唯一内容为Task 1 implementation worktree当时HEAD的`BASE_SHA=<40hex>`；Task 1验证regular file、单行、commit存在且后续只读，所有dispatch携带其absolute路径。
  2. 或删除`BASE_FILE`推导，要求controller显式传入40hex `BASE_SHA`，像`CONTROL_REPO_ROOT`/`IMPLEMENTATION_WORKTREE`一样验证后使用。

无论选择哪一种，都必须保证manifest首base、BASE..HEAD exact1/400和Task 1实际execution BASE来自同一immutable值。

## Important

### I1 — Task 1的provider-absent三种调用澄清仍放在Task 2，Task 1 brief自身可漏测flag

- 位置：`tasks.md:27`与`:65`。
- 证据：Task 1步骤4仍写“验证no-arg/all/provider-absent均rc0”，把两个argv形态与一个dependency状态混成同一列表，既没有逐字写`--dependency-absent`，也没有说明三次运行都在同一个provider物理缺席root。正确澄清出现在Task 2步骤4：“任务1的provider-absent root必须分别以no-arg、`all`、`--dependency-absent`调用”；但执行agent/reviewer按tasks细则可能只拿到当前任务brief，不能依赖未来任务补充当前任务green oracle。
- 影响：Task 1可以只测provider-absent default，或误把第三项当成状态标签而不是flag调用，仍生成本任务PASS manifest行。Task 2最终虽可能补测，但Task 1的R3/R4纵切与独立review不再自足。
- 可执行修复：把`:65`的完整句子复制到Task 1步骤4并删除含混短语；Task 2保留自身fake-call优先级测试即可。

### I2 — 最终“fail-closed”骨架会掩盖Git查询错误，且没有在验收后确认accepted implementation clean

- 位置：`tasks.md:136-148,177-183,196-207`。
- 证据一：主implementation在accepted default/offline及dependency hash复核后没有运行`git -C "$IMPLEMENTATION_WORKTREE" status --porcelain`。Task 3步骤5只要求提交时clean；最终review/fix后重跑controller时，未提交或untracked污染可以留在主worktree，而full/depth clone只读取HEAD并继续全绿，违反R8的最终clean门。
- 证据二：`:206`使用`! git worktree list --porcelain | grep ...`，`:207`使用`! git show-ref --verify --quiet ...`。在`set -o pipefail`下实际反证：让pipeline上游返回23或单命令返回17，前置`!`都把整体状态变成0；因此Git查询/仓库错误会被当成“03b不存在”而放行，不是fail closed。前面的repo/common-dir检查降低了概率，但没有改变该命令的错误分类。
- 影响：accepted worktree污染或Git检查异常时仍可写ledger并解除03b门；manifest/HEAD正确也不能补偿当前状态和顺序证据假绿。
- 可执行修复：
  - 在所有accepted main测试、hash和BASE..HEAD检查之后追加`[[ -z $(git -C "$IMPLEMENTATION_WORKTREE" status --porcelain) ]]`，并在review fix后再次运行。
  - 先把`git worktree list --porcelain`成功输出捕获到变量/文件，再单独用`! grep`查内容；对`show-ref`用`if ...; then exit 1; else rc=$?; [[ $rc == 1 ]]; fi`，只接受“ref不存在”的精确rc1，任何其他错误拒绝。
  - rollback段同时逐字检查offline末摘要，并对`session-state-snapshot.sh`与`tests/test-session-snapshot.sh`都做`! -e && ! -L`，使“不需要任何03b文件”与sizing evidence一致。

## 已确认成立的部分

- 三任务五字段、编号、消费/产出链与scope均正确；需求并集精确为`R1..R10`，源码diff仍唯一`tests/test-session-path-races.sh`。
- 三个实现骨架无TODO/省略号，顺序与prototype一致；Task 1/2的唯一过渡红灯不会把真实dependency-present状态假报PASS。
- Task 2新增fake fixture调用矩阵已闭合provider/driver/core优先级：healthy/provider-absent/18 anchor为0调用，driver absent为0行，flag/foundation/core为唯一`protocol`且无run-matrix/self-test。
- Task 3主验收现在逐字捕获protocol 28B、self-test 38B、default 41B与offline discovery；fake evidence复核37行/37唯一ID/九类计数/ordered log；full/depth-1逐checkout检查精确双流、SHA与clean；rollback先删除entrypoint再跑private self-test/offline。
- 三行manifest AWK用合法连续样本实跑rc0，空reviewer样本rc1；task-1..3、40hex、首base、相邻连续、末HEAD与全PASS条件正确。
- controller fenced block提取后`bash -n` rc0；双仓使用显式absolute roots且common-dir检查与现有linked worktree布局相符。上述B1/I2是运行期对象/错误分类问题，不是shell语法问题。
- 137行总实现与约一分钟的完整prototype controller证据仍支持三片各自一次上下文、独立回滚和`<10分钟`review，无需重新拆spec。

## Mechanical checks

- `check-tasks.py`: rc0
- `check-req.py`: rc0
- `check-criteria.py`: rc0
- `check-analyze.py`: rc0
- `check-plan.py`: rc0
- `git diff --check`: rc0
- controller fenced Bash：`bash -n` rc0
- manifest合法三行：rc0；空reviewer：rc1
- negated worktree pipeline上游rc23：整体rc0（反证I2）
- negated `show-ref`替身rc17：整体rc0（反证I2）

机械脚本不覆盖B1的execution-base owner或I2的negation错误分类。
