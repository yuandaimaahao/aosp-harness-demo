# design 独立审查 — Round 1

审查对象：原 `2026-09-01-00-environment-seed-preflight/design.md` 当前磁盘版本。该 design 被解释为 R24 触发后的知识终止/拆分设计，而不是 00a/00b 已实现声明。

同时完整读取：`PLAN.md` v6、`PLAN-history.md`、`DECISIONS.md`、原 00 的 `requirements.md`、`design.md`、`sizing-prototype.md`、`ledger.md`、`work/plan-review-v6-incremental-round-2.md`，以及 spec `references/04-design.md`、`references/07-review.md`。为判断能否安全进入 retro，另核对了当前 `STATE.md`、per-spec mode/workflow、状态机合法后继和 retro/accept 规则。未修改被审产物，未运行 AOSP、lunch、build、sync、download 或网络安装。

## 结论摘要

- 结论：**不通过**。Findings 为 **3 个阻断、4 个重要、2 个次要**。
- 形式上八节齐全并附文件清单；R1–R27 的编号也都至少出现一次。三个 Mermaid block 的基础语法静态检查未见语法错误。
- 实质上仍不能安全终止原 00：当前状态从 `spec/design` 只能进入 `spec/tasks`，而 design 明确要求不写 tasks、直接选择 00a/进入 retro；同时没有可执行的知识终止验收和独立回滚契约。
- design 没有把 runtime/probe 当成已经实现，方向是诚实的；但把 sizing **估算**写成“已证明”，且若干跨片接口/责任被写成已经定死，证据强度和接口成熟度被夸大。

## 规格符合性

| 审查项 | 结论 | 说明 |
|---|---|---|
| 八节 + 文件清单 | ✅ | 八节顺序完整，另有文件清单。 |
| R1–R27 文本覆盖 | ✅ | 每个编号至少出现一次。 |
| R1–R27 跨片归属 | ❌ | R6、R19、R20、R23、R25 等承重需求的 owner/共同责任与 PLAN v6 不闭合，见 B2。 |
| 与 requirements frontmatter / PLAN v6 接口一致 | ❌ | 原 frontmatter 被引用但没有形成可消费的 successor 签名；另引入未冻结的 Python API，见 I1。 |
| 00a/00b 架构、数据、错误、测试、文件边界 | ❌ | 只有概念级切口，错误、测试和文件 owner 未落到两片可起草 spec 的程度，见 I2。 |
| Mermaid | ⚠️ | 基础语法可成立；ER 图的基数语义与 ref 的二选一 kind 冲突，见 I3。 |
| 无伪实现声明 | ✅ | 明确声明不产生 `common/` implementation diff，没有把 00a/00b 代码称为完成。 |
| 独立验收、回滚、retro | ❌ | 生命周期无合法出口，验收为空验证，回滚未定义，见 B1/B3。 |

## Findings

### 阻断

#### B1 — design 要求的“终止后直接进入 00a/retro”不是合法生命周期路径

- **位置：** `design.md:5,11,45-49,112`；当前 `STATE.md:9-10` 为 `current_spec=2026-09-01-00-environment-seed-preflight`、`spec_stage=design`。
- **依据：** requirements-first 状态机从 `spec/design` 的唯一直接后继是 `spec/tasks`；large spec 只有从 `spec/accept` 才能进入 `retro`。design 却规定“不进入代码实现”“不在 tasks 中……”并把端到端目标写成“将下一片选为 00a”。现稿没有描述如何经过 tasks、execute、accept，也没有经批准的 design→retro/plan/select 例外。
- **影响：** 门③即使通过，控制器仍只能起草 tasks；若按 design 直接选 00a，则绕过门④、任务执行审查、门⑤和 large-spec retro 前置条件，原 00 永远没有合法完成锚点。
- **必须修复：** 为原 00 定义一个明确的“文档/知识终止”任务与 accept 路径，按现有状态机走 `design -> tasks -> execute -> accept -> retro`；或者先给出并批准一个框架支持的终止迁移。design 必须写清 exact transition、ledger/status 锚点以及何时选择 00a，不能让实现者自行决定跳门。

#### B2 — R1–R27 虽全出现，但承重需求的跨片 owner 自相矛盾

