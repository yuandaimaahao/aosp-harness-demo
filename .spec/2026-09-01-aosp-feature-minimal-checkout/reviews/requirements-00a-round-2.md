# 00a requirements review — round 2

结论：**FAIL**

- 规格符合性：**FAIL**。round 1 的 14 项中，8 项关闭、5 项部分关闭、1 项仍未关闭；原 R5/R8/R21/R22/R23/R25/R27 的大部分边界已经迁入，但 00a 独占的 closed schema、store/runtime consumer API 与 exact error order 仍不能由 00b 唯一消费。
- 需求质量：**FAIL**。18 条 R 均满足 EARS，来源已统一回到既定 PLAN，0/15 questions 与 0/2 rounds 合理，未发现把 00b 或 01–05 功能提前实现的 YAGNI 扩张；失败来自已在范围内的 ABI 自相矛盾和验收 oracle 缺口。
- 机械检查：使用 spec skill 的 `check-req.py`、`check-criteria.py`、`check-analyze.py` 对修订稿运行，三者均 exit 0。以下是机械门禁未覆盖的跨条、跨文档与 producer/consumer 语义问题。
- 审查期间未运行 envsetup、lunch、m/mm/mmm、ninja、package、flash、repo sync、Git fetch/clone 或下载，也未修改 requirements 草稿。

## Blocker

### B1 — schema 仍非逐项 closed，且新增的全局 array 规则会拒绝原 ABI 的合法 payload

修订稿第 28、66、151 行把“重复或乱序 array”作为全局拒绝/mutation oracle；但原 ABI 与修订稿自己的具体 schema 同时包含只保持语义顺序、并非集合排序的 array：`trace.records[].exec_argv_b64` 是 argv 顺序，重复 argv 合法；`paths` 是 syscall operand 顺序，两个 operand 可以解析成相同 bytes；`summary_lines` 也没有 unique/sort 约束。只有 `projects`、`entries`、manifest `remotes/projects`、command stages、`failed_checks` 等有明确唯一键或优先级的 array 才能拒绝 duplicate/out-of-order。当前规则会让两个实现分别选择“拒绝合法重复 argv”或“只对声明 sorted/unique 的 array 拒绝”，两者都能从不同段落找到依据。

此外，修订稿仍未达到 round 1 B1 所要求的 nested key/type/enum/nullability/order 闭合：

- `source-state/v1` 未固定 `manifest_sha256`、`path`、`status_sha256`、各 base64/digest 字段的 exact type/format，也未列出三种 `entry_kind` 各自哪些 digest 必须为 null/non-null。
- `trace/v1` 未固定 `sequence`、`process_ordinal`、`syscall`、`address_family`、`raw_b64`、`resolved_b64` 的 type/nullability，`exec_argv_b64` 也未明确为 string array；这不是仅由 00b 决定的采集策略，而是 00a validator 必须接受/拒绝的 bytes 合同。
- `command-journal/v1` 未固定 `argv_b64`、`cwd_b64`、exit/sequence 字段的 exact type/nullability。
- `terminal-report/v1` 要求 `failed_checks` “priority-sorted”，却没有迁移原 requirements 第 143 行的 environment reason 全序和值域；00a 无法验证 00b 发布的 terminal report。`primary_reason` 与 `failed_checks` 的关联也未固定。
- `seed_identity` 仍用“execution/lunch/source-state identity 排除哪些字段”描述，而没有把三个 nested payload 的 exact children/type 直接列出；`verify-seed INPUT` 也没有写明如何从单个 seed 重建 request payload 并核对 `request_digest`、scope/source/lunch/minimums/estimate 的对应关系。

artifact 与两个内部 digest payload 已正确分开，`seed_content`/`seed_identity` 也不再被错误要求 `schema_version`/`kind`；但上述缺口和全局 array 冲突仍足以让 canonical bytes、validator 和 golden 产生分叉。00a 是唯一 schema/digest owner，不能把这些选择留到 design 或 00b。

### B2 — artifact-store 与 runtime API 仍不能完成 PLAN/原 00 的 00b 交接

修订稿 R5（第 32 行）要求调用者传入的 `artifact-store` 精确等于 `STATE_DIR/artifacts/v1/sha256`；批准的 PLAN 第 26、28–38 行及第 158、162 行则把 CLI `STORE` 固定为 `STATE_DIR/artifacts/v1`，object 才位于 `STORE/sha256/<digest>`。原 00 requirements 第 84 行也只把 object 定位到 `STATE_DIR/artifacts/v1/sha256/<digest>`，没有把 CLI store 参数改成 sha256 leaf。按修订稿实现的 `verify-seed` 会拒绝项目级整体验收传入的合法 store；按 PLAN 实现又会违反 R5。这是直接的 public CLI ABI 冲突。

