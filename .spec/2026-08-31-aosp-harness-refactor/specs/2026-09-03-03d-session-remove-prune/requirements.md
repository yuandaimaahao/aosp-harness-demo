---
id: 2026-09-03-03d-session-remove-prune
依赖: [2026-09-03-03c-session-write-interrupts]
消费: "session-signals-facade-v1的唯一私有export _harness_session_write_with_signals <project-id> <session-id> <feature>（常规沿用snapshot write的0|1|2|3双流空，HUP/INT/TERM恰129|130|143）；session-foundation-v1、session-path-delivery-v1、session-snapshot-core-v2的既有public/private export（harness_validate_feature_name、_harness_session_state_run、_harness_session_state_foundation_path、_harness_session_path_core、_harness_session_snapshot_worker、_harness_session_snapshot_write_core、_harness_session_snapshot_read_core，供aggregator thin转接）；03c accepted ledger中的03d启动门（dependency-present active证据、exact2/400、full/depth-1/rollback与顺序门证据，无其他运行时API）"
产出: "session-state-provider-v1 —— common/.harness/lib/session-state.sh aggregator在foundation/path/snapshot/signals/remove五模块及预期export完整时设置HARNESS_SESSION_STATE_PROVIDER_VERSION=1并发布完整五public API（harness_validate_feature_name <name>；harness_session_state_path <project-id> <session-id>；harness_session_state_write <project-id> <session-id> <feature>；harness_session_state_read <project-id> <session-id>；harness_session_state_remove <project-id> <session-id>；成功0、OS错1、协议/安全错2、write异值冲突与read缺失3、remove缺失幂等0、write信号129|130|143）plus tests/test-session-state.sh固定摘要`RESULT PASS  session state`与独占tests/coverage.d/03d-session-state.md fragment"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户已授权后续按autopilot执行；03c验收记录（DECISIONS.md 2026-09-03 03c行）确认signals facade、exact2/400、full/depth-1/rollback与03d顺序门证据已入ledger，PLAN v5.7与03c requirements R8规定的03d启动门由该记录满足
---

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并确认后续按 autopilot 执行。PLAN v5.7要求03d交付remove模块与最终aggregator：remove实现non-creating verified remove、feature缺失prune与ENOENT/ENOTEMPTY幂等；aggregator仅在五模块及预期私有函数完整时设置marker并原子发布五public API，任一missing-module状态走legacy由03e/08处理。

## 目标

只新增私有模块`common/.harness/lib/session-state-remove.sh`、最终aggregator `common/.harness/lib/session-state.sh`、默认发现集成测试`tests/test-session-state.sh`与独占coverage fragment `tests/coverage.d/03d-session-state.md`：remove交付`_harness_session_remove_core <project-id> <session-id>`，以held fd identity核对（`PRUNE_BEFORE_IDENTITY`）自底向上prune安全的空session/project/root层级；aggregator只做thin组合，在五个模块及预期export逐个点名在场时才定义完整五public API——foundation已公开的`harness_validate_feature_name <name>`与新发布的`harness_session_state_path`/`harness_session_state_write <project-id> <session-id> <feature>`/`harness_session_state_read`/`harness_session_state_remove <project-id> <session-id>`——并设置`HARNESS_SESSION_STATE_PROVIDER_VERSION=1`，任一缺失则静默失败、完整capability不出现。本片不复制任何模块内部逻辑、不修改上游九tracked文件；dependency-present active证据入ledger后才可启动03e，inert PASS不能解除该顺序门。

## 需求

R1. [计划] 当`_harness_session_write_with_signals`已定义时，系统必须使source `common/.harness/lib/session-state-remove.sh`返回0、stdout/stderr为空，且只新增唯一私有export `_harness_session_remove_core`；source不得读写文件、覆写依赖、定义四个状态public API或设置`HARNESS_SESSION_STATE_PROVIDER_VERSION`。（依据PLAN v5.7 03d详情：remove模块的精确私有接口为`_harness_session_remove_core`；03c->03d依赖边：signals export absent时remove inert，其逆即present时定义）

R2. [计划] 当source remove模块的依赖检查中`_harness_session_write_with_signals`缺席时，系统必须静默返回0、双流空，并保持remove export、四个状态public API与provider marker全缺席。（依据PLAN v5.7 03d详情与03c->03d依赖边：signals export缺失时remove模块静默inert）

