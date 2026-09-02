# 00a design review — round 1

结论：**FAIL**

- 规格符合性：**FAIL**。八节和文件清单齐全，R1–R18 均有映射，rollback/no-AOSP 边界存在；但 canonical JSON 选型无法实现 requirements 的 RFC 8785 + uint64 合同，publish 时序违反 lock-before-observation，frontmatter 接口没有逐字传递，Python expected-error API 也有不可同时满足的解释。
- 设计质量：**FAIL**。整体分层方向合理，三张 sequenceDiagram 和一张架构图/ER 图人工语法检查未见明显 Mermaid 语法错误；但 downstream 连接图、domain table、只读返回类型、exact error state machine、rollback topology 与行预算尚不足以让任务实现者不再临时决策。
- findings：**4 blocker / 6 important / 1 minor**。blocker 与 important 修复后必须由全新 reviewer 回审；minor 可同步修复或按流程挂账。
- 审查边界：完整阅读了 PLAN v6、DECISIONS、最终 requirements、requirements 三轮 review 及熔断后的 ledger/最终文本；未修改 `design.md`，未执行 AOSP envsetup/lunch/build/sync/download/fetch/clone，也未读取 LK7K AOSP tree。Node/Python 仅用于纯标量 JSON 序列化对照；本机没有 `mmdc`，所以 Mermaid 结论是逐行语法审查而非渲染器执行证明。

## Blocker

### B1 — `json.dumps` 不是当前数值域上的 RFC 8785 实现

设计第 46 行断言：对 closed schema，`json.dumps(ensure_ascii=False, sort_keys=True, separators=(",", ":"))` 满足 RFC 8785 子集。最终 requirements 第 75 行却允许除 signed-64 特例外的整数为 `0..2^64-1`，而 RFC 8785 数字序列化采用 ECMAScript/IEEE-754 的 JSON number 语义。两者在该范围内会产生不同 canonical bytes：本机 Python 对 `18446744073709551615` 输出 `18446744073709551615`，Node/ECMAScript 输出 `18446744073709552000`。因此同一承重 payload 会得到不同 object/identity digest。

此外，合法 UTF-8 JSON bytes 可以通过 `"\ud800"` 这类 escape 产生 lone surrogate；Python parser 会形成 surrogate，而 `ensure_ascii=False` 的 UTF-8 encode 路径不能把它当作正常 RFC 8785 字符串。当前设计没有把该分支固定为 schema error，可能泄漏为 `RUNTIME_INTERNAL`。

这不是实现细节：它直接破坏 R4、所有 domain digest、golden bytes、collision 语义和 00b–05 的共享 ABI。修复必须在进入 tasks 前二选一并回到相应门：

1. 修改 requirements，把 JSON number 限制为 RFC 8785/I-JSON 可无损承载的安全整数，并明确 surrogate 拒绝；或
2. 改 schema，把 uint64 承重值编码成规范十进制 string，并相应重审 schema/digest ABI。

不能用“手写保留 Python 大整数十进制”后仍称其为 RFC 8785；那会是另一个 canonicalization profile。若继续坚持当前 RFC 8785 + uint64 数字合同，design 不可实现。

### B2 — 「组件与接口」没有逐字传递 requirements frontmatter 的消费/产出合同

requirements frontmatter 第 4–5 行固定：

- `消费: 2026-09-01-00-environment-seed-preflight 的 supersession/v1 replacement、R1-R27 owner 与预算合同`
- `产出: seed-contract-runtime/v1 marker+Python module API；...；同 grammar 的 ... direct recovery ABI`

design 第 48–89 行没有出现完整的消费接口；产出被拆成多段近义描述，也没有逐字复现 frontmatter。尤其第 59 行先给 direct command 路径，随后说 dispatcher 形式“在前面逐字加 `./common/.harness/bin/feature-closure verify-seed`”，字面执行会把 dispatcher prefix 与 direct executable 同时放进 argv；它不是 frontmatter 的两个 production，也没有唯一说明是“替换 executable”还是“prepend”。

