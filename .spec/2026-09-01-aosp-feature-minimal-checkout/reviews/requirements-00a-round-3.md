# 00a requirements review — round 3

结论：**FAIL**

- 规格符合性：**FAIL**。round 2 的 store root、object-only publish、keyword-only runtime API、lock-before-observation 骨架、public predicate code、预算时点与流程字段已实质修复；但 public-real gate 尚未验证一个 `seed/v1` 确实代表成功 preflight，closed schema 仍缺承重 cross-field/evidence 约束，ref/lock 失败仍没有唯一 error code，producer API 也仍有两种合法解释。
- 需求质量：**FAIL**。18/18 条 R 均满足中文 EARS；18 条均为 `[计划]`，可追溯至 PLAN v6、DECISIONS、原 00 migration contract 或 supersession，不存在未处理的 `[推断]`/`[默认]`；0/15 questions、0/2 rounds 合理，未发现提前实现 00b 或 01–05 的 YAGNI 扩张。失败点是已在 00a unique-owner 范围内的 schema/API/error ABI 与验收 oracle。
- 机械检查：`check-req.py` exit 0，`check-analyze.py` exit 0。当前 `check-criteria.py` exit 2 的唯一原因是 frontmatter `已由用户确认: false`；这是按用户指示等待本轮 PASS 的流程状态，不是内容 finding。使用不落盘的替换流把该字段视为 `true` 时，`check-criteria.py` exit 0。
- 审查期间未执行 AOSP envsetup、lunch、m/mm/mmm、ninja、package、flash、repo sync、Git fetch/clone 或下载，也未修改 requirements 草稿。

## Blocker

### B1 — `--require-public-real` 只验身份标签，不验 `seed` 是否真的表示成功 preflight

R11（第 44 行）和 ref state machine（第 132、138 行）把 public predicate 固定为 `evidence_class` 与四个 `source_scope` 字段。可是当前 `seed/v1` schema（第 108–124 行）允许以下全部 payload 成为 schema-valid、digest-valid、ref/object matching 的 public `real_source` seed：

- `resources.passed` 中任一项为 false，或 `passed` 与 measured/minimums/estimate 的比较结果不一致；
- `envsetup_exit`/`lunch_exit` 非 0；
- parent/probe network namespace inode 相同；
- `external_network_count`、`source_mutation_count`、`sync_download_count`、`module_build_count` 或 `package_count` 非 0；
- `source_state.before_digest != after_digest`；
- `manifest.project_count != len(manifest.projects)`；
- guard/source-state 中引用的 `source_state`、`trace`、`command_journal` digest 在 ref-mode artifact store 中缺失、wrong kind 或内容 digest 不匹配。

这与原 00 R17/R19、environment priority 中的 `FORBIDDEN_EXECUTION`/`SOURCE_MUTATION`/`SOURCE_CHANGED`、PLAN v6 的 `verify-seed --require-public-real` 控制门冲突。按当前文字，一个 producer bug 或手工构造的 ref 可以让上述失败证据输出 `SEED ABI PASS public_aosp17_cuttlefish`，随后 control plane 记录 `GATE CONTINUE_PUBLIC`。

修复要求：把 success-seed 的 cross-field invariants 与 ref-mode evidence-closure verification 写成 closed contract，并明确它们在 positional fixture 与 ref mode 中各自的唯一错误码。至少应固定 resources 的 iff/全 true、lunch exits、netns 分离、五类 forbidden count、source before/after、project count，以及 ref mode 下四类 evidence digest 的存在/kind/content 关系。fixture positive 仍可只走纯 seam，不得因此创建伪 production ref。

### B2 — lock-before-observation 已写出骨架，但 missing/symlink/invalid-lock 仍无法得到唯一 error code

R8（第 38 行）正确要求在首次观察 existing ref/object 前取得 lock；第 138 行也把 ref/object 检查移到 lock 后。但以下分支仍未进入唯一状态机：

