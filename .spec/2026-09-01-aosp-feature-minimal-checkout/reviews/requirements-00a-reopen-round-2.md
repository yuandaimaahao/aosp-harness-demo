# 00a requirements reopen review — round 2

结论：**FAIL**

- 规格符合性：**FAIL**。上一轮 numeric supersession blocker 已实质关闭：`DECISIONS.md` 新增的 2026-09-02 口径明确替代原 signed/unsigned-64 JSON number 接受域，当前 requirements frontmatter、Stable data ABI 与 design 都消费 I-JSON safe-integer 口径，且下游 00b–05 的 overflow observation 被明确要求不得截断/舍入、按 schema/`TRACE_UNAVAILABLE` 路径 fail closed。R1–R18 也均有来源与承接。但 requirements 宣称的全局 exact error priority 与 generic dispatcher/direct parser 分层仍不可同时实现。
- 需求质量：**FAIL**。closed schema、runtime/publisher API、lock/ref、evidence closure、publish fault、rollback、预算、EARS 与 YAGNI 主体均闭合；numeric/surrogate 边界矩阵也已补齐。仍有一项阻断的跨层错误优先级冲突，以及一项重要的 `TypeError -> RUNTIME_INTERNAL` 验收 oracle 未逐字锁定。
- findings：**1 blocker / 1 important / 1 minor**。blocker 与 important 修复后必须由全新 reviewer 回审；minor 可同步修复或按流程挂账。
- 机械检查：`check-req.py` exit 0，`check-analyze.py` exit 0，`git diff --check` exit 0。`check-criteria.py` exit 2 的唯一原因是 frontmatter `已由用户确认: false`；这是等待本轮 PASS 的流程态，不是 finding。使用不落盘的只读替换流把该字段视为 `true` 时，`check-criteria.py` exit 0。
- 审查边界：完整阅读了 spec skill 的 `SKILL.md`、`references/03-requirements.md`、`references/07-review.md`、PLAN v6、DECISIONS（含 2026-09-02 numeric supersession）、当前 requirements/design、requirements reopen round 1、design round 1 与 ledger；另只读核对原 00 requirements 中 R13/R17/R20/R27 与 numeric/trace schema。未修改 requirements/design 草稿，未执行 AOSP envsetup/lunch/build/sync/download/fetch/clone，也未读取 LK7K AOSP tree。

## Blocker

### B1 — `ARGUMENT_ERROR -> INVALID_COMMAND -> COMMAND_UNAVAILABLE` 的全局顺序无法由既定 generic dispatcher 实现

requirements 第 138 行把所有“不读取 ref/object 的 validation”声明为一个 stop-at-first 的 exact 全序：

`ARGUMENT_ERROR -> INVALID_COMMAND -> COMMAND_UNAVAILABLE -> ...`

但 R1 与当前 design 第 60–69 行同时固定 dispatcher 只校验 subcommand name、定位 direct executable 并 `exec`；command-specific 的两个 argv production 由 `verify-seed` direct command 自己解析。于是至少两个组合没有可实现的唯一 oracle：

1. `verify-seed` target missing/symlink/non-executable，同时 argv 是非法 missing/repeated/reordered/extra form：generic dispatcher 无法执行不存在的 child parser，因此只能按 R13 返回 `COMMAND_UNAVAILABLE`，却违反第 138 行要求更高优先的 `ARGUMENT_ERROR`。
2. subcommand name 不合法，同时其余 argv 也不符合任何 production：不存在可选定的 command grammar 来判 `ARGUMENT_ERROR`，dispatcher 必然先得到 `INVALID_COMMAND`，仍与该全序冲突。

这不是测试没写，而是 R1/R2/R13 与 exact error ABI 不能同时满足。修复应把优先级明确拆为 entry/stage-specific 状态机，例如：dispatcher 先判 subcommand presence/name/target contract，成功 exec 后 direct wrapper 才判自身 argv grammar；runtime availability preamble、direct grammar 与 runtime bound-value 的相对顺序也须逐字固定。若坚持全局 `ARGUMENT_ERROR` 遮蔽 `COMMAND_UNAVAILABLE`，就必须让 dispatcher 拥有每个后序 command 的 grammar，这又会破坏 PLAN/requirements 固定的只读 generic dispatcher owner 边界。验收 matrix 应增加上述 mixed-fault case，证明所选顺序而不是只验单故障。

## Important

### I1 — `RUNTIME_INTERNAL` matrix 未固定用 call-shape `TypeError` 穿过 CLI boundary

requirements 第 64、71 行的正文三分法已经一致且可实现：

- CLI argv error -> `ContractError("ARGUMENT_ERROR")` -> exact CLI `CONTRACT ARGUMENT_ERROR`；
- 成功绑定后的 runtime value/type/combination invalid -> `ContractError("ARGUMENT_ERROR")`；
- Python unknown/missing/positional call-shape -> interpreter-native `TypeError`，属于 programmer error；
- CLI boundary 的非 `ContractError` -> exit 30、empty stdout、exact `CONTRACT RUNTIME_INTERNAL`、无 traceback。

第 167 行也分别写到了这四类，但最后一项只要求“注入非 `ContractError`”，没有像 reopen round 1 I1 的通过条件那样固定“至少注入一个 call-shape binding `TypeError`”。实现可以用 `ValueError` 完成 boundary case，同时只在 Python API 单测中观察 `TypeError`，仍未证明最关键的 call-shape exception 不会从 CLI 泄漏 traceback或被误映射为 `ARGUMENT_ERROR`。

应把最后一项收紧为：CLI boundary 至少注入一个由 stable callable 的 unknown/missing/positional call-shape 产生的 binding `TypeError`，并逐字断言 exit 30、stdout empty、stderr `CONTRACT RUNTIME_INTERNAL`、无 traceback；可另加其他 unexpected exception，但不能替代该 case。

