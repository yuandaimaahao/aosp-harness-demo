# requirements 独立审查 · round 2

审查对象：`specs/2026-09-01-00-environment-seed-preflight/requirements.md`

依据：`PLAN.md` v4、`DECISIONS.md`、round 1 报告、`references/03-requirements.md` 与 `references/07-review.md`。本轮仅做文档与静态检查；没有运行主验证、AOSP lunch、编译、下载、源码修改或 state-dir 写入。

## 结论摘要

- 规格符合性：FAIL。修订稿已把 input/output descriptor 拆名，也补上 dispatcher、direct module、内容寻址、退出矩阵、独立 syscall/path/digest oracle；但它把 `seed-request/v1` 固定为 `local_lk7k_product`/`public_aosp_baseline=false`，没有产出或接收 PLAN 后序唯一需要的公开 AOSP 17 Cuttlefish seed，导致 00→02 的已批准链路没有 owner。
- 文档质量：FAIL。exit 0/20/30 的类别已经基本互斥，但“发布失败 exit 30 且 artifact/ref 零写入”与 artifact-first、rename、file/dir fsync 的提交顺序不可同时保证；稳定输出 ABI 仍把关键子字段交给未来 fixture 决定。
- 外部 oracle：round 1 的假绿主问题已关闭。验收明确要求从真实 CLI 外层使用 network namespace、`strace -ff`、poison PATH、独立 digest 重算和 mutation cases，已不再只信任被测程序自写日志或固定 PASS 文本。
- YAGNI：没有发现把 closure 求解、materialize、build 等后序功能提前塞进 00；新增的 namespace/trace/store/dispatcher 都有 PLAN、DECISIONS 或 round 1 finding 依据。问题是同片承载量很可能超过 PLAN 的 800 行非生成 diff 人审预算，requirements 尚未把超限时的拆分门写成可执行判据。
- 机械检查：`check-req.py`、`check-criteria.py`、`check-analyze.py` 均 exit 0。静态通过不覆盖下述跨文档、POSIX 提交语义和 ABI 完整性问题。

## round 1 findings 关闭状态（4 blocker / 7 important / 3 minor）