Runtime API 第 62 行也缺少 00b 必需的 object-only publish primitive。原 R19/R20 要求先发布 `source_state`/`trace`/`command_journal` evidence objects，再发布 seed/terminal object，最后提交 ref；当前唯一 `publish(...)` 强制接收 `out_ref`/`ref_kind`，且只允许 `env_pass -> seed` 与 `terminal_report -> terminal_report`，无法发布三类无 ref evidence object。00b 要么绕过 00a 独占 store runtime，要么伪造临时 ref，都会破坏 owner 边界。

同一 API 段还写“positional-free keyword API”，但列出的 Python signatures 没有 `*`，`validate_state_paths(...) -> normalized paths` 没有固定返回 type/keys，错误也没有固定 exception/return carrier。R14 要求后序 wrapper 精确翻译为单行错误，只有错误码名字而没有 runtime error propagation ABI，00b 仍需猜测如何调用和捕获。必须统一 store root，增加可幂等提交 evidence object 的稳定入口，并固定 keyword-only signatures、返回结构和错误传播合同。

### B3 — exact error priority 仍与 lock 生命周期冲突，且 public gate 负例没有唯一 code

R8（第 38 行）要求从“首次观察 existing ref”到 ref-dir fsync 全程持锁。第 125 行却把 `ARTIFACT_MISSING -> REF_CORRUPT` 放在 pre-lock validation 全序，第 127 行才取得 lock 并“重新验证 existing ref”。这既允许第一次无锁读取 ref，也改变了原 requirements 第 141 行已固定的 `... WORKTREE_MISMATCH -> REF_BUSY -> REF_CORRUPT` 次序。若 ref 同时 corrupt 且 lock busy，修订稿可先报 `REF_CORRUPT`，原 ABI 则必须先报 `REF_BUSY`；若完全不在锁前读 ref，又无法执行第 125 行的顺序。exact priority 因而不可实现为单一状态机。

`--require-public-real` 的 fixture/local/vendor/malformed 负例同样没有 exact code。它们可以是 schema-valid、digest-valid、ref/object matching，只是 public predicate 为 false，因此既不自然属于 `REF_CORRUPT`，又没有 `PUBLIC_SCOPE_REQUIRED` 一类 code。nested digest mismatch 在 fixture form 下应映射 `DESCRIPTOR_SCHEMA_INVALID`、`REF_CORRUPT` 或其他 code 也未固定。R12/验收要求 exact `CONTRACT ERROR_CODE`，但没有 oracle 可判这两类强制负例。必须恢复可执行的 lock-before-observation 全序，并逐项固定 public predicate、nested digest、missing object、wrong object kind/digest/noncanonical ref 的唯一 code 与相互优先级。

## Important

### I1 — no-follow/forbidden-roots 边界还有两个调用路径缺口

R5 已补 state-dir/store/out-ref 的 normalized absolute、regular-file 与 no-follow 规则，R6 也补了 `forbidden_roots` 参数；但 adjacent `OUT_REF.lock` 没有 existing/missing leaf 的 `O_NOFOLLOW`、regular-file、mode 与 parent confinement 合同，攻击性 symlink lock 仍可能让 publisher 打开 state-dir 外文件。

另外，ref-mode CLI 只有 `--ref` 与 `--artifact-store`，没有 state-dir/forbidden-roots 输入；`resolve_ref(ref, artifact_store, require_public_real=False)` 也不接收它们。requirements 没有说明 `verify-seed` 如何推导 state-dir、harness root 和所有 source/project worktree realpath，或它必须先调用哪个可表达该集合的 API。当前 R6 只规定“调用者传入”，没有闭合这条公共 verifier 路径。应把推导规则/参数与调用顺序写入合同，并让 lock file 服从同一 no-follow regular-file policy。

### I2 — 730/140 数值已修正，但 estimate gate 的时点仍比 PLAN 弱

R17 和清单已正确区分 supersession ceiling 730/140 与项目外层绝对上限 800/160，也明确 731–800、141–160 不是可接受区间；round 1 I5 的数值问题已关闭。但 R17 把 `tasks estimate` 与 `actual` 一并写成“implementation acceptance 前回 PLAN”。tasks estimate 在门④前已经可知，PLAN 的目的正是阻止超预算实现启动；当前文字仍允许先实现 731+ 行、到 acceptance 才拆。应固定 estimate 超限在 implementation 前返回 PLAN，actual 超限在 implementation acceptance 前返回 PLAN。

## Minor

### M1 — `已由用户确认: true` 仍早于本轮 fresh review/门②自动通过

frontmatter 第 7–8 行把当前 requirements 标为已确认，同时承认“最终门②仍以 fresh re-review 为前提”。用户授权 autopilot 可以让控制器在 review 通过后自动拍板，但不能让尚未通过 review 的文档提前成为已确认状态。round 1 M3 因而未关闭；应在本轮 blocker/important 修复并 fresh review PASS、ledger 记录自动通过后再置 true。

### M2 — 目标段与稳定 API 对 `publish` export 的枚举不一致