R3. [计划] 当调用`_harness_session_remove_core <project-id> <session-id>`且feature存在时，系统必须先校验两个ID为安全单组件，经non-creating verified路径删除该feature规则文件，并以held parent/child fd identity核对（`PRUNE_BEFORE_IDENTITY`）后自底向上尝试删除安全的空session/project/root目录；成功或目标缺失返回0，普通OS错（含remove路径真实EIO）返回1，协议/安全错返回2，stdout恒空，stderr精确为rc1 `error: session state operation failed\n`、rc2 `error: unsafe session state\n`，不存在rc3分支。（依据DECISIONS 2026-09-01 03 round 2错误表、round 3 prune口径与PLAN v5.7 03d详情的remove接口契约）

R4. [计划] 如果发生feature缺失而安全session/project/root目录存在，系统必须仍返回0并自底向上prune空层级；遇到并发非空目录时必须保持成功且不删除其他条目，ENOENT与ENOTEMPTY均按幂等成功处理。（依据DECISIONS 2026-09-01 03收窄round 3 I1-I3「remove在安全目录存在但feature缺失时仍prune空层级」与round 3「遇并发非空仍成功且不删其他条目」）

R5. [计划] 当foundation/path/snapshot/signals/remove五个模块文件均存在时，系统必须使aggregator `common/.harness/lib/session-state.sh`先验证五个模块文件路径，再按foundation、path、snapshot、signals、remove顺序逐个source，并逐个点名核对预期export：foundation的`harness_validate_feature_name`、`_harness_session_state_run`、`_harness_session_state_foundation_path`，path的`_harness_session_path_core`，snapshot的`_harness_session_snapshot_worker`、`_harness_session_snapshot_write_core`、`_harness_session_snapshot_read_core`，signals的`_harness_session_write_with_signals`，remove的`_harness_session_remove_core`。（依据PLAN v5.7 03d详情「先验证五个模块文件路径，再逐个source」及DECISIONS 2026-09-01 PLAN v5.3 P5/P2回流「03d仅在五模块及预期私有函数完整时设置marker并发布五API」）

R6. [计划] 如果发生任一模块文件缺席、source非零或预期export缺失，系统必须使aggregator静默返回1、双流空，不设置`HARNESS_SESSION_STATE_PROVIDER_VERSION`、不定义四个状态public API，使missing-module状态走legacy由03e/08处理。（依据PLAN v5.7 03d详情「任一source非零或预期私有函数缺失时自身静默返回1，不设置marker或定义四个状态public API」与03c->03d依赖边「aggregator返回1」）

R7. [计划] 当五个模块及全部预期export完整时，系统必须使aggregator只做thin组合：定义public `harness_session_state_path`、`harness_session_state_write`、`harness_session_state_read`、`harness_session_state_remove`分别转接`_harness_session_path_core`、`_harness_session_write_with_signals`、`_harness_session_snapshot_read_core`与`_harness_session_remove_core`，并设置`HARNESS_SESSION_STATE_PROVIDER_VERSION=1`；不得复制任何模块内部逻辑，public `harness_session_state_path`沿用path协议成功path+LF/0，write/read沿用snapshot的`0|1|2|3`与write信号`129|130|143`，remove沿用R3/R4契约；public `harness_validate_feature_name`继续由foundation单独提供，不代表完整capability。（依据PLAN v5.7 03d详情「只有全部成功后才定义public path/write/read/remove并设置marker；public validate可由foundation单独存在但不代表完整capability」与03d->03e依赖边）

R8. [计划] 系统必须提供默认发现且shfmt-clean的`tests/test-session-state.sh`，只接受无参数、`all`、唯一`--dependency-absent`或唯一`--session-provider-fixture <missing-foundation|missing-path|missing-snapshot|missing-signals|missing-remove>`；dependency-present默认/all必须覆盖remove矩阵（feature存在删除并prune、feature缺失幂等0且仍prune空层级、并发非空成功且不删他项、完整rc/stdout/stderr契约）与aggregator发布面（五个public API逐个存在、marker精确为1、五模块各自缺席与aggregator缺席的隔离shell fixture中marker未设置且完整五API predicate为false、consumer忽略任何已加载前序函数）；真实依赖缺席时默认与`--dependency-absent`运行同一inert surface并零active case；成功唯一摘要为`RESULT PASS  session state\n`，unknown/extra/flag带值返回1且不打印PASS。（依据PLAN v5.7 03d行验收命令、03d详情测试契约与回滚矩阵的`--session-provider-fixture` test-only参数要求；其中aggregator缺席fixture为本片自愿加严、非PLAN原文要求——PLAN.md:221将aggregator缺席覆盖划给03e/08；`--dependency-absent` flag在PLAN.md:223-234对本入口无直接依据，为本片与03c `tests/test-session-signals.sh`的同构外推）