| round 1 finding | 状态 | round 2 结论 |
|---|---|---|
| B1 descriptor 输入/输出/产物同名，数据 ABI 不可实现 | ⚠️ 部分关闭 | R4 已拆成只读 `seed-request/v1` 输入和 `env-preflight/v1`/`terminal-report/v1` 输出，env override 也已禁止；但成功输出 schema 仍未逐字段固定，且拆分后丢失了 PLAN 公共 seed 的 owner/consumer 闭环。见 B1、B3。 |
| B2 遗漏 dispatcher、direct recovery ABI 与回滚 | ⚠️ 部分关闭 | frontmatter、R3/R19/R20 和清单已纳入三者；但 direct ABI 的精确 argv/入口签名、合法子命令语法，以及 exact merge commit 何时进入主验收仍未固定。见 I1、I6。 |
| B3 exit 20/30 与 artifact/ref 状态机不互斥 | ⚠️ 部分关闭 | state-dir/schema/path 归 30、有效请求下环境不可用归 20，artifact-first/ref-second 与 sentinel 已补；但发布失败的“零 artifact 写入”要求在 rename/fsync 后不可实现，多故障 reason/error 也无固定优先级。见 B2、I2。 |
| B4 安全不变量可被空日志/固定输出假绿 | ✅ 已关闭 | R11/R12 与清单第 1、4 项要求真实入口、外层 trace/namespace/poison、独立重算和 anti-mutation；原则上形成独立 oracle。其 trace 证据格式尚不完整，归入 B3/I4，不再是“只信自报”的原 finding。 |
| I1 PLAN seed 字段与 LK7K/vendor 角色未闭合 | ⚠️ 部分关闭 | Repo/manifest/container role/URL/disk/offline/seed digest 等字段和机器 role flag 已补；但 `public_aosp_baseline=false` 的本地结果明确不可被后序公开证明消费，却没有另一 seed owner。见 B1。 |
| I2 R1/R2/R3 来源标签覆盖非该来源子句 | ⚠️ 部分关闭 | dispatcher 已拆成 R3 `[计划]`；R1 仍把“调用侧展开/CLI 不展开/不硬编码”整体标 `[原话]`，R2 仍把 cwd、外置 OUT_DIR、记录字段和禁编译整体标 `[原话]`。见 I5。 |
| I3 worktree 隔离算法不可执行 | ⚠️ 部分关闭 | 已加入 realpath、symlink、分量 containment 和多 repo 枚举；但未存在的 out-ref/OUT_DIR 无法直接 realpath、`.repo/repo` 未纳入 worktree 枚举，创建时的 no-follow 口径也未固定。见 I1。 |
| I4 资源“可用”口径和边界未定义 | ⚠️ 部分关闭 | R9/R21/R22 增加了来源和等值/差 1/非法值；但 bytes、cgroup remaining、CPU quota 的精确算法仍不完整。见 I3。 |
| I5 dirty tree 证据与后序约束不完整 | ⚠️ 部分关闭 | R10/R12/R95 已补内容 digest、project 去重计数和 `clean_source_proof=false`；但 source-state canonical payload/domain、untracked 递归和 ignored 输入仍未闭合。见 I4。 |
| I6 默认问题与确认依据无审计记录 | ✅ 已关闭 | frontmatter 有确认依据，Autopilot 段写明 0/15、0/2、默认裁定和猜错代价，稳定口径已进入 `DECISIONS.md`。ledger 尚空是因为本轮 review 未通过，当前不应先记“自动通过”。 |
| I7 验收矩阵与主输出不精确 | ⚠️ 部分关闭 | exact stdout/stderr、路径/环境/dispatcher/collision/terminal 矩阵和 anti-fake 已显著补齐；仍缺 reason/error 枚举优先级、terminal 后控制流和可执行的 post-merge rollback 入口。见 I2、I6。 |
| M1 字面量 `~` 责任边界不清 | ✅ 已关闭 | R1/R4/ABI 已明确由调用侧展开，通用 CLI 拒绝字面量 `~`，且不读取测试环境变量。 |
| M2 terminal report 120 行上限丢失 | ✅ 已关闭 | R14、terminal schema 和清单均固定不超过 120 行。 |
| M3 `exit 30并` 文案空格 | ✅ 已关闭 | 修订文本已消除该格式错误。 |

汇总：完全关闭 5 项，部分关闭 9 项，未关闭 0 项；“部分关闭”中仍有 3 个阻断级缺口，因此不能 PASS。

## ① 规格符合性：R1–R22

