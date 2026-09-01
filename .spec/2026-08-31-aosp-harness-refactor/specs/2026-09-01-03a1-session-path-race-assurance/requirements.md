---
id: 2026-09-01-03a1-session-path-race-assurance
依赖: [2026-09-01-03a-session-path-safety]
消费: "session-path-delivery-v1 —— common/.harness/lib/session-state-path.sh中的_harness_session_path_core <project-id> <session-id>与三个生产文本唯一anchor；core成功path+LF/0、OS错1、安全/协议错2"
产出: "session-path-race-driver-v1 —— tests/lib/session-path-race-driver.py提供protocol、self-test与run-matrix私有CLI，self-test固定输出RESULT PASS  session path race driver；无运行时API"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户已明确后续按autopilot执行；PLAN v5.6增量review round2 PASS，round7可执行原型补齐路径隔离后实测private driver 400/400、37/37、14项active self-disproof与full/depth-1全PASS
---

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并确认后续按 autopilot 执行。原单文件设计在round6实测411/400后回PLAN；本requirements按已通过review的PLAN v5.6只定义03a1 private driver片。

## 目标

在不修改03a provider、不进入root gate默认发现、不发布运行时API的前提下，交付一个可由未来03a2纯数据调用的private Python race driver。driver通过三个生产anchor、完整对象签名/inventory/delta oracle、精确37-case自测与14项主动自反证，证明root/project/session三层竞态下的返回分类、nofollow身份与零意外副作用。

私有接口目标明确包含`protocol`、`ABSENT_WORKSPACE`、`CASE_TSV`与`CASE_LOG`，路径语义以Python `Path`词法解析结果为准；注入目标仅为`HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN`、`HARNESS_TEST_MARKER_EXPECTED_EUID`与`HARNESS_TEST_MARKER_OS_ERROR`；对象签名明确包含symlink `readlink` target。本片始终保证`HARNESS_SESSION_STATE_PROVIDER_VERSION`缺席。

## 需求

R1. [计划] 当03a provider与foundation存在时，系统必须只新增`tests/lib/session-path-race-driver.py`；driver只读显式传入的foundation/provider，只在私有临时workspace内创建provider copy并替换单一anchor，不得修改、source覆盖或提交provider，不得读取/执行未来`tests/test-session-path-races.sh`，不得设置`HARNESS_SESSION_STATE_PROVIDER_VERSION`或定义任何状态public API。

R2. [计划] 当调用private CLI时，系统必须只接受以下三种形状：`protocol`、`self-test FOUNDATION PROVIDER`、`run-matrix FOUNDATION PROVIDER ABSENT_WORKSPACE CASE_TSV CASE_LOG`。`protocol`必须在不读任何依赖或matrix时以rc0、stderr空、stdout逐字节`session-path-race-driver-v1\n`返回；`self-test`与`run-matrix`成功必须以rc0、stderr空、stdout逐字节`RESULT PASS  session path race driver\n`返回。unknown mode、arity错或额外参数必须返2；row、oracle或执行失败必须返1；任何失败都不得打印private PASS摘要。

R3. [计划] 当调用`run-matrix`时，系统必须要求`ABSENT_WORKSPACE`与`CASE_LOG`经Python `Path`词法解析后都是absolute path且不含`..`组件。从filesystem root到workspace parent的每层都已物理存在且为非symlink directory，leaf在调用前物理不存在，并由driver以`parents=False`、0700创建；`CASE_LOG`必须是workspace的直接子项且调用前不存在，由driver以`O_CREAT|O_EXCL|O_NOFOLLOW`、0600创建并只通过持有fd写入。`CASE_TSV`必须至少含一行、无NUL，每行为`id<TAB>family<TAB>layer<TAB>variant`四列枚举数据，不得解释为代码、路径或表达式。系统必须在任何case执行前拒绝workspace/log的直连、symlink、hardlink、既有对象或缺失parent，以及空列/额外列、重复ID、未知family/layer/variant和非法组合；失败时provider hash必须不变。成功时`CASE_LOG`必须按输入顺序且仅记录每个真实执行的唯一case ID；合法非37子集也必须只执行输入rows并成功。

R4. [计划] 当运行`self-test`时，系统必须在driver内部自足构造并实际执行且仅执行以下37个唯一case：root/project/session × existing换入safe-dir/link/file共9；三层wrong EUID共3；三层 × EEXIST safe/unsafe/disappearing共9；三层mkdir-success replacement、mkdir failure、post-mkdir disappearance、open disappearance、final-stat disappearance各3；真实`OSError(errno.EIO)`共1。EEXIST safe必须是path+LF/0；safe-dir identity replacement、link/file、wrong EUID和mkdir-success replacement必须是空stdout/unsafe stderr/2；disappearance、mkdir failure和EIO必须是空stdout/operation stderr/1。

R5. [计划] 当执行任一race case时，系统必须仅通过生产文本各精确一次的`HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN`、`HARNESS_TEST_MARKER_EXPECTED_EUID`、`HARNESS_TEST_MARKER_OS_ERROR`之一做copy/count/replace；每个child只替换一个marker-bearing line，不得替换普通生产needle。MANAGED必须核对`layer/name/phase/made/catch`，EXPECTED_EUID必须核对`layer/name/N/A/made/0`，OS_ERROR必须是layer-independent的全N/A；EEXIST必须有序命中`before_mkdir/catch=0`与`after_eexist/catch=1`。marker缺席/重复、替换计数非1、sentinel/phase/made/catch不符、case未真实执行或ID重复/缺失必须失败；生产provider前后字节摘要必须相同。

