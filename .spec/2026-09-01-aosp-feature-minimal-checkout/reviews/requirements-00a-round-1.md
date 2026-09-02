# 00a requirements review — round 1

结论：**FAIL**

- 规格符合性：**FAIL**。原 R5/R8/R21/R22/R23/R25/R27 均能在草稿中找到意图对应项，但 R8/R21/R22/R23/R25/R27 只有部分迁移；00a 独占的 schema/runtime ABI 还存在已审字段冲突和未定义接口。
- 需求质量：**FAIL**。18 条 R 均通过 EARS 机械检查，主命令和 4 个不变量也都是 fixture/本仓命令，不会偷跑真实 AOSP；但 closed schema、CLI grammar、error priority、runtime marker 和 rollback oracle 尚不足以无歧义进入 design。
- 机械检查：`check-req.py`、`check-criteria.py`、`check-analyze.py` 均 exit 0。以下均为机械门禁未覆盖的跨文档/ABI 语义问题。
- 审查期间未运行 envsetup、lunch、build、sync、download，也未修改 requirements 草稿。

## Blocker

### B1 — R3/R4/R10/R11 的“closed schema”与已审 seed ABI 冲突，且实际上没有闭合

草稿 Stable data ABI 第 66–73 行只列顶层摘要，并在 R77 把完整 nested key/type/enum/order 推迟到 design；这不满足“00a 独占 schema、00b 只填充并发布”的边界，也让 design 可以重新发明 identity 输入。至少存在这些实质冲突：

- `seed_request` 被写成 `source_scope,manifest,tools,execution,resources,lunch,output`，而原 requirements 第 86–97 行固定的是 `source_root,envsetup_relpath,lunch,source_scope,resource_minimums,estimated_disk_upper_bound_bytes`。当前版本既漏掉 00b 必需的源码/envsetup/threshold 字段，又新增未获授权的 request 字段。
- `trace` 顶层新增了 `classification`，但原 ABI 的 `classification` 是 record 字段，顶层只有 `schema_version,kind,records,counts`。
- `command_journal` 没有闭合顶层 `{schema_version,kind,records}` 和 record 字段；`source_state`、`seed`、`seed_content`、`seed_identity` 也都缺完整 nested type/enum/nullability/order。
- R3 声称所有 payload 都要求 `schema_version=1` 与 `kind`，但原 `seed_content`/`seed_identity` 是 digest payload，并无这两个字段，草稿自身与表格也未解决该冲突。
- R11 要求 `fixture_only=false`，但原 closed `seed/v1` 只有 `evidence_class=real_source|fixture_only`，没有 `fixture_only` boolean；同时漏验 public scope 已固定的 `platform_family=aosp-17`。

这会使原本合法的 00b seed 被 00a 判 unknown/missing field，或使不同实现计算不同 digest。必须在 requirements 中恢复完整且唯一的八类 schema，明确哪些是 artifact、哪些只是 digest payload，并逐项对齐 `real_source`、`env_pass`、`envsetup_relpath`/envsetup、lunch 与 public scope。

### B2 — R2/R10/R11 的 `verify-seed` CLI grammar 有两种合理解释

frontmatter 与 R2 写成 `verify-seed INPUT|--ref REF --artifact-store STORE [--require-public-real]`。它既可读成“`INPUT` 或 `--ref REF`，之后两者都必须带 store”，也可读成“fixture 位置参数”与“完整 ref 形式”二选一；PLAN 第 66 行及 R10 又明确要求 `verify-seed seed.golden.json` 不带 store。`--require-public-real` 是否可与 positional INPUT 联用、参数顺序/重复/额外参数如何报错也未固定。

必须写成两个互斥 production，例如 `verify-seed INPUT` 与 `verify-seed --ref REF --artifact-store STORE [--require-public-real]`，并固定非法组合的 exact exit/channel/code。否则 public ABI、direct ABI 和验收命令不是同一个合同。

### B3 — frontmatter 产出的 runtime ABI 不能被 00b 具体消费

frontmatter 产出一个未定义的 `seed-contract-runtime/v1`；R14 又要求后序 wrapper 在 import 前检查“00a marker/schema”，但全文没有 marker 路径、精确 bytes/version、shared runtime 模块路径、可调用入口、参数/返回值或错误传播合同。R5/R6 还要求调用者提供 source/project worktree containment 集合，却没有对应 runtime 参数接口；`OUT_REF`/artifact-store 的 normalized absolute/no-follow/under-state-dir 约束及 existing ref/object 的 regular-file no-follow 读取也未闭合。