| 需求 | 结论 | 审查要点 |
|---|---|---|
| R1 | ⚠️ | 行为边界清楚，但来源并非全是用户原话。 |
| R2 | ⚠️ | cwd、OUT_DIR 与 dumpvars-only 边界可验证；来源混标，且依赖未完全列出的 trace/variable ABI。 |
| R3 | ⚠️ | owner 与双入口方向符合 PLAN；合法子命令语法和 direct argv 未固定。 |
| R4 | ✅ | input/output 角色与 env precedence 已明确。 |
| R5 | ⚠️ | confinement 方向正确；未存在 leaf 的 canonicalization/no-follow 算法不完整。 |
| R6 | ⚠️ | 覆盖 harness、manifest repo 和 manifest projects；遗漏 Repo client checkout `.repo/repo`。 |
| R7 | ⚠️ | PLAN 所列观测大体齐全；多项字段的 canonical 表示仍由未来 fixture 决定。 |
| R8 | ❌ | 本地/vendor 隔离本身正确，但与 PLAN 后序必须消费的 public AOSP seed 形成断链。 |
| R9 | ❌ | threshold 数字正确，资源计量算法不足以唯一实现，且 `f_bavail` 不是 bytes。 |
| R10 | ⚠️ | dirty 可继续与 clean-proof flag 正确；source-state digest ABI仍不完整。 |
| R11 | ✅ | namespace、trace、禁止执行器与 dumpvars-only 边界形成可验收安全要求。 |
| R12 | ⚠️ | 前后独立重算方向正确；ignored 输入和 untracked 递归口径缺失。 |
| R13 | ⚠️ | 成功输出和发布顺序清楚；env artifact schema 与 post-rename failure 语义未闭合。 |
| R14 | ⚠️ | terminal artifact/ref 与行数闭合；并发多故障时 reason code 无优先级。 |
| R15 | ❌ | exit 类别清楚，但把所有发布失败都要求为 artifact/ref 零写入在 POSIX 提交点后不可保证。 |
| R16 | ✅ | 可构造 collision 与 object/ref 不变性明确。 |
| R17 | ⚠️ | digest、mode、no-replace、fsync 顺序充分；失败发生在 rename/dir-fsync 之后时的结果未定义。 |
| R18 | ❌ | artifact-first 后 ref 失败可合法留下无 ref 的 immutable object，当前却要求任何失败都不改变旧状态，无法普遍实现。 |
| R19 | ⚠️ | 等价性要求正确；缺 direct module 的精确调用签名。 |
| R20 | ⚠️ | PLAN 回滚目标已进入需求；但当前主验收在 merge commit 产生前无法执行 exact-commit revert。 |
| R21 | ⚠️ | 边界意图明确，依赖 R9 尚未确定的“实测值”算法。 |
| R22 | ⚠️ | invalid threshold 归 exit 30 已互斥；未给各 case 的稳定 `ERROR_CODE`。 |

## Findings

### 阻断（3）

#### B1. 00 的输出不能供已批准的公开 AOSP 17 链路消费，且没有其他 seed owner

- PLAN v4 的总目标、整体验收和 02 都固定消费 `common/tests/fixtures/aosp17-services/seed.json`，00 的职责是产出/固化公开 AOSP 17 Cuttlefish 的 immutable seed/环境描述。
- 当前 `seed-request/v1` schema 却把 `source_scope` 固定为 `role=local_lk7k_product`、`public_aosp_baseline=false`，R8/R118 又正确禁止后序把它当 public baseline。
- frontmatter 将 descriptor 改为“消费”而非 00 的产出；`env-preflight/v1` 通过 ref 发布，但 PLAN 的 `extract --descriptor .../seed.json` 和 `verify-proof --descriptor ...` 不消费这个 ref。01–05 的 owner 表也没有任何一片可以回头修改 00 schema 或补 public seed。
- 因而当前规格即使全部实现并 `ENV PASS lk7k-a17`，也不能解锁 02 的 `aosp17-services`，更不能完成 PLAN 的总验收。这不是 LK7K 标签问题，而是 dependency/output contract 断链。
- 必须在 requirements 中二选一并与 PLAN/DECISIONS 同步：让 00 的 v1 request/preflight ABI同时支持并验收 public AOSP17 Cuttlefish seed，另把 LK7K 作为明确的第二 fixture；或回 PLAN 重新分配 public seed owner、修改 02/整体验收 consumer 签名。仅写“后序仍需独立 seed”没有 owner，不能关闭此问题。

#### B2. 发布失败的“exit 30 + artifact/ref 零写入”与 atomic create/replace/fsync 协议不可同时实现

- R13/R14/R18 要求先发布 artifact，再发布 ref；R17/R18 的提交过程包含 rename/no-replace publish 和随后 parent-dir fsync。
- R15 与决策表又把任何发布失败都规定为 artifact、ref 和已有 sentinel 零变化；R18 甚至要求“任何失败”不改变旧 ref。
- 一旦 object rename/no-replace 已成功而后续 dir fsync 或 ref 发布失败，新 immutable object 已可能可见；一旦 ref rename 已成功而 dir fsync 报错，旧 ref 已被替换。POSIX 下无法保证恢复旧 bytes，也无法在 crash/IO error 后可靠判定 rename 是否持久化。强行删除 object 还违反已发布 object 不可变，并可能误删并发 producer 已复用的同 digest object。
- PLAN v4 对 exit 30 只禁止“任何新 ref”，并允许 content-addressed store 留下未被 ref 引用的同 bytes object；requirements 不应擅自强化成不可实现的事务。
- 必须定义明确提交点和可恢复状态：例如 pre-commit failure 零 ref 变化，artifact-first 后 ref failure 允许留下可重算的 orphan object但绝不留下 dangling/new ref；ref rename 后结果按可重读 bytes 判定成功或进入可审计 uncertain/recovery，而不是声称全量 rollback。故障注入验收要按每个提交点分别断言。