这违反 `04-design.md` 的硬完成标准：组件接口签名必须与 requirements frontmatter 的产出/消费逐字一致。修复应在「组件与接口」增加一个 exact upstream/downstream contract 小节，逐字复制两条 frontmatter 值，并分别列出完整 dispatcher positional/ref production 与完整 direct positional/ref production，不用“在前面加”描述签名。

### B3 — durable publish 在取得 ref lock 前读取 evidence object，违反最终 lock-before-observation 状态机

requirements R8 与第 140 行固定：publisher/resolver 必须在首次观察 existing ref/object 前验证并取得 adjacent ref lock；合法 pre-lock contract 后先处理 lock contract/`REF_BUSY`，取得锁后才观察 ref、primary object 和 evidence object。

design 的 Durable publication 图第 151–154 行却明确排序为：

1. `publish(full artifact, ref metadata)`；
2. `validate schema/digests/evidence before writes`；
3. `acquire adjacent ref lock`；
4. object/ref commit。

seed evidence closure 必须读取 store 中四个 existing objects，因此第 2 步已经发生 object observation。这会令 concurrent publisher/lock contention 与 corrupt/missing evidence 的 error priority 不再唯一，也直接回归 requirements round 2/3 已修复并熔断裁定的 finding。

修复图应拆成：纯 argv/in-memory schema/path/fault-point validation（不观察 ref/object）→ validate/open lock leaf + nonblocking flock → 首次观察 existing ref/object/evidence 并完成 closure/collision check → object commit → ref commit → ref-dir fsync → runtime 释放锁。`publish_object` 无 ref lock，须另列其 object-only 时序或在同图中明确独立分支。

### B4 — Python 参数绑定错误的设计与 `ContractError` 唯一 expected carrier 合同冲突

requirements Runtime API 第 64、71 行同时固定：wrapper 只捕获 `ContractError`，其他 exception 映射 `RUNTIME_INTERNAL`；而 public API 的 unknown/missing/positional/type-invalid 参数必须是 `ARGUMENT_ERROR`。对第 74–80 行这种真实 keyword-only Python signature，missing/unknown/positional 参数会在函数体执行前由 Python 产生 `TypeError`。

design 第 83 行选择“Python 自身产生的 `TypeError` 在 CLI boundary 映射为 `ARGUMENT_ERROR`”，这要求 wrapper 捕获 `TypeError`，与 requirements 的“只捕获 `ContractError`，其他 exception 统一 `RUNTIME_INTERNAL`”不一致。若不捕获，则又违反 `ARGUMENT_ERROR`。

必须在 requirements/design 间固定一个可实现的唯一方案，例如：CLI grammar 自己只产生 `ContractError(ARGUMENT_ERROR)`，stable Python API 的调用绑定 `TypeError` 明确属于 programmer error/`RUNTIME_INTERNAL`；或者修改 stable invocation shape，使 runtime 能在绑定前自行校验并抛 `ContractError`。在合同修改并重审前，任务实现者无法同时满足两套 exact oracle。

## Important

### I1 — `StatePaths` 用 `TypedDict` 不能实现“只读 mapping”

requirements 第 66 行要求 `StatePaths` 是只读 mapping 且 exact keys 固定。design 第 83 行用 dict-compatible `TypedDict` 表达。`TypedDict` 只提供静态 shape，运行时实例仍是可变 `dict`，无法满足只读 ABI。

应固定真正的运行时表示，例如 `MappingProxyType` 包裹的 exact dict，或 frozen object 明确实现 `Mapping[str, str | None]`；同时保留 exact key/value/normalization oracle。`ObjectResult`/`PublishResult` 若允许普通 dict，也应在 design 中与只读 `StatePaths` 分开表述。

### I2 — 架构图把 00b–05 全部错误地路由到 `verify-seed`

第 31–35 行把 `00b-05 wrappers or operator` 同时连到 dispatcher 和 `commands.d/verify-seed`，再由 verify-seed loader 进入 runtime。PLAN/requirements 的 owner 边界是：每个后序 command 有自己的 direct wrapper，并在 import 前执行 R14 preamble；00b producer 直接消费 stable runtime 的 `publish_object`/`publish`，不是调用 verify-seed 来发布。

