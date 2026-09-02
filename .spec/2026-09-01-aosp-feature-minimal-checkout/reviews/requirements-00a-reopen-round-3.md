# 00a requirements reopen review — round 3

结论：**PASS**

- 规格符合性：**PASS**。round 2 的 dispatcher → direct preamble → direct grammar → runtime 分阶段优先级已形成可实现的 stop-at-first 合同，四个 mixed-fault oracle 与正文逐字一致；numeric ABI 已有显式 supersession；R1–R18 均有来源、EARS 句式和验收承接。
- 需求质量：**PASS**。六类 artifact、两个内部 digest payload、stable runtime API、path/store/ref、四对象 evidence closure、publish commit point、rollback、预算、主命令、清单和不变量均闭合，未发现无验证需求、内部矛盾或未声明实现选择。
- findings：**0 blocker / 0 important / 0 minor**。
- confirmation：frontmatter `已由用户确认: false` 是等待本轮复核的流程态，不是内容 finding。当前内容已 PASS，**可以只做元数据 flip 为 `true`，无需再修改 requirements 正文**；翻转后 `check-criteria.py` 可通过。
- 机械检查：`check-req.py` exit 0，`check-analyze.py` exit 0，`git diff --check` exit 0；当前文件 `check-criteria.py` exit 2 的唯一输出是缺 `已由用户确认: true`，通过不落盘只读替换模拟该字段为 `true` 后 exit 0。
- 审查边界：完整阅读 spec `SKILL.md`、`references/03-requirements.md`、`references/07-review.md`、PLAN v6、DECISIONS、当前 requirements/design、requirements reopen round 1/2、design round 1 与当前 spec ledger；另核对 STATE/config/mode/workflow。未修改 requirements/design 草稿，未执行 AOSP envsetup/lunch/build/sync/download/fetch/clone，也未读取 LK7K AOSP tree。

## Round 2 finding closure

| 上一轮 finding | 本轮结论 | 依据 |
|---|---|---|
| B1 跨层 error priority 不可实现 | **PASS** | `Error priority 与 publish matrix` 已按 entry stage 拆分：dispatcher 只判 subcommand presence/name/target；成功 exec 后 direct wrapper 先做 marker/module/import preamble，再解析自身 grammar；最后才进入 runtime bound-value/schema/path 顺序。dispatcher 不再需要理解 child grammar，也不存在全局 `ARGUMENT_ERROR` 反向遮蔽 unavailable target 的矛盾。design 的错误处理 1–3 步与该顺序一致。 |
| B1 mixed-fault 可验收性 | **PASS** | 验收清单逐字固定四组 oracle：invalid subcommand + invalid child argv → `INVALID_COMMAND`；missing/symlink/non-executable target + invalid child argv → `COMMAND_UNAVAILABLE`；direct runtime unavailable + invalid argv → `RUNTIME_UNAVAILABLE`；runtime available + invalid argv → `ARGUMENT_ERROR`。这四组覆盖 dispatcher name、target、direct preamble 和 direct grammar 四个阶段边界。 |
| I1 call-shape exception 未穿 CLI boundary | **PASS** | argument carrier matrix 明确要求至少一次 stable callable unknown/missing/positional call-shape 产生的真实 binding `TypeError` 穿过 CLI boundary，并逐字断言 exit 30、stdout empty、stderr exact `CONTRACT RUNTIME_INTERNAL`、无 traceback，且其他 unexpected exception 不可替代。design 进一步固定 test-only seam 在 runtime import 后以 positional call 调 stable keyword-only callable，走同一 CLI boundary。 |
| M1 autopilot 文案自相矛盾 | **PASS** | `Autopilot decisions` 现写明“没有待用户回答的问题”，并把 numeric ABI 明确归因于本节与 DECISIONS 的 supersession 裁定，不再宣称“没有需要改变实现方向的新业务选择”。Questions 0/15、rounds 0/2 与已批准 autopilot 口径一致。 |

## 完整回归矩阵