- **位置：** `design.md:17-25,51-61`；对照 `requirements.md:34-74` 和 `PLAN.md:77-92,158-162,177-190`。
- **依据：**
  - R6 明确是 `preflight` direct recovery ABI，PLAN v6 又明确 `preflight` 归 00b；映射表却只把 R6 放在 “00a dispatcher/direct verifier”。
  - R19/R20 同时包含 00b 的环境判定、精确 stdout/exit/control gate 与 00a 的 publish 语义；映射表只列在 00a path/store/ref runtime。行 25 虽称它们跨接口，却没有给 00b 对应责任。
  - R23 的 dispatcher/direct parity 同时需要 00a dispatcher/runtime 和 00b `preflight` direct command；表中只归 00a。
  - R25 是原 combined 00 exact merge commit 的回滚判据；表中整体归 00a，却没有说明如何替换为 PLAN v6 已要求的 00a 与 00b 两个独立 merge/revert 判据。
- **影响：** successor requirements 可据此重复实现或漏实现 direct parity、terminal gate 与 rollback；这会破坏 PLAN v6 的独占 owner 和独立回滚边界。
- **必须修复：** 用“需求/00a责任/00b责任/跨片验收 owner”矩阵重写映射。对被拆开的 R7/R10/R16/R18/R19/R20/R23/R25/R27 明确区分 schema/validator/publisher、field provider/producer、control plane 和最终验收；R6 必须归 00b command owner，00a 只拥有 dispatcher/runtime 支持。

#### B3 — 知识终止片没有可执行的独立验收或独立回滚，且现有端到端检查属于空验证

- **位置：** `design.md:97-113,115-125`；对照原 `requirements.md:163-185` 的 implementation/rollback 判据。
- **依据：** 测试策略没有本终止片的 exact command、exit 和 expected output。`git diff -- common` 只说明当前未提交工作区相对 index 的差异，无法证明历史/待合入 commit 没改 `common/`，也可能被无关用户改动污染；“STATE/ledger”没有命令或断言。原 R25 rollback 是实现版 combined 00 的 dispatcher recovery 测试，不能验收或回滚当前由 PLAN/history/DECISIONS/design/sizing/ledger 组成的文档终止片。文件清单也没有规定知识终止 merge commit 被 revert 后 PLAN v6 与 00a/00b 条目应保留还是撤回。
- **影响：** 该片无法独立判成败、无法形成 exact merge SHA、无法证明 revert 后计划/状态一致，因此不满足进入 accept/retro 的前提；一个始终为空的 `git diff` 就可能给出假 PASS。
- **必须修复：** 固定本终止片的验收脚本或一组 exact assertions，至少验证：R24 sizing 算术与阈值、PLAN v6 存在 00a/00b 且旧 00 不再可选、DAG/owner/check-plan、`common/` 相对固定 base commit 零改动、STATE/ledger 的知识终止锚点。再固定本片 exact merge commit 的 isolated-worktree revert 命令与预期：哪些计划文档一起回退、回退后旧 00 是否恢复为可选、STATE 不悬空。只有该验收/回滚通过后才能进入 retro。

### 重要

#### I1 — 组件接口既没有逐字闭合原 frontmatter/PLAN v6，又提前发明了未审核 API

- **位置：** `design.md:45-61`；原 frontmatter 为 `requirements.md:3-6`；PLAN v6 判据见 `PLAN.md:66-67,158-162`。
- **依据：** design 只在说明句中引用原 combined output，没有给出 00a/00b successor frontmatter 的确切 `消费`/`产出`。`feature-closure verify-seed SEED_FILE` 没覆盖 PLAN v6 后序使用的 `verify-seed --ref REF --artifact-store STORE --require-public-real` 形态；00b 的 direct interface 没写固定 module path；`seed_contract.publish(payload, kind, state_dir, out_ref)` 是 requirements/PLAN v6 从未冻结的 Python 调用签名，模块名、类型、错误返回和版本均未定义。00b 还被写成依赖“00a 的 `seed-request/v1 输入描述符`”，但 descriptor 是原 frontmatter 的外部消费，不是 00a 运行产物。
- **影响：** 后续起草者无法逐字复制可靠签名，可能把外部 input 当上游 artifact，或把概念 publisher 锁成未经设计的 Python ABI。
- **建议：** 写出两个 successor frontmatter 的 exact strings，以及 dispatcher、direct module、fixture verifier、ref verifier、publisher library（若确需公开）的完整签名/返回；未决定的内部 API不要伪装成已冻结接口。

#### I2 — 00a/00b 的错误、测试与文件拆分不足以锁定实现边界

