# PLAN 独立审查 — Round 1

审查对象：`research/report.md`、`PLAN.md`、`config.yml`

审查方式：逐行核对 report → spec 溯源、P1–P5、依赖/稳定接口/资源、总目标闭合、风险排序，并在当前仓库中实测可运行命令与入口是否存在。未修改 `PLAN.md`。

## 结论摘要

- ① **计划/规格符合性：不符合。** 主体方向正确，五片形成“契约 → 风险 spike → 缩减证明 → 单仓 job → feature 集成”的非简单加总链，依赖图无环，02 也明确瞄准核心技术假设；但当前版本存在 3 个阻断项：已知不存在的真实 `dev-sidebar` 源码/goal 使总验收不可达；没有任何独立回滚契约；真实 AOSP seed、host/container 和离线构建能力是未建模的外部前置，导致 02/03 不能独立验收。
- ② **文档质量：不通过。** 文档简洁、层次清楚，report 遗留项基本都有文字处置，`check-plan.py` 也通过；但验收命令的根目录、CLI 安装位置、环境初始化和成功摘要生产者不明确，稳定接口只定义了 `verify-lock` 一条，且大体积生成物没有受控的人审摘要。当前不足以交给人拍板后直接进入 spec 选择。

## 验证记录

- `python3 /home/zzh0838/.agents/skills/spec/scripts/check-plan.py PLAN.md`：退出 `0`。
- 从仓库根运行 `./common/tests/test-harness.sh`：退出 `0`，输出 `RESULT PASS  shared Harness regression suite`。
- 从仓库根运行 `./common/.harness/bin/check-parity.sh`：退出 `0`，输出 `PARITY PASS  Claude/Codex 共享同一公共契约`。
- `command -v feature-closure`：无结果；当前不存在该 CLI。
- 当前不存在根目录 `.harness/features/dev-sidebar/closure.lock.json`，也不存在 `common/.harness/features/dev-sidebar/closure.lock.json`。这与“所有 spec 均未开始”相容，不单独算成虚假现有能力；但 PLAN 没有定义未来 CLI 的可执行文件路径和 lock 的唯一落盘位置，见 I1。

## Findings

### 阻断

#### B1 — 总验收依赖已知不存在且本计划不产出的真实 `dev-sidebar` 源码/goal，目标不可达

- **位置：** `PLAN.md:8`、`PLAN.md:18-21`、`PLAN.md:35`、`PLAN.md:39`、`PLAN.md:50`、`PLAN.md:84-87`、`PLAN.md:109-110`；依据 `research/report.md:15`、`research/report.md:19-20`、`research/report.md:24-25`。
- **依据：** report 已明确 demo 没有真实 SidebarApp、SidebarFlinger、SidebarService 源码，真实 module/project 映射也未知；PLAN 又把范围限定为公开 AOSP/Cuttlefish，不包含取得或创建这些 feature 源码的 spec。05 一方面要求映射缺失时 `GOAL_COVERAGE_MISSING` fail closed，另一方面其独立判据及整体验收要求 `FEATURE BUILD PASS dev-sidebar`。在当前已知输入下，两者不能同时满足。它不是“执行时可能遇到的风险”，而是计划内没有生产者的必要输入。
- **建议：** 二选一并写死：
  1. 将本轮总目标收窄为公开 AOSP `services` 的真实 closure/repo-unit/integration 原型，05 只集成这一已存在目标；完整 `dev-sidebar` 五仓 build/device gate 另立一轮、以真实源码仓和 goal 已可用为前置；或
  2. 在 05 前新增独立 spec，明确取得/创建最小真实 Sidebar 源码、manifest project、module goal 和设备行为 fixture 的来源与验收。若依赖企业私有仓，必须把它列为显式外部输入及 preflight，不得继续声称仅覆盖公开 AOSP。

#### B2 — 线性依赖和串行执行没有满足 P2；回滚任一前序片会破坏已合入消费者