PLAN 第 80、83、88、160–162、181 行把 schema/digest/store/ref/dispatcher runtime 明确交给 00a，00b 只允许调用它而不能修改它。当前文本会迫使 00b 猜 marker、import 和 publisher/ref-reader ABI。必须把 frontmatter 产出展开为可定位、可版本检查、可调用的接口，并让 R14 的 pre-import 行为可独立测试。

### B4 — R12 与错误优先级没有迁移 shared R21/R22/R27 的 exact error ABI

R12 只写 `CONTRACT ERROR_CODE`，第 81 行只给七个错误类别，未固定 `ARGUMENT_ERROR`、`INVALID_COMMAND`、`COMMAND_UNAVAILABLE`、invalid UTF-8、duplicate key、unsupported schema、schema invalid、state-dir/out-ref contract、`ARTIFACT_MISSING`、`REF_CORRUPT`、`DIGEST_COLLISION`、`REF_BUSY` 等输入到 code 的唯一映射及类别内优先级。00b 因而无法完成原 R21/R27 中“provider 不归一化非法输入、由 00a schema/error ABI 精确拒绝”的共享责任。

此外 R12 允许 validation/collision failure 的 sentinel “保持不变或只进入 R9 状态”，弱化了原 R21 的 pre-publish 零写入：schema/path/ref-validation 错误不得借 R9 进入 orphan/uncertain；只有原 R22 的 post-observation publish fault 可进入该矩阵。需拆开 pre-publish validation 与 post-observation publish 错误并列出全序。

### B5 — R14/R16 尚不能运行 PLAN 要求的“00a revert、后序 wrapper 保留”oracle

R16 的方向与 DECISIONS 第 23 行一致，但“后序 recovery fixture direct command”没有精确路径、版本 marker、创建/保留方式和完整 exit/stdout/stderr oracle。00a 合入时真实 00b–05 尚不存在；若 fixture 属于 00a merge，它会随 revert 消失，无法证明“后序 commit 保留”。验收清单也只写 isolated revert/三项回归，未勾验 wrapper 文件仍存在并精确返回 exit 30、空 stdout、单行 `CONTRACT RUNTIME_UNAVAILABLE`；rollback 不变量命令也未说明如何取得 ledger merge SHA。

必须固定一个模拟后序 wrapper 的 descendant/外置 fixture 拓扑：先确保 wrapper 不属于被 revert 的 00a merge，再 `git revert -m 1` exact SHA，逐字断言 dispatcher 与 verify-seed 消失、wrapper 仍为 regular executable、wrapper 返回 RUNTIME_UNAVAILABLE，并断言三项旧 harness 的 exact PASS 行。

## Important

### I1 — 原 R23 的 00a 半片只迁移了 channel parity，未固定 ref/object/digest parity

R13 只要求相同“验证结果”，比原 R23 的 exact artifact digest/ref bytes 弱；R10 虽要求重算，但没有把 ref mode 下 dispatcher/direct 两条路径的 ref bytes、object bytes、artifact digest 与 nested digest 逐项相等连到 parity oracle。应明确哪些 bytes/digest 必须相同，00b 再负责 preflight producer parity。

### I2 — ref kind 到 object kind 的映射有歧义

第 75 行称 ref digest 必须解析到 “matching kind/object”，但 R11 同时要求 ref `kind=env_pass`、object `kind=seed`。需显式固定 `env_pass -> seed`、`terminal_report -> terminal_report`，并固定 missing object、wrong object kind、wrong digest、noncanonical ref bytes 的 code/priority；否则 `REF_CORRUPT` 与 `ARTIFACT_MISSING` 可被不同实现互换。

### I3 — R15 与 R18 的来源标签不准确，0 问题结论因此没有完整依据

R15 的 commit-point 状态机已经由 PLAN/DECISIONS 固定，不是新 `[默认]`；应标 `[计划]`。R18 的“不运行 AOSP/envsetup/lunch/build/sync/download”来自 PLAN 的 00a 范围，不是所列用户原话，应同样标 `[计划]`。如果保留 `[默认]`，按 requirements 规则它必须进入问题池或“已定告知”；当前 Questions 0/15 又称没有新选择，二者不一致。修正 provenance 后，0 个问题是合理的。

### I4 — schema/digest 验收矩阵混淆“乱序非法”和“canonical key order 不影响 digest”

