# 2026-08-31-aosp-harness-refactor 拆分计划 v5.5

> 上游：`research/report.md`
> v5.3 依据：03 task 1.1/1.2 的真实 diff 与增量 PLAN review 证明 359/400 行 sizing prototype 失真且 1400 行例外不满足 P5；按安全完成边界拆为互不叠改的私有模块，只有最终 aggregator 发布完整 capability。
> v5.3.1 依据：03a design review round 1 发现其实现必须实际消费 foundation public validate，原依赖边只把两 private export 写作 provider 能力，无法机械解释 source guard 与 fail-fast；本版只补齐既有 `03 -> 03a` 边的第三个既存签名，不改变图、顺序、owner 或验收门。
> v5.4 依据：03a design review round 2 证明 311 行 sizing 原型只执行1个fresh case，无法把完整三层竞态fixture压入剩余89行。03a保留private provider与功能/静态/代表性竞态验收；新增只拥有独立race test的03a1，在任何消费者进入前完成穷举竞态保证。
> v5.5 依据：03a task4 fix1实测未格式化包397行，但pinned shfmt后为527行；把root代表性race留在03a仍无法同时满足格式门和400行/P5。全部anchor-driven provider-copy mutation移到03a1，03a只保留完整private provider、source/root/static、确定性错误分类probe和anchor结构验收。round2可运行原型实测03a exact2为392/400，03a1三层共享driver为269/400并执行19个代表case，完整37-case矩阵剩18个data rows/calls。

## 总目标

在保留 `claude-code/`、`codex/`、`common/` 现有入口和离线 Demo 能力的前提下，将安全、设备/进程调用、资源租约、验收契约和 feature/session 基础能力收敛为公共内核，并用单一离线门禁阻止三套实现再次漂移。

整体验收：

- `./scripts/check.sh --offline` 退出 `0`，末行为 `RESULT PASS  aosp-harness offline quality gate`。
- `./tests/test-device-safety.sh && ./tests/test-session-path-races.sh && ./tests/test-session-state.sh && ./tests/test-claude-session-lifecycle.sh && ./tests/test-resource-leases.sh && ./tests/test-verifier-contract.sh && ./tests/test-command-runtime.sh && ./tests/test-registry-resolver.sh && ./tests/test-client-session-adapters.sh && ./tests/test-verifier-adapters.sh` 全部退出 `0`。
- Claude、Codex、common 三套旧回归全部退出 `0`；`git diff --check` 退出 `0`。
- 默认验收全程不连真实 ADB/CVD，不跑 AOSP build，不改被跟踪的 `CURRENT_FEATURE`，不残留 session/lease 文件。

整体不变量：

- 三个顶层目录和已文档化的 wrapper/demo/test 路径保留；可改为薄适配，但不删入口。
- 真实模式在首次 ADB 调用前必须固定安全 serial；无/非法 serial、查询失败或必需断言 SKIP 时不得退出 `0`。
- 严格 PASS 至少覆盖 boot、system_server、crash baseline、service、package 五项，不降低现有 Codex 负向测试强度。
- 每个存在可回滚 provider 依赖的 consumer，都要在 fixture 中验证 provider-present/provider-absent 两条路径，并保留上一版兼容 fallback。
- `03a–03d` 的模块测试必须同时覆盖依赖齐全的功能分支与直接依赖缺席时的 inert 分支；inert 分支不得设置完整 capability 或状态 public API，仍以本测试固定 PASS 摘要退出 `0`，使任一前序模块可单独回滚而不拖垮已合入测试。
- 实现类 spec 严格串行，不发布、提交或推送。

## 全局约束

- 默认方向：`common` 为唯一可运行内核，Claude/Codex 保留薄适配入口；本决定在门①由人确认。
- 公共 shell API 只接收分离参数，不接受 `eval` 字符串；临时状态使用私有目录、原子写和 trap 清理。
- 超时/重试可配置且有界；只重试幂等查询/重连，不自动重试 `push`、`remount` 等变更。
- 失败日志至少保留阶段、serial/资源 ID、脱敏命令、退出码、stderr 和耗时，不将命令失败误报为业务缺失。
- 新回归只使用 `mktemp` fixture/mock，不依赖已连设备、已安装客户端、网络或真实 AOSP tree。
- 未实测的跨平台、性能、覆盖率或真机时序不写成硬指标，离线 PASS 不宣称为真实 AOSP/设备 PASS。

## spec 列表