- **位置：** `PLAN.md:46-50`、`PLAN.md:56-80`、`PLAN.md:84-87`、`PLAN.md:92-105`。
- **依据：** 01 产出的 schema/CLI 被 02–05 消费；02 产出的 lock/closure 被 03 消费；03 的 proof/工作区能力被 04 消费；04 的 job 被 05 编排。PLAN 没有版本化接口、文件 owner、dependency-absent 行为、兼容窗口或独立回滚命令。`PLAN.md:103-105` 只说明用串行规避修改冲突，不能证明“回滚它不牵连已合入的其他 spec”。尤其 01 与 05 还会叠改同一个 resolver/公共回归，撤销 01 后 05 不可能保持可运行。
- **建议：** 增加逐 spec 的“独占文件/稳定产出签名/消费者缺席行为/独立回滚命令”矩阵。可行模式包括：01 发布带版本 marker 的稳定 CLI；后续仅新增独占模块并在依赖缺席时静默回退旧 harness；生成的 lock/proof 作为 immutable versioned artifact，不随生产者回滚消失。若某两片无法做到这种独立回滚，应合并为一个原子 spec，而不是仅靠依赖串行。

#### B3 — 02/03 把未确认的 AOSP 基础设施当成隐含前置，P1 与 E 都未闭合

- **位置：** `PLAN.md:47-48`、`PLAN.md:63-66`、`PLAN.md:70-73`、`PLAN.md:99`、`PLAN.md:104`、`PLAN.md:109`、`PLAN.md:112`；依据 `research/report.md:24-27`。
- **依据：** 02 假定已有 canonical full AOSP 17 tree、Repo、可用 manifest/mirror、匹配 host/container 和足够磁盘；03 又假定能创建 fresh checkout、fresh `OUT_DIR` 并在真实断网约束下构建。report 明确这些均未确认。PLAN 没有 seed 获取/校验步骤、容量与工具 preflight、容器镜像 digest、网络隔离证明方式，也没有规定“基础设施缺失”时的可验收产出；02 的 NOT-VIABLE 只覆盖图不能生成候选集。因此验收动作仍要等待计划外环境，违反 P1。并且环境可用性比图抽取更早成为单点失败，E 的风险排序也不完整。
- **建议：** 在 01 前增加极小的 environment/seed preflight spike，独立产出 pinned seed descriptor（manifest SHA、Repo SHA、container digest、host arch、磁盘预算、mirror/source URL、网络隔离探针）以及 `ENV PASS` 或分类明确的 `ENV NOT-AVAILABLE` 报告；或者把完全等价的自举与 preflight 纳入 02 的可执行入口。只有 preflight 通过才开展 schema 完整实现和 graph spike。

### 重要

#### I1 — 验收命令没有统一的工作目录、入口和参数契约，当前命令块不可复现

- **位置：** `PLAN.md:10-21`、`PLAN.md:46-50`、`PLAN.md:59`、`PLAN.md:63-64`、`PLAN.md:71`。
- **依据：** 前两条命令只能按当前文档自然理解从 demo 仓根运行；同一代码块后四条却引用根下不存在的 `.harness/...`，而现有 canonical harness 位于 `common/.harness/...`。表中 04/05 使用裸 `build-repo`/`build-feature`，整体验收使用 `feature-closure build-repo`/`build-feature`。01 只承诺 `verify-lock` 的接口，没有定义 CLI 最终安装路径、`extract`/`verify-worktree`/`build-*` 的完整签名。原始 `m` 是 source `build/envsetup.sh` 并 `lunch` 后的 shell 函数，不是 fresh shell 可直接执行的命令；`m nothing && m services` 本身也不会产生 PLAN 要求的 `CLOSURE PROVEN` 摘要。
- **建议：** 所有验收统一为一个从仓库根可运行的显式入口，例如 `./common/.harness/bin/feature-closure ...`，并逐条定义 cwd、必需参数、输入路径、退出码、stdout 摘要与 artifact 路径。由 wrapper 完成 envsetup/lunch、fresh `OUT_DIR`、网络隔离及摘要输出；不要把 shell 函数当独立验收入口。另加“实现前预期 command-not-found / 实现后预期 PASS”的说明，避免把未来能力读成现有能力。

