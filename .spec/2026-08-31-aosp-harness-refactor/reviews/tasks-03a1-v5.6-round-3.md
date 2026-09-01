# 03a1 tasks review（PLAN v5.6 round 3）

Verdict: **NEEDS_CHANGES** — blocker 2 / important 2 / minor 0

审查范围：只读复核当前`tasks.md`，对照同目录`requirements.md`、`design.md`、PLAN v5.6及spec tasks门禁；实际检查五任务红绿、14-mutant代码块、最终shell条件、exact400蓝图和accepted-HEAD顺序。未修改规格、STATE或ledger；本文是本轮唯一新增文件。

## Blocker

### B1 — 14-mutant harness不能命中任务给出的`inode` callback，Task 5无法按文档转绿

- 位置：`tasks.md:132-133`与`tasks.md:155-170`。
- 违反依据：`requirements.md:33,53`要求14项自反证逐项真实触发、名称/顺序精确且任一被破坏时无PASS；spec tasks门禁要求每个任务有可直接判定成败的验证，禁止把关键实现留给执行者二次设计。
- 证据：callback骨架把`inode`写成两行：第一行有`reject_field(`但没有`"inode"`，第二行有`"inode"`但没有`reject_field(`。mutation harness只接受“同一物理行同时包含label及`must_reject(`/`reject_field(`”。对当前代码块逐字执行其hit表达式，13项各命中一次，`inode`结果为`[]`；随后`assert len(hits) == 1`必然中止，根本不会完成14-mutant执行。该harness还对无语义影响的Python换行方式敏感。
- 具体修法：最小修复是把`inode` callback保持为round7原型中的单物理行，并在tasks中逐字固定这一约束；更稳健的修复是让harness按AST调用节点或完整调用span定位并替换，先机械断言14个label各对应一个完整call site，再实际运行14份mutant。修后必须把14个hit列表和14次rc1/0B/no-PASS作为证据。

### B2 — 最终顺序门没有一个cwd能同时绑定accepted实现HEAD和controller主仓`.spec`

- 位置：`tasks.md:174-191`，尤其`:180,182-187`。
- 违反依据：`requirements.md:35-37,55`要求manifest末HEAD绑定03a1 accepted HEAD，并且controller主仓的03a2 worktree/base/dispatch artifacts在ledger写入前不存在；PLAN `:65,246-250,268`把controller manifest和03a1→03a2顺序列为硬门；spec execute采用独立implementation worktree。
- 证据：命令用同一个当前仓同时计算`HEAD_SHA=$(git rev-parse HEAD)`和`PROJECT_SPEC_ROOT="$REPO_ROOT/.spec/..."`。在implementation worktree运行时，`HEAD_SHA`才是待验收candidate/accepted HEAD，但检查的是implementation worktree下的`.spec`副本，不能看到controller主仓中新建的spec/work/brief；在controller主仓运行时，`.spec`路径正确，但`HEAD_SHA`是主仓HEAD而不是隔离实现HEAD。当前项目也实际证明两者分离：controller root为`.../aosp-harness-demo`、既有implementation root为`.../aosp-harness-demo-03a-session-path-safety`，HEAD分别为`109c414...`与`f91f54d...`。因此该门可能漏掉已提前创建的03a2控制产物，或错误拒绝正确manifest，不能证明R8/R9。
- 具体修法：显式、分别传入并验证absolute `CONTROL_REPO_ROOT`与`IMPLEMENTATION_WORKTREE`。用`git -C "$IMPLEMENTATION_WORKTREE" rev-parse HEAD`、status和BASE对象检查绑定accepted实现；用`$CONTROL_REPO_ROOT/.spec/...`检查spec/work/execution-base/manifest/task-1-brief；worktree/ref检查也显式指定同一个Git common-dir所属仓。不要从一个cwd推导两个角色。

## Important

### I1 — 两个自反证名称没有逐字匹配R7

