# 2026-09-01-aosp-feature-minimal-checkout 拆分计划 v6

> 上游：`research/report.md`
> v1 依据：调研证明 reduced manifest 可行，但当前 harness 缺少源码物化、版本锁、依赖闭包和真实 clean-build 证明；“单仓”必须定义为单一可写仓，而不是只存在一个物理 Git 仓。
> v2 依据：`work/plan-review-round-1.md` 的 3 个阻断、5 个重要与 2 个次要 finding；首轮交付收窄到公开 AOSP `services`，增加环境 preflight、版本化接口/回滚矩阵、全角色 witness、全 ClosureKey 变异和有界 review 产物。
> v3 依据：`work/plan-review-round-2.md` 的 2 个阻断与 4 个重要 finding；固定 candidate→materialize→probe→prove→repo-unit 全链路 CLI，增加 `aosp17-services` harness 成功正例、content-addressed artifact store、独占 command owner、无环 digest DAG 及 00/02 人审预算。
> v4 依据：`work/plan-review-round-3.md` 触发 `fix_loop_max=3` 熔断后的逐条裁定；event hash chain 消除 closure 自引用，用 worktree 外 `AOSP_HARNESS_STATE_DIR` 发布 proof，固定 exit/ref 状态机、direct recovery ABI 和单仓 fixture 的 `build-feature` 等价验收。
> v5 依据：`00-environment-seed-preflight/work/review-requirements-round-3.md` 触发 requirements `fix_loop_max=3` 熔断；拆开 public seed request 与 seed ref consumer，固定 real-public gate、stable seed identity、trace/source-state ABI 和 post-commit publish recovery。
> v6 依据：`00-environment-seed-preflight` 门③ sizing 估算 890–1310 行非生成 diff，超过已批准的 800 行人审上限；沿已固定 seed/store ABI 拆为 00a contract runtime 与 00b environment probe，拆后高位分别 730/630 行。

## 总目标

把当前 feature 级 harness 扩展为可复现的 AOSP 缩减工作区原型：以公开 AOSP 17 Cuttlefish 的 `frameworks/base -> services` 为第一个真实证明，只物化单一可写业务仓、共享只读构建底座和经证明的依赖闭包，并将该能力以可选、版本化契约接回当前 Claude/Codex harness。`dev-sidebar` 真实五仓集成构建不在本轮交付范围；在它没有真实源码与 native goal 时，harness 必须给出明确的 `GOAL_COVERAGE_MISSING`。

整体验收：

```bash
set -euo pipefail
test -n "$AOSP_HARNESS_STATE_DIR"
test "${AOSP_HARNESS_STATE_DIR#/}" != "$AOSP_HARNESS_STATE_DIR"
test -n "$AOSP17_SEED_REQUEST"
test -f "$AOSP17_SEED_REQUEST"
./common/tests/test-harness.sh
./common/.harness/bin/check-parity.sh
./common/.harness/bin/feature-closure preflight --descriptor "$AOSP17_SEED_REQUEST" --state-dir "$AOSP_HARNESS_STATE_DIR" --out-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/aosp17-services-env.json"
./common/.harness/bin/feature-closure verify-seed --ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/aosp17-services-env.json" --artifact-store "$AOSP_HARNESS_STATE_DIR/artifacts/v1" --require-public-real
echo 'GATE CONTINUE_PUBLIC'
./common/.harness/bin/feature-closure extract --descriptor-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/aosp17-services-env.json" --seed-workspace "$AOSP_HARNESS_STATE_DIR/seed" --goal services --artifact-store "$AOSP_HARNESS_STATE_DIR/artifacts/v1" --out-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/services-candidate.json"
./common/.harness/bin/feature-closure materialize --candidate-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/services-candidate.json" --workspace "$AOSP_HARNESS_STATE_DIR/workspaces/services-reduced" --artifact-store "$AOSP_HARNESS_STATE_DIR/artifacts/v1"
./common/.harness/bin/feature-closure probe --candidate-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/services-candidate.json" --workspace "$AOSP_HARNESS_STATE_DIR/workspaces/services-reduced" --out-dir "$AOSP_HARNESS_STATE_DIR/out/services-probe" --artifact-store "$AOSP_HARNESS_STATE_DIR/artifacts/v1" --out-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/services-probe.json"
./common/.harness/bin/feature-closure prove --candidate-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/services-candidate.json" --probe-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/services-probe.json" --workspace-root "$AOSP_HARNESS_STATE_DIR/workspaces" --out-root "$AOSP_HARNESS_STATE_DIR/out" --artifact-store "$AOSP_HARNESS_STATE_DIR/artifacts/v1" --max-iterations 8 --max-added-projects 64 --out-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/services-proof.json"
./common/.harness/bin/feature-closure verify-proof --descriptor-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/aosp17-services-env.json" --proof-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/services-proof.json" --artifact-store "$AOSP_HARNESS_STATE_DIR/artifacts/v1"
./common/.harness/bin/feature-closure build-repo --proof-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/services-proof.json" --artifact-store "$AOSP_HARNESS_STATE_DIR/artifacts/v1" --workspace "$AOSP_HARNESS_STATE_DIR/workspaces/services-repo-unit" --out-dir "$AOSP_HARNESS_STATE_DIR/out/services-repo-unit" --write-project frameworks/base --goal services
./common/.harness/bin/feature-closure build-feature --proof-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/services-proof.json" --artifact-store "$AOSP_HARNESS_STATE_DIR/artifacts/v1" --workspace "$AOSP_HARNESS_STATE_DIR/workspaces/services-integration" --out-dir "$AOSP_HARNESS_STATE_DIR/out/services-integration" --feature aosp17-services
./common/.harness/bin/resolve-feature.sh --root common --feature aosp17-services --artifact-store "$AOSP_HARNESS_STATE_DIR/artifacts/v1" --format contract
./common/.codex/bin/codex-feature --feature aosp17-services --artifact-store "$AOSP_HARNESS_STATE_DIR/artifacts/v1" --dry-run --contract
./common/.claude/bin/claude-feature --feature aosp17-services --artifact-store "$AOSP_HARNESS_STATE_DIR/artifacts/v1" --dry-run --contract
./common/.harness/bin/resolve-feature.sh --root common --feature dev-sidebar --artifact-store "$AOSP_HARNESS_STATE_DIR/artifacts/v1" --format contract
```

