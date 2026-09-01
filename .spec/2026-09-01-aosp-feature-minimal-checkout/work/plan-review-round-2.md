# PLAN 独立审查 — Round 2

审查对象：`research/report.md`、`PLAN.md` v2、`config.yml`、`work/plan-review-round-1.md`。

审查方式：以全新 reviewer 上下文逐行核对 report 溯源、上一轮 3 个阻断 / 5 个重要 / 2 个次要 finding 的修复状态，并重新检查 A–E 五维及每片 P1–P5。只审查，未修改 `PLAN.md`。

## 结论摘要

- ① **计划/规格符合性：仍不符合。** v2 已正确把成功范围收窄到公开 AOSP `services`，前置了 environment/seed preflight，并补齐全角色 witness、ClosureKey 全字段 mutation、只读 seed/cache、回滚矩阵与资源排序；上一轮多数结构性问题已经解决。但 03a/03b 仍没有可执行的独立 wrapper 验收契约，且总验收没有“已证明的公开 `services` 经 resolver + Claude/Codex wrapper 成功暴露”的正例，因此 P1、稳定消费接口和总目标闭合仍有 2 个阻断。
- ② **文档质量：不通过。** v2 的范围、术语、失败边界和 review 摘要明显更清楚，`check-plan.py` 退出 0；但“唯一 CLI/cwd”只统一了入口外形，没有写全 workspace、artifact、proof 的输入输出签名。另有 00/02 的非生成 diff 无人审预算、普通 `git revert` 与 immutable artifact 保留关系未落到文件/存储边界、digest 关系存在循环歧义。这些会让后续 spec 在设计前各自补协议，不能直接进入选择。

## 验证记录

- 完整阅读了四份指定材料；同时按规格流程读取了 PLAN 拆分与 review 细则。
- `python3 /home/zzh0838/.agents/skills/spec/scripts/check-plan.py .spec/2026-09-01-aosp-feature-minimal-checkout/PLAN.md`：退出 `0`。
- 当前仓只存在 `common/.harness/bin/{resolve-feature.sh,check-branches.sh,check-parity.sh}`，尚无 `feature-closure` 与相应 fixtures；PLAN 已在 `PLAN.md:23` 明确这些是“全部 spec 完成后”的未来验收契约，因此不把当前 command-not-found 计为 finding。
- 未重复运行 round 1 已记录为 PASS 的现有 harness/parity 套件；v2 只改 PLAN，没有新增实现证据需要复验。

## Round 1 findings 修复核对

| Round 1 finding | Round 2 状态 | 依据 |
|---|---|---|
| B1 `dev-sidebar` 成功目标依赖不存在源码/goal | ✅ 已解决 | `PLAN.md:9,23,41,104-107,161-162` 将本轮成功范围锁定为公开 `services`，并把 `dev-sidebar` 明确定义为 `GOAL_COVERAGE_MISSING` fail-closed 边界，而非虚构 build PASS。 |
| B2 无独立回滚契约 | ⚠️ 部分解决 | `PLAN.md:124-136` 已有版本化产出、缺席行为和 revert 规则；但单一 CLI 后续子命令的文件 owner、普通 revert 是否触碰后序文件、以及 immutable artifact 的外部留存位置未定义，见 I2。 |
| B3 环境是隐含前置，P1/E 不闭合 | ✅ 已解决 | 新增 00，固定 seed/container/product/release/host、资源与断网探针，并允许 `ENV NOT-AVAILABLE` 作为带证据知识产出后回 PLAN；依赖和排序均前移。 |
| I1 CLI/cwd/参数契约不统一 | ⚠️ 部分解决 | `PLAN.md:13-23,70,122` 已统一仓根 cwd 和唯一 CLI；但 03a/03b 没有子命令，workspace/artifact/proof 参数仍缺，见 B1。 |
| I2 P5 无 bounded review artifact | ⚠️ 部分解决 | 01、03a、03b、04、05 已给非生成 diff/摘要上限；00 和核心 extractor 所在的 02 仍未限制非生成实现 diff，见 I3。 |
| I3 B0/B1 无 witness | ✅ 已解决 | `PLAN.md:39,69,77,113-117` 对每个 project 的每个重叠角色均要求角色特定 witness，禁止重分类规避。 |
| I4 ClosureKey 仅变异 `build/make` | ✅ 已解决 | `PLAN.md:27,99` 逐一覆盖 manifest、Repo、host/container、product、release、variant、goals、used-env、extractor 及四类 bootstrap/framework 输入，并含 hit/canonical-order 正例。 |
| I5 共享 seed/cache 可写边界不清 | ✅ 已解决 | `PLAN.md:42,61-63,155-156` 固定 digest-pinned seed、content-addressed object 只读消费、禁止 spec job 维护，并为每个 job 分配独立 workspace/`OUT_DIR`。 |
| M1 report 溯源靠推断 | ✅ 已解决 | `PLAN.md:60,67,75,83,90,97,104,159-164` 给每片来源，并逐条处置两项冲突和未确认项。 |
| M2 角色与 digest 未定义 | ⚠️ 部分解决 | `PLAN.md:109-122` 已定义角色、重叠、消费者和三类 digest；但 `closure.lock.json` 内的 proof 字段与三层 digest 的计算顺序仍有循环歧义，见 I4。 |

