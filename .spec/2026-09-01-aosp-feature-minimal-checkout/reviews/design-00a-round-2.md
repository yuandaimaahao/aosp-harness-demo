# 00a design review — round 2

结论：**PASS**

- 规格符合性：**PASS**。八节、文件清单和验收资产边界齐全；R1–R18 均有组件与测试承接；requirements frontmatter 的 `消费`/`产出` 已逐字传递，dispatcher/direct 四个 production 均为完整无歧义签名；修订后的架构、数据流、错误状态机、rollback 与 no-AOSP 边界均与当前门②重开 PASS 的 requirements 一致。
- 设计质量：**PASS**。round 1 的 4 blocker、6 important、1 minor 已全部关闭；没有发现新的 blocker、important 或 minor。
- findings：**0 blocker / 0 important / 0 minor**。
- 机械检查：requirements 的 `check-req.py`、`check-criteria.py`、`check-analyze.py` 均 exit 0；design `git diff --check` exit 0；八个固定章节、R1–R18 token、九个 domain separator、frontmatter exact text、四个 CLI production 与 executable mode 均通过只读脚本核对。环境仍无 `mmdc`，Mermaid 结论来自逐图语法与关系审查，不宣称有渲染器运行证据。
- 审查边界：完整阅读 spec `SKILL.md`、`references/04-design.md`、`references/07-review.md`、PLAN v6、DECISIONS、当前 requirements（含门②重开后的 confirmed/PASS 状态）、当前 design、`design-00a-round-1.md`、requirements reopen round 1–3 与当前 ledger。未修改 `design.md` 或 requirements；未执行 AOSP envsetup、lunch、m/mm/mmm、ninja、package、flash、repo sync、fetch/clone 或下载，也未读取 LK7K AOSP tree。

## Round 1 finding closure

| Round 1 finding | 本轮结论 | 依据 |
|---|---|---|
| B1 RFC 8785 与原 uint64 域不可兼容 | **PASS** | DECISIONS 已显式以 I-JSON safe integer supersede 原 signed/unsigned-64 JSON number 接受域；design 将 canonical domain 限定为 ASCII closed keys、null/bool、无 float、无 lone surrogate、`±(2^53-1)` 内整数，并固定相邻边界、surrogate 与 Unicode golden。该域内 stdlib compact/sorted UTF-8 JSON 与要求的 RFC 8785 bytes 一致，00b–05 越界 observation 只能 fail closed、不得截断或舍入。 |
| B2 frontmatter consumer/output 与 production 不逐字 | **PASS** | 「Exact upstream/downstream contract」逐字复制当前 frontmatter 的 `消费` 与 `产出`；随后分别列出 dispatcher positional/ref 和 direct positional/ref 四个完整 production，不再用 prepend 等歧义描述。 |
| B3 publish 在 lock 前观察 evidence object | **PASS** | durable publication 图和错误状态机均固定：纯 call/in-memory schema/path/fault validation → 验证 lock leaf 并 nonblocking flock → 首次观察 ref/primary/evidence object → object commit → ref commit/fsync → `finally` 解锁。`publish_object` 另列为无 ref/lock 的 object-only 分支。 |
| B4 Python `TypeError` carrier 冲突 | **PASS** | CLI grammar 与成功绑定后的 value/combination invalid 归 `ContractError("ARGUMENT_ERROR")`；Python unknown/missing/positional call-shape 保留原生 `TypeError`，在 CLI boundary 与其他非 `ContractError` 统一消毒为 `RUNTIME_INTERNAL`。test-only seam 明确制造真实 keyword-only binding `TypeError` 并核对 exact channel/no traceback。 |
| I1 `StatePaths` 不是真只读 | **PASS** | 固定为 `MappingProxyType` 包裹 exact dict 的 runtime read-only `Mapping[str, str | None]`；`ObjectResult`/`PublishResult` 单独固定为 exact-key ordinary dict。 |
| I2 后序 wrapper 错接到 `verify-seed` | **PASS** | 架构图现在是 dispatcher → `commands.d/COMMAND` → 00a `verify-seed` 或 00b–05 各自 direct wrapper；各 wrapper 独立经过 marker/module loader，00b producer 的 `publish_object`/`publish` 边直接进入 runtime。 |
| I3 domain table 漏 project source-state | **PASS** | domain→payload table完整列出 seed-request、project-source-state、source-state、trace、command-journal、seed-content、seed-identity、seed-artifact、terminal-report 共九个 domain。 |
| I4 exact staged error machine 缺失 | **PASS** | 错误处理按 dispatcher、direct startup、runtime pre-lock、lock、post-lock observation、commit、release 七阶段完整传递 exact priority；mixed target/argv fault 的遮蔽关系与 requirements reopen round 3 的四个 oracle 一致。 |
| I5 rollback topology 未锁定 | **PASS** | 测试策略固定 ledger exact two-parent merge SHA → isolated worktree → descendant commit 唯一新增 0755 recovery wrapper → `git revert -m 1` → retained wrapper/removed 00a files → exact unavailable channel → 三个旧 harness oracle；descendant/revert 不进入主线。 |
| I6 730 行预算可行性未分配 | **PASS** | 七个源码/测试文件逐项 high estimate 为 18/60/1/360/1/260/25，总计 725；设计明确用 declarative exact-key/type/domain tables 与 table-driven mutation 承载闭 schema/matrix，且不允许靠省略 matrix 换预算。仅余 5 行不是合同缺陷：任一 tasks estimate 调整导致 high >730 时，R17 要求立即回 PLAN，不能进入 implementation。 |
| M1 executable mode 未锁定 | **PASS** | 文件清单明确 dispatcher、verify-seed direct command、Bash acceptance entry 为 mode 0755；rollback descendant fixture 也明确唯一新增 mode 0755 executable。 |

