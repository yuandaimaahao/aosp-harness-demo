# 00a requirements reopen review — round 1

结论：**FAIL**

- 规格符合性：**FAIL**。design B1 选择的 RFC 8785/I-JSON safe-integer + lone-surrogate 拒绝方案本身可实现，design B4 的 CLI grammar / 成功绑定后的 runtime value / Python call-shape 三分法也已消除原自相矛盾；但 safe-integer 方案把已由 `DECISIONS.md` 和被本片声明消费的原 R1–R27 固定的 signed/unsigned-64 JSON ABI 静默收窄，尚无 supersession 决策，因此不能称为“不改变既定 ABI 的迁移”。
- 需求质量：**FAIL**。closed schema、runtime/publisher API、lock/ref/error priority、success/evidence closure、rollback、预算与 R1–R18 主体均已闭合；但本次重开的两个承重点没有进入逐字可勾的验收 oracle，尤其 Python call-shape 与 bound-value 的不同错误载体目前只能从正文推断测试意图。
- findings：**1 blocker / 1 important / 0 minor**。blocker 必须先裁定并同步上游口径，再由全新 reviewer 回审；important 应同步补齐。
- 机械检查：`check-req.py` exit 0，`check-analyze.py` exit 0，`git diff --check` exit 0。`check-criteria.py` 对当前文件 exit 2 的唯一原因是 frontmatter `已由用户确认: false`；这是等待本回归 review 的正确状态，不是 finding。使用不落盘的只读替换流把该字段视为 `true` 时，`check-criteria.py` exit 0。
- 审查边界：完整阅读 PLAN v6、DECISIONS、当前 requirements/design、design round 1、requirements round 1–3、ledger、STATE/config/research report；未修改 requirements/design 草稿，未执行 AOSP envsetup/lunch/build/sync/download/fetch/clone，也未读取 LK7K AOSP tree。

## Blocker

### B1 — safe-integer 修订可实现，但未经授权地收窄了已固定的 64-bit ABI

当前 requirements 第 75、87、98 行把所有 unsigned integer 限为 `0..2^53-1`，把 trace `result`/`dirfd` 限为 `-(2^53-1)..2^53-1`。这确实关闭了 design round 1 B1 的实现矛盾：在 closed schema 的 ASCII object keys、无 float、无 lone surrogate 和 safe integer 域上，Python `json.dumps(ensure_ascii=False, sort_keys=True, separators=(",", ":"))` 可产生本设计所需的 RFC 8785 bytes；escaped lone surrogate 也被明确归入 schema rejection，合法 surrogate pair/Unicode string 可以继续 canonicalize。

问题是该选择不是无 ABI 变化的修复：

- `DECISIONS.md:21` 仍逐字固定“trace result/dirfd 为 signed-64”。
- requirements frontmatter 第 4 行声明消费原 `2026-09-01-00-environment-seed-preflight` 的 R1–R27 owner 合同；该原 requirements 第 80、84、105 行固定 threshold 允许到 unsigned-64、普通 integer 为 `0..2^64-1`、trace result/dirfd 为 signed-64。
- 当前 requirements 第 16 行又把 `DECISIONS.md` 声明为上游口径，第 152 行称“本片只迁移已审 ABI，没有需要改变实现方向的新业务选择”。实际却会让原本合法的 `2^53` 以上 resource/count/mode/sequence 值以及 full signed-64 trace 值改为 `DESCRIPTOR_SCHEMA_INVALID`。

因此当前 `[计划]` 来源和“0 questions”结论不能支持这一具体数值域选择。它还会让 00b 按 DECISIONS/原 ABI 产出的 payload 被 00a 拒绝，正是本片作为唯一 schema owner 必须避免的 producer/consumer 分叉。

通过条件必须明确选定并记录一个 supersession，而不能只改 canonicalizer 文案：

1. 若接受 safe-integer ABI：在 `DECISIONS.md` 明确它 supersede 原 signed/unsigned-64 数值域，并同步原 R27/00b consumer 口径及迁移代价；或
2. 若必须保留完整 64-bit 值域：把超 safe-range 的承重值改为规范十进制 string 等可由 RFC 8785 无损承载的 closed schema，并重新审 schema/digest bytes。

两条都会改变 observable schema 接受集合；在上游口径完成裁定前，不能把当前稿纯元数据翻为 confirmed。

## Important

### I1 — B1/B4 修订缺少逐字验收矩阵，正文合同可能无测试地回归

验收清单第 163–167 行只笼统写 `type/boundary` 和 dispatcher/direct parity，没有逐字要求本次重开的关键分界：

- numeric/JCS：`2^53-1`、`2^53`、`-(2^53-1)`、`-2^53`，以及 escaped high/low lone surrogate、合法 surrogate pair、raw Unicode 的 exact accept/reject 与 canonical bytes/digest；
- CLI grammar：unknown/missing/repeated/reordered/positional option 必须是 `ContractError(ARGUMENT_ERROR)` 对应的 exact CLI contract；
- stable Python API：成功绑定后 value/type/combination invalid 必须是 `ContractError("ARGUMENT_ERROR")`，unknown keyword/missing keyword/positional call-shape 必须由解释器原生抛 `TypeError`；
- CLI boundary：非 `ContractError`（至少注入一个 call-shape `TypeError`）必须被消毒为 exit 30、空 stdout、stderr exact `CONTRACT RUNTIME_INTERNAL`，不得泄漏 traceback。