#### B3. `env-preflight/v1` 及其证据 digest 仍不是完整、独立可实现的数据 ABI

- 输入与 terminal payload 都至少显式提到 schema/kind；成功输出只列“字段组，并由 schema fixture 固定每组的子字段”，没有在 requirements 固定完整字段名、类型、nullability、排序/集合去重规则、`schema_version`/artifact `kind` 值。
- PLAN 要求所有输入 artifact 含 `schema_version: 1`，但 env payload 列表没有它；artifact store 路径也没有在本规格明确为 `artifacts/v1/sha256/<digest>`。
- `source-state digest`、trace digest、command-journal digest、completed-observations digest 都是承重 oracle，却没有各自的 payload schema、domain separator、成功 syscall/路径归一化和 reason-count 规则。R95 只定义 seed-content 如何引用 source-state digest，没有定义 source-state digest 本身。
- “以后由 fixture 固定”会让实现者自己决定验收标准，两个字段名/类型不同的实现都能满足当前 requirements；01/02 也无法在不读取实现细节的情况下稳定消费。
- 必须把 fixture 从“标准的来源”降为“标准的例子”：requirements 先固定每个 v1 payload/digest 的完整 schema 和 canonical algorithm，fixture/golden bytes 只验证该规范。

### 重要（7）

#### I1. dispatcher/direct recovery 与路径校验还缺可执行签名

- R3 只说 direct module 可执行，没有固定直接调用是 `commands.d/preflight --descriptor ...` 还是仍带 `preflight` argv；R19 因此无法独立写出等价调用。
- “合法子命令名”没有 regex/allowlist，无法机械证明 `../x`、slash、空串、Unicode/confusable 或额外参数不会越过 `commands.d`。
- R6 漏掉 Repo client Git checkout `.repo/repo`；R5 对尚不存在的 out-ref/OUT_DIR 使用“realpath 后”也没有规定解析现存 parent、拒绝 symlink 和创建 leaf 的办法。
- 应固定 direct argv、command-name grammar/lookup/error mapping，以及 non-existing leaf 的 parent-realpath/open-no-follow 规则，并把 `.repo/repo` 纳入枚举或解释为何顶层 containment 已覆盖。

#### I2. exit 类别虽互斥，稳定 reason/error 状态机仍不确定

- R14/R15 使用自由占位的 `REASON_CODE`/`ERROR_CODE`，除 `COMMAND_UNAVAILABLE`、`DIGEST_COLLISION`、`PUBLISH_FAILED` 外没有封闭枚举和 case→code 映射。
- 同一调用可能同时缺 `.repo`、资源不足和 namespace 不可用，或同时有 schema/path 错误；requirements 没有验证顺序/优先级。两次相同输入可能因实现检查顺序不同得到不同 terminal artifact digest。
- 应列出 code enum、各检查的 deterministic priority、stdout/stderr/ref kind 和 terminal `failed_checks` 排序。这样“互斥”才不仅是 exit 数字互斥，也包括 exact bytes/ref ABI。

#### I3. resource oracle 仍允许错误 PASS

- `f_bavail` 是 block 数，不是 available bytes；必须固定 `f_bavail * f_frsize`（含溢出处理），inode 才直接使用 `f_favail`。
- effective cgroup memory 不能只取 host `MemAvailable` 与 memory limit 的较小值，还要考虑当前 cgroup usage（通常为 limit-current）；并需固定 cgroup v1/v2、`max`/unlimited 和读取失败语义。
- CPU 要固定 online set∩cpuset 与 quota/period 的算法、fractional quota 如何和“至少 8 CPUs”比较，而非含糊的“较小值”。
- R21 的 equality/plus-one cases 只有在上述 measurement provider 可被确定性 fixture 注入且算法固定后才可执行。