| id | 目标（一句话） | 依赖 | 独立判据 | 状态 |
|---|---|---|---|---|
| `01-device-safety` | 关闭错设备操作和真实模式假成功的本计划最高风险缺口 | 无 | `./tests/test-device-safety.sh` 输出 `RESULT PASS  device safety` | ✅ 完成 |
| `02-offline-quality-gate` | 建立根级离线验收和 CI 门禁 | `01-device-safety` | `./scripts/check.sh --offline` 输出统一 PASS | ✅ 已完成 |
| `03-session-state-safety` | 交付安全名称 API 与私有 fd/root foundation 模块 | `02-offline-quality-gate` | `./tests/test-session-state-foundation.sh` 输出 `RESULT PASS  session state foundation` | ✅ 完成 |
| `03a-session-path-safety` | 交付 fully-hardened 私有 path 模块及source/root/static/anchor结构验收 | `03-session-state-safety` | `./tests/test-session-path.sh` 输出 `RESULT PASS  session path safety` | ✅ 完成 |
| `03a1-session-path-race-assurance` | 在任何消费者进入前穷举 path 的三层竞态与 mutation oracle | `03a-session-path-safety` | `./tests/test-session-path-races.sh` 输出 `RESULT PASS  session path race assurance` | ⬜ 未开始 |
| `03b-session-snapshot-safety` | 交付独占的 create-once snapshot write/read 模块 | `03a-session-path-safety`, `03a1-session-path-race-assurance` | `./tests/test-session-snapshot.sh` 输出 `RESULT PASS  session snapshot safety` | ⬜ 未开始 |
| `03c-session-write-interrupts` | 交付独占的 write child/facade/group signal 模块 | `03b-session-snapshot-safety` | `./tests/test-session-signals.sh` 输出 `RESULT PASS  session write interrupts` | ⬜ 未开始 |
| `03d-session-remove-prune` | 交付 remove 模块与 complete-provider aggregator | `03c-session-write-interrupts` | `./tests/test-session-state.sh` 输出 `RESULT PASS  session state` | ⬜ 未开始 |
| `03e-claude-session-lifecycle` | 将 Claude hook/demo 接入完整安全状态 API并验证生命周期 | `03d-session-remove-prune` | `./tests/test-claude-session-lifecycle.sh` 输出 `RESULT PASS  claude session lifecycle` | ⬜ 未开始 |
| `04-runtime-resource-leases` | 为源码、build、device、CVD 提供跨会话独占租约 | `02-offline-quality-gate` | `./tests/test-resource-leases.sh` 输出 `RESULT PASS  resource leases` | ⬜ 未开始 |
| `05-verifier-contract` | 对齐三套 verifier 的断言和 PASS/FAIL/SKIP 契约 | `02-offline-quality-gate` | `./tests/test-verifier-contract.sh` 输出 `RESULT PASS  verifier contract` | ⬜ 未开始 |
| `06-resilient-command-runtime` | 为 ADB/build/CVD 步骤增加超时、诊断、取消和 fail-fast | `04-runtime-resource-leases` | `./tests/test-command-runtime.sh` 输出 `RESULT PASS  command runtime` | ⬜ 未开始 |
| `07-feature-registry-resolver` | 收敛 client registry、manifest schema、resolver 和 branch contract | `02-offline-quality-gate` | `./tests/test-registry-resolver.sh` 输出 `RESULT PASS  registry resolver` | ⬜ 未开始 |
| `08-client-session-adapters` | 收敛 Claude/Codex wrapper 与 Codex session hook，保留 03e 独占的 Claude hook | `03d-session-remove-prune`, `04-runtime-resource-leases`, `07-feature-registry-resolver` | `./tests/test-client-session-adapters.sh` 输出统一 PASS | ⬜ 未开始 |
| `09-verifier-adapters` | 将三套 verifier 入口收敛到共用 contract/runtime | `01-device-safety`, `05-verifier-contract`, `06-resilient-command-runtime`, `07-feature-registry-resolver` | `./tests/test-verifier-adapters.sh` 输出统一 PASS | ⬜ 未开始 |
| `10-docs-and-readiness` | 修复文档漂移并固化环境、安全、验收和未验证边界 | `08-client-session-adapters`, `09-verifier-adapters` | `./scripts/check-docs.sh && ./tests/test-docs.sh` 均退出 `0` | ⬜ 未开始 |

状态：⬜ 未开始 / ⏳ 进行中 / ✅ 完成 / ❌ 不成立

## 审查规模与文件边界

每片的实现 diff 上限是 8 个非生成文件、400 行新增+删除（用 review package 中的 `git diff --numstat` 机械统计）。任一片超限或实际 reviewer 判断全部产出无法在 1 小时内审完，必须回 PLAN 门继续拆片。controller 是 review 完整性 owner：每片维护六列 `seq<TAB>task<TAB>base<TAB>head<TAB>reviewer<TAB>final-status` manifest；验收机械确认 `seq==NR`、task 与 tasks 清单一一对应、首 base 等于 execution BASE、每行 base 等于前行 head、末 head 等于 accepted HEAD、reviewer 非空且 status 全为 `PASS`。