R9. [计划] 系统必须交付独占coverage fragment `tests/coverage.d/03d-session-state.md`，登记本片session-state capability的需求到测试映射，不得修改02的`tests/COVERAGE.md`。（依据PLAN v5.7文件边界表03d行「独占`tests/coverage.d/03d-session-state.md` fragment；不修改02的`tests/COVERAGE.md`」与独立回滚矩阵02行）

R10. [计划] 当03d进入验收时，系统必须在candidate、完整历史checkout和真实`git clone --depth 1 file://...`中分别运行默认session-state测试与`bash ./scripts/check.sh --offline`，自动发现本入口恰好一次，且每个checkout的当前tracked上游九文件（common/.harness/lib/session-state-foundation.sh、common/.harness/lib/session-state-path.sh、tests/lib/session-path-race-driver.py、tests/test-session-path-races.sh、common/.harness/lib/session-state-snapshot.sh、tests/test-session-snapshot.sh、tests/test-session-snapshot-assurance.sh、common/.harness/lib/session-state-signals.sh、tests/test-session-signals.sh）SHA-256在测试前后不变。controller必须先逐字验证shfmt `v3.14.0`与ShellCheck version field `0.11.0`，再只对本片exact四文件中三个shell文件运行`shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`与`bash -n`；execution BASE到accepted HEAD必须exact只新增`common/.harness/lib/session-state-remove.sh`、`common/.harness/lib/session-state.sh`、`tests/test-session-state.sh`与`tests/coverage.d/03d-session-state.md`、numstat总和`<=400`，六列review manifest必须与tasks一一对应、首尾/相邻连续、reviewer非空且全PASS，`git diff --check`与worktree clean必须通过。（依据PLAN v5.7审查规模与文件边界、DECISIONS 2026-09-02 03b1上游集合裁定「后序片在此基础上累加各自前序交付」）

R11. [计划] 当验证独立回滚与顺序时，系统必须从accepted HEAD建立隔离临时分支，提交一个exact只删除本片四个交付文件的rollback commit，在该clean checkout运行03b基础测试、03b1 assurance入口、03c signals入口与offline并要求全绿、本入口发现0次；验收后丢弃临时checkout，不改变candidate/full/depth-1 checkout。controller只有在03d accepted HEAD、dependency-present active证据、exact4/400与全PASS manifest入ledger后，才可创建规范ID `03e-claude-session-lifecycle`（日期前缀由创建日决定，本片不预知）的spec目录、同名`spec/`分支/worktree、ledger execution BASE或dispatch记录；此前这五类资产必须物理缺席，以nullglob下`ls -d "$PROJECT"/specs/*03e-claude-session-lifecycle`缺席、`git show-ref | rg 'refs/heads/spec/.*03e-claude-session-lifecycle'`零匹配、`git worktree list --porcelain | rg 03e-claude-session-lifecycle`零匹配与`rg 03e-claude-session-lifecycle`对ledger/dispatch/execution-base记录零匹配机械核对；requirements/design/tasks等spec文档允许出现NEXT全名，禁令只针对ledger/dispatch/execution-base三类记录；任何inert PASS不得作为本片验收证据或解除该顺序门。（依据PLAN v5.7 spec表03e行为本片NEXT、独立回滚矩阵03d行与DECISIONS 2026-09-01 PLAN v5.3 P5/P2回流）

## 验收标准

主验证命令: bash ./tests/test-session-state.sh
期望输出: dependency-present时退出码为`0`、stderr空，stdout逐字节精确为`RESULT PASS  session state\n`

验收清单:

- [ ] remove模块source功能fixture返回0、双流空且只新增`_harness_session_remove_core`一个export；signals export缺席fixture逐字比较rc/双流、export inventory、四public API与provider marker全缺席，证明inert零副作用。
- [ ] feature存在时remove删除规则文件并自底向上prune空session/project/root层级；feature缺失幂等返回0且安全目录存在时仍prune空层级；并发非空目录仍成功且不删除其他条目；rc0/1/2与stderr错误表逐字一致，stdout恒空，不存在rc3分支。
- [ ] 五模块及预期export逐个点名在场时aggregator返回0，public path/write/read/remove分别转接`_harness_session_path_core`、`_harness_session_write_with_signals`、`_harness_session_snapshot_read_core`、`_harness_session_remove_core`且生产文本不含模块内部逻辑副本，marker精确为`1`，public validate由foundation提供。
- [ ] 五模块各自缺席的隔离shell fixture中，aggregator返回1、双流空，marker未设置且完整五API predicate为false；`--session-provider-fixture`五个取值各自复现对应missing-module inert surface。
- [ ] aggregator缺席的隔离shell fixture中，source尝试返回非零，marker未设置且完整五API predicate为false，不断言双流空（aggregator缺席fixture为本片自愿加严、非PLAN原文要求，PLAN.md:221将该覆盖划给03e/08）。
- [ ] 真实dependency-present默认/all与隔离dependency-absent默认/flag均得唯一固定摘要`RESULT PASS  session state\n`，但只有dependency-present active证据计入本片验收；unknown/extra/flag带值rc1且无PASS。
- [ ] `tests/coverage.d/03d-session-state.md`存在且为03d独占fragment；`tests/COVERAGE.md`的SHA-256在测试前后不变。
- [ ] candidate/full/depth-1的默认入口与offline全PASS，offline发现本入口恰好一次，depth-1 commit-count=1且shallow marker非空；每个checkout的上游九文件SHA-256测试前后不变且clean。
- [ ] 隔离rollback commit exact只删除本片四个交付文件后，clean checkout中03b基础测试、03b1 assurance入口、03c signals入口与offline全PASS且本入口发现0次；03e的spec/ref/worktree/BASE/dispatch按R11机械查缺席。
- [ ] review manifest六列、任务序号、execution BASE、相邻base/head、accepted HEAD和全PASS一次机械验证通过；BASE..HEAD exact name-only为上述四文件、numstat总和`<=400`，固定版本断言后对exact四文件中三个shell文件运行shfmt/ShellCheck/bash-n全绿，`git diff --check`和clean通过；只有dependency-present active证据入ledger后才可创建03e。

不变量（不许劣化，2-4 项）:

- 上游九tracked文件在execution BASE..HEAD的变更数 ≤ `0`，验证: `git diff --name-only "$BASE" "$HEAD" -- common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh tests/lib/session-path-race-driver.py tests/test-session-path-races.sh common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh tests/test-session-snapshot-assurance.sh common/.harness/lib/session-state-signals.sh tests/test-session-signals.sh`。
- 并发非空目录或其他session条目被remove/prune删除的次数 ≤ `0`，验证: `bash ./tests/test-session-state.sh`并发非空case前后对临时状态根做完整namespace inventory比较。
- 任一missing-module或aggregator-absent fixture中出现marker或形成partial五API capability的次数 ≤ `0`，验证: `bash ./tests/test-session-state.sh`六类inert fixture逐个核对marker unset与完整五API predicate为false。
- 既有Claude、Codex、common与已合入session回归失败数 ≤ `0`，验证: `bash ./scripts/check.sh --offline`。

## 超出范围

- 不实现Claude hook/demo生命周期接入（03e独占）；03e的全部资产（spec目录、`spec/`分支、worktree、ledger execution BASE、dispatch记录）在本片dependency-present active证据入ledger前继续物理缺席。
- 不修改上游九tracked文件（foundation/path/03a1 driver/03a2 entrypoint/snapshot/03b基础测试/03b1 assurance/signals/03c测试）与02的`tests/COVERAGE.md`；不新增信号契约，write的`129|130|143`沿用03c facade。
- 不承诺同EUID攻击者在最终dev/inode身份检查后、`rmdir`前换入空目录窗口的保护（DECISIONS 2026-09-01 03 design review B1已定此收窄）；`rmdir`不删除非空目录的保证不变。
- inert PASS不替代dependency-present证据；不调用设备、网络、AOSP build、Claude/Codex客户端，不push、不清理已有spec/prototype/implementation分支或worktree。