上述命令均从 demo 仓根执行，且是“全部 spec 完成后”的验收契约。`AOSP_HARNESS_STATE_DIR` 必须是一个已存在、独立于所有 Git/spec worktree 的项目级绝对路径，00b preflight 通过 00a runtime 对这两条做 fail-closed 校验。期望：回归保持 `RESULT PASS`/`PARITY PASS`；闭包链依次输出 `ENV PASS`、`CANDIDATE READY`、`WORKTREE PASS`、`PROBE PASS` 或可收敛的 `MISSING_INPUT`、`CLOSURE PROVEN`、`PROOF PASS`；repo-unit 输出 `REPO BUILD PASS frameworks/base services`，integration 输出 `FEATURE BUILD PASS aosp17-services`，两者必须报告相同 proof/source set/goal digest。resolver 与两 wrapper 对 `aosp17-services` 必须输出同一 `closure_digest`/`proof_digest`、`closure_status=CLOSURE_PROVEN`、`goal=services`、`write_project=frameworks/base`；`dev-sidebar` 必须输出 `closure_status=GOAL_COVERAGE_MISSING`。

整体不变量：

- 最小闭包只对 manifest SHA、Repo 版本、host/container、product、release config、variant、goals、used environment 和 extractor 版本的完整 key 有效；任一项变更必须 cache miss。
- 物化只能获取 platform lock 中的 exact SHA；构建阶段断网，不运行裸 `repo sync`。
- 不存在“失败就同步全树”回退；多义、未知、vendor/private 或超过补仓预算必须 fail closed。
- 第一次证明使用 fresh workspace 和 fresh `OUT_DIR`；补仓后丢弃上轮不完整输出再重试。
- repo-unit job 只有一个 project 可写，其他项目在构建前后 HEAD、content 和 status 不变；单编不替代 feature integration build。
- `build/make`、`build/soong`、`build/blueprint` 或 bootstrap prebuilt 变更时必须重算 baseline/closure 并使用新的 out/cache namespace。
- 当前 Claude/Codex 公共契约、安全路径、分支漂移、唯一 verifier 和 fail-closed 回归不退化。

## 全局约束

- 范围仅覆盖公开 AOSP 与 Cuttlefish 可验证路径；私有 vendor/BSP 依赖输出 `UNRESOLVED_VENDOR_BOUNDARY`，不自动扩权或替换依赖。
- feature 意图、platform lock 和 closure proof 分离：人工只维护 feature 意图，Git project SHA 集合和证明日志必须机器生成。
- 每个 project 的每个 B0/B1/F/D 角色都必须有对应的 bootstrap/product/intent/dependency 机器可读 witness；每次补仓必须记录原始失败摘要、日志 digest、exact SHA、前后 lock digest 和前一 event digest，不在 event 中记录 closure digest。
- 默认补仓预算为最多 8 轮、64 个 project；本数值是原型安全上限，只能通过新的已审核契约修改。
- 先完成 `services` 目标的缩减证明，再扩展 SidebarApp、native 目标和 SELinux；不把当前 `repos.tsv` 的 5 仓当成已证明闭包。
- 实现类 spec 串行执行；真实 AOSP seed、Repo mirror/cache 和 clean-build 工作区不与其他任务共享可写状态。

