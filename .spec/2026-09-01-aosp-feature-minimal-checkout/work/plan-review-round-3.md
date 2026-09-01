# PLAN 独立审查 — Round 3

审查对象：`research/report.md`、`PLAN.md` v3、`config.yml`、`work/plan-review-round-1.md`、`work/plan-review-round-2.md`。

审查方式：先逐条核验 Round 2 的 2 个阻断与 4 个重要 finding，再独立重做 A 溯源、B 每片 P1–P5、C 依赖/接口/资源、D 总目标闭合、E 风险排序。只审查，未修改 `PLAN.md`。

## 结论摘要

- ① **计划/规格符合性：仍不符合。** v3 已补出 candidate→materialize→probe→prove→verify-proof→repo-unit 命令链，加入 `aosp17-services` 的 resolver/Claude/Codex 成功正例，保留 `dev-sidebar` 的 fail-closed 负例，并补了 00/02 人审预算与 command owner。但 closure digest 与 audit event 仍自引用；同时在 `isolation: worktree` 下，相对当前工作树的 `.cache/aosp-harness/` 没有成为 03b→04→05 可持久的项目级 artifact/ref 交接点。这两项使承重证明主键无法规范计算，且后续 spec 不能保证消费前序的真实 proof。
- ② **文档质量：不通过。** PLAN 的范围、溯源、命令名、参数、owner、预算和失败边界已接近可交接状态，`check-plan.py` 也通过；但预期分支的退出码/是否产生 ref 未写死，“只读 store”与 producer 发布新 artifact 的语义不一致，回滚 00 后也无法通过 dispatcher 执行后序已合入 command 的缺席契约。这些是承重协议，不是可留到 design 任意选择的措辞细节。

## 验证记录

- 完整阅读五份指定材料，并按 spec 路由读取 `references/02-decompose.md` 与 `references/07-review.md`。
- `python3 /home/zzh0838/.agents/skills/spec/scripts/check-plan.py .spec/2026-09-01-aosp-feature-minimal-checkout/PLAN.md`：退出 `0`。
- 核对当前仓库入口：`resolve-feature.sh` 当前只接收 `--client/--contract`，Claude/Codex wrapper 当前只处理 `--dry-run/--contract`；v3 明确新参数是 05 将实现的未来契约，故不把当前 unknown option 计为 finding。
- 未重跑 Round 1 已记录 PASS 的现有 harness/parity 回归；v3 只有计划改动，没有新增实现证据。

## Round 2 findings 修复核对

| Round 2 finding | Round 3 状态 | 依据 |
|---|---|---|
| B1 03a/03b 无独立 wrapper 验收与完整签名 | ⚠️ 部分解决 | `PLAN.md:17-23,85,93-102,132` 已写出唯一 CLI、cwd、workspace/OUT/store/ref/proof 消费链；但独立判据仍有缩写/缺参命令，预期失败分支的退出码与 ref 规则未定义，见 I1。 |
| B2 缺少公开 services 的 harness adapter 成功正例 | ✅ 已解决 | `PLAN.md:24-30,61,111-117` 给出 resolver、Codex、Claude 三条命令，并要求消费 03b 真实 proof、输出相同 digest/status/goal/write project；`dev-sidebar` 保留为 `GOAL_COVERAGE_MISSING` 负例。 |
| I1 总验收未覆盖 candidate→probe→audited proof 真实链 | ✅ 已解决 | `PLAN.md:17-23` 已串起 preflight、extract、materialize、probe、prove、verify-proof、build-repo。 |
| I2 dispatcher/file owner、revert 与 artifact 留存不可执行 | ⚠️ 部分解决 | `PLAN.md:134,138-148` 已给 owner、exact merge commit 和 revert；但 worktree-local `.cache` 不是可证明留存到 closeout 的外部存储，回滚 00 又会删除所有后序 command 的唯一入口，见 B2/I2。 |
| I3 00/02 无 P5 预算 | ✅ 已解决 | `PLAN.md:70-71,86-88` 已限制 800 行非生成 diff、160/200 行测试或摘要，并定义超额重分。 |
| I4 三层 digest 存在循环歧义 | ❌ 未解决 | `PLAN.md:128-132` 已把 proof 移出 lock；但 `PLAN.md:46,100,129` 同时要求 audit event 记录“前后 closure digest”且 closure digest 哈希全部 audit events，当前 event 的 after digest 因而自引用，见 B1。 |