| 审计项 | 结论 | 说明 |
|---|---|---|
| numeric supersession | **PASS** | DECISIONS 2026-09-02 明确以 I-JSON safe integer 替代旧 signed/unsigned-64 JSON number 接受域；requirements frontmatter 和 design exact upstream contract 均显式消费。全局 safe signed/unsigned 范围、四个相邻边界、lone-surrogate/合法 Unicode oracle闭合；00b–05 对越界 observation 禁止截断/舍入并 fail closed。旧 DECISIONS 行仍作为历史口径保留，但后置 supersession 与当前消费声明使优先关系唯一。 |
| R1–R2 dispatcher/CLI | **PASS** | command regex、self-realpath target、regular executable、两个互斥 grammar、direct recovery 与 stage-specific errors 均唯一；mixed-fault matrix 防止解析职责回流 dispatcher。 |
| R3–R4 closed schema/canonical digest | **PASS** | 六类完整 artifact 与两个非发布内部 payload的 exact key/type/enum/nullability/order 均固定；safe integer、duplicate key、UTF-8/surrogate、sorted/unique 与 semantic-order 分界、九个 domain 和 canonical bytes/digest oracle闭合。 |
| R5–R9 path/store/ref | **PASS** | state-dir/store/out-ref exact relation、literal tilde/relative/missing/unwritable/symlink/containment、forbidden roots、no-follow traversal、object immutability、lock-before-observation、owner/mode、contention、orphan 与 durability-uncertain 都有 exact code/state oracle。 |
| R10–R13 fixture/ref/public/error | **PASS** | positional embedded verification 与 ref evidence closure 分离；fixture 不冒充 real source；public predicate 在 structural/evidence validation 后执行；dispatcher/direct parity 与 exact channel contract可机械验证。 |
| R14 stable runtime API | **PASS** | marker bytes、module、九个 exports、keyword-only signatures、只读 `StatePaths`、exact result keys、expected `ContractError` 与 programmer-error `TypeError` 边界均固定；design 的真实 binding-TypeError seam补足 CLI 可验收性。 |
| R15 publish matrix | **PASS** | validation 遮蔽 fault injection；`DIGEST_CHECK`、pre-object-link、object-linked/pre-ref-rename、post-ref-rename 和 no-fault 五种结果及 durable state唯一；temp ownership与 dangling-ref 不变量闭合。 |
| evidence closure | **PASS** | before/after source-state、trace、journal 四对象的 existence/kind/path/content/domain/nested/cross-field关系、project digest、path set、trace counts、journal sequence/stage/lunch exit全部有确定失败分类和 public-priority顺序。 |
| R16 rollback | **PASS** | exact two-parent merge SHA → isolated descendant executable wrapper fixture → `git revert -m 1` → retained wrapper/removed 00a files → exact `RUNTIME_UNAVAILABLE` → 三个旧 harness oracle，顺序、文件 mode、隔离边界与 ledger source均固定。 |
| R17 budget | **PASS** | 730/140 是本片 estimate/actual hard ceiling，800/160 仅为不可放宽外层上限；design 七文件 high estimate 725，超额时点明确要求在 implementation 前或 acceptance 前回 PLAN。 |
| R18 / YAGNI | **PASS** | 00a 只交付 fixture 可验的 schema/runtime/store/ref/dispatcher/verify 能力；真实 source、environment evidence、preflight、closure/build 与 00b–05 command 实现均保持在范围外，且明确禁止 AOSP/build/sync/download 操作。 |
| 来源与 EARS | **PASS** | `check-req.py` exit 0；R1–R18 均使用当前 legacy 项目允许的单一 `[计划]` 来源，且全部匹配中文 EARS 五类之一。numeric observable change另有 DECISIONS supersession，不再是无来源选择。 |
| 主判据与不变量 | **PASS** | 主命令的 exit/stdout/stderr 精确；八项清单均为可独立勾选事实；五项不变量各含阈值与命名验证命令，覆盖 byte immutability、confinement、dangling ref、public gate 与 rollback regression。 |

## 最终裁定

本轮内容审查通过，没有需修订或挂账的 finding。控制器可将 `已由用户确认: false` **纯元数据翻为 `true`**，随后运行 `check-criteria.py`；该动作不需要再开一轮内容 review，也不授权推进或修改 design 之外的后续阶段。