| spec | 独占文件/接口边界 |
|---|---|
| `01` | Claude verifier + build/sepolicy skill、Codex verifier flag、device-safety test |
| `02` | root gate、CI workflow、`tests/COVERAGE.md`、gate test |
| `03` | `session-state-foundation.sh`、`test-session-state-foundation.sh` |
| `03a` | `session-state-path.sh`、`test-session-path.sh`；不修改03文件 |
| `03a1` | `test-session-path-races.sh`；只消费03a provider，不修改03/03a实现和测试 |
| `03b` | `session-state-snapshot.sh`、`test-session-snapshot.sh`；不修改03/03a文件 |
| `03c` | `session-state-signals.sh`、`test-session-signals.sh`；不修改前序模块 |
| `03d` | `session-state-remove.sh`、最终`session-state.sh` aggregator、`test-session-state.sh`、独占 `tests/coverage.d/03d-session-state.md` fragment；不修改02的`tests/COVERAGE.md` |
| `03e` | Claude hook/settings/demo 适配、lifecycle test |
| `04` | lease 公共库、lease 协议文档、resource-leases test |
| `05` | verifier contract 文档、common verifier 断言、contract test |
| `06` | command runtime 库、ADB/build/CVD 执行代码块、runtime test |
| `07` | client registry、resolver/branch checker、manifest adapter、registry test |
| `08` | common client launcher、Claude/Codex wrapper、Codex session hook 薄适配、adapter test；不修改 03e 的 Claude hook |
| `09` | common verifier dispatcher、三个薄 verifier 入口、adapter test |
| `10` | root/clients README、受管长文、docs checker 与 `tests/test-docs.sh` |

## spec 详情

### `01-device-safety`

依据：report “安全与结果语义”。为 Claude verifier/build/sepolicy 部署增加 `ANDROID_SERIAL` 校验，所有 ADB 强制同一 `-s "$serial"`；Codex 真实模式拒绝 `--allow-skip`；mock 证明校验失败时零次 ADB 调用。产出：serial/SKIP 行为契约与 `tests/test-device-safety.sh`。

### `02-offline-quality-gate`

依据：report “工程门禁、可复现性与当前基线”。新建 `scripts/check.sh`：`--offline` 只运行仓库内核心检查，不检测/跳过可选工具，语义跨环境一致；`--ci` 强制固定版本的 ShellCheck/shfmt/有限秘密扫描，少任一工具立即失败。CI 先安装锁定版本再跑 `--ci`。门禁按字典序自动发现存在的 `tests/test-*.sh`，不硬编码任一 provider 文件。产出：根门禁、CI 配置和 `tests/COVERAGE.md` 需求→测试矩阵；数字行/分支覆盖率明确为本轮非目标。

### `03-session-state-safety`

依据：report 的名称/路径风险与 task 1.1/1.2 已独立 review 的 373 行实测。独占交付 `common/.harness/lib/session-state-foundation.sh`：公开 `harness_validate_feature_name <name>`，保留只供后续私有模块消费的 `_harness_session_state_run`、root selector 与 fresh fd 链，但不发布尚未完成 existing-object hardening 的 public path facade。独立 foundation test 证明名称、四级根选择、physical parent、fresh EUID/0700、零副作用和测试隔离。回滚只删除该模块/test；最终 aggregator 因 source 缺失而不设置 capability marker，consumer 自动走 legacy。

### `03a-session-path-safety`

独占交付 `session-state-path.sh`，在 foundation 的 public `harness_validate_feature_name <name>` 与两 private path exports 上补既有 root/project/session 的 nofollow 类型、EUID、0700、name-fd identity 与multi-phase checkpoint。精确私有接口是 `_harness_session_path_core <project-id> <session-id>`：成功唯一输出 physical absolute path+LF并返回0，普通OS错1，协议/安全错2。source 时若三个预期函数缺任一，必须静默返回0且不定义本模块 export/状态public API/marker；独立shfmt-clean测试覆盖source/inert、根选择、隔离、三层静态攻击、fake-python fail-fast、确定性post-mkdir disappearance分类probe，以及三个anchor与三phase在managed helper内的occurrence/位置结构，不执行anchor-driven provider-copy mutation。全部anchor-driven动态race由03a1独占，03a1通过前没有任何消费者进入。

### `03a1-session-path-race-assurance`

只新增shfmt-clean `tests/test-session-path-races.sh`，不修改 provider：复用03a生产文本仅一次的 `MANAGED_BEFORE_OPEN`、`EXPECTED_EUID`、`OS_ERROR` anchor，以单一copy/count/replace/sentinel/scoped-inventory driver穷举root/project/session三层 existing swap（含换入safe dir、link、file）、wrong EUID、EEXIST safe/unsafe/disappearing、mkdir-success replacement、checkpoint-driven mkdir/post-mkdir/open/final-stat消失与真实EIO，并证明made/catch、exact `0|2|1`、无后续创建、所有允许对象完整签名和victim/replacement不被chmod或跟随。03a core缺席时本测试执行inert断言并以同一摘要PASS，使03a可独立回滚。此片不产出运行时API；其验收证据是03b开始前的强制前置门。