#### I2 — 02、03、05 的“全部产出”缺少人审上限，P5 `<1 小时` 未被证明

- **位置：** `PLAN.md:37-38`、`PLAN.md:47-50`、`PLAN.md:61-87`。
- **依据：** 02 可生成包含大量 project/witness/action/include 的 lock、XML 和原始报告；03 最多 8 轮/64 project，并保留每轮日志 digest/audit event；05 同时改 resolver、两套 wrapper、五仓 goal coverage、repo-unit 编排、集成构建和 device verifier。PLAN 没有 diff/文件/行数预算，也没有规定机器校验后的 bounded review manifest。要求人审全部原始 closure、日志和跨组件 diff，很可能超过一小时。
- **建议：** 每片写明可审 artifact：固定字段的 summary、项目/角色/失败类别计数、随机抽样 witness、digest 到原始日志的索引；原始海量数据由 schema/一致性测试验，不要求逐行人审。给每片设置代码与 review 文档预算；若 03 或 05 超预算，沿稳定 CLI 拆成“materialize+offline probe / audited supplement proof”和“contract integration / real build+device gate”两片，每片仍需端到端独立判据。

#### I3 — B0/B1 被排除在 witness 要求之外，可能用角色重分类绕过“底座不可硬编码”的 report 结论

- **位置：** `PLAN.md:37`、`PLAN.md:47`、`PLAN.md:57`、`PLAN.md:64-65`、`PLAN.md:70`；依据 `research/report.md:11`。
- **依据：** PLAN 只要求“每个非底座 project”有 witness，02 的判据也只检查非底座 project。report 恰恰指出 bootstrap/product baseline 会随 revision、host、product 和 module 类型变化，不能永久硬编码。实现若把多余项目标成 B0/B1，就可在没有路径/include/tool 边的情况下通过当前判据，既不能证明 closure 的来源，也不能审计最小性。
- **建议：** 对每个 project 都要求角色特定 witness：B0 为 bootstrap/tool/action 输入链，B1 为 product/release/include 链，F 为 feature intent/mutable 映射，D 为 module/path/action 依赖链。validator 应拒绝无 witness 的任何角色，并有“把 D 伪标成 B0/B1”负 fixture。

#### I4 — 完整 ClosureKey 是总不变量，但验收只变异 `build/make`，可让不完整 cache key 误通过

- **位置：** `PLAN.md:25`、`PLAN.md:30`、`PLAN.md:49`、`PLAN.md:57`、`PLAN.md:80`。
- **依据：** 总不变量要求 manifest SHA、Repo、host/container、product、release config、variant、goals、used environment、extractor 版本任一变化都 cache miss，并额外点名 build/soong/blueprint/bootstrap prebuilt。04 的独立判据仅检查修改 `build/make` 返回 `CACHE_MISS_FRAMEWORK_CHANGED`。只把 `build/make` SHA 放进 key、漏掉其余维度的实现仍可通过。
- **建议：** 在 01 或 04 加表驱动 mutation matrix，对每个 ClosureKey 字段和四类 framework/bootstrap 输入逐一变异并断言 cache miss；同时有“完全相同 key 命中”和字段规范化/顺序不影响 digest 的正例。

#### I5 — “共享 seed/mirror/cache”与“不共享可写状态”的资源约束没有可执行边界