当前 requirements 第 64、71 行的三分法本身**PASS 且可实现**：CLI parser 在调用 runtime 前处理 argv；keyword-only callable 只在绑定成功后自行校验 value/combination 并抛 `ContractError(ARGUMENT_ERROR)`；绑定失败保留原生 `TypeError`，wrapper 对非 expected exception 走 generic `RUNTIME_INTERNAL`。缺口是“什么算做完”没有要求证明这些 observable 分支。应把上述四组 oracle 加入验收清单或一个命名 case，避免任务实现只覆盖普通 schema mutation 后仍宣称 B4 已验。

## 回归矩阵

| 审计项 | 结论 | 说明 |
|---|---|---|
| design B1 可实现性 | **PASS** | safe integer + reject lone surrogate + ASCII closed keys 使 stdlib canonicalizer 子域可与 RFC 8785 对齐；不存在原 uint64 数字序列化矛盾。 |
| design B1 ABI 保持 | **FAIL** | 当前 safe range 拒绝 DECISIONS/原 R1–R27 允许的 signed/unsigned-64 值，且没有 supersession 记录。 |
| design B4 合同一致性 | **PASS** | CLI argv、绑定后的 runtime value、Python binding `TypeError` 与 `ContractError`/`RUNTIME_INTERNAL` 已形成唯一可实现解释。 |
| design B4 可验收性 | **FAIL（重要）** | 清单未逐字覆盖 call-shape/bound-value/boundary mapping。 |
| closed schema | **PASS（除 B1 数值域来源）** | 六 artifact、两个内部 digest payload、leaf/nullability/order/request reconstruction 与 success invariants 均闭合。 |
| publisher/runtime API | **PASS** | complete artifact envelope、kind/domain dispatch、object-only publish、keyword-only signatures、typed result 与 pre-write validation 已唯一。 |
| ref/path/error ABI | **PASS** | lock-before-observation、invalid lock leaf、missing/corrupt ref/object、public predicate 与 publish stages 有 exact code/order。 |
| evidence closure | **PASS** | 四 object existence/kind/path/content/cross-field、project/trace/journal relations与 public priority均已固定。 |
| R1–R18 覆盖 | **PASS** | 每条 R 均有组件/判据承接；B1 是上游合同冲突，不是 R 编号缺失。 |
| EARS | **PASS** | R1–R18 均满足中文 EARS 模板；机械检查通过。 |
| 来源/问题预算 | **FAIL（随 B1）** | legacy `[计划]` 形式合法，但 safe-integer 具体选择不在 PLAN/DECISIONS，且与 DECISIONS 冲突，不能计为“0 个新选择”。 |
| YAGNI/范围 | **PASS** | 未把 00b 的真实环境采集或 01–05 closure/build 能力拉入 00a；R18/no-AOSP 边界保持。 |
| 主命令/清单/不变量 | **部分 PASS** | 主命令、五个不变量、public/ref/fault/rollback oracle 可执行；缺本次 B1/B4 的 exact regression case，见 I1。 |
| confirmation=false | **PASS（流程态）** | 正确等待本轮内容 review；不作为 finding。因本轮内容 FAIL，目前不可纯元数据翻 true。 |

## 前三轮 finding closure

- requirements round 1–3 的 CLI 两个 production、runtime marker/exports、object-only publisher、full envelope、closed leaves、semantic arrays、store root、forbidden roots、lock leaf/error order、public success/evidence closure、rollback topology、730/140 budget、temp ownership等 finding，本轮均复核为已关闭。
- design round 1 的 B2/B3 与 I1–I6/M1 已在当前 design 中逐字接口、wrapper architecture、lock-first publish、`MappingProxyType`、九个 domain、exact state machine、rollback topology、725-line allocation和 executable mode中得到承接；它们没有反向暴露新的 requirements 缺口。
- design round 1 B1 的“不可实现”已技术关闭，但上游 ABI 保持未关闭，形成上述 B1；B4 的正文冲突已关闭，但验收闭环未关闭，形成上述 I1。

## 通过条件

1. 对 safe-integer 与原 signed/unsigned-64 ABI 的关系作显式 supersession 裁定并同步 `DECISIONS.md`/下游口径，或改用保留完整值域的 string schema。
2. 在验收清单增加 numeric/surrogate 与 CLI/bound-value/call-shape/`RUNTIME_INTERNAL` 的 exact matrix。
3. 重新运行 `check-req.py`、`check-analyze.py`、`git diff --check`，并由全新上下文 reviewer 完整回审；内容 PASS 后，`已由用户确认: false` 才可作为纯流程元数据翻为 `true` 并运行 `check-criteria.py`。