## spec 列表

| id | 目标（一句话） | 依赖 | 独立判据 | 状态 |
|---|---|---|---|---|
| 2026-09-01-00a-seed-contract-runtime | 固化 dispatcher、seed/evidence schema、canonical digest、state-dir 与 recoverable store/ref runtime | — | `./common/.harness/bin/feature-closure verify-seed common/tests/fixtures/aosp17-services/seed.golden.json` 输出 `SEED ABI PASS`；schema/path/digest/collision/ref fault matrix 精确 fail closed；预计非生成 diff ≤730 行 | ✅ 已完成 |
| 2026-09-02-00b-environment-seed-probe | 消费 00a runtime，在真实 local/public source 上产出 seed 或 terminal report，并证明 source/network/build guard | 2026-09-01-00a-seed-contract-runtime | `preflight --descriptor FILE --state-dir ABS_DIR --out-ref REF` 对 real public seed stdout 仅为 `ENV PASS public_aosp17_cuttlefish`；随后 `verify-seed --ref ... --require-public-real` 退 0，control plane 才记录 `GATE CONTINUE_PUBLIC`；预计非生成 diff ≤630 行 | ⬜ 未开始 |
| 01-feature-lock-contract | 建立 feature 意图、platform SHA lock 和 closure proof v1 契约与 fail-closed 校验 | 2026-09-02-00b-environment-seed-probe | `./common/.harness/bin/feature-closure verify-lock common/tests/fixtures/closure/valid.json` 输出 `LOCK PASS`；每个角色无 witness、缺 SHA、非唯一 path 和占位 product 均被指定错误码拒绝 | ⬜ 未开始 |
| 02-services-closure-spike | 在锁定 seed 上为 `services` 生成项目级候选闭包和全角色 witness，证明或否定核心假设 | 01-feature-lock-contract | `./common/.harness/bin/feature-closure extract --descriptor-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/aosp17-services-env.json" --goal services` 仅消费 real-source public ref，产出非空 lock/manifest 与最多 200 行审查摘要，或产出带证据 `CLOSURE NOT-VIABLE` 报告并触发复盘 | ⬜ 未开始 |
| 03a-reduced-materialize-probe | 只物化候选 closure project，完成 exact-SHA 工作区校验与断网 clean parse/build probe | 02-services-closure-spike | `materialize --candidate-ref REF --workspace DIR --artifact-store STORE` 输出 `WORKTREE PASS`；`probe --candidate-ref REF --workspace DIR --out-dir DIR --artifact-store STORE --out-ref REF` 输出 `PROBE PASS` 或结构化 `MISSING_INPUT` | ⬜ 未开始 |
| 03b-audited-closure-proof | 以有界、可审计补仓将 `MISSING_INPUT` 收敛为可重复 closure proof | 03a-reduced-materialize-probe | `prove --candidate-ref REF --probe-ref REF --workspace-root DIR --out-root DIR --artifact-store STORE --max-iterations 8 --max-added-projects 64 --out-ref REF` 输出 `CLOSURE PROVEN`，`verify-proof` 输出 `PROOF PASS`；超预算/vendor/多义均 fail closed | ⬜ 未开始 |
| 04-repo-unit-build | 将已证明闭包封装为单一可写 project 的 repo-unit build，并验证完整 ClosureKey 缓存隔离 | 03b-audited-closure-proof | `build-repo --proof-ref REF --artifact-store STORE --workspace DIR --out-dir DIR --write-project frameworks/base --goal services` 输出 `REPO BUILD PASS`；非目标仓改动被拒绝，ClosureKey 每个字段变异都 cache miss | ⬜ 未开始 |
| 05-harness-closure-adapter | 以可选 v1 adapter 将 proof/repo-unit/feature-integration 能力接入当前 Claude/Codex 契约 | 04-repo-unit-build | `build-feature --feature aosp17-services` 与 repo-unit 的 proof/source-set/goal digest 一致；resolver/Claude/Codex 输出同一 digest/status/goal/write-project；`dev-sidebar` 输出 `GOAL_COVERAGE_MISSING` | ⬜ 未开始 |

## 每个 spec 具体要干什么

### 00a-seed-contract-runtime