R3 拒绝乱序 array，R4 要求 JSON object key 输入顺序变化不改 digest；验收清单却笼统要求八种 kind 的每个 field 覆盖 `order` mutation，容易把 object key reorder 误判为 schema error。另需区分 run-evidence 字段只改变 seed artifact digest，而不得改变 `seed_identity_digest`。应为各 array 写唯一排序键，为 object key reorder 写等 digest oracle，为 identity 排除字段写“不变”oracle。

### I5 — frontmatter 声称消费 supersession budget，但 R17 只保留外层 800/160

R17 正确保留 PLAN 正文的硬上限 `non-generated diff <=800`、summary `<=160`；但 machine-readable supersession 给 00a 的 sizing ceiling 是 730/140，PLAN 第 66 行也写预计 `<=730`。当前 frontmatter 又明确称消费该预算合同。应明确 730/140 是本片承诺还是仅 estimate；若继续消费 supersession exact budget，就不能只在 801/161 才回 PLAN。至少不能静默丢掉 730/140 与 800/160 的层次。

### I6 — `--require-public-real` 成功分支的验收边界未闭合

R10/R11/R18 正确禁止把 fixture 冒充 real proof，但清单又要求“只有 matching real public ref”可输出 public PASS，而 00a 明确不读取真实 AOSP，也没有 operator-supplied real ref。需说明 00a 只以负例和纯 predicate/unit seam 验 gate，真实 positive integration 归 00b；不得为覆盖分支而发布伪 `real_source` production ref。

## Minor

### M1 — 主判据对通道约束不够逐字

主命令可运行且不触碰真实 AOSP，但“最后一行精确”允许前面出现意外输出，且未声明主命令 stderr 为空。建议固定完整 stdout/stderr，或固定允许的逐行集合；rollback 的三项旧 harness 也应写回原合同中的 exact PASS 文本。

### M2 — temp cleanup 的验收状态未定义

R15 允许 best-effort cleanup，清单又要求逐例核对 temp 状态。应明确 fault 后允许残留 temp 的命名/mode/不可消费规则，或明确测试注入下必须清零；否则两种实现都能声称通过。

### M3 — 当前 frontmatter 的“已由用户确认: true”早于本轮 review/自动拍板记录

用户已批准 PLAN 和 autopilot，足以授权本轮自动裁定，但 ledger 目前只有 draft/check/review-dispatch，尚没有门②自动通过记录。建议在 review 修复完成并记录自动拍板后再把“当前 requirements 已确认”写为 true，或把字段语义明确成“已授权 autopilot”。

## 原 owner 迁移核对

| 原 requirement | 草稿对应 | 结论 |
|---|---|---|
| R5 dispatcher | R1、R13 | 部分符合；command grammar/realpath/regular executable 已迁移，非法 argv/error 全序未闭合 |
| R8 state-dir primitive | R5、R6 | 部分符合；state-dir 自身规则已迁移，runtime 参数、OUT_REF/store/read no-follow 边界缺失 |
| R21 validation/error | R3、R12、第 81 行 | 不符合；缺 exact code/priority，且错误地允许 validation 进入 publish-fault 状态 |
| R22 publisher/ref fault | R7–R9、R12、R15 | 大体机制已迁移；仍被 B4 的错误分层与 I2 的 ref-kind 映射阻断 |
| R23 parity | R2、R10、R13 | 部分符合；CLI grammar 与 bytes/digest parity 不完整 |
| R25 rollback | R14、R16 | 目标一致但 oracle 不可独立执行，未证明 retained wrapper |
| R27 invalid threshold | R3、第 62 行、R12 | 仅有 generic missing/float/range 拒绝；因 seed-request threshold schema 与 exact error 缺失而未完成 |
| 00a 独占 schema/digest/store/ref/dispatcher/runtime | R1–R15 + Stable data ABI | dispatcher、digest算法和 publish commit points 有基础；schema、consumer/runtime marker/interface、error ABI 未达到 design-ready |

## 可保留部分

- R1 的 dispatcher 路径解析、command regex、regular executable 约束与 PLAN 一致。
- R7–R9/R15 的 immutable object、lock 生命周期、object-before-ref、orphan 与 durability-uncertain 基本遵守“不虚构 post-commit 全回滚”。
- R17/R18、主命令与 4 个不变量均把验收限制在 fixture/本仓测试，没有偷跑真实 AOSP。
- 验收方式“混合判定”、0/15 questions、0/2 rounds 在把既定项正确标回 `[计划]` 并补齐接口后是合理的。

通过条件：修复全部 blocker 与 important，重新运行三项 requirements checker，并由全新 reviewer 对修订稿重审。当前稿不可进入 design。