结论：6 条中 3 条完全解决，2 条部分解决，1 条未解决；第三轮未收敛。

## Findings

### 阻断

#### B1 — audit event 的 after closure digest 与 closure digest 定义相互引用，digest DAG 仍成环

- **位置：** `PLAN.md:46,100,128-132`。
- **依据：** lock digest 已排除 digest/ref/audit/proof，proof digest 也排除自身，这两层无环。但 closure digest 定义为 `H({lock_digest, audit_events})`，而每个 audit event 又必须记录补仓前后 closure digest。当前 event 的 after closure digest 需要先哈希包含该 after 值的 event，不存在规范的有限字节表示能满足该定义。“按 iteration 排序”只解决顺序，不解决自引用。proof payload 中泛称的 `artifact digests` 也应明确排除 proof artifact/ref 自身。
- **建议：** audit event 只记录 `before_lock_digest`/`after_lock_digest`、前一 event digest、missing-input/log/witness 等已存在前驱；全部 event 固定后，再用 final lock digest + audit event digests/root 一次计算 closure digest。写出严格的 `seed/platform/graph → lock → audit root → closure → proof` DAG、逐层字段允许/排除表，以及固定 fixture 的确定 digest 正例。

#### B2 — worktree 隔离下 `.cache/` store/ref 不是持久交接面，03b→04→05 无法保证消费同一真实 proof

- **位置：** `config.yml:14`；`PLAN.md:18-30,57-61,114,132,142-148,167-168`。
- **依据：** 配置为 `isolation: worktree`，PLAN 却把 store/ref 固定在“当前 demo 仓根”下的相对 `.cache/aosp-harness/`，只用 `.gitignore` 说明它不进 merge commit。不同 spec 的隔离 worktree 会解析到不同 `.cache/`；前序 worktree 移除时，忽略生成物没有 Git 或发布者保留。03b proof 即使在自身验收中存在，04/05 也不保证取得；05 的 tracked fixture 也不能从 merge commit 得到被忽略的运行时 ref。`PLAN.md:148` 声明“至少保留到 closeout”，但没有独立于 worktree 的 store owner、publish/fetch、retention 或 stable ref namespace。这使 04/05 的 P1 和 02/03b 的 P2 产物留存不成立。
- **建议：** 把 store 定义为独立于任一 spec worktree 的项目级/CI 持久资源，由 descriptor 或单一环境参数给出；写死 atomic publish、immutable object、stable ref namespace、fetch/verify、closeout retention 和清理 owner。05 应引用 03b publish 的逻辑 ref并在传入 store 中重验 proof，不能引用临时 worktree 相对路径。store 应表述为“可原子追加、已发布 object 只读”。

### 重要

#### I1 — CLI 外形已完整，但预期状态的退出码与 ref 产生规则仍不完整

- **位置：** `PLAN.md:17-30,55-61,70,87,93-102,116,132`。
- **依据：** 未定义 `ENV NOT-AVAILABLE`、`CLOSURE NOT-VIABLE`、`MISSING_INPUT`、超预算/vendor/多义、`GOAL_COVERAGE_MISSING` 分别返回 0 还是非 0，也未明确 `probe` 在 `PROBE PASS` 与 `MISSING_INPUT` 两条路径上是否都原子写出可被 `prove --probe-ref` 消费的 ref。整体命令块因此不能在 `set -e`/CI 下无歧义编排。spec 表中 02 的独立判据还省略 `--seed-workspace/--artifact-store/--out-ref`，03a–04 使用无唯一入口前缀的缩写。
- **建议：** 为每个 subcommand 列成功、可继续知识结果和 fail-closed 结果的 exit code，以及每条分支必须/不得写出的 artifact kind/ref；定义 `PROBE PASS` 的零补仓 proof 路径和 `MISSING_INPUT` 的可消费 ref。独立判据应使用完整命令，或明确引用一张完整 CLI 签名表。