- 来源：`research/report.md:24`–`27` 与原 00 requirements round 3 熔断裁定；先把后序共同消费的 ABI 与持久状态做成独立可验收能力。
- 独占只读 dispatcher 与 `verify-seed` direct command；固定 seed-request/seed/source-state/trace/journal/terminal schema、RFC 8785 domain digest 和 stable seed identity。
- 建立 worktree 外 state-dir 的 no-follow confinement、content-addressed object、scope ref lock、atomic publish、orphan/ref-durability recovery 与 validation/publish error ABI。
- 用 deterministic fixture 与 fault injection 独立验 `SEED ABI PASS`、dispatcher/direct parity、collision/ref corruption/commit point；不读取真实 AOSP，不执行 envsetup/lunch。
- 所有后序 direct command wrapper 在 import runtime 前检查 00a marker/schema；00a 被单独 revert 时，它们保留自身文件但精确 exit 30、stdout 空、stderr `CONTRACT RUNTIME_UNAVAILABLE`，无需联动 revert 后序 commit。
- 非生成 diff ≤800 行，schema/test 摘要 ≤160 行；回滚后 dispatcher/verify-seed 缺席，旧 harness 三项回归 PASS。

### 00b-environment-seed-probe

- 来源：`research/report.md:24`–`27` 与原 00 requirements 的真实环境半片；消费 00a 的 schema/publisher/direct recovery ABI，不修改 dispatcher/runtime。
- 在 local LK7K 与 operator-supplied public AOSP17 request 上收集 manifest/Repo/tool/host/cgroup/lunch/source-state/trace evidence；所有 OUT_DIR/evidence 留在 state-dir。
- network namespace + syscall trace + before/after source state 证明 external network、source mutation、sync/download、module build、package 计数为 0；stable seed identity 排除调度/瞬时资源。
- local LK7K 只验证 product/vendor context；preflight stdout 保持单行 `ENV PASS SCOPE_ID`，control plane 仅在 `verify-seed --ref ... --require-public-real` 退 0 后记录 `GATE CONTINUE_PUBLIC`。缺 public source/资源/tool/namespace 时发布 ≤120 行 terminal report、回 PLAN 且不进入 01。
- 非生成 diff ≤800 行，preflight summary ≤160 行；回滚 00b 后 00a `SEED ABI PASS` 与旧 harness 回归仍 PASS。

### 01-feature-lock-contract

- 来源：`research/report.md:7`–`11`，解决当前 harness 无 Git SHA、构建上下文和 closure proof 契约。
- 新增 v1 `feature.yaml`、`platform.lock.xml` 和 candidate `closure.lock.json` schema，固定目标、exact SHA、角色、witness 与 ClosureKey；proof 是 03b 产出的独立 artifact，不嵌入 lock。
- 每个 B0/B1/F/D project 都必须有角色特定 witness：分别是 bootstrap/action input、product/release/include、feature mutable intent、module/path/action dependency；不允许用重分类规避证据。
- 提供固定 bytes 的 lock/event-chain/empty-audit/proof digest golden fixtures，每个 fixture 存一个明确 64 位 expected SHA-256；键顺序变化必须不改 digest，任一承重字段变化必须改 digest。
- 唯一 CLI 路径为 `./common/.harness/bin/feature-closure`，所有子命令均从 demo 仓根执行；00a 已发布只读 dispatcher ABI，本片只新增 v1 validator command module 和正负 fixture，不修改 dispatcher。
- 人审包括不超过 800 行非生成 diff 与不超过 160 行 schema/测试摘要；超额则在 tasks 门重分。

### 02-services-closure-spike

- 来源：`research/report.md:9`–`15`，直接检验“完整图能生成可审计项目候选闭包”的核心假设。
- 只读使用 00b 的 pinned seed，运行 `m nothing`、`m json-module-graph module-info`，收集 graph/actions/used-env、Make/product includes 与 bootstrap inputs。
- 只以 `services` 为 seed，实现 module/path 到 manifest project 最长前缀映射，通过 `extract --descriptor-ref ... --seed-workspace ... --goal services --artifact-store ... --out-ref ...` 重算 public seed ref/object 后输出 B0/B1/F/D 项目、全角色 witness 和 SHA-pinned checkout manifest。
- 人审只看最多 200 行 summary：各角色数量、无 witness 计数必须为 0、3 条固定随机种子的 witness 抽样、digest 到原始图/日志索引。机械校验全量 artifact，人不逐行审数万行生成数据。
- 若图无法产生可审计候选，用不超过 200 行、带原始证据 digest 的 `CLOSURE NOT-VIABLE` 报告独立验收并回 PLAN 复盘，不进入 03a。
- 非生成 extractor/mapping/test diff 不超过 800 行，测试摘要不超过 160 行；超额则在 tasks 门沿“证据采集”与“project/witness 映射”稳定 artifact 接口重分。

### 03a-reduced-materialize-probe