- 第 132 行只规定“合法 ref 指向的 object missing”为 `ARTIFACT_MISSING`，没有规定 ref leaf 本身 missing 的 code；PLAN v6 的稳定接口文字要求 ref 或 artifact 任一缺失为 `ARTIFACT_MISSING`。
- R5（第 32 行）把 existing ref symlink/non-regular 归入 path no-follow contract，pre-lock 全序（第 136 行）又含 `OUT_REF_CONTRACT`；R8 则禁止 lock 前观察 existing ref，而 post-lock 全序只写 ref bytes/type/kind/digest 为 `REF_CORRUPT`。因此 ref symlink 可被实现为 pre-lock `OUT_REF_CONTRACT` 或 post-lock `REF_CORRUPT`。
- R8 固定 existing lock 必须为 0600 regular file，但没有规定 symlink、non-regular、wrong mode/owner、open error 分别返回 `OUT_REF_CONTRACT`、`REF_BUSY` 还是其他 code；“nonblocking lock failure 必须 REF_BUSY”也可能被理解为覆盖这些 contract failure。

这些不是错误文案细节：R12、验收清单和 runtime `ContractError` 都要求逐例 exact `CONTRACT CODE`，两种实现会生成不同 CLI ABI 与 fault matrix。修复时应明确 pre-lock 只校验哪些 lexical/parent facts、lock leaf 每种失败的 code、lock 后 ref leaf missing/symlink/non-regular/noncanonical 的 code，并保持绝不在 lock 前观察 ref/object。

## Important

### I1 — `publish_object`/`publish` 的 payload 形态和验证责任仍未闭合

Runtime API（第 68–71 行）同时传入 `object_kind` 与 `payload`，但没有固定 `payload` 是：

1. 已含 `schema_version`/`kind` 的完整 artifact，runtime 只检查 `object_kind == payload.kind`；还是
2. 不含 envelope 的 body，由 runtime 插入 `schema_version`/`kind` 后 canonicalize。

也没有明确 producer entry point 必须在任何 temp/object commit 前执行本节全部 schema、nested digest、cross-field validation，并用 kind 对应的唯一 domain 计算 object digest。`load_artifact` 只覆盖 path-based consumer，API 没有另一个 producer validator；因此 00b 可以合理地选择“publish 只 canonicalize/store caller bytes”或“publish 构造并验证 artifact”，两者都能引用当前文字，却产出不同 bytes/error timing。

修复要求：为两个 publish signature 固定 exact payload envelope、kind/domain dispatch、schema/nested/cross-field validation 与 error timing；说明 `publish_object` 是否验证 evidence object，`publish` 是否在 object commit 前验证 seed/terminal 及其 evidence references。这样 00b 才不需要绕过或重新发明 00a unique-owner runtime。

### I2 — leaf type/format 与 semantic relation 仍不足以称为逐项 closed schema

round 2 指出的主要 nested 字段已补齐，但 seed 表仍留下可导致不同 validator 的空白：

- `manifest.remotes[].name` 未给 exact type/nonempty 约束；
- `execution.host_arch`、`kernel_release` 与 container 模式的 `container_digest` 未给 exact type/format；
- `resources.measured` 各字段只写“only cgroup/cpuset nullable”，没有逐字段声明 uint/null 及 numerator/denominator 的合法关系；
- `lunch.out_dir_relative` 未恢复原 ABI 的 normalized relative、位于 `tmp/preflight` 下等约束；
- `source_state.state`、`clean_source_proof`、`affected_project_count` 的相互关系未固定。

全局“integer 若出现则为 uint”不能回答一个字段究竟必须是 integer 还是 string；字段名也不能替代类型合同。应把这些 leaf type/format/nullability 和关系直接补入 Stable data ABI。B1 所列承重 success invariants 修复后，本项剩余部分属于局部 closed-schema 补全。

## Minor

### M1 — evidence object temp 的 cleanup 叙述与无锁 API 不一致

R15（第 52 行）说意外终止 temp 由“后续 locked invocation”清理；第 71 行又明确 `publish_object` 不创建 lock/ref。`publish_object` 同样会创建 object-dir temp，因此它的 stale temp 是无锁清理、借后续 ref publish 的 scope lock 清理，还是不承诺清理，并不唯一。该 temp 不可消费，暂不破坏内容正确性，但会影响并发安全和状态清单。应固定 object-dir stale-temp 的 owner/age/lock 或明确只保证不可消费、不保证由 `publish_object` 清理。