#### I2 — dispatcher owner 已固定，但回滚 00 会使所有已合入后序 command 不可达

- **位置：** `PLAN.md:78,134,138-148`。
- **依据：** 后序只新增独占 command module，解决了同文件冲突；但 dispatcher 由 00 独占，撤回 00 后所有后序 module 均无入口，不能返回表中的 `CAPABILITY_UNAVAILABLE`/`*_MISSING`。00 的回滚判据只要求旧 harness PASS，没有证明“回滚它不牵连已合入的其他 spec”。其余行也只有自然语言预期；`PLAN.md:148` 给通用 revert 操作，却未给每片对应的具体缺席验收命令。
- **建议：** 把 dispatcher 作为不参与各 capability 回滚的先置基座并据此重切 00，或给后序 command 一个不依赖 00 merge commit 的稳定入口。每片写出 revert 后必跑的具体命令和 exit/status；若 dispatcher 与第一个消费者不能独立回滚，应合并为原子片。

#### I3 — “repo-unit 不替代 integration”是总不变量，却没有对应交付或范围裁定

- **位置：** `PLAN.md:10,23-30,38,60-61,104-117`；依据 `research/report.md:13`。
- **依据：** report 和 PLAN 均声明 repo-unit 不取代 feature integration；但整体验收只运行 `build-repo`，05 只做 resolver/wrapper dry-run contract，没有 integration build 入口。若单一 mutable project 的 `aosp17-services` 使 repo-unit 在本轮与 integration 等价，PLAN 未写等价条件或验证；若不等价，则 report 的承重结论只有复述、没有处置。
- **建议：** 增加消费同一 proof 的 `build-feature aosp17-services`；或明确并验证本轮单一 feature commit 下 repo-unit 与 integration source set/goal 相同，同时把真正跨仓 integration 定义为未来 `dev-sidebar` 计划的显式入口条件。

### 次要

#### M1 — “只读 artifact store”容易被实现成 producer 不可发布

- **位置：** `PLAN.md:18-23,30,132`。
- **依据：** extract/probe/prove 都要向 store 产生新 object，但文案把整个 store 称为只读；另一处才说单个完整 artifact 是只读文件，作用域不一致。
- **建议：** 统一为：store 支持 atomic create-if-absent；已发布 digest object 不可覆盖/修改；consumer 只读；同 digest 不同 bytes 必须 fail closed。

## 五维审查结果

### A — 溯源与遗留项

- 00 对应环境未确认；01 对应无锁定契约；02–03b 对应完整种子预计算、clean reduced build 和有界补仓；04 对应单一可写仓；05 对应 harness adapter。行级来源成立。
- report 的两项冲突和四项未确认均在 `PLAN.md:171-176` 有处置；公开 `services` 与 `dev-sidebar` 边界不再混用。
- A 维基本通过；但“repo-unit 不替代 integration”只声明未闭合，见 I3。

### B — 每片 P1–P5

| spec | P1 独立验收 | P2 独立回滚 | P3 独立产出 | P4 ≤15 | P5 <1h |
|---|---|---|---|---|---|
| 00 | ✅ PASS/NOT-AVAILABLE 均有知识产出 | ❌ 撤回 dispatcher 使后序 command 不可达 | ✅ seed/环境结论 | ✅ | ✅ 800 + 160 |
| 01 | ✅ validator 正负 fixture 具体 | ⚠️ 受 00 dispatcher 回滚影响 | ✅ contract/schema/validator | ✅ | ✅ 800 + 160 |
| 02 | ⚠️ 详细节签名完整，表中判据仍缺参 | ⚠️ candidate 留存受 worktree-local store 限制 | ✅ candidate 或 NOT-VIABLE | ✅ | ✅ 800 + 160/200 |
| 03a | ⚠️ PASS/MISSING_INPUT ref/exit 分支未写死 | ⚠️ 无逐片具体 revert 验收 | ✅ worktree/probe | ✅ | ✅ 800 + 160 |
| 03b | ⚠️ 命令已具备，但 digest 成环 | ❌ proof/ref 未与 worktree 解耦 | ✅ proof 或有界失败证据 | ✅ | ✅ 800 + 200 |
| 04 | ❌ 必需 proof 无持久项目级发布点 | ⚠️ owner 独占但缺具体 revert 命令集 | ✅ repo-unit/cache isolation | ✅ | ✅ 800 + 160 |
| 05 | ❌ 正负例具体，但真实 proof ref 的跨 worktree 来源未闭合 | ✅ 末片 optional adapter 可恢复旧行为 | ✅ harness capability | ✅ | ✅ 800 + 160 |