- 来源：`research/report.md:9`、`15`，先把“只物化候选并断网构建”与补仓策略分开验收。
- `materialize --candidate-ref ... --workspace ... --artifact-store ...` 从 candidate digest 读 reduced manifest，仅同步 exact-SHA project，校验 project 集、remote、HEAD、blob completeness 和只读角色，成功输出 `WORKTREE PASS`。
- `probe --candidate-ref ... --workspace ... --out-dir ... --artifact-store ... --out-ref ...` 自行完成 envsetup/lunch、fresh `OUT_DIR`、构建断网与摘要输出；不把 shell function `m` 暴露为独立验收入口。
- 成功输出 `PROBE PASS`；缺 path/module/tool 只输出结构化 `MISSING_INPUT` 和日志 digest，不做任何 sync。人审不超过 800 行非生成 diff + 160 行 probe summary。

### 03b-audited-closure-proof

- 来源：`research/report.md:9`–`11`，只把 clean reduced build 而不是静态图当作最终证明。
- `prove --candidate-ref ... --probe-ref ... --workspace-root ... --out-root ... --artifact-store ... --max-iterations 8 --max-added-projects 64 --out-ref ...` 只处理可在 platform lock 中唯一映射的 missing path/module/tool/product include；每轮记录 exact SHA、witness、原失败 digest、before/after lock digest 和 previous event digest。
- 每次补仓后丢弃 partial `OUT_DIR` 并重跑 03a probe；最多 8 轮/64 project，多义、vendor/private、非缺仓编译错误和超预算均 fail closed。
- 成功后必须再运行 `verify-proof --descriptor-ref ... --proof-ref ... --artifact-store ...`；它重算 seed ref/object 和所有 digest 并输出 `PROOF PASS`。人审只看最多 200 行 audit summary：轮次、新增角色计数、错误分类、closure/proof digest 和原始日志索引；非生成 diff 上限 800 行。

### 04-repo-unit-build

- 来源：`research/report.md:13`–`15`，将“单仓”定义为单一可写边界并保留集成语义。
- `build-repo --proof-ref ... --artifact-store ... --workspace ... --out-dir ... --write-project frameworks/base --goal services` 先校验 proof digest，再把 B0/B1/D 只读暴露，只为 `frameworks/base` 建可写 overlay/worktree；构建前后校验其他项目 HEAD/content/status 不变。
- 用表驱动 mutation matrix 逐一变异 manifest SHA、Repo、host/container、product、release、variant、goals、used-env、extractor 以及 make/soong/blueprint/bootstrap prebuilt，全部必须 cache miss；完全同 key 必须 hit，canonical ordering 不改 digest。
- 跨仓未合入 API 不隐式切依赖分支，返回 `REQUIRES_STACKED_INTEGRATION`。人审上限为 800 行非生成 diff + 160 行测试摘要。

### 05-harness-closure-adapter

- 来源：`research/report.md:7`、`13`、`15`，只把已证明的 repo-unit 能力接入当前 harness，不声称虚构 `dev-sidebar` 已可真实集成构建。
- 新增公开 `aosp17-services` feature fixture，它引用 03b 的 proof ref/digest；resolver、Claude wrapper、Codex wrapper 必须从指定 `--artifact-store` 校验并输出同一 closure/proof digest、`CLOSURE_PROVEN`、`services` 和 `frameworks/base`，不接受常量占位 digest。
- 新增 `build-feature --proof-ref ... --artifact-store ... --workspace ... --out-dir ... --feature aosp17-services`；因首轮 fixture 只有一个 mutable project 和一个 goal，其 source-set/goal/proof digest 必须与 repo-unit 精确相同，成功输出 `FEATURE BUILD PASS aosp17-services`。未来跨仓 `dev-sidebar` 只能在真实源码/goal 齐备后以该子命令做所有 feature revisions 同时可见的 integration gate。
- 以可选 v1 adapter 让 resolver 和 Claude/Codex wrapper 暴露上述 capability；无 v1 artifact 时完全保持旧 contract/行为。
- `dev-sidebar` 五仓仅作 mutable intent 迁移 fixture；由于 native goal 和真实源码不存在，验收值是确定的 `GOAL_COVERAGE_MISSING`，不是 `FEATURE BUILD PASS`。
- 保留 parity、唯一 verifier、safe serial、branch drift 和回归套件。人审上限为 800 行非生成 diff + 160 行 contract 对比摘要；超额则在 tasks 门重分。

## 稳定接口、术语与 digest