目标第 20 行说 runtime exports 固定覆盖到 `resolve_ref`，遗漏 `publish`；R14 与 Runtime API 又把 `publish` 列为 stable import。后两处足以推断 intended ABI，但 closed export list 不应一处为六个、一处为七个。

## Round 1 全部 14 项复核

| round 1 finding | round 2 状态 | 复核结论 |
|---|---|---|
| B1 closed schema / artifact-vs-digest | ⚠️ 部分关闭 | 六类 artifact 与两个内部 digest payload 已分开，原顶层字段大体恢复；全局 array 规则冲突、nested type/nullability、terminal reason 全序和 identity/request 关系仍未闭合，见 B1。 |
| B2 CLI grammar | ✅ 关闭 | positional 与 ref form 已写成两个互斥 production，非法 missing/repeated/reordered/extra args 统一 `ARGUMENT_ERROR`，并由 R12 固定 exit/channel。 |
| B3 runtime marker/module/API/path | ⚠️ 部分关闭 | marker/module 路径、bytes、exports 和 pre-import failure 已固定；store root 冲突、evidence object publish 缺席、return/error ABI 与 verifier forbidden-roots 路径仍阻断 00b，见 B2/I1。 |
| B4 exact errors / zero-write | ⚠️ 部分关闭 | validation 与 publish stage 已拆开，pre-publish object/ref/temp/sentinel zero-write 已明确；ref observation/lock priority 和 public/nested-digest code 仍不唯一，见 B3。 |
| B5 descendant rollback oracle | ✅ 关闭 | descendant fixture commit 在 00a merge 之后唯一新增 wrapper，revert 只针对 00a merge；wrapper 明确保留、regular executable、exact `RUNTIME_UNAVAILABLE`，三项旧 harness oracle 逐字固定。它不属于被 revert merge。 |
| I1 parity bytes/digests | ✅ 关闭 | R13 已把 exit/channels、canonical object/ref bytes、artifact/nested digest 与 predicate 结果全部纳入 dispatcher/direct parity。 |
| I2 ref-kind mapping | ✅ 关闭 | `env_pass -> seed`、`terminal_report -> terminal_report` 及 missing/corrupt 分类已显式列出；其相对 error priority 仍归 B3。 |
| I3 provenance / zero questions | ✅ 关闭 | R15/R18 已改为 `[计划]`，18 条均可追溯到 PLAN/DECISIONS/原 00；没有 `[默认]`/`[推断]` 遗留，0 个问题成立。 |
| I4 order/digest mutation oracle | ⚠️ 部分关闭 | object-key reorder 与 run-evidence/identity 不变 oracle 已补；对所有 array 一律 duplicate/out-of-order invalid 又引入原 ABI 冲突，见 B1。 |
| I5 730/140 vs 800/160 | ⚠️ 部分关闭 | 两层数值和不可借外层放宽已闭合；estimate stop 时点仍弱，见 I2。 |
| I6 public positive boundary | ✅ 关闭 | 00a positive 只走 pure predicate seam，CLI/ref integration 只做负例，真实 positive 归 00b；未要求伪 real-source production ref。 |
| M1 main/exact channels | ✅ 关闭 | 主命令完整 stdout 精确一行、stderr 空；dispatcher/direct 输出被捕获；旧 harness 三个 exact PASS 已固定。 |
| M2 temp cleanup | ✅ 关闭 | 受控 fault 返回前 temp=0；意外终止残留的命名、0600、不可消费和后续 locked best-effort cleanup 均已固定。 |
| M3 confirmation timing | ❌ 未关闭 | `已由用户确认: true` 仍早于 fresh re-review PASS，见 M1。 |

## 规格与质量结论

- 规格迁移：dispatcher grammar、digest payload 分层、ref-kind 映射、rollback、budget 数值、public seam、channels/temp 已达到可保留状态；closed schema、store/runtime API 和 error state machine 尚未达到 00a unique-owner 的 design-ready 标准。
- EARS/来源/问题预算：**PASS**。18/18 条 R 成句，来源均为已批准计划；0/15、0/2 没有隐藏业务选择。frontmatter 的确认时点是流程状态错误，不改变来源结论。
- YAGNI：**PASS**。未发现新增真实 AOSP probe、closure/build 或 adapter 功能；新增 marker、fault seam、descendant rollback fixture 都服务于已批准边界。
- 可验收性：**FAIL**。三项静态 checker 能通过，但 schema matrix 会在合法重复 argv 上产生相反 oracle，整体验收传入的 store 会被 R5 拒绝，00b 无 API 发布 evidence object，public/ref 错误又无唯一 expected code。
- 不变量：pre-publish zero-write、no dangling ref、rollback regression 和 controlled temp cleanup 的方向成立；lock no-follow 与 ref-mode forbidden-roots 未闭合，路径不变量尚不能判 PASS。

通过条件：修复全部 blocker 与 important，修正两个 minor，重新运行三项 requirements checker，并由第三个全新上下文 reviewer 对下一版完整复审。当前稿不可进入 design。