应把图改为 dispatcher → 各 `commands.d/COMMAND`，其中 verify-seed 只是 00a 的一个 command；每个 direct wrapper各自经过 marker/module check，再消费 stable runtime。00b producer 的 publish 边也应显式进入 runtime，而非进入 verify-seed。

### I3 — Domain table 漏掉承重的 per-project source-state domain

requirements 第 94、126 行要求每个 project item 用 `aosp-harness/project-source-state/v1\0` 重算 digest，并与 manifest `source_state_digest` 逐项相等。design 第 107 行列举 domain table 时没有该 domain，只笼统说 request/content/identity 使用各自 domain。

这是 evidence closure 的承重 digest，不应靠实现者回 requirements 猜。应把 request、project-source-state、workspace source-state、trace、journal、seed-content、seed-identity、seed-artifact、terminal-report 全部列成唯一 domain→payload mapping。

### I4 — 错误处理节没有把最终 exact priority/state machine传递到设计

第 163–174 行把多种错误压成 `CONTRACT CODE`、`priority code`，没有列出最终 requirements 第 138–148 行的完整 pre-lock 顺序、lock leaf contract/`REF_BUSY`、post-lock ref/object顺序和 publish stage 顺序。尤其 `DESCRIPTOR_NOT_FOUND`、invalid UTF-8、duplicate key、unsupported version、`SOURCE_ROOT_CONTRACT`、`WORKTREE_MISMATCH` 在表中不可定位。

错误优先级是 round 1–3 的核心熔断裁定，也是 observable ABI，不能只在 requirements 存在。应在 design 的错误节引用并完整重现 state machine，或提供一张逐状态 transition table，明确每个组件在哪个状态可观察哪些 filesystem leaf、何时释放锁、哪个 code 遮蔽哪个 fault。

### I5 — rollback 只被映射/点名，设计没有锁定 R16 的 executable topology

design 第 20、25、184、187、201 行提到 rollback，但没有给出顺序：00a exact two-parent merge SHA 写 ledger → 从 merge 创建 descendant fixture commit且唯一新增 executable recovery wrapper → `git revert -m 1 --no-edit MERGE_SHA` → 逐项验证 retained wrapper 与 removed dispatcher/marker/module/verify-seed → 三个旧 harness oracle。

R16 的关键正是 fixture 不能属于被 revert 的 merge。应增加一段 rollback sequence（可作为测试策略内步骤，不必增加第 4 张数据流图），并明确该 fixture/revert 只在隔离 worktree，不进入源码文件清单。当前文件清单的资产边界是对的，但拓扑仍需回看 requirements 才能实现。

### I6 — ≤730 行只给最终 gate，没有证明当前方案在修复 blocker 后仍可行

supersession sizing 给 00a 的区间是 610–730 行，其中实现 330–390、测试 250–300、wrapper 30–40；高位恰好等于硬 ceiling，没有余量。design 第 185 行只说 final review 用 `git diff --numstat`/`wc -l` 统计，没有把七个文件分配到该估算，也没有解释完整 six-artifact/two-payload field mutation、fault/path matrix、rollback routing如何落在 250–300 测试行内。

更重要的是，当前 330–390 实现估算显然建立在第 46 行的 `json.dumps` shortcut 上；B1 若改为合规 canonicalizer/额外 surrogate/number vectors，会增加实现与测试成本。应在 tasks 前按七文件给出 line allocation，并对 RFC 8785 修复后重算。任何 high estimate >730 或 summary >140 按 R17 立即回 PLAN，不得以删测试、合并逻辑块或把验证资产标成 generated 绕过。

## Minor

### M1 — 文件清单没有锁定三个 executable 文件的 mode

R1/R2/R16 均把 regular executable 作为合同；文件清单第 193–199 行只写“创建”。建议在职责或创建列明确 dispatcher、`commands.d/verify-seed`、shell test entry（以及隔离 descendant recovery fixture）的 executable bit，避免实现阶段临时决定或遗漏 mode oracle。

## 八节与逐项覆盖审计