## Minor

### M1 — “没有新业务选择”与紧随其后的 numeric supersession 叙述相冲突

第 152 行仍写“本片只迁移已审 ABI，没有需要改变实现方向的新业务选择”，第 155 行则正确记录 design review 后选择了 I-JSON safe-integer supersession。当前 supersession 已有明确 DECISIONS 来源、下游和 fail-closed 处置，因此这不再是来源 blocker；但建议把第 152 行改成“无待用户回答的问题；numeric ABI 由 autopilot 按第 155 行及 DECISIONS 裁定”，避免以后把 observable schema 收窄误读成无 ABI 变化的迁移。

## 上一轮 finding closure

| 上一轮 finding | 本轮结论 | 依据 |
|---|---|---|
| B1 numeric supersession 来源 | **PASS** | `DECISIONS.md:26` 明确以 safe integers 替代原 64-bit JSON number 接受域；requirements frontmatter 第 4 行逐字消费该 supersession，第 75/87/98/155 行落实接受域与 producer 禁止截断/舍入。 |
| B1 downstream/fail-closed | **PASS** | DECISIONS 明确 00b–05 producer/consumer 全部消费新口径，overflow observation 走 schema/trace-unavailable；00a 自身 schema overflow 是 `DESCRIPTOR_SCHEMA_INVALID`，不会 canonicalize 后再舍入。 |
| I1 numeric/surrogate oracle | **PASS** | 第 166 行逐字覆盖四个数值边界、escaped high/low lone surrogate、合法 surrogate pair/raw Unicode，以及 exact canonical bytes/digest。 |
| I1 CLI/bound-value/call-shape semantics | **PASS** | 第 64、71、167 行把 CLI grammar、成功绑定后的值错误与原生 binding `TypeError` 分开，正文不再自相矛盾。 |
| I1 `RUNTIME_INTERNAL` exact boundary oracle | **FAIL（重要）** | exit/channel/无 traceback 已 exact，但 injected exception class 仍未锁定为上一轮要求的 call-shape binding `TypeError`，见 I1。 |

## 完整回归矩阵

| 审计项 | 结论 | 说明 |
|---|---|---|
| R1–R2 dispatcher/CLI | **FAIL** | production、regex、direct recovery 与 parity 均明确；mixed invalid-argv/unavailable-command 的 global priority 不可实现，见 B1。 |
| R3–R4 schema/canonical digest | **PASS** | 六 artifact、两个内部 payload、safe integer、surrogate、sorted/semantic arrays、ASCII closed keys 与 RFC 8785 子域一致。 |
| R5–R9 path/store/ref | **PASS** | state-dir/store/out-ref confinement、forbidden roots、object immutability、lock-before-observation、orphan/uncertain recovery闭合。 |
| R10–R13 verify/parity/errors | **FAIL（随 B1）** | fixture/public/evidence checks与 exact channel 已闭合；R12/R13 的跨层错误优先级冲突阻断。 |
| R14 runtime availability/API | **PASS（验收见 I1）** | marker/module/nine exports、keyword-only API、expected/unexpected carrier 和 recovery ABI 明确；正文可实现。 |
| R15 publish faults | **PASS** | 四 commit-point 状态、temp ownership、dangling-ref 不变量与 design staged flow 一致。 |
| R16 rollback | **PASS** | exact merge -> descendant fixture -> isolated revert topology、mode 与三个旧 harness oracle均固定。 |
| R17 budget | **PASS** | 730/140 inner ceiling 与 800/160 outer ceiling、estimate/actual stop point明确；design high estimate 725。 |
| R18 no-AOSP/YAGNI | **PASS** | 00a 不读取真实 source、不运行 envsetup/lunch/build/sync/download，未拉入 00b–05 实现。 |
| closed schema/API | **PASS** | exact keys/types/nullability/enums/order、complete publisher envelope、typed result 与只读 `StatePaths` 已闭合。 |
| evidence closure | **PASS** | before/after source-state、trace、journal 四引用的 existence/kind/path/content/cross-field、project digest、counts/sequence/public priority均闭合。 |
| error closure | **FAIL** | ref/lock/publish 内部顺序闭合；dispatcher/direct 跨层全序仍冲突，见 B1。 |
| EARS | **PASS** | R1–R18 均为中文 EARS 可识别句式，`check-req.py` exit 0。 |
| 来源/问题预算 | **PASS（M1 文案除外）** | 18 条均为合法 legacy `[计划]`，numeric 选择有 DECISIONS supersession；0/15、0/2 符合 autopilot，无待答问题。 |
| 主命令/清单/不变量 | **FAIL（随 B1/I1）** | 主命令、五项不变量及大部分 matrix 可执行；mixed-fault priority 与 exact call-shape-to-boundary case仍缺。 |
| confirmation=false | **PASS（流程态）** | 不作 finding；但因本轮内容 FAIL，当前不可纯元数据 flip true。 |

## 通过条件

1. 把 dispatcher、direct wrapper、runtime availability、runtime bound-value 的 error priority 拆成可执行的 stage-specific 顺序，并增加 invalid argv + invalid/missing command target 的 mixed-fault oracle。
2. 将 CLI boundary 的 unexpected-exception case逐字固定为至少一个 call-shape binding `TypeError -> RUNTIME_INTERNAL`。
3. 建议同步修正 M1 文案；随后重跑 `check-req.py`、`check-analyze.py`、`git diff --check`，并由全新上下文 reviewer 完整回审。只有内容 PASS 后，`已由用户确认: false` 才可纯元数据翻为 `true` 并运行 `check-criteria.py`。