- **位置：** `PLAN.md:40`、`PLAN.md:104-105`；依据 `research/report.md:27`。
- **依据：** 全局约束说 seed、mirror/cache 和 workspace 不与其他任务共享可写状态，资源节又说 02–04 共用同一 seed、Repo mirror/cache。串行只能消除同时写，不能防止上一片更新 mirror/cache 或 seed 后让下一片基线漂移，也没有说明 mirror 是只读快照、带锁服务还是允许维护。
- **建议：** 将 canonical seed 明确为只读且以 manifest/container digest 校验；mirror/cache 规定为 content-addressed 只读消费，维护动作移出 spec，或给出锁与 mutation audit；每片仅拥有独立 workspace/`OUT_DIR`。把这些写成 preflight 和验收断言，而非调度说明。

### 次要

#### M1 — spec 到 report 的溯源目前靠读者推断，缺少可机械检查的映射

- **位置：** `PLAN.md:42-87`、`PLAN.md:107-112`。
- **依据：** 实际抽查能建立对应关系，但每片没有标注 report 行/结论 ID；后续 report 更新或 PLAN 复盘时难以发现孤儿需求和漏处置。
- **建议：** 在 spec 表增加“report 依据”列，或在每个 spec 小节列 `来源：report.md:...`。为 report 的两项冲突和四项未确认逐条标注处置 spec/验收结果。

#### M2 — B0/B1/F/D、proof digest、closure digest 的边界没有在 PLAN 内定义

- **位置：** `PLAN.md:21`、`PLAN.md:37`、`PLAN.md:47`、`PLAN.md:57`、`PLAN.md:65`、`PLAN.md:84`。
- **依据：** 这些术语承担跨 spec 稳定接口，但 PLAN 未说明 F 是否仅 mutable project、baseline 与 dependency 重叠时如何定角色、proof digest 覆盖哪些 artifact、closure digest 与 lock digest 是否相同。不同 spec 可各自作出不同解释。
- **建议：** 加一个短的“术语与 digest 覆盖面”表，写明角色互斥/优先级、canonical serialization、各 digest 的输入集合和消费者。

## 五维审查结果

### A — 溯源与遗留项

- 01 可追溯到 report 的当前 harness 缺少版本锁/结构化契约；02、03 可追溯到“完整种子树预计算 + clean reduced build + 有界补仓”；04 可追溯到 repo-unit 单一可写仓；05 可追溯到 integration 不可被单编取代。主线溯源成立。
- product/release/host、图覆盖、mirror/RBE/overlay 均有文字处置；但真实 Sidebar 源码/goal 只被定义为 fail closed，没有成为能达成总目标的输入生产者，构成 B1；基础设施遗留项只说“不改变 lock/可回退”，没有可执行 preflight，构成 B3。

### B — P1–P5

| spec | P1 独立验收 | P2 独立回滚 | P3 独立产出 | P4 ≤15 | P5 <1h |
|---|---|---|---|---|---|
| 01 | ⚠️ 判据具体，但 CLI 路径/fixture 路径未固定 | ❌ 后序均直接消费，未定义版本/缺席行为 | ✅ schema、validator、稳定校验入口 | ✅ `config.yml:15` 设 15；未见必须超过预算的问题 | ⚠️ 未给文件/diff 预算，但单片尚可能控制 |
| 02 | ❌ 依赖计划外 seed/host/mirror；NOT-VIABLE 不覆盖环境缺失 | ❌ 03 消费其 lock/closure，无回滚契约 | ✅ PASS 或带证据 NOT-VIABLE 都增加知识 | ✅ 同上 | ❌ 全量 graph/witness/report 无 bounded review artifact |
| 03 | ❌ raw `m` 不是独立入口，离线/fresh 环境无自举与探针 | ❌ 04 消费 proof/工作区能力 | ✅ reduced closure 与 proof | ✅ 同上 | ❌ materializer、离线隔离、8/64 补仓状态机和审计合片过大且无预算 |
| 04 | ⚠️ 主正例具体，但 cache-key 负例覆盖不足 | ❌ 05 编排其 job，未定义撤销后的行为 | ✅ repo-unit build 能力 | ✅ 同上 | ⚠️ 需要 scope 预算；当前仍可能通过拆 task 控制 |
| 05 | ❌ 已知源码/goal 缺失时只能 fail closed，却要求最终 PASS | ✅ 作为末片不存在已合入后序消费者，但仍需说明撤销恢复旧契约 | ✅ 若输入存在则交付集成 gate | ✅ 同上 | ❌ 两 wrapper + resolver + 五仓 coverage + integration/device gate 未受控 |