P3、P4、P5 已闭合；P1 被 digest/store/ref 阻断，P2 被 dispatcher 根依赖与 artifact 留存阻断，故 B 维失败。

### C — 依赖、接口与资源

- spec 逻辑依赖为严格线性 `00→01→02→03a→03b→04→05`，表格、正文、文本图一致，无 spec 依赖环。
- CLI/cwd/主参数和 command owner 已大幅收敛，`aosp17-services` 三客户成功正例及 `dev-sidebar` 负例具体。
- digest 依赖成环、artifact/ref 与 worktree 生命周期冲突，状态 exit/ref 契约和 dispatcher 根回滚仍不完整，故 C 维失败。
- CPU/RAM/磁盘、只读 seed/Git objects、独立 workspace/OUT_DIR 及实现串行已识别；除 store 生命周期外，未发现新的资源冲突。

### D — 总目标闭合

- 00→04 已形成“环境→候选锁→缩减物化→断网试探→审计补仓证明→单一可写仓构建”的非简单加总链，05 再向三个 harness 客户暴露同一 capability，拆分方向正确。
- `dev-sidebar` 已明确只作 fail-closed 边界，不再虚构源码/goal 成功。
- 但真实 proof 既无可计算的无环 digest，也无跨 spec 持久交接；integration 不变量又没有验收或等价裁定。具体命令可通过同 worktree 预置 ref/跳过 integration 而未达成全部承重不变量，故 D 维失败。

### E — 风险排序

- 00 先验环境/seed，01 固化最薄契约，02 紧接验证图到 project closure 的核心假设，之后才投入物化、补仓、隔离构建和 harness 接入。
- NOT-AVAILABLE/NOT-VIABLE/超预算分支均要求回 PLAN 复盘，没有把知识性失败冒充项目成功。
- E 维通过；未发现应排在 00/02 之前的新单点风险。

## 文档质量抽查

- 抽查 `research/report.md:7`：当前 harness 不下载、不求闭包、不机器选择构建器，已由 01–05 的 contract/extract/materialize/prove/build/adapter 链覆盖。
- 抽查 `research/report.md:9-11`：pinned seed、B0/B1/F/D、fresh OUT、断网、有界补仓均有消费者；当前缺陷是 digest 协议内部自引用。
- 抽查 `research/report.md:13-15`：单一可写仓、不虚构 `dev-sidebar` 成功、公开 services 先行均正确收窄；integration 仍缺显式裁定。
- 未发现 `[推断]` 混入已确认结论，也未把未来 `feature-closure` 声称为当前能力；`PLAN.md:30` 已标注命令属于全部 spec 完成后的契约。
- 文档形状、来源、依赖图、资源冲突和人审预算齐全；质量缺口集中在字节级 digest、跨 worktree artifact 生命周期、状态机与回滚可执行性。

## 最小修订顺序

1. 消除 audit event/closure digest 自引用，写出字段级无环 DAG 和固定 digest 正例。
2. 将 store/ref 与 spec worktree 解耦，固定 publish/fetch/retention/owner，让 05 确定消费 03b 同一 proof。
3. 补齐各预期分支 exit/ref 规则和逐片完整命令，重切 dispatcher/00 的 P2 边界。
4. 给 integration 增加 job，或写死本轮与 repo-unit 等价的范围条件和未来跨仓 gate。

VERDICT: FAIL