结论：上一轮 10 条中 6 条完全解决，4 条仅部分解决；不能认定 v2 已解决全部 findings。

## Findings

### 阻断

#### B1 — 03a/03b 没有独立可执行的验收入口，统一 CLI 仍缺核心 producer/consumer 签名

- **位置：** `PLAN.md:18-19,50-53,76-86,90-93,118-122`。
- **依据：** 03a 的表格判据仍写 fresh workspace 中运行 `m nothing && m services`，而其正文又明确“wrapper 自行完成”且“不把 shell function `m` 暴露为独立验收入口”；PLAN 没有给出该 wrapper 对应的 `feature-closure` 子命令。03b 只写“成功输出 `CLOSURE PROVEN`”，完全没有命令、输入 candidate/probe 的方式或 proof artifact 落点。`extract` 没有 `--out`，`verify-worktree` 只接收 lock 而没有 `--workspace`，`build-repo` 也没有 workspace/`OUT_DIR`/proof 输入；canonical lock 不应靠机器本地绝对路径隐式定位这些状态。于是 02→03a→03b→04 的消费接口不能由下一片仅按 PLAN 执行，03a/03b 不满足 P1。
- **建议：** 为 03a/03b 写死完整命令和稳定签名，例如分别定义 `materialize/probe/prove`（名称可另定）的 `--lock|--candidate`、`--workspace`、`--out-dir`、`--artifact-dir` 参数，成功/失败退出码、stdout 摘要、结构化 artifact 路径和只读约束；`extract` 同样固定输出目录。把 `CLOSURE PROVEN` 或 `verify-proof` 命令纳入整体验收，且让 04 显式消费 proof digest/artifact，而不是靠隐式本地状态。

#### B2 — 总目标缺少公开 `services` 在 harness adapter 上的成功正例，失败边界不能证明成功接入

- **位置：** `PLAN.md:9,20-23,54,104-107,161-162`。
- **依据：** 总目标不仅要证明 repo-unit build，还要把能力接回 Claude/Codex harness。整体验收在 adapter 边界只运行 `resolve-feature ... dev-sidebar` 并期待 `GOAL_COVERAGE_MISSING`；这是正确的 fail-closed 负例，但不能证明一个带 `CLOSURE PROVEN` 的公开 `services` feature 会由 resolver 和两个 wrapper 暴露相同的真实 closure/proof digest、roles、goal 与 capability。05 的“两个客户解析同一 closure digest”既没有具体命令/fixture，也未明确该 digest 来自本轮 03b 的 `services` proof。仅实现旧契约 + `dev-sidebar` 错误码，或让两个 wrapper 同时输出固定占位 digest，都可能通过当前具体总验收，却未达成 `PLAN.md:9` 的成功接入目标。
- **建议：** 增加一个由 03b 真实 proof 驱动的 `aosp17-services` 成功 fixture/feature，写出 resolver、Claude wrapper、Codex wrapper 三条可执行验收；断言三者的 closure/proof digest 与 proof artifact 一致、`closure_status=CLOSURE_PROVEN`、goal=`services`、write project=`frameworks/base`。保留 `dev-sidebar -> GOAL_COVERAGE_MISSING` 作为独立负例。

### 重要

#### I1 — 整体验收没有直接覆盖 candidate → probe → audited proof 的真实闭包链

- **位置：** `PLAN.md:11-23,50-53,76-93`。
- **依据：** 总命令只做 preflight、verify-lock、verify-worktree、build-repo；没有执行 02 的 extract、03a 的 offline probe 或 03b 的 audited supplement/proof。文案虽要求“真实闭包证明”，但当前命令块可以只消费预置的 `closure.lock.json` fixture，无法证明 fixture 是在当前 pinned seed 上经 fresh workspace/`OUT_DIR`、断网、8/64 预算与 clean retry 生成的。各 spec 的独立验收可以补足分片证据，但 B1 表明 03a/03b 目前连独立命令也不存在。
- **建议：** 整体验收要么串起 extract → materialize/probe → prove → verify-proof → build-repo，要么明确引用 CI 产生的 content-addressed proof artifact，并先用独立 `verify-proof` 校验 seed/container/commands/env/log digests 后再执行 build-repo。