| 名称 | v1 定义 | digest 覆盖面 / 消费者 |
|---|---|---|
| seed identity | `SHA-256("aosp-harness/seed-identity/v1\0" + RFC8785(stable source/manifest/tools/execution/lunch/source-state payload))`；排除调度相关 trace、journal、瞬时资源和 OUT_DIR | 00b 产出，01–05 通过 00a runtime 从固定 public seed ref/object 重算并消费 |
| seed artifact | 完整 `seed/v1` audit payload 的 content-addressed object；artifact digest 可随 run evidence 变化，但同 request/source 的 seed identity 必须稳定 | 固定 ref 只接受 `evidence_class=real_source` public scope；local/vendor ref 不解锁 01 |
| B0 | bootstrap/tool/action input 项目；必须有 bootstrap witness | seed + bootstrap inputs；02–04 消费 |
| B1 | product/release/include 项目；必须有 product witness | product/release/variant/includes；02–04 消费 |
| F | feature 明确声明的 mutable project；必须有 intent witness | feature yaml + base/feature revision；01–05 消费 |
| D | 目标 module/path/action 传递依赖；必须有 dependency witness | configured graph/actions；02–04 消费 |
| 角色重叠 | 同一 project 可有多个角色，不丢弃任一 witness；可写权只由 F 与 job `write_project` 共同决定 | canonical 序列化按 project path、role、witness 排序 |
| lock digest | `SHA-256("aosp-harness/lock/v1\\0" + RFC8785(lock payload))`；payload 只含 ClosureKey、platform lock、projects/roles/witnesses/check-out manifest，不含任何 digest 字段、ref、audit 或 proof | validator、materializer、cache key 消费 |
| event digest / audit root | event payload 仅含 iteration、before/after lock digest、previous event digest、missing-input/log/witness/project，`event_digest=SHA-256("aosp-harness/event/v1\\0" + RFC8785(payload))`；`audit_root=SHA-256("aosp-harness/audit/v1\\0" + RFC8785(ordered_event_digests))`，空列表合法 | 03b 产出，不引用 closure/proof digest |
| closure digest | `SHA-256("aosp-harness/closure/v1\\0" + RFC8785({final_lock_digest, audit_root}))` | 03b–05 消费 |
| proof digest | `SHA-256("aosp-harness/proof/v1\\0" + RFC8785(proof payload))`；payload 只引用 closure/seed/container/commands/used-env/workspace/out/log/artifact digests，不含 proof digest 自身 | 03b–05 消费，是 `CLOSURE PROVEN` 的证据主键 |

v1 唯一可执行入口是 `./common/.harness/bin/feature-closure SUBCOMMAND`，从 demo 仓根运行。输入 artifact 均含 `schema_version: 1`，未支持版本以 `UNSUPPORTED_SCHEMA_VERSION` 非零退出，不猜测兼容。每层 payload 先按 RFC 8785 转 UTF-8 bytes，再加上表中 ASCII domain separator 求 hash；`out-ref` 只写 `{schema_version, kind, digest}`，不参与 payload hash。完整 artifact 存于 `STORE/sha256/` 下以 64 位小写十六进制 digest 命名的只读文件；对应 ref 和 artifact 任一缺失即 `ARTIFACT_MISSING`。

dispatcher 在 00a 一次性固化为只读 ABI：它仅按子命令名加载 `common/.harness/closure/v1/commands.d/COMMAND`，后续 spec 不得修改 dispatcher。每个 command module 本身也是 direct recovery ABI。文件 owner：00a 独占 dispatcher、schemas/store/ref runtime 与 `verify-seed`；00b 独占 `preflight` 和 environment evidence provider；01 独占 `verify-lock`；02 独占 `extract`；03a 独占 `materialize`/`probe`；03b 独占 `prove`/`verify-proof`；04 独占 `build-repo`；05 独占 `build-feature`、resolver/wrappers 与 feature adapter fixtures。通用库只能在 `closure/v1/lib/SPEC_ID/` 下新增版本化模块。

store owner 是 00a 建立的项目级 state-dir 契约，不是任一 spec worktree。producer 只能执行 atomic create-if-absent + fsync + rename；已发布 digest object 永不覆盖/修改，同 digest 不同 bytes以 `DIGEST_COLLISION` fail closed；consumer 只读并重算 digest。stable ref namespace 是 `$AOSP_HARNESS_STATE_DIR/refs/PROJECT_ID/`；00b 发布 public/local env ref，03b 发布 services proof ref。已验收 object/ref 保留到 closeout。

## CLI 结果码与 ref 规则