### `03b-session-snapshot-safety`

独占交付 `session-state-snapshot.sh`，增加 verified snapshot open、create-once `renameat2(RENAME_NOREPLACE)` write/read、同值/异值竞争、winner 生命周期、软/硬链/属性/内容攻击和 `SNAPSHOT_BEFORE_OPEN`/`OS_ERROR` mutation。精确私有接口：`_harness_session_snapshot_write_core <project-id> <session-id> <feature>` 双流空，首次/同值0、OS错1、安全错2、异值冲突3；`_harness_session_snapshot_read_core <project-id> <session-id>` 成功唯一feature+LF/0，OS错1、安全错2、缺失3。source 时若 `_harness_session_path_core` 缺失则静默返回0且不定义本模块exports/public API/marker；独立测试在依赖present时跑功能矩阵，在真实上游或fixture缺席时验证inert并以同一摘要PASS。回滚本模块后 aggregator 不设置 marker，consumer 自动走 legacy。

### `03c-session-write-interrupts`

独占交付 `session-state-signals.sh`，在 snapshot core 上增加 `TEMP_BEFORE_PUBLISH`、Python owned-temp cleanup、Bash `pending_signal/child_pid/child_rc` facade 与 child/facade/group HUP/INT/TERM。精确私有接口 `_harness_session_write_with_signals <project-id> <session-id> <feature>`：常规双流/返回沿用 snapshot write，HUP/INT/TERM 返回129/130/143，并证明 loser/post-publish/repeated-signal 不删 winner。source 时若 snapshot write/read exports 缺任一则静默返回0且不定义本模块export/public API/marker；独立测试在依赖present时跑功能矩阵，在真实上游或fixture缺席时验证inert并以同一摘要PASS。回滚本模块后 aggregator 不设置 marker，consumer 自动走 legacy。

### `03d-session-remove-prune`

独占交付 `session-state-remove.sh` 与最终 `session-state.sh` aggregator：remove 模块的精确私有接口 `_harness_session_remove_core <project-id> <session-id>` 双流空，成功/缺失0、OS错1、安全错2，并实现 non-creating verified remove、feature 缺失 prune、held parent/child identity、`PRUNE_BEFORE_IDENTITY`、ENOENT/ENOTEMPTY幂等和remove EIO；signals export缺失时 remove模块静默inert。aggregator 先验证五个模块文件路径，再逐个source；任一 source 非零或预期私有函数缺失时自身静默返回1，不设置marker或定义四个状态public API。只有全部成功后才定义public path/write/read/remove并设置`HARNESS_SESSION_STATE_PROVIDER_VERSION=1`；public validate可由foundation单独存在但不代表完整capability。`tests/test-session-state.sh` 在依赖齐全时跑完整集成，在每个模块缺席、source非零或预期export缺失的隔离shell中验证marker未设置、完整五API predicate为false、consumer忽略任何已加载前序函数；两类分支都以固定摘要PASS。coverage只写03d独占fragment。回滚本片或任一前序模块时后序standalone tests、root gate与consumer均保持legacy绿色路径。

### `03e-claude-session-lifecycle`

依据：report “安全与结果语义”、“资源生命周期”和执行期 P5 拆片证据。保留现有 Claude hook/demo 入口，只有 marker 精确为 `1` 且五个 public API 全存在才消费 v1；fixture 至少覆盖完整 provider、aggregator 缺席以及 foundation/path/snapshot/signals/remove 任一模块缺席，所有 partial 状态必须走 legacy。SessionStart 按 source 建立或读取基线，UserPromptSubmit 检查漂移，SessionEnd 同步幂等清理；demo 在成功、受控失败和信号退出时只改自建 `mktemp` 子目录。产出：Claude `SessionStart`/`UserPromptSubmit`/`SessionEnd` 生命周期行为契约与 `tests/test-claude-session-lifecycle.sh`；不新增稳定公共 API。

### `04-runtime-resource-leases`

依据：report “验收强度与契约漂移”中只有文字约束、无运行时锁的结论。实现跨进程组合租约：request TSV 每行为 `domain<TAB>canonical_id<TAB>mode`，`domain=workspace|android`，`mode=source|build|device|cvd`。`workspace` 的 source/build 互斥，`android` 的 device/cvd 互斥；多资源按 `domain+canonical_id` 排序后全部获取或全部释放。workspace ID 是 `realpath` 结果；所有真实 device/CVD 调用必须由上层显式传入同一 `android-instance-id`（安全单组件，不是 serial 或 CVD name），ADB serial/CVD name 只作命令参数、绝不作 lease key；缺少/非法 instance ID 在任一命令前返回 `2`。fixture 使用不同 serial/name+同一 instance ID 验证互斥，并拒绝同一 request 中同 instance 的冲突别名。租约支持有界等待、主动释放和 stale-owner 回收，不抢占存活 owner。产出：`harness_lease_acquire <session-id> <wait-seconds> <request-tsv>` 和 `harness_lease_release <lease-token>`；acquire stdout 唯一 token，release 成功无 stdout；两者返回 `0` 成功、`2` 协议/所有者错、`3` 占用/超时。token 必须与 owner/session/request hash 同时匹配；配套 `tests/test-resource-leases.sh`。