#### I2 — P2 矩阵声明了缺席行为，但普通 revert 与 artifact 保留仍不可执行验证

- **位置：** `PLAN.md:68-70,84-100,124-136,154`。
- **依据：** 01 创建唯一 `feature-closure` CLI，02–04 又要增加 extractor/materializer/probe/supplement/repo-unit 子命令；PLAN 只声明 01 与 05 的文件 owner，没有说明 02–04 是否修改 01 的 dispatcher。若多个 merge commit 改同一入口，回滚 01 或中间片可能冲突或删除后序依赖代码。另一方面，02/03b 的行声称回滚 producer 时不删除已发布 digest fixture，而 `git revert` 会删除与该 commit 一同跟踪的 artifact；若 artifact 在外部只读存储，PLAN 没写发布位置、retention 和消费者查找协议。当前矩阵是目标状态，不足以证明表中普通 revert 能得到该状态。
- **建议：** 补逐片实际文件 owner/路径：01 的稳定 dispatcher/ABI 一经发布不再被后片修改，后片只新增独占模块与注册数据；若做不到则合并原子片。明确 generated artifact 不属于 merge commit 的外部 content-addressed store、发布/留存/查找接口，或承认 fixture 会随 revert 删除并把消费者缺席行为纳入回滚命令。每片给出至少一条具体 `git revert <merge> && ...` 预期命令集合，而不是笼统“跑前序与旧 harness”。

#### I3 — 00 与 02 仍未证明 P5：summary 有界不等于全部非生成产出可在一小时内审完

- **位置：** `PLAN.md:58-79`；对照 `PLAN.md:71,86,93,100,107`。
- **依据：** 00 只限制 `ENV NOT-AVAILABLE` 报告 120 行，没有限制 preflight/descriptor 实现 diff；02 只限制机器生成 artifact 的 review summary 200 行，没有限制 graph/actions/includes/manifest mapping extractor 的非生成实现 diff。02 是最核心、最不确定的实现片，代码与测试完全可能远超其他片统一采用的 800 行预算。P5 检查的是“全部产出”，不能仅排除数万行生成数据后省略实现预算。
- **建议：** 为 00、02 同样写不超过 800 行非生成 diff与固定测试摘要上限；超额在 tasks 门沿稳定接口重分。02 若预计超限，可拆成“只读证据采集器”和“project closure/witness 映射 spike”，每片仍需独立知识产出与判据。

#### I4 — `closure.lock.json` 与 proof digest 的归属使三层 digest 计算存在循环歧义

- **位置：** `PLAN.md:68,118-120,130-136`。
- **依据：** 01 说 `closure.lock.json` schema “固定……proof digest”；术语表又说 lock digest 是 canonical `closure.lock.json` 全字段 SHA-256、closure digest 基于 lock digest、proof digest 再基于 closure digest。若 proof digest 是 `closure.lock.json` 的被哈希字段，就形成自引用；若“全字段”实际排除 proof 字段，当前“只排除 proof result”的说法仍不精确。03b 同时产出独立 `proof/v1` artifact，说明 proof digest 更适合属于该 artifact。两个客户端必须解析相同 digest，这个歧义不能留给不同 spec 各自决定。
- **建议：** 明确无环 DAG：例如 `closure.lock.json` 只含 lock 输入并产生 lock digest；audit events + lock digest 产生 closure digest；独立 `proof/v1` 引用 closure digest 并产生 proof digest。逐层写 canonical byte representation、字段排除表、排序、hash 拼接/domain separator 和空 audit event 规则。

### 次要

本轮无独立次要 finding；文案层的小问题已被上述接口/digest finding 包含，不另行重复计数。

## 五维审查结果

### A — 溯源

- 每片均有 report 行级来源；report 的两项冲突和四项未确认均在 `PLAN.md:159-164` 有处置。
- 公开 `services`、repo-unit 不替代 integration、图覆盖需要 clean proof、baseline 不可硬编码等主结论均有对应 spec 和不变量。
- A 维通过；未发现把 `[推断]` 写成已确认事实。

### B — P1–P5