- **位置：** `design.md:27-42,63-65,95-125`。
- **依据：** 架构只画层级；错误表只处理“估算超限/check-plan 失败”，没有把 `CONTRACT RUNTIME_UNAVAILABLE`、validation priority、exit 20 environment terminal、exit 30 publish fault、public-real control gate分配给 00a/00b。测试表只验证 sizing/PLAN，没有分别列 00a pure-fixture matrix、00b real local/public/terminal matrix及 exact commands。文件清单只列当前五个规划文档，没有锁定 successor spec 文档/实现目录/command owner，也漏掉本轮已参与口径的 `DECISIONS.md` 和两份 PLAN v6 incremental review evidence。
- **影响：** “未来 00a tasks/00b tasks 再决定”会把关键架构、错误 ABI、测试 oracle 和文件 owner推迟到门④，违反 design 阶段锁定拆解决策的要求。
- **建议：** 即使原 00 只做知识终止，也应在本 design 给出 successor 级别的 owner/file-family 清单和错误/测试责任矩阵；具体代码行数可留给各自 tasks 重算，但接口、错误 owner、oracle 与不可共同修改的文件必须先定死。

#### I3 — ER 图语法可解析，但 ref 基数语义与 closed ref schema 冲突

- **位置：** `design.md:67-76`；对照 requirements 的 `ref bytes`：ref kind 只能在 `env_pass` seed 与 `terminal_report` 中二选一。
- **依据：** 图中同时写 `REF ||--|| SEED` 和 `REF ||--|| TERMINAL_REPORT`，表示每个 REF 必须同时解析到恰好一个 SEED 和恰好一个 TERMINAL_REPORT。实际契约是由 `kind` 决定只解析其中一种。`SEED_REQUEST` 到两种结果也缺少互斥/状态说明。
- **影响：** 实现者若按图建 validator，会要求一个 ref 同时满足两个 artifact kind，或无法表达 success/terminal 的互斥状态。
- **建议：** 以 `ARTIFACT` supertype + `kind` discriminator 建模，或把两条关联改成 optional 并在文字中固定 XOR invariant。Mermaid `graph` 与 `sequenceDiagram` 的基础语法未发现问题。

#### I4 — Python 3.11+ 是无来源的新兼容性门槛，属于 YAGNI

- **位置：** `design.md:41`。
- **依据：** requirements 只要求记录 Python identity，PLAN v6 只要求 stdlib/runtime owner，没有批准 Python 3.11 最低版本。知识终止片没有 host-tool 证据证明 public AOSP17 与 local LK7K 环境都提供 3.11。
- **影响：** 00a 可能在无需 3.11 特性的情况下人为阻塞 AOSP host；若后续降版本又会让本 design 的技术栈承诺失真。
- **建议：** 删除 3.11+ 下限，或给出确切依赖的语言特性和两类目标环境证据，再把下限写入 successor requirements/DECISIONS。

### 次要

#### M1 — 把 sizing 估算称为“已证明”，证据强度表述过头

- **位置：** `design.md:5`；`sizing-prototype.md:3-17`。
- **依据：** sizing 文件明确是按组件的行数估算，并且 ledger 已挂账要求各 successor tasks 门重算；它证明的是“按当前估算触发 gate 的决策”，不是已经实现后的 actual diff 事实。
- **影响：** 不会把 00a/00b 代码冒充完成，但可能让后续误以为 730/630 是已测量上限。
- **建议：** 改为“门③ sizing 估算给出 890–1310，因此按 R24 触发 replan；实际值仍在 successor tasks/acceptance 重算”。

#### M2 — 00b sizing 的两种区间算法仍有已知文案歧义

- **位置：** `sizing-prototype.md:17`，已由 `plan-review-v6-incremental-round-2.md:51-56` 挂账。
- **依据：** `620–820` 扣除 `150–210` 的保守区间是 `410–670`，而后半句明细重估为 `470–630`；两者都低于 800，但不是同一算式。
- **影响：** 不改变拆分结论，仍会妨碍后续复算和实际预算对比。
- **建议：** 明确标成“保守扣减区间”与“组件重估收窄区间”，或只保留一套估算。

## 质量结论

- **YAGNI：** 未发现实现范围外重构；但 Python 3.11+ 与未定义的 `seed_contract.publish(...)` 属于无证据新增约束/API。
- **空验证：** `git diff -- common`、人工映射和笼统的 `STATE/ledger` 检查不足以验收知识终止，构成承重缺陷。
- **伪完成：** 没有声称 runtime/probe 已实现；sizing 的“已证明”需降格为估算结论。
- **错误路径：** 原 runtime/probe 的错误矩阵存在于 requirements，但 design 的 split error ownership 没有落地。

VERDICT: FAIL