| 结果类型 | exit | stdout/status | ref 规则 | 下游行为 |
|---|---:|---|---|---|
| 正常成功 | 0 | `ENV PASS` / `CANDIDATE READY` / `WORKTREE PASS` / `PROBE PASS` / `CLOSURE PROVEN` / `PROOF PASS` / build PASS | 有 `--out-ref` 的 producer 必须原子写对应 kind ref；无该参数的 verifier/builder 不写 ref | 继续 |
| 可收敛缺输入 | 10 | `MISSING_INPUT` | `probe --out-ref` 必须写 `kind=missing_input` 且含日志/missing digest；`prove` 必须能消费 | 仅进入 03b |
| 知识性终止 | 20 | `ENV NOT-AVAILABLE` / `CLOSURE NOT-VIABLE` | 必须写 `kind=terminal_report` ref，不写 candidate/proof ref | 停止实现链并回 PLAN 复盘 |
| 契约/验证失败 | 30 | schema/digest/ref/worktree mismatch | 不得写任何新 ref | fail closed |
| 边界/预算/编译失败 | 40 | vendor、多义、超 8/64、非缺仓错误、`GOAL_COVERAGE_MISSING` build | producer 可写 `kind=failure_report` 证据 ref，绝不写 proof ref | fail closed |
| contract 状态查询 | 0 | resolver/wrapper 可输出 `GOAL_COVERAGE_MISSING` | 只读，不写 ref | 允许展示；后续 build 必须以 exit 40 拒绝 |

CI 不把 exit 10/20 当普通成功；编排器显式分支并校验 ref kind。`PROBE PASS` 的 probe ref 也传给 `prove`，此时 audit event 列表为空，03b 仍生成 closure/proof artifact，不跳过 proof 阶段。

## 独立回滚与文件所有权

| spec | 独占/版本化产出 | 消费者缺席行为 | 独立回滚验证 |
|---|---|---|---|
| 00a | seed/evidence v1 schemas、store/ref runtime、固定 dispatcher 与 `verify-seed` | 无 runtime/dispatcher 时后序 capability 不存在；每个后序 direct wrapper 精确返回 exit 30/`CONTRACT RUNTIME_UNAVAILABLE`，旧 harness 不受影响 | 撤回 00a 后不联动撤回后序 commit；dispatcher/verify-seed 缺席，后序 direct 缺席协议和旧 harness 回归仍 PASS |
| 00b | `preflight` direct module、local/public seed 或 terminal artifact/ref | 无 preflight 时不能产出 real seed，但 00a `SEED ABI PASS` 仍成立 | 撤回 00b 不修改 00a runtime/fixtures；`verify-seed` 与旧 harness 回归仍 PASS |
| 01 | `contract/v1` schema、validator、fixtures | 无 v1 contract 时 adapter 不启用，resolver 保留旧 contract | 撤回 01 后 v1 套件可明确 skip 为 `CAPABILITY_UNAVAILABLE`，旧 harness 回归仍 PASS |
| 02 | immutable `candidate/v1` artifacts 与 extractor adapter | 无 candidate 时 03a 返回 `CANDIDATE_MISSING` | 撤回 extractor 不删除已发布的 digest fixture；01 validator 仍独立 PASS |
| 03a | `materialize/v1` 与 `probe/v1` | 无 probe 时 03b 返回 `PROBE_CAPABILITY_MISSING` | 撤回 03a 不改 00a–02 artifact，01/02 验收仍 PASS |
| 03b | immutable `proof/v1` artifact 与 supplement adapter | 无 proof 时 04 返回 `PROOF_MISSING` | 撤回 supplement adapter 不改已发布 proof fixture，03a probe 仍可独立运行 |
| 04 | `repo-unit/v1` executor 与 cache namespace | 无 executor 时 05 只不对外暴露 repo-unit capability | 撤回 04 不影响 proof 校验和旧 harness；03b 仍 PASS |
| 05 | resolver/wrapper 中的可选 `closure_capability=v1` adapter | 无 adapter 时输出与当前 HEAD 一致的旧 contract | 撤回 05 立即恢复旧客户行为，00a–04 CLI/artifact 仍可独立验收 |

实现时每个 implementation spec 使用独立 two-parent merge commit；回滚验收在隔离 worktree 中对 task ledger 记录的 exact merge commit执行 `git revert -m 1 --no-edit COMMIT_SHA`，再跑该片缺席行为与旧 harness 回归；`COMMIT_SHA` 在任务完成时写入 ledger，不由运行时猜测。已被v6从表中移除的原`00-environment-seed-preflight`只负责机器可验supersession：它先把已审process documents提交为base，再在隔离分支以四个non-overlap task commits交付manifest/core/pre-commit/accept/self-test，最后同样以parent1=base、parent2=task tip的two-parent merge验收，不再采用single-parent例外。生成 artifact/ref 仅位于worktree之外的`$AOSP_HARNESS_STATE_DIR`，不属于任何merge commit，因此普通revert不删它们；被已验收spec引用的digest至少保留到项目closeout，缺失时消费者按表中错误fail closed。