### `05-verifier-contract`

依据：report “验收强度与契约漂移”。定义 boot、system_server、crash baseline、service、package 五项断言及 PASS/FAIL/SKIP/退出码；补齐 common 的 crash/package/baseline；同一 mock 矩阵验证三入口的成功、命令失败、业务缺失、SKIP 和时间边界。产出：`docs/verifier-contract.md`、`tests/test-verifier-contract.sh` 与稳定 CLI `verify-sidebar.sh [--demo] [--since <epoch[.nsec]>] [--allow-skip]`；末行只能为 `RESULT PASS|FAIL|INCOMPLETE` 及可选解释，退出码分别为 `0|1|2`。

### `06-resilient-command-runtime`

依据：report “ADB 可靠性与可诊断性”及 build/CVD 超时未处置项。实现分离参数的命令执行器：查询可有界重试，变更/build 只 fail-fast，reconnect 可有界等待；超时时终止子进程组；保留诊断；更新可执行流程和 build/CVD skill 代码块。产出：`harness_command_run <class> <timeout-seconds> <session-id> <wait-seconds> <lease-request-tsv|-> -- <argv...>`（`class=query|mutate|reconnect|build|cvd`）。当 `04` provider 存在且 request 不是 `-` 时，runtime 内部 acquire/release；provider 缺席时只在 `HARNESS_LEGACY_SINGLE_SESSION=1` 下告警并运行，否则返回 `2`。stdout 仅传透子命令 stdout，stderr 输出诊断，返回 `0`、子命令非零码、`124` 超时或 `2` 协议/租约错；配套 provider-present/provider-absent `tests/test-command-runtime.sh`。

### `07-feature-registry-resolver`

依据：report “工程形态与单一真相源”和“重复代码与扩展点”。将 client 发现改为声明式 registry，收敛 feature resolver、四列 manifest 和 branch contract；先保留 legacy schema 读适配，不迁移 hook/verifier。产出：`common/.harness/clients/<client>/client.conf`（`name`、`command`、`context`、`hook_adapter`），manifest `repo_path<TAB>expected_branch<TAB>build_target<TAB>verify_scope`，以及 `harness_resolve_contract --client <name> --root <path>`；stdout 为排序的 `key=value`，返回 `0` 成功、`2` 配置/schema 错、`1` 运行错。负向测试覆盖重名、缺键、非法 command/context、重复 repo 和畸形列，产出 `tests/test-registry-resolver.sh`。

### `08-client-session-adapters`

依据：report 中 wrapper/hook 重复与 session 漂移。Claude/Codex wrapper 与 Codex session hook 改为消费 `03d` 完整 feature/session API、`04` source/build lease 和 `07` resolver，保留旧命令/链接；Claude 的三个 hook及其生命周期测试由 `03e` 独占，08 不修改或包装这些文件。只有 `HARNESS_SESSION_STATE_PROVIDER_VERSION=1` 且五个 public API 全存在才启用新 provider；完整、aggregator 缺席及五种 missing-module partial fixture 都必须验证，任一不完整状态回退当前 legacy adapter并显式标记 `contract_version=legacy`。产出：`harness_client_launch <client> [--dry-run] -- <client-args...>`，透传客户端退出码，配置错返回 `2`。

### `09-verifier-adapters`

依据：report 中三套 verifier 重复与断言漂移。将三入口收敛到消费 `05` CLI 契约、`06` command runtime 和 `07` registry 的公共 dispatcher，保留旧路径。dispatcher 自带与 `01` 等价、不依赖 legacy 文件的 serial/SKIP 前置层。产出：`harness_verify <feature> [--session-id <safe-id>] [--lease-wait-seconds <0..300>] [--android-instance-id <safe-id>] [contract CLI args...]`；真实 v2 模式强制 session/instance ID，demo 模式可生成进程内唯一 session ID；wait 默认 `0`、只接受显式 CLI 覆盖，不从未约束环境取值。缺少/非法控制参数在 ADB/lease 前返回 `2`；中断必须释放 lease。stdout/退出码与 `05` 相同；`tests/test-verifier-adapters.sh` 覆盖 v2/legacy、`01` present/absent、控制参数缺失/非法、中断释放、未知 feature、畸形 registry 和命令失败。

### `10-docs-and-readiness`