- 位置：`tasks.md:129-130,148-150,155-157`；上游要求见`requirements.md:33`。
- 违反依据：R7不仅规定14类，还明确要求“比较精确名称/顺序”。tasks步骤2自己也声称按requirements名称精确比序。
- 证据：requirements名称是`symlink readlink target`与`regular file hash`；callbacks、`expected_disproofs`和mutation labels却写成`readlink target`与`file hash`。当前内部列表可以自洽PASS，却没有实现上游规定的精确名称。`design.md:110`也使用短名，但依据优先级为requirements高于design/tasks。
- 具体修法：在两个`reject_field` label、`expected_disproofs`和mutation `labels`三处统一改成`symlink readlink target`、`regular file hash`；这只改字符串，不增加LOC。同步验证14项顺序逐字等于R7。

### I2 — `[[ ! -e ... ]]`把dangling symlink当作“不存在”，03a2路径门可假绿

- 位置：`tasks.md:190-191`。
- 违反依据：`requirements.md:35,55`要求预定03a2 spec/work/worktree与execution/base/dispatch在ledger前不存在；这是对象不存在而非“目标可被follow”。
- 证据：Bash `-e`跟随symlink；对`ln -s missing dangling`实测`[[ ! -e dangling ]]`为真。于是NEXT_SPEC、NEXT_WORK、NEXT_WORKTREE或其artifact路径若是dangling symlink，当前两行仍可能全PASS，无法证明路径本身物理缺席。
- 具体修法：对每个精确路径同时拒绝存在对象和symlink，例如`[[ ! -e $p && ! -L $p ]]`；或者用一个明确的`lexists`式helper逐项检查。保留glob-free精确路径，并增加dangling-symlink负例，期望门非零。

## 已通过项

- 五任务均有`文件/消费/产出/需求/必需`五字段及五个编号步骤；编号单层、无重复。
- 需求并集精确为`R1..R9`；消费/产出链`race-cli-v1 → race-matrix-boundary-v1 → race-primary-families-v1 → race-selftest-red-v1 → session-path-race-driver-v1`连续，无孤儿产出。
- 五个纵切均有确定红因和本任务green：文件缺席→protocol；executor incomplete→EIO/preflight；首个swap未实现→primary families；首个managed family未实现→37-row executor且留下唯一self-disproof红；最后闭合self-disproof与验收。每片只改同一private driver、严格串行review后再派下一片，独立回滚条件成立；相邻diff可按明确family区段在10分钟内review。
- accepted-HEAD顺序本体正确：Task 5先本地green并提交、确认clean，再从candidate HEAD跑full/真实file-URL depth-1，review fix后对新HEAD重跑，最后才生成manifest并写ledger。B2只针对最终门的仓根绑定。
- 六列manifest AWK以五行合法样本实跑rc0；空reviewer和非PASS样本均rc1，seq/task/40hex/首base/相邻/末HEAD条件成立。
- round7 driver原型实际为400行，已记录37/37、14项、合法1/2/37-row与full/depth-1证据。按五任务顺序提取该蓝图、只改label字符串并在Task 5删除Task 4的唯一临时红灯，exact1/400仍可信；不得照当前展开后的callback排版增加行数，B1最小单行修复与已验证蓝图一致。
- scope正确：实现diff只允许新增`tests/lib/session-path-race-driver.py`，未带回03a2入口、inert dispatcher、public API或consumer；五个提交均为个人项目普通Conventional Commits。

## Mechanical evidence

- `check-tasks.py tasks.md`: rc0
- `check-req.py requirements.md`: rc0
- `check-criteria.py requirements.md`: rc0
- `check-analyze.py requirements.md`: rc0
- `check-plan.py PLAN.md`: rc0
- `git diff --check -- tasks.md requirements.md design.md`: rc0
- final shell fenced block `bash -n`: rc0
- 14-label line-hit probe：13项singleton，`inode=[]`
- dangling-symlink absence probe：`[[ ! -e dangling ]]`为true

修复B1/B2/I1/I2后，应重跑上述机械检查、14-mutant harness与最终shell的双仓/链接负例，再派全新上下文reviewer做下一轮复审。