#### I4. source-state/immutability coverage 未包含所有可能影响探针的本地状态

- R12 没有要求 porcelain v2 使用 `--untracked-files=all`，目录折叠会漏掉内部 bytes；source-state digest exact payload/domain 也未定义。
- ignored 文件完全不进入前后 digest，但 requirements 又宣称“不修改 tracked、untracked 或 ignored 内容”，且 ignored local files 可能被 envsetup/lunch 读取并影响观测。
- trace 可以捕获本轮成功 mutation，却不能证明运行前已有的 ignored 输入已进入 seed identity；只对 status-referenced entries 求 digest也无法覆盖读取但未改写的 ignored input。
- 应显式声明 ignored tree 的策略：排除并以独立 oracle证明不被读取，或纳入有界 canonical digest；同时固定 untracked recursion、symlink target、file mode/missing entry 和 project ordering。

#### I5. R1/R2 仍违反“一条需求一个真实来源”的门②规则

- 用户原话只确认本地路径、envsetup 命令和 lunch target。
- R1 的 caller expansion、CLI literal-tilde policy、不硬编码路径来自本轮 ABI裁定；R2 的 cwd、state-dir OUT_DIR、exit/build-variable 记录和禁编译边界来自 PLAN/DECISIONS。
- 将整条标 `[原话]` 会把新增承重策略伪装成用户已明确表达。应拆成 `[原话]` 的输入值需求与 `[计划]`/`[默认]` 的行为需求，或在同条明确逐子句来源；后者仍需满足 check-req 的整条 EARS 形状。

#### I6. terminal 与 rollback 验收缺少可执行的控制平面阶段

- 主脚本对真实分支的 `ENV PASS` 或 `ENV NOT-AVAILABLE` 都最终输出 `RESULT PASS` 并 exit 0；这可正确表示“测试了 terminal path”，但 requirements 没要求控制器在真实 exit 20 时阻止进入 01并回 PLAN 复盘。
- 因此自动流程可能把知识性终止误当作实现链成功。应让主验证输出一个机器可判的 outcome，并规定 `terminal_report` 只验收知识增量、随后必须走 PLAN review而非 design/01。
- R20/清单又要求 revert “00 exact merge commit”，而该 SHA 在实现 merge 前不存在；当前单一主验证命令没有 post-merge 参数或 ledger 输入，无法在正常 G-VERIFY 时完成这一条。
- 应把 pre-merge verification 与 post-merge rollback verification 分成两个明确 gate，后者以 ledger 的 exact SHA 为必需输入；并写出第三项 feature verifier 的精确命令和期望输出。

#### I7. 单片可实现性与人审预算没有形成门禁

- 当前 00 同时包含 dispatcher、direct ABI、RFC 8785/content store、atomic publisher、Repo/manifest/source-state scanner、cgroup resource parser、namespace/lunch runner、syscall trace analyzer、failure injection、rollback与多组 fixtures。
- 这些工作都有依据，不是 YAGNI；但在 PLAN 的“≤800 行非生成 diff + ≤160 行摘要”约束下高度可能超限。
- requirements 没有把该预算写入验收，也没有规定 tasks 门一旦估算/实际超限要沿 dispatcher+artifact publisher 与 preflight probe 的稳定接口重分。若只在实现后发现超限，人审预算已经失效。

### 次要（2）

#### M1. ref 的 exact values 应与“恰含三字段”一起写明

- R18 规定 ref 恰含三个字段，但没有在同处固定 `schema_version=1` 以及 artifact kind/ref kind 的值域；这些值目前散落在输入 schema、R13/R14 和表格中。集中列出可减少实现者交叉猜测。

#### M2. “三段 fsync”不是清楚的事实名称