| 审计项 | 结论 | 说明 |
|---|---|---|
| 概述 | PASS | 一句话方案 + 4 个“选择/理由/放弃方案”，无 TBD/TODO。 |
| 需求映射 | PASS | R1–R18 均至少出现一次；R17/R18 由 process/test/rollback 边界承接。 |
| 架构 | FAIL | 图语法人工检查通过，但 downstream wrapper→verify-seed 连接错误，见 I2；RFC 8785 选型不可实现，见 B1。 |
| 组件与接口 | FAIL | stable Python signatures大体完整，但 frontmatter 非逐字、dispatcher production 有歧义，见 B2/B4/I1。 |
| 数据模型 | FAIL | 六 artifact/两 nested payload、object/ref 关系和 mode 已描述，但漏 project domain，见 I3。 |
| 数据流 | FAIL | 3 条主流程数量合规；publish lock 时序错误且未表达 object-only publish，见 B3。ref-resolution 图第 141 行写成 `V` 解锁也与 lock 实际由 runtime 持有不一致，应随 B3 一并改为 runtime/context-manager 释放。 |
| 错误处理 | FAIL | happy/error paths均有，但 exact priority/state 不完整，见 I4。 |
| 测试策略 | FAIL | unit/integration/e2e/performance 四层齐全且主命令对齐；rollback topology与 budget feasibility不够，见 I5/I6。 |
| 文件清单 | 基本 PASS | 七个源码/测试文件职责清楚，验收资产另列；补 executable mode，见 M1。 |
| Mermaid | 人工 PASS | 1 个 `graph TB`、1 个 `erDiagram`、3 个 `sequenceDiagram` 语法结构未见错误；因本机无 `mmdc`，未形成渲染器运行证据。 |

## R1–R18 覆盖复核

| R | design 承接点 | 结论 |
|---|---|---|
| R1–R2 | dispatcher/direct command + parity tests | 覆盖；B2 阻断 exact signature。 |
| R3–R4 | schema/canonical/digest layer + unit matrix | 覆盖；B1 阻断 canonical bytes。 |
| R5–R9 | path/store/ref layer + integration/fault matrix | 覆盖；B3 阻断 publish observation order。 |
| R10–R13 | verify/public validator/parity/error tests | 覆盖；I3/I4 影响 evidence digest与错误 oracle。 |
| R14 | loader contract + direct command | 覆盖；B4 影响 expected-error carrier。 |
| R15 | publish state machine + fault tests | 覆盖；B3/I4 影响 commit-point实现。 |
| R16 | loader/rollback process/e2e | 覆盖但不充分，见 I5。 |
| R17 | review/process + performance gate | 覆盖但可行性未证，见 I6。 |
| R18 | process/test边界 | **PASS**；第 187 行明确实现阶段不运行 AOSP 命令，文件清单无 AOSP provider。 |

## 可保留部分

- 八节固定顺序、文件清单和验收资产分离符合 design skill。
- 完整 artifact 入参、producer/consumer 共用 validator、immutable object + mutable ref、orphan 不回滚的方向与熔断裁定一致。
- `ARTIFACT_STORE=STATE_DIR/artifacts/v1`、object child `sha256`、0444 object/0600 temp+lock、exact ref shape与最终 requirements 一致。
- 单元/集成/端到端分层、主验收命令 exact stdout/stderr、四个 case entry、真实 public positive 留给 00b 和不运行 AOSP 的边界均可保留。
- 文件清单没有把 evidence、report 或 isolated rollback worktree 混入源码 diff。

## 通过条件

1. 先解决 B1/B4 涉及的 requirements/API 不可实现或自相矛盾处；若修改 requirements，必须回门②并按配置重新 review，不能只改 design 文案。
2. design 逐字传递 frontmatter 消费/产出，改正 downstream architecture 与 publish lock-before-observation/data-flow。
3. 固定真正只读的 `StatePaths`、完整 domain table、exact error transition 和 rollback sequence。
4. 对修订方案按七个文件重算行数；high estimate 必须 ≤730、summary ≤140，否则按 R17 回 PLAN 拆分。
5. 修复后重新执行 design 自查，并由全新上下文 reviewer 完整回审。当前 design 不可进入 tasks/实现。