依据：report “文档漂移”与“我没能确认的”。重写定位/快速开始，区分离线 Demo 和真机；文档化环境、gate、serial/租约/超时/严格 PASS；修链接/不存在 skill；为长文设主副本/同步检查；记录未验证真机、跨平台和数字覆盖率。文档同时说明 legacy/v2 capability marker，只引稳定入口，因此允许 `08/09` 回滚。产出：README/契约文档、`scripts/check-docs.sh` 和自动发现包装 `tests/test-docs.sh`；后者保证 `check.sh --offline` 持续阻止链接/副本漂移，但 `10` 的独立验收不依赖 `02` 存在。

## 依赖契约

以下只列直接边，与 spec 表及文本依赖图一一相等：

| 直接边 | provider 产出协议 | consumer 消费方式 |
|---|---|---|
| `01 -> 02` | serial/SKIP 行为；无新 API | `02` 按字典序发现实际存在的 `tests/test-*.sh` |
| `01 -> 09` | fail-closed 行为契约 | `09` 自带等价 preflight，不 source `01` 代码；返回 `2` 代表 serial/flag 协议错 |
| `02 -> 03` | gate 插件约定 `tests/test-*.sh`；`0` PASS/非零 FAIL | `03` 产出可独立执行的 `tests/test-session-state-foundation.sh` |
| `02 -> 04` | 同上 | `04` 产出 `tests/test-resource-leases.sh` |
| `02 -> 05` | 同上 | `05` 产出 `tests/test-verifier-contract.sh` |
| `02 -> 07` | 同上 | `07` 产出 `tests/test-registry-resolver.sh` |
| `03 -> 03a` | `harness_validate_feature_name <name>`：合法0/双流空，非法2/固定错误；`_harness_session_state_foundation_path <project-id> <session-id>` 与 `_harness_session_state_run path <project-id> <session-id>`：path+LF/0，OS错1，安全/arity/op错2 | `03a` 用 public validate 做两ID fail-fast 但映射为自身unsafe错误，产出 `_harness_session_path_core <project-id> <session-id>` 同path结果协议；public validate 或任一 private export absent 时source静默0、不定义export，standalone test以inert摘要PASS |
| `03a -> 03a1` | `_harness_session_path_core <project-id> <session-id>` + 三个生产文本唯一的mutation anchor；path+LF/0、OS错1、安全错2 | `03a1` 只复制provider做穷举race assurance；core缺席时自身test走inert PASS，不定义API |
| `03a -> 03b` | `_harness_session_path_core <project-id> <session-id>`：path+LF/0，OS错1，安全错2；无marker/public path | `03b` 产出 `_harness_session_snapshot_write_core <project-id> <session-id> <feature>` 与 `_read_core <project-id> <session-id>`，协议如详情；path export absent时source静默0且test走inert PASS |
| `03a1 -> 03b` | `test-session-path-races.sh` 固定PASS摘要；无运行时API | controller 只有在03a1验收PASS后才开始03b；03b运行时仍直接消费03a core |
| `03b -> 03c` | snapshot write：双流空、`0|1|2|3`；snapshot read：feature+LF/0或双流按详情返回`1|2|3` | `03c` 产出 `_harness_session_write_with_signals <project-id> <session-id> <feature>`；snapshot exports absent时source静默0且test走inert PASS |
| `03c -> 03d` | `_harness_session_write_with_signals <project-id> <session-id> <feature>`：常规沿用write，信号`129|130|143` | `03d` 产出 `_harness_session_remove_core <project-id> <session-id>`和aggregator；signals export absent时remove inert、aggregator返回1，集成test验证legacy PASS |
| `03d -> 03e` | `session-state.sh` 完整 capability：marker精确`1` + validate/path/write/read/remove 全存在；常规 `0|1|2|3`、remove缺失0、write信号129/130/143 | Claude hook 只有 marker+五API 同时满足才启用；aggregator缺席或任一模块缺席都走legacy并输出compat marker |
| `03d -> 08` | 同上 | Codex/公共 adapter 同时检查 marker+五API；完整、aggregator缺席和五种missing-module fixture覆盖，partial/absent均走legacy并输出 `compat: session-provider=legacy` |
| `04 -> 06` | request TSV + `harness_lease_acquire/release`；`0|2|3` 协议如 spec 详情 | `06` 内部 acquire/release；provider 缺席时只允许显式 legacy 单会话模式 |
| `04 -> 08` | 同上 | `08` 为 source/build 生成 workspace request；provider 缺席时 stderr 输出 `compat: lease-provider=legacy` |
| `05 -> 09` | verifier CLI；末行 `RESULT ...`；退出 `0|1|2` | `09` 原样传递 stdout/退出码；provider 缺席时 legacy verifier 仍经 `01` 等价 preflight |
| `06 -> 09` | `harness_command_run`；stdout 传透、stderr 诊断；`0|child|124|2` | `09` 从自身 CLI 取已校验 session ID、0..300 秒 wait 和 Android instance ID，生成 lease request 并传分离 argv；provider 缺席时走 legacy verifier |
| `07 -> 08` | resolver stdout 固定 key 集 `contract_version,client,command,context,hook_adapter,feature,target_branch,manifest,workflow,verifier,repositories,contract_sha256`，键按 ASCII 排序，值禁止 LF/NUL/`=`；`0|1|2` | 按 key 解析，不依赖行号；provider 缺席时 stderr 输出 `compat: contract_version=legacy` |
| `07 -> 09` | 同上 | 按 registry 定位 verifier/feature；缺席时走 legacy verifier |
| `08 -> 10` | 稳定旧 wrapper 路径 + `contract_version=v2|legacy` capability marker | 文档同时描述两种 marker，不引内部 adapter 路径 |
| `09 -> 10` | 稳定旧 verifier 路径 + `contract_version=v2|legacy` capability marker | 文档同时描述两种 marker，不引内部 dispatcher 路径 |