## 依赖图

```text
00a-seed-contract-runtime
  -> 00b-environment-seed-probe
    -> 01-feature-lock-contract
      -> 02-services-closure-spike
        -> 03a-reduced-materialize-probe
          -> 03b-audited-closure-proof
            -> 04-repo-unit-build
              -> 05-harness-closure-adapter
```

排序理由：00a 先固定所有后序共享且可纯 fixture 验收的 seed/store ABI；00b 再排除真实环境不存在这个最早单点失败；01 只建最薄的 v1 契约；02 紧接着检验候选闭包核心假设。任一 spike 不成立都在投入后序前回 PLAN。

## 资源冲突

- 01 只在 00a 已存在的 versioned directory 下新增其独占 contract schema、validator 与 `verify-lock` command module，公共 dispatcher/runtime 零修改；05 才修改 resolver/wrapper。
- 00b–04 共用同一 digest-pinned 只读 AOSP seed 和 content-addressed Git objects；preflight 在每片开始前重校 digest，不允许 spec job 维护/更新 mirror/cache。
- 02–04 共用大体积磁盘和构建 CPU/RAM，不并行运行；每个验收 job 使用独立缩减工作区与 `OUT_DIR`。
- 所有 spec 均为实现或受控实验，按流程串行执行；无可并行实现切片。

## 调研遗留项的处置

- Android tag/product/release/host 与资源未锁定：由 00a 固定 ABI、00b 产出 immutable seed 或 `ENV NOT-AVAILABLE`，不允许占位符进入 lock。
- SidebarApp/SidebarFlinger 真实 project/module 未确认：已从本轮成功目标移除；00b–04 只证明公开 `services`，05 对 `dev-sidebar` 以 `GOAL_COVERAGE_MISSING` 验收边界。完整 Sidebar 集成待真实源码/goal 可用后另立计划。
- Soong/Make/Bazel 图覆盖不完全：02 用多源数据生成候选，03a 做断网 clean probe，03b 用有界补仓与 clean retry 作最终证明。
- Repo mirror、RBE 和只读 overlay 能力未确认：00b 检查 source/mirror/disk/network isolation；RBE 不作为首版前置；overlay 不可用时回退到独立 checkout + content-addressed Git object cache，不放宽只读校验。

## Review 熔断裁定

`config.yml` 允许的 3 轮 PLAN agent review 均已执行；第 3 轮仍为 FAIL，因此按 review 细则不再派第 4 个 reviewer，而是对 `work/plan-review-round-3.md` 逐条裁定，由人在门①一并审核：

- **B1（阻断）已裁定为承重修复：** audit event 不再存 closure digest，只存 before/after lock + previous event digest；最终以 ordered event digests 得 audit root，再与 final lock 得 closure digest。如判断错误，代价是 proof 主键不可重算或不同客户得到不同 digest，将直接破坏缓存和依赖证明。
- **B2（阻断）已裁定为承重修复：** proof store/ref 必须位于所有 worktree 之外的绝对 `AOSP_HARNESS_STATE_DIR`，v6 后由 00a runtime 校验、producer 原子追加、closeout 唯一清理。如判断错误，代价是 04/05 可能丢失或误用 03b proof，导致假 PASS。
- **I1（重要）已裁定为承重修复：** exit 0/10/20/30/40 和每条分支的 ref kind/是否写 ref 已固定；`MISSING_INPUT` 必须写可被 `prove` 消费的 probe ref。如判断错误，代价是 CI 把知识性终止当成成功，或无法编排补仓。
- **I2（重要）已裁定为承重修复：** dispatcher 是 00a 的固定公开 ABI，后续 command 同时是独占文件和可直接执行的 recovery ABI；回滚 00a 后旧 harness 仍 PASS，后续能力可用 direct ABI 审计。如判断错误，代价是回滚 dispatcher 会让已合入 capability 只能通过内部入口运行，需将 00a 与第一个消费者合并重规划。
- **I3（重要）已裁定为承重修复：** 05 增加 `build-feature aosp17-services`；由于该 fixture 只有一个 mutable project/goal，integration 与 repo-unit 的 source-set/goal/proof digest 必须精确相同。如判断错误，代价是单仓 PASS 被错误当成集成 PASS；未来跨仓 feature 必须以不同 source set 运行真实 integration gate。
- **M1（次要）已裁定为文案/实现约束：** store 是“可 atomic create-if-absent，已发布 object 不可改，consumer 只读”，不再称整个 store 不可写。如判断错误，代价是 producer 无法发布或同 digest 被静默覆盖。