| spec | P1 独立验收 | P2 独立回滚 | P3 独立产出 | P4 ≤15 | P5 <1h |
|---|---|---|---|---|---|
| 00 | ✅ `ENV PASS` 或分类 NOT-AVAILABLE 都可独立增加知识 | ⚠️ 有缺席行为，但 CLI/file owner 仍见 I2 | ✅ immutable seed/preflight 结论 | ✅ `question_budget: 15`，未见超额必需问题 | ❌ PASS 路径的实现 diff 无预算 |
| 01 | ✅ validator 正负 fixture 具体 | ⚠️ 版本/缺席语义已有，普通 revert 边界仍见 I2 | ✅ schema、validator、fixtures | ✅ | ✅ 800 + 160 行上限 |
| 02 | ⚠️ 命令存在，但输出目录/消费签名隐式 | ⚠️ artifact 留存与 extractor owner 见 I2 | ✅ viable candidate 或带证据 NOT-VIABLE | ✅ | ❌ 仅生成物 summary 有界，extractor diff 无上限 |
| 03a | ❌ 正文要求 wrapper，表格却只给 raw `m`，无子命令 | ⚠️ 声明 absent 行为，未落文件边界 | ✅ materialized probe 或结构化 missing-input 知识 | ✅ | ✅ 800 + 160 行上限 |
| 03b | ❌ 无任何可执行 prove 命令 | ⚠️ proof artifact 留存位置不明 | ✅ proven closure 或有界 fail-closed 证据 | ✅ | ✅ 800 + 200 行上限 |
| 04 | ⚠️ 总命令补了 CLI 路径，但 workspace/proof 输入隐式 | ⚠️ executor owner/dispatcher 见 I2 | ✅ 单一可写 repo-unit 与 cache isolation | ✅ | ✅ 800 + 160 行上限 |
| 05 | ❌ 缺公开 `services` adapter 成功正例 | ✅ 末片 optional adapter 可恢复旧行为 | ✅ 可选 harness capability | ✅ | ✅ 800 + 160 行上限 |

P3 全部成立，P4 配置上限为 15 且未发现某片必然需要更多问题；但 P1、P2、P5 尚未全满足，因此 B 维失败。

### C — 依赖、接口与资源

- 依赖图为严格线性链，无环，表格与文本一致；00 前置环境单点失败正确。
- B0/B1/F/D witness、角色重叠和 ClosureKey 消费方向已清楚。
- 资源边界已覆盖只读 seed/object cache、独立 workspace/`OUT_DIR`、磁盘/CPU 串行，符合实现类不并行。
- 但 02→03a→03b→04 的 artifact/workspace/proof 签名和 CLI subcommand 不完整，回滚文件 owner 也未闭合，故 C 维失败。

### D — 总目标闭合

- 00→04 能形成“环境 → lock → candidate → clean proof → 单仓 build”的非简单加总链，结构方向正确。
- `dev-sidebar` 明确只验 fail-closed，不再与公开成功范围矛盾。
- 但总命令没有直接证明 audited closure 链，05 也没有公开 `services` 的 adapter 成功正例；因此“真实 proof 已接回两客户端”的必要能力可缺失而具体命令仍通过，D 维失败。

### E — 风险排序

- 00 先验证环境/seed，02 紧接着验证图到 project closure 的核心假设，03a 再做最小 probe，03b 才投入有界补仓；环境与技术单点失败均排在昂贵集成之前。
- 所有 NOT-AVAILABLE/NOT-VIABLE/fail-closed 分支都要求回 PLAN 复盘，未把知识性失败冒充总目标成功。
- E 维通过。

## 文档质量抽查

- 统一 CLI 路径和 cwd 的文字已清楚，且明确命令属于未来最终验收，不再误导为现有能力。
- `dev-sidebar` 的 fail-closed 边界清楚：真实源码/native goal 缺失只允许 `GOAL_COVERAGE_MISSING`，不会回退到全树或声称 integration PASS。
- witness、只读 seed/cache、review summary、角色重叠和资源串行均比 v1 明确。
- 主要质量问题集中在“接口名有了但完整签名没有”“负例有了但成功 adapter 正例没有”“digest 名称有了但无环计算没有”；这些是承重协议，不是可留到措辞润色的细节。

## 最小修订顺序

1. 先补 03a/03b 完整 CLI、workspace/`OUT_DIR`、artifact/proof 签名，并把真实 proof 验证纳入整体验收。
2. 给 05 增加公开 `aosp17-services` 的 resolver + Claude/Codex wrapper 成功正例，同时保留 `dev-sidebar` 失败负例。
3. 固定单一 CLI 的 dispatcher/file owner 和 content-addressed artifact 留存协议，使普通 revert 可实际验证。
4. 给 00/02 补非生成 diff 预算；明确三层 digest 的无环 artifact DAG 与 canonical hash 规则。

VERDICT: FAIL