## 独立回滚矩阵

| spec | 独立回滚路径 | 已合入消费者的行为 |
|---|---|---|
| `01` | 回退 serial/flag 补丁与安全测试 | `02` 只发现现存测试；`09` 的独立 preflight 继续拦截裸 ADB/真实 SKIP，并用 `01`-absent fixture 验证 |
| `02` | 删除根 gate/CI/`tests/COVERAGE.md` | `03–10`（含 `03a–03e`）的独立test与判据均不调用`check.sh`，03d coverage位于独占fragment而不依赖该文件；`10`直接调用`check-docs.sh`/`test-docs.sh` |
| `03` | 删除 foundation 模块与独立测试，不改后序模块文件 | aggregator preflight/source 失败，marker 未设置且完整五API predicate 为 false；`03e/08` 的 missing-foundation fixture 自动转 legacy |
| `03a` | 删除 path 模块与独立测试，不改 foundation/后序模块 | aggregator preflight/source 失败，marker 未设置且完整五API predicate 为 false；`03e/08` 的 missing-path fixture 自动转 legacy |
| `03a1` | 删除独立race assurance test，不改provider或后序模块 | 无运行时API，03b及后序行为不变；只失去额外门禁证据，可单独恢复该测试 |
| `03b` | 删除 snapshot 模块与独立测试，不改其他模块 | aggregator preflight/source 失败，marker 未设置且完整五API predicate 为 false；`03e/08` 的 missing-snapshot fixture 自动转 legacy |
| `03c` | 删除 signals 模块与独立测试，不改其他模块 | aggregator preflight/source 失败，marker 未设置且完整五API predicate 为 false；`03e/08` 的 missing-signals fixture 自动转 legacy |
| `03d` | 删除 remove模块、aggregator、集成测试和独占coverage fragment，不改前序私有模块或02文件 | marker未设置且完整五API predicate为false；foundation的public validate可单独存在，`03e/08`仍自动转legacy且不丢旧入口 |
| `03e` | 回退 Claude hook/settings/demo 接入 | `03d` 完整 provider与测试不依赖03e；08不修改03e独占hook |
| `04` | 回退 lease provider | `06` 只在 `HARNESS_LEGACY_SINGLE_SESSION=1` 下告警运行，否则返回 `2`；`08` 走已保留的 legacy adapter；两者均有 provider-absent fixture |
| `05` | 回退 contract 文档/共用断言 | `09` 的 legacy fixture 保持旧 verifier 入口可运行 |
| `06` | 回退 command runtime/skill 更新 | `09` 自动使用仍符合 `01` 基线的 legacy verifier |
| `07` | 回退 registry/resolver/schema，保留 legacy 数据 | `08/09` 的 legacy fixture 验证回退路径 |
| `08` | 回退 client/session adapter | `09` 不依赖 `08`；`10` 只引稳定入口 |
| `09` | 回退 verifier adapter | `08` 不依赖 `09`；`10` 的契约文档仍适用 legacy 入口 |
| `10` | 单独回退文档/check-docs | 不影响任何运行时和回归 |

每个存在可回滚 provider 依赖的 consumer 必须包含对应 present/absent fixture；对 session provider，`03e/08` 还必须逐个覆盖 foundation/path/snapshot/signals/remove 缺席以及 aggregator 缺席，断言 marker 与五API不会形成 partial capability。`01/02/10` 没有此类 provider 前置，不适用该要求。

session 模块的回滚验收命令固定如下；对应测试脚本必须实现这些 test-only 参数，默认无参数运行在真实依赖缺席时执行相同 inert 断言，所有成功摘要仍与 spec 表一致：