## Round 2 的 3 blocker / 2 important / 2 minor 逐项复核

| round 2 finding | round 3 状态 | 复核结论 |
|---|---|---|
| B1 closed nested schema / semantic arrays | ⚠️ 部分关闭 | sorted/unique 与 semantic-order arrays 已正确分开；source-state、trace、journal、terminal reason、identity children 与 request reconstruction 大幅补齐。但 success cross-field/evidence closure 与若干 leaf type/format 仍不 closed，见 B1/I2。 |
| B2 store root / object-only publish / keyword API | ⚠️ 部分关闭 | store 已统一为 `STATE_DIR/artifacts/v1`，`publish_object`、keyword-only signatures、typed result 与 `ContractError` 均已补；publish payload envelope、producer validation 与 nested evidence responsibility 仍不唯一，见 I1。 |
| B3 lock/error priority / public code | ⚠️ 部分关闭 | ref/object observation 已移到 lock 后，public false 固定为 `PUBLIC_SCOPE_REQUIRED`，nested mismatch 分 positional/ref 两类；missing ref、ref symlink/non-regular 与 invalid lock leaf 仍无唯一 code，见 B2。 |
| I1 no-follow / verifier forbidden roots | ⚠️ 部分关闭 | adjacent lock 的 `O_NOFOLLOW`/0600/parent confinement、CLI store→state-dir 推导及 00b full forbidden-roots API 已补。路径动作基本闭合；lock/ref leaf 的 error assignment 仍由 B2 阻断 exact ABI。verifier 只使用 harness root 是文档已明确的 owner choice，本轮不另报 source-root finding。 |
| I2 730/140 estimate timing | ✅ 关闭 | estimate 超限明确在 implementation 开始前回 PLAN；actual 超限在 acceptance 前回 PLAN；731–800/141–160 不可借外层上限放宽。 |
| M1 confirmation timing | ✅ 关闭 | `已由用户确认: false` 与“等待 round 3 PASS”一致，是正确流程状态，不是内容缺陷。当前因本轮 FAIL 保持 false。 |
| M2 runtime export list | ✅ 关闭 | 目标、R14 与 Runtime API 均列出 `publish_object` 和 `publish`，export list 已一致。 |

## 完整质量复核

- EARS：**PASS**。R1–R18 均匹配泛在、事件、状态、可选或异常中文模板；没有占位式“优化/支持/完善”需求。
- 来源与提问：**PASS**。当前项目沿 legacy 来源语义使用裸 `[计划]`；18 条都来自已批准 PLAN/DECISIONS/原 00 successor migration contract，没有 `[默认]`/`[推断]`，所以 0 个问题不是静默假设。
- 范围与 YAGNI：**PASS**。未把真实 source probe、resource/trace provider、closure/build/adapter 拉进 00a；marker、dispatcher、schema、store/ref runtime、fixture fault seam 和 descendant rollback 都服务于 PLAN v6 的 00a 边界。
- 主命令与人工清单：**部分 PASS**。完整 stdout/stderr、dispatcher/direct capture、schema/path/fault/rollback matrix、730/140 budget 都可执行；但 public matrix 当前只能验证过窄 predicate，publish matrix 也无法为 B2/I1 的分支写唯一 expected code/bytes。
- 不变量：**部分 PASS**。四项数量、阈值和命令形状满足 requirements 规则；zero-write、path confinement、no dangling ref、rollback regression 均有 oracle。尚缺“public PASS 不得携带 failed environment evidence”的承重不变量/验收矩阵，属于 B1。
- closed API/schema/error order：**FAIL**。核心缺口见 B1、B2、I1、I2；在修复前进入 design 会把本应由 00a 决定的字节合同和错误状态交给实现者/00b 猜测。

## 通过条件

修复两个 blocker 与两个 important；M1 可同步修正文案或记 ledger 留至验收。修订后重新运行 `check-req.py`、`check-analyze.py`，并在内容 review PASS 后把 frontmatter `已由用户确认` 作为纯流程元数据改为 `true` 再运行 `check-criteria.py`。本轮内容未 PASS，因此当前不得只翻转该字段，也不得进入 design。