R6. [计划] 当执行R4的任一case时，系统必须在调用前后比较按relative-path filesystem bytes（等价C locale）排序的scoped inventory与完整对象签名：path key、lstat type/dev/inode/mode/uid，symlink `readlink` target，regular file内容SHA-256以及允许对象集。共享delta必须精确区分`added/removed/replaced/protected/post-predicate`；swap必须按相对suffix对victim subtree做path-key重键并保持签名；mkdir replacement必须在rename前记录runtime original完整签名并与`.old`逐字比较。系统必须证明不跟随link/file victim、不chmod任何既有或替换对象、不在不安全层下创建后续层、不删除或改写允许delta之外的对象。逆序创建的非字典序名称必须得到同一canonical inventory。

R7. [计划] 当`self-test`准备打印成功摘要时，系统必须已主动破坏并真实拒绝且仅拒绝以下14类oracle：protected signature、unexpected inventory、allowed changed paths、symlink readlink target、regular file hash、mode、inode、EEXIST second hook、marker count、sentinel、phase、made、catch、case invocation。自反证必须比较精确名称/顺序与预期异常；缺少任一项、未触发失败或吞掉未知错误时不得打印PASS。

R8. [计划] 当03a1进入验收时，系统必须在accepted HEAD的完整历史与真实file-URL `--depth 1`两种checkout中分别以当前tracked foundation/provider运行`protocol`与`self-test`，两种都必须rc0、精确摘要且不查询固定历史SHA；`bash ./scripts/check.sh --offline`必须rc0且不默认发现`tests/lib/*.py`。Python语法编译、provider hash、03/03a回归、`git diff --check`和worktree clean必须通过。execution BASE到accepted HEAD必须exact只新增`tests/lib/session-path-race-driver.py`且numstat总和`<=400`，03/foundation、03a provider/core test diff为空；六列review manifest必须与tasks一一对应、首尾/相邻连续、reviewer非空且全PASS。controller必须先把03a1 accepted HEAD与全PASS manifest记入ledger，才允许创建03a2 worktree、固定base或dispatch任务。

R9. [计划] 如果发生case数或九类计数不符R4、自反证数不是14、implementation numstat超过400、完整/depth-1任一失败、03/03a发生非零diff、manifest断链或任何review非PASS，系统必须拒绝03a1验收并不得开始03a2。

## 验收标准

终交付物：`session-path-race-driver-v1 —— tests/lib/session-path-race-driver.py提供protocol、self-test与run-matrix私有CLI，self-test固定输出RESULT PASS  session path race driver；无运行时API`。

主验证命令: python3 tests/lib/session-path-race-driver.py self-test common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh
期望输出: 退出码为`0`、stderr空，stdout逐字节精确为`RESULT PASS  session path race driver\n`

验收清单:

- [ ] `protocol`在不读依赖时输出精确`session-path-race-driver-v1\n`；self-test/run-matrix成功输出精确38-byte摘要，unknown mode/arity/extra为2，row/oracle/执行错为1，所有失败无PASS。
- [ ] self-test自足执行37/37：按R4顺序的九类计数为`9/3/9/3/3/3/3/3/1`，没有重复、未知或缺失ID，不读取03a2文件。
- [ ] 外部四列TSV的37-row与合法非37子集run-matrix均与self-test使用同一family executor；case log与输入ID逐字、有序一致，非法列/组合/ID全拒绝。workspace/log的直连、symlink、hardlink、既有对象和缺失parent均在0 case前拒绝，provider hash不变。
- [ ] 每个child只替换一个唯一anchor；MANAGED/EXPECTED_EUID/OS_ERROR字段、EEXIST双hook、sentinel/made/catch、stdout/stderr/rc全部逐例闭合，provider hash不变。
- [ ] 九family全部消费共享完整signature/inventory/delta oracle；swap subtree重键、symlink target/file hash/mode/inode、mkdir runtime-original、protected/allowed set与无后续创建逐例通过。
- [ ] 14项active self-disproof逐项真实触发预期失败，名称/顺序精确；主动破坏任一项时总摘要不得PASS。
- [ ] 完整历史与真实depth-1 checkout的protocol/self-test均PASS；offline gate不发现private driver，Python语法、03/03a回归、provider hash、diff-check和clean均PASS。
- [ ] BASE..HEAD exact1且只是driver，numstat`<=400`，03/03a零diff；review manifest连续绑定accepted HEAD并全PASS；03a1记录入ledger前不存在03a2 worktree/base/dispatch。

不变量（不许劣化，2-4项）:

- 37个允许case之外的动态case数 ≤ `0`，验证: self-test内建ID集与run-matrix case log。
- victim、original、replacement与允许对象的未授权签名变化数 ≤ `0`，验证: 主验证命令。
- 03/foundation、03a provider/core test的BASE..HEAD变更文件数 ≤ `0`，验证: 限定路径的`git diff --name-only "$BASE" "$HEAD"`。
- 完整历史与depth-1 checkout的private self-test失败数 ≤ `0`，验证: 两种checkout分别运行主验证命令。

## 超出范围

- 不新增`tests/test-session-path-races.sh`，不实现root gate默认入口、37-row外部matrix生成、provider/driver/foundation/core缺席inert或最终`session path race assurance`摘要；这些由03a2独占。
- 不修改03/foundation、03a provider/core test，不新增生产模块、public API、capability marker或coverage fragment。
- 不实现snapshot/write/read、signals、remove/prune、aggregator或任何consumer；03a2必须等待本片accepted HEAD。
- 不声称抵御未由三个生产anchor表达的任意真实调度时序；本片是确定性race assurance driver，不是形式化证明、压力或性能测试。
- 不调用真实设备、网络、AOSP build或Claude/Codex客户端，不发布、不push，不清理既有worktree/分支。