| 回滚目标 | 已合入后序测试必须保持绿色的命令 |
|---|---|
| `03` | `./tests/test-session-path.sh --dependency-absent && ./tests/test-session-path-races.sh --dependency-absent && ./tests/test-session-snapshot.sh --dependency-absent && ./tests/test-session-signals.sh --dependency-absent && ./tests/test-session-state.sh --session-provider-fixture missing-foundation && ./tests/test-claude-session-lifecycle.sh --session-provider-fixture missing-foundation && ./tests/test-client-session-adapters.sh --session-provider-fixture missing-foundation` |
| `03a` | `./tests/test-session-path-races.sh --dependency-absent && ./tests/test-session-snapshot.sh --dependency-absent && ./tests/test-session-signals.sh --dependency-absent && ./tests/test-session-state.sh --session-provider-fixture missing-path && ./tests/test-claude-session-lifecycle.sh --session-provider-fixture missing-path && ./tests/test-client-session-adapters.sh --session-provider-fixture missing-path` |
| `03a1` | 无运行时consumer；删除本测试后 `./tests/test-session-snapshot.sh` 与后序测试行为不变 |
| `03b` | `./tests/test-session-signals.sh --dependency-absent && ./tests/test-session-state.sh --session-provider-fixture missing-snapshot && ./tests/test-claude-session-lifecycle.sh --session-provider-fixture missing-snapshot && ./tests/test-client-session-adapters.sh --session-provider-fixture missing-snapshot` |
| `03c` | `./tests/test-session-state.sh --session-provider-fixture missing-signals && ./tests/test-claude-session-lifecycle.sh --session-provider-fixture missing-signals && ./tests/test-client-session-adapters.sh --session-provider-fixture missing-signals` |
| `03d` | `./tests/test-claude-session-lifecycle.sh --session-provider-fixture absent && ./tests/test-client-session-adapters.sh --session-provider-fixture absent`；另以 `missing-remove` 覆盖保留aggregator但remove模块回退 |

## report 遗留项去向

| 遗留/冲突 | 去向 |
|---|---|
| 离线 Demo 与真实 ADB 定位矛盾 | `10` 明确分层入口与证据边界 |
| common verifier 弱、Codex `--allow-skip` 冲突 | `01` + `05` |
| 三套 Demo 是否永久独立 | 门①确认默认 canonical-core 方案 |
| 真机/CVD/AOSP 时序未验证 | 不做性能结论；`06` 只用 mock 定义超时/取消，`10` 列待真机矩阵 |
| build/CVD 命令缺超时/取消 | `06` 的 `build|cvd` class 与 skill 代码块 |
| 跨平台未验证 | `02` 只声明 CI 实跑平台；`10` 列其他平台为未支持/待验证 |
| 数字覆盖率未知 | `02` 产出需求→测试矩阵；数字行/分支覆盖率本轮明确不承诺 |
| 路径逃逸/软链/并发竞争未实测 | `03a–03d` 按安全边界执行 provider 探针，`03e` 验证 hook/demo 消费边界 |
| 源码/build/device/CVD 无租约 | `04` 实现，`06/08` 消费 |
| 文档断链/副本漂移 | `10` + `scripts/check-docs.sh` |

## 依赖图

```text
01 --> 02
01 --> 09
02 --> 03
03 --> 03a
03a --> 03a1
03a --> 03b
03a1 --> 03b
03b --> 03c
03c --> 03d
03d --> 03e
02 --> 04
02 --> 05
02 --> 07
03d --> 08
04 --> 06
04 --> 08
05 --> 09
06 --> 09
07 --> 08
07 --> 09
08 --> 10
09 --> 10
```

实施顺序固定为 `01 → 02 → 03 → 03a → 03a1 → 03b → 03c → 03d → 03e → 04 → 05 → 06 → 07 → 08 → 09 → 10`。`01` 先关闭单点安全风险；`02` 建防线；`03a1` 在任何path consumer进入前补全穷举race assurance；`03–03c` 逐个交付互不叠改的私有模块，`03d` 才由 aggregator 原子发布完整五API capability，`03e` 再接 Claude 生命周期；然后锁定资源、交付语义和执行时；最后收敛 registry/session/verifier 并更新文档。

## 资源冲突

- 16 个 spec 均为实现或验收代码片，必须按上述顺序串行。
- `01/05/06/09` 会触及 verifier/设备路径；`03–03c` 各自独占不同私有模块/test，`03a1`只拥有独立race test，`03d` 独占remove、aggregator、最终集成test和coverage fragment，因接口依赖仍串行但没有跨spec同文件叠改；`03e`独占Claude hook而`08`只修改wrapper/Codex hook；`07/08/09`触及resolver/adapter，不允许重叠实施。
- 真实运行时使用 `04` 的组合 lease：同一 canonical workspace 的 source/build 互斥，同一 Android instance 的 device/cvd 互斥；多租约按稳定键排序后全有或全无获取，不允许部分占有。
- 所有测试使用独立 `mktemp` fixture/mock，不共享真实设备、CVD、AOSP tree 或外部环境。

## 待人审确认的口径

默认决定：保留三个顶层 Demo 和现有用户入口，但把可运行公共逻辑收敛到 `common/.harness`；Claude/Codex 只保留适配、上下文和兼容路径。如果三套必须继续可单独复制、无跨目录依赖，则 `07–09` 需改为“生成/同步共享逻辑”。