## 八节、接口与图复核

| 审计项 | 结论 | 说明 |
|---|---|---|
| 1. 概述 | **PASS** | 一句话方案与四个“选择/原因/放弃方案”齐全；无 TBD/TODO/“适当处理错误”。 |
| 2. 需求映射 | **PASS** | R1–R18 全覆盖；组件范围与 requirements owner 边界一致。 |
| 3. 架构 | **PASS** | dispatcher、各 direct wrapper、loader、stable runtime、schema/path/object/ref 分层和 00b publish 边正确；技术栈版本下限与选择理由明确。 |
| 4. 组件与接口 | **PASS** | frontmatter exact text、四 production、marker bytes、九个 stable exports、keyword-only signatures、返回 shape 与依赖均固定。 |
| 5. 数据模型 | **PASS** | 六类完整 artifact、两个内部 payload、九个 domain、immutable object/mutable ref、mode 与 ref bytes 均唯一；ER 关系与 requirements 一致。 |
| 6. 数据流 | **PASS** | 三条主流程数量符合细则；fixture verification、locked ref/public gate、durable publish 均跨组件且时序承重；object-only 分支另有精确文字。 |
| 7. 错误处理 | **PASS** | 不只 happy path；entry/pre-lock/lock/post-lock/commit/release 和 collision/precommit/orphan/durability-uncertain 状态均有 exact code、可见状态与恢复语义。 |
| 8. 测试策略 | **PASS** | unit/integration/e2e/performance 四层均给范围与工具；主命令、四个 case entry、rollback case、exact stdout/stderr、numeric/surrogate、carrier、mixed-fault、path/ref/fault/public closure matrix 与 requirements 判据对齐。 |
| 文件清单 | **PASS** | 七个预期 BASE..HEAD 文件均为单一职责；mode 已锁定；red/report/rollback worktree 等验收资产另列且不混入源码清单。 |
| Mermaid | **PASS（人工语法审查）** | 1 个 `graph TB`、1 个 `erDiagram`、3 个 `sequenceDiagram` 的 fence、participant/entity、edge/message 与 relation 结构未见语法错误；当前环境无 `mmdc`。 |
| no-AOSP / YAGNI | **PASS** | 文件清单和设计只包含 fixture/runtime/dispatcher/verify/test；明确禁止实现阶段运行 AOSP 命令，真实 source/preflight/closure/build 仍留在 00b–05。 |

## R1–R18 完整复核

| 需求 | design 承接点 | 结论 |
|---|---|---|
| R1–R2 | dispatcher、verify-seed、exact four productions、parity/mixed-fault tests | **PASS** |
| R3–R4 | closed schema、safe RFC 8785 domain、九 domain table、canonical mutation vectors | **PASS** |
| R5–R6 | `validate_state_paths`、no-follow directory-fd traversal、forbidden roots、path matrix | **PASS** |
| R7–R9 | immutable object commit、locked ref publish、lock-before-observation、orphan/uncertain recovery | **PASS** |
| R10–R11 | positional fixture verification、ref evidence closure、public pure seam/negative integration | **PASS** |
| R12–R13 | exact staged error machine、dispatcher/direct parity、channel and no-write assertions | **PASS** |
| R14 | marker/module pre-import contract、九 exports、direct recovery、TypeError/internal boundary | **PASS** |
| R15 | object-only/publish fault stages、temp ownership、dangling-ref invariant | **PASS** |
| R16 | exact merge/descendant/revert topology与三项旧 harness oracle | **PASS** |
| R17 | seven-file 725 high estimate、730/140 hard stop、800/160 outer ceiling | **PASS** |
| R18 | explicit no-AOSP/no-download boundary、fixtures 不读取真实 tree | **PASS** |

## 最终裁定

本轮 design 内容审查通过，无需修改或挂账。可将本报告作为 design round 2 的独立 agent review PASS 依据；是否执行门③自动通过、ledger 记录与阶段推进由控制器按 autopilot 流程处理。