P4 的 `question_budget: 15` 配置有效，`route.py` 能正常解析；但它只是 requirements 阶段的程序性上限，不能弥补 B1/B3 的外部输入缺口。

### C — 依赖、接口与资源

- 表格和文本图均为 `01 → 02 → 03 → 04 → 05`，无环，排序一致。
- 逻辑消费链方向正确，但只有 `verify-lock` 写成稳定接口；其余 producer/consumer 签名、路径、版本和 absent 行为缺失，见 B2/I1/M2。
- 已识别 resolver 同文件冲突和 AOSP 磁盘/seed 冲突，串行策略符合“实现类不并行”；但共享 mirror/cache 的可写性和漂移控制不清，见 I5。

### D — 总目标一致性

- 五片不是收益简单相加：01 的契约是 02 的输入，02 的候选闭包由 03 真实证明，04 在证明上建立单一可写仓，05 再恢复跨仓集成与 verifier，形成端到端能力链。
- 但完整链的最后必要输入没有生产者，因此“结构上相连”尚未等于“能达成总目标”，见 B1。02 的 NOT-VIABLE 分支作为知识产出合法，但应明确它完成该 spec 后会使当前 PLAN 作废/回调研，而不是把 NOT-VIABLE 与项目总目标成功混在同一状态。

### E — 风险排序

- 02 明确优先验证“图能否生成可审计闭包”的技术单点失败，且失败即复盘；这个判断正确。
- 但 02 前先完整实现 01 的 schema/validator/CLI，且没有先验证 seed/host/mirror/离线隔离是否可用。当前最大、最早的不确定性是“实验环境是否存在并可复现”，其次才是 graph coverage；B3 的 preflight 应前移，随后用最薄契约做 02 spike，再固化完整 contract。

## 文档质量抽查

- 抽查 1：report `:7` 的“当前 harness 不下载源码、不求闭包”被 PLAN 01–03 覆盖，来源与计划一致。
- 抽查 2：report `:13` 的“repo-unit 不替代 integration”被 PLAN 04–05 及整体不变量覆盖，来源与计划一致。
- 抽查 3：report `:15` 的“先 services、不能把 5 仓当证明答案”被 `PLAN.md:39` 和 02–03 覆盖；但同一 report 的“真实业务源码不存在”没有被最终 PASS 路径闭合，故形成 B1。
- 未发现 `[推断]` 被混入 PLAN 结论；PLAN 以未来时态描述要新增的能力，未直接宣称 `feature-closure` 已存在。问题在于验收代码块没有标出这是“全部实现后的命令”，也没有定义由哪个 spec 在何处安装它。
- `config.yml` 的 review 四档均为 `both`，`fix_loop_max=3`、worktree 隔离、15 问/2 轮均可被路由解析；与本轮“先独立 agent review，再人审”的流程一致。

## 建议的最小修订顺序

1. 先裁定 B1：本轮只证明公开 `services`，还是显式引入真实 Sidebar 源码输入。
2. 增加或前移 environment/seed preflight，固定自举与不可用结果。
3. 重新切片并补独立回滚矩阵、文件 owner、version/absent 契约；不能回滚的相邻片合并。
4. 统一所有 CLI 路径与签名，补 ClosureKey 全字段 mutation matrix、所有角色 witness。
5. 给 02/03/05 增加 bounded review artifact 和人审预算，必要时沿稳定接口再拆片。

VERDICT: FAIL