- 验收清单第 2 项写“三段 fsync/no-replace/atomic-ref 行为”，R17/R18 实际涉及 object temp/file/dir 与 ref temp/file/dir 的多个步骤。建议用明确的 fault-injection stage 名称代替“三段”，避免测试和实现对阶段数理解不同。

## ② 文档质量与验收审计

### 数据 ABI

- ✅ input request 与 success/terminal output 已分名；env 不覆盖 descriptor；请求/env/terminal 顶层 digest domain 已给出。
- ❌ success artifact 子字段、artifact kind/schema、source-state/trace/journal 等内嵌 digest ABI未完整固定。
- ❌ public AOSP seed 与本地 LK7K env result 的 producer/consumer 图断开。

### exit/ref 状态机

- ✅ 0/20/30 不再把 state-dir containment 同时归两类；preflight 明确不产生 10/40。
- ✅ exit 20 要 artifact-first/ref-second，exit 30 不产生 dangling ref，collision 不覆盖。
- ❌ post-rename/fsync failure 无法满足全量零写入；reason/error code 和多故障优先级未固定。

### dispatcher / direct recovery / rollback

- ✅ dispatcher owner、commands.d lookup、direct executable 与 00 revert 目标均进入需求。
- ❌ exact direct command line和子命令 grammar 未定义；rollback 是 post-merge gate，却被混入单一 preflight 主验收。

### 外部 oracle 与假绿

- ✅ 真实 CLI、outer namespace/strace/poison PATH、independent digest recomputation 和 anti-mutation tests 已明确，round 1 的空日志/constant echo 假绿已被针对。
- ⚠️ oracle 自身的 canonical trace/source-state schema尚未固定；ignored inputs和 untracked recursion仍可漏证据。
- ⚠️ 真实 exit 20 可以让测试脚本 PASS 是知识性终止的合理测试语义，但必须有独立控制平面阻止后续 spec；当前缺失。

### 验收与错误路径

- ✅ 覆盖 success、terminal、contract、collision、literal tilde、state-dir/path containment、resource boundary、dirty state、dispatcher absence、direct recovery和旧 harness regression。
- ❌ 缺封闭 error/reason enum、priority、post-commit failure和 post-merge rollback 两阶段命令。
- ⚠️ PLAN 的人审行数预算未进入门禁。

### P1–P5

| 判据 | 结论 | 说明 |
|---|---|---|
| P1 独立验收 | ❌ | local preflight 本身可独立测，但 B2/B3 使判据不能唯一实现，真实 terminal 后的流程也未闭合。 |
| P2 独立回滚 | ⚠️ | 目标已写入，执行阶段/输入 SHA 未分离，当前主命令不可完整验收。 |
| P3 独立产出 | ❌ | LK7K env artifact 是独立知识产出，却不是 PLAN 后序 public seed 的可消费产出；依赖图断链。 |
| P4 值得问用户的问题 ≤15 | ✅ | 0/15、0/2 已记录；剩余问题均可由已批准 PLAN、POSIX 语义和 ABI一致性技术裁定，不需要再消耗用户提问预算。 |
| P5 人审全部产出 <1h | ⚠️ | PLAN 有 800/160 行限制，但当前范围明显承压，requirements 未把超限重分设为验收门。 |

## 必须先修的最小集合

1. 重新闭合 public AOSP17 seed producer→consumer 链；不能只留下“未来独立 seed”而无 owner。
2. 以明确 commit point 重写 object/ref publish failure matrix，允许无 ref 的 orphan content object，禁止声称 post-rename/fsync 错误可全量回滚。
3. 在 requirements 本身固定 env/source-state/trace/journal 的完整 v1 schema与 digest算法，不由未来 fixture 创造标准。
4. 补 direct argv、command grammar、reason/error enum和 priority；修正 disk/cgroup/CPU measurement。
5. 把 terminal→PLAN review 与 post-merge exact-revert 分成机器可判的控制平面 gate，并把 800/160 行预算前置到 tasks/验收。

VERDICT: FAIL
