# 2026-08-31-aosp-harness-refactor 拆分计划 v6.1

> 上游：`research/report.md`
> v5.3 依据：03 task 1.1/1.2 的真实 diff 与增量 PLAN review 证明 359/400 行 sizing prototype 失真且 1400 行例外不满足 P5；按安全完成边界拆为互不叠改的私有模块，只有最终 aggregator 发布完整 capability。
> v5.3.1 依据：03a design review round 1 发现其实现必须实际消费 foundation public validate，原依赖边只把两 private export 写作 provider 能力，无法机械解释 source guard 与 fail-fast；本版只补齐既有 `03 -> 03a` 边的第三个既存签名，不改变图、顺序、owner 或验收门。
> v5.4 依据：03a design review round 2 证明 311 行 sizing 原型只执行1个fresh case，无法把完整三层竞态fixture压入剩余89行。03a保留private provider与功能/静态/代表性竞态验收；新增只拥有独立race test的03a1，在任何消费者进入前完成穷举竞态保证。
> v5.5 依据：03a task4 fix1实测未格式化包397行，但pinned shfmt后为527行；把root代表性race留在03a仍无法同时满足格式门和400行/P5。全部anchor-driven provider-copy mutation移到03a1，03a只保留完整private provider、source/root/static、确定性错误分类probe和anchor结构验收。round2可运行原型实测03a exact2为392/400，03a1三层共享driver为269/400并执行19个代表case，完整37-case矩阵剩18个data rows/calls。
> v5.6 依据：03a1 round6把全部37-case、完整对象delta oracle与14项active self-disproof放入单文件后，固定格式实测411/400，再次证伪原边界。round7将测试专用private Python driver与默认发现shell matrix真实拆开，补齐路径隔离后分别实测400/400与109/400；driver独立self-test，entrypoint独立生成/核对37 rows，因而新增03a2并让03b等待dependency-present的03a2穷举验收。
> v5.7 依据：03b requirements round1证明原03c无法访问封装在03b Python worker内的owned temp/publish点，且259行代表原型没有覆盖完整rename/mutation oracle。把child信号处理、owned-temp cleanup和`TEMP_BEFORE_PUBLISH`归还03b worker，03c只做可组合的Bash转发facade；新增只拥有默认发现穷举测试的03b1，在其dependency-present证据通过前禁止03c启动。design round2 cleanup优先级修复后的fixed-format核心208行+基础测试192行实跑400/400，补齐四态source rc/双流/完整inventory/export属性、strict worker、held capture、字节级read、并发winner、close前ownership transfer、early-second latch、post-rename winner、signal+cleanup-close-error的全fd遍历与静态攻击整树delta并使exact2 ShellCheck全绿；03b1完整active-family runnable prototype再以exact1=308/400、240项调用/状态delta、换入对象身份/shape、EEXIST全oracle前temp清理/完整winner指纹、四个信号线性化/cleanup窗口、固定工具全绿证明单文件边界可实施。
> v5.8 依据：04 design round1以真实探针证明原387/400原型存在CLI假绿，且缺strict record/global overlap、工具与输出I/O收敛、Python3.8兼容及tombstone恢复；完整R9矩阵不可能进入余13行。04保留完整runtime/docs与每类核心机制至少一个基础回归，修复四项后fixed-shfmt runnable exact3实测336+7+57=400/400；新增04a独占完整mutation/I/O/concurrency/adapter assurance，其runnable exact1原型398/400，并只替换生产文本唯一test seam做故障注入；04a的dependency-present证据通过前禁止05/06/08启动，严格串行的NEXT改为04a再05。
> v5.9 依据：04a requirements起草前在已合入04 provider上实跑398行转交assurance原型，稳定复现`FAIL monotonic attempt count`：资源扫描后首次观测deadline到达时直接rc3，未进入最后一次无sleep锁尝试。隔离provider只替换该分支相邻两行；requirements round1再按全局churn口径和负向oracle findings把assurance收敛为fixed-shfmt 396行，补齐七类damaged provider、三种真实absent入口、同owner异mode、tracked hash/repo外fixture与mutant双流反证。修订原型default/all/`--dependency-absent`三路逐字PASS，provider diff `2增2删`加assurance `396增0删`恰为400行新增+删除。因此04a收窄为exact两文件的相邻修复+穷举保证，不改public API/文档/基础测试，仍在任何消费者前验收。
> v6.0 依据：05 requirements round1独立review的B1证明“05同测三入口”与文件表“05只拥有common、09拥有三个薄入口”互相冲突，且三套331/156/120行既有实现加文档与完整矩阵没有400行sizing证据；round2 P-B1进一步证明05若修改既有common入口，仍会与09重叠且无法独立回滚。05因此新增不被09改写的canonical CLI并独占contract doc/test；09在消费05/06/07后独占三个旧入口、dispatcher、legacy fallback与parity，05回滚时以canonical文件物理缺席无歧义切回fallback。
> v6.1 依据：05 design round1的B1证明canonical provider若只在内部直接执行ADB并丢弃stderr，09在永不修改05的owner边界下无法把06逐query timeout/retry/diagnostics组合进来；新增私有分离argv runner seam闭合05→09与06→09。B2–B4/I1–I2又证明原368/400 prototype缺完整case oracle、argv边界、cleanup门、文档全表及bytes grammar，补齐无法落入余32行。05保留provider、完整doc和代表性base test，新增05a exact1穷举assurance；05a active证据前禁止06/09启动。

## 总目标

在保留 `claude-code/`、`codex/`、`common/` 现有入口和离线 Demo 能力的前提下，将安全、设备/进程调用、资源租约、验收契约和 feature/session 基础能力收敛为公共内核，并用单一离线门禁阻止三套实现再次漂移。

整体验收：

- `./scripts/check.sh --offline` 退出 `0`，末行为 `RESULT PASS  aosp-harness offline quality gate`。
- `./tests/test-device-safety.sh && ./tests/test-session-path-races.sh && ./tests/test-session-snapshot-assurance.sh && ./tests/test-session-state.sh && ./tests/test-claude-session-lifecycle.sh && ./tests/test-resource-leases.sh && ./tests/test-resource-leases-assurance.sh && ./tests/test-verifier-contract.sh && ./tests/test-verifier-contract-assurance.sh && ./tests/test-command-runtime.sh && ./tests/test-registry-resolver.sh && ./tests/test-client-session-adapters.sh && ./tests/test-verifier-adapters.sh` 全部退出 `0`。
- Claude、Codex、common 三套旧回归全部退出 `0`；`git diff --check` 退出 `0`。
- 默认验收全程不连真实 ADB/CVD，不跑 AOSP build，不改被跟踪的 `CURRENT_FEATURE`，不残留 session/lease 文件。

整体不变量：

- 三个顶层目录和已文档化的 wrapper/demo/test 路径保留；可改为薄适配，但不删入口。
- 真实模式在首次 ADB 调用前必须固定安全 serial；无/非法 serial、查询失败或必需断言 SKIP 时不得退出 `0`。
- 严格 PASS 至少覆盖 boot、system_server、crash baseline、service、package 五项，不降低现有 Codex 负向测试强度。
- 每个存在可回滚 provider 依赖的 consumer，都要在 fixture 中验证 provider-present/provider-absent 两条路径，并保留上一版兼容 fallback。
- `03a`及`03a2–03d`（含03b1）的默认测试必须同时覆盖依赖齐全的功能分支与直接依赖缺席时的 inert 分支；inert 分支不得设置完整 capability 或状态 public API，仍以本测试固定 PASS 摘要退出 `0`，使任一前序模块可单独回滚而不拖垮已合入测试。`03a1`是不进入默认发现的private driver，以独立self-test验收。
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
| `03a1-session-path-race-assurance` | 交付不进入默认发现的path race私有driver与自反证oracle | `03a-session-path-safety` | `python3 tests/lib/session-path-race-driver.py self-test common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh` 输出 `RESULT PASS  session path race driver` | ✅ 完成 |
| `03a2-session-path-race-matrix` | 在任何path consumer前以37-row默认入口穷举三层竞态 | `03a-session-path-safety`, `03a1-session-path-race-assurance` | dependency-present时driver `protocol`/`self-test`与`./tests/test-session-path-races.sh`均退0，入口内部37/37及九类计数逐字通过，末摘要为`RESULT PASS  session path race assurance` | ✅ 完成 |
| `03b-session-snapshot-safety` | 交付signal-aware create-once snapshot worker/write/read模块 | `03-session-state-safety`, `03a-session-path-safety`, `03a2-session-path-race-matrix` | `./tests/test-session-snapshot.sh` 输出 `RESULT PASS  session snapshot safety` | ✅ 完成 |
| `03b1-session-snapshot-assurance` | 在signals facade前穷举snapshot mutation/publish/child signal | `03b-session-snapshot-safety` | dependency-present时`./tests/test-session-snapshot-assurance.sh`输出`RESULT PASS  session snapshot assurance`且完整矩阵全PASS | ✅ 完成 |
| `03c-session-write-interrupts` | 交付独占的 write facade/group signal 模块 | `03b-session-snapshot-safety`, `03b1-session-snapshot-assurance` | `./tests/test-session-signals.sh` 输出 `RESULT PASS  session write interrupts` | ✅ 完成 |
| `03d-session-remove-prune` | 交付 remove 模块与 complete-provider aggregator | `03c-session-write-interrupts` | `./tests/test-session-state.sh` 输出 `RESULT PASS  session state` | ✅ 完成 |
| `03e-claude-session-lifecycle` | 将 Claude hook/demo 接入完整安全状态 API并验证生命周期 | `03d-session-remove-prune` | `./tests/test-claude-session-lifecycle.sh` 输出 `RESULT PASS  claude session lifecycle` | ✅ 完成 |
| `04-runtime-resource-leases` | 为源码、build、device、CVD 提供跨会话独占租约 | `02-offline-quality-gate` | `./tests/test-resource-leases.sh` 输出 `RESULT PASS  resource leases` | ✅ 完成 |
| `04a-runtime-resource-lease-assurance` | 修复deadline最后一次无sleep锁尝试并穷举状态损坏、I/O与并发矩阵 | `04-runtime-resource-leases` | dependency-present时`./tests/test-resource-leases-assurance.sh`输出`RESULT PASS  resource lease assurance`且完整矩阵全PASS | ✅ 完成 |
| `05-verifier-contract` | 交付独立 canonical verifier、逐query runner seam与基础合同 | `02-offline-quality-gate`, `04a-runtime-resource-lease-assurance` | `./tests/test-verifier-contract.sh` 输出 `RESULT PASS  verifier contract` | ✅ 完成 |
| `05a-verifier-contract-assurance` | 在任何runtime/adapter消费者前穷举verifier grammar、CLI、argv与失败矩阵 | `05-verifier-contract` | dependency-present时`./tests/test-verifier-contract-assurance.sh`输出`RESULT PASS  verifier contract assurance`且完整manifest全PASS | ✅ 完成 |
| `06-resilient-command-runtime` | 为 ADB/build/CVD 步骤增加超时、诊断、取消和 fail-fast | `04-runtime-resource-leases`, `04a-runtime-resource-lease-assurance`, `05a-verifier-contract-assurance` | `./tests/test-command-runtime.sh` 输出 `RESULT PASS  command runtime` | ⬜ 未开始 |
| `07-feature-registry-resolver` | 收敛 client registry、manifest schema、resolver 和 branch contract | `02-offline-quality-gate` | `./tests/test-registry-resolver.sh` 输出 `RESULT PASS  registry resolver` | ⬜ 未开始 |
| `08-client-session-adapters` | 收敛 Claude/Codex wrapper 与 Codex session hook，保留 03e 独占的 Claude hook | `03d-session-remove-prune`, `04-runtime-resource-leases`, `04a-runtime-resource-lease-assurance`, `07-feature-registry-resolver` | `./tests/test-client-session-adapters.sh` 输出统一 PASS | ⬜ 未开始 |
| `09-verifier-adapters` | 将三套 verifier 入口收敛到共用 contract/runtime | `01-device-safety`, `05-verifier-contract`, `05a-verifier-contract-assurance`, `06-resilient-command-runtime`, `07-feature-registry-resolver` | `./tests/test-verifier-adapters.sh` 输出统一 PASS | ⬜ 未开始 |
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
| `03a1` | `tests/lib/session-path-race-driver.py`；不进入默认发现，不修改03/03a实现和测试 |
| `03a2` | `tests/test-session-path-races.sh`；只消费03a provider与03a1 private driver，不修改前序文件 |
| `03b` | `session-state-snapshot.sh`、`test-session-snapshot.sh`；不修改03/03a文件 |
| `03b1` | `tests/test-session-snapshot-assurance.sh`；只消费03b provider，不修改前序文件 |
| `03c` | `session-state-signals.sh`、`test-session-signals.sh`；不修改前序模块 |
| `03d` | `session-state-remove.sh`、最终`session-state.sh` aggregator、`test-session-state.sh`、独占 `tests/coverage.d/03d-session-state.md` fragment；不修改02的`tests/COVERAGE.md` |
| `03e` | Claude hook/settings/demo 适配、lifecycle test |
| `04` | lease 公共库、lease 协议文档、resource-leases test |
| `04a` | `common/.harness/lib/resource-leases.sh`的deadline两行相邻修复；`tests/test-resource-leases-assurance.sh`完整保证 |
| `05` | 新增 `common/.harness/bin/verify-sidebar.sh` canonical CLI/private query-runner seam、完整contract文档、代表性base test；不修改三个旧入口 |
| `05a` | 新增 `tests/test-verifier-contract-assurance.sh`；只消费05 provider/doc，不修改05 exact3或后序文件 |
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

独占交付 `session-state-path.sh`，在 foundation 的 public `harness_validate_feature_name <name>` 与两 private path exports 上补既有 root/project/session 的 nofollow 类型、EUID、0700、name-fd identity 与multi-phase checkpoint。精确私有接口是 `_harness_session_path_core <project-id> <session-id>`：成功唯一输出 physical absolute path+LF并返回0，普通OS错1，协议/安全错2。source 时若三个预期函数缺任一，必须静默返回0且不定义本模块 export/状态public API/marker；独立shfmt-clean测试覆盖source/inert、根选择、隔离、三层静态攻击、fake-python fail-fast、确定性post-mkdir disappearance分类probe，以及三个anchor与三phase在managed helper内的occurrence/位置结构，不执行anchor-driven provider-copy mutation。全部anchor-driven动态race的共享oracle由03a1独占，默认37-case矩阵由03a2独占，两片通过前没有任何path consumer进入。

### `03a1-session-path-race-assurance`

只新增`tests/lib/session-path-race-driver.py`，不修改provider，不进入root gate默认发现。driver独占only-anchor copy/replace、有序hook oracle、完整signature/inventory/delta、swap subtree rekey、mkdir runtime-original、family executor与14项active self-disproof；`self-test` 在driver内构造自足矩阵，不读取未来entrypoint。私有CLI固定为`protocol`、`self-test <foundation> <provider>`与`run-matrix <foundation> <provider> <absent-workspace> <case-tsv> <case-log>`；protocol唯一输出`session-path-race-driver-v1\n`，self-test与run-matrix成功均唯一输出`RESULT PASS  session path race driver\n`且stderr空。workspace必须先不存在并由driver以0700创建；TSV只允许`id/family/layer/variant`固定列枚举数据，不接受代码或表达式。unknown mode/CLI misuse返2，协议内容、row、oracle或执行失败返1；任何失败都不打印private PASS。此片不发布运行时API、环境marker或capability。验收必须在完整历史与真实file-URL depth-1 checkout的accepted HEAD分别运行private self-test，不得查询固定历史SHA。

### `03a2-session-path-race-matrix`

只新增shfmt-clean `tests/test-session-path-races.sh`：从自身路径解析repo root，生成并在driver调用前后独立核对37个唯一row及九类计数`9/3/9/3/3/3/3/3/1`，通过03a1 private CLI穷举root/project/session三层race并唯一输出`RESULT PASS  session path race assurance\n`。顺序固定为：先拒绝参数/自有matrix损坏；provider缺席inert；provider存在时先验三anchor各一次；driver物理缺席inert，但存在且非普通文件、是symlink、protocol/语法/执行失败则fail closed；随后`--dependency-absent`、foundation缺席或core unavailable才走同一零case inert oracle；其余必须真实`run-matrix`。inert摘要不能作为本片验收证据；controller必须另证accepted HEAD上provider/driver present、默认入口实跑37个case和九类计数，并在完整历史与真实file-URL depth-1 checkout分别运行默认入口和`bash ./scripts/check.sh --offline`。

### `03b-session-snapshot-safety`

独占交付 `session-state-snapshot.sh`，增加held-fd path capture、逐层managed reopen、verified snapshot open、create-once `renameat2(RENAME_NOREPLACE)` write/read及Python child信号清理。精确私有接口：spawn-only `_harness_session_snapshot_worker write <project-id> <session-id> <feature>`与`_harness_session_snapshot_worker read <project-id> <session-id>`由调用方放入独立进程后最终`exec python3`且PID不变。write core与worker write始终双流空，首次/同值0、OS错1、安全/协议错2、异值冲突3、HUP/INT/TERM为129/130/143；read core与worker read成功唯一stdout为feature+LF、stderr空/0，失败双流空且OS错1、安全/协议错2、缺失3。worker拥有本调用temp与publish提交点；首次HUP/INT/TERM必须先ignore三种后续信号再进入finally，以首信号码返回，只清未发布owned temp、绝不回滚winner。source时若public validate或path core缺失则静默返回0且不定义三个本模块exports/public API/marker；同片默认测试验source/inert、基础功能/静态攻击/竞态、TEMP barrier后的真实worker PID、连续TERM+HUP首信号码/temp清理及anchor结构，完整provider-copy穷举由03b1独占。

### `03b1-session-snapshot-assurance`

只新增shfmt-clean `tests/test-session-snapshot-assurance.sh`，不修改snapshot provider。入口用provider-copy逐项反证held capture fd不受同名路径重建影响、managed与snapshot stat→open mutation、无特权wrong-owner、短读、真实EIO、libc symbol缺失、ENOSYS以及确定性EEXIST后same/different/disappear/unsafe；并核对全部marker精确一次、无rename/link fallback、winner/victim/temp完整delta及child HUP/INT/TERM清理。provider物理缺席时默认与`--dependency-absent`走同一零case inert摘要；provider存在但类型/marker/协议损坏必须fail closed。完整runtime/base prototype `a708ce6f0979c6644292b58b4a7b0d4afcdf821d`经固定shfmt、exact-file ShellCheck、bash-n及实跑全绿，03b core/base 208+192=400/400且worker misuse在capture前返回并保持state root缺席，source后只留下三个约定export，capture anchor再钉pathname absent、0600/nlink0与Python fd消费；03b1 prototype `cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e`单文件308/400、240项调用/状态delta，所有失败检查双流，managed/snapshot换入对象核对注入身份与精确shape，EEXIST核对完整winner且全oracle前temp已清，post-close/early-second/post-rename-success/signal+cleanup-close-error四行核五次close、锁存rc和namespace，保留92行给inert/CLI/controller整合。controller只有在dependency-present完整矩阵、exact1/400、full/depth-1/offline与回滚证据入ledger后才允许03c启动；inert PASS不能解除顺序门。

### `03c-session-write-interrupts`

独占交付 `session-state-signals.sh`，只在已由03b/03b1验收的signal-aware snapshot worker上增加Bash `pending_signal/child_pid/child_rc` facade、spawn-gap补转发、facade first-signal-wins与facade/process-group HUP/INT/TERM；不复制temp/publish逻辑、不修改snapshot模块。精确私有接口 `_harness_session_write_with_signals <project-id> <session-id> <feature>`：常规双流/返回沿用snapshot write，HUP/INT/TERM返回129/130/143。source时必须同时验证worker/write/read三个exports，任一缺席都静默inert且不定义signals export/public API/marker；独立测试逐个覆盖三export缺席及facade/group矩阵。回滚本模块后aggregator不设置marker，consumer自动走legacy。

### `03d-session-remove-prune`

独占交付 `session-state-remove.sh` 与最终 `session-state.sh` aggregator：remove 模块的精确私有接口 `_harness_session_remove_core <project-id> <session-id>` 双流空，成功/缺失0、OS错1、安全错2，并实现 non-creating verified remove、feature 缺失 prune、held parent/child identity、`PRUNE_BEFORE_IDENTITY`、ENOENT/ENOTEMPTY幂等和remove EIO；signals export缺失时 remove模块静默inert。aggregator 先验证五个模块文件路径，再逐个source；任一 source 非零或预期私有函数缺失时自身静默返回1，不设置marker或定义四个状态public API。只有全部成功后才定义public path/write/read/remove并设置`HARNESS_SESSION_STATE_PROVIDER_VERSION=1`；public validate可由foundation单独存在但不代表完整capability。`tests/test-session-state.sh` 在依赖齐全时跑完整集成，在每个模块缺席、source非零或预期export缺失的隔离shell中验证marker未设置、完整五API predicate为false、consumer忽略任何已加载前序函数；两类分支都以固定摘要PASS。coverage只写03d独占fragment。回滚本片或任一前序模块时后序standalone tests、root gate与consumer均保持legacy绿色路径。

### `03e-claude-session-lifecycle`

依据：report “安全与结果语义”、“资源生命周期”和执行期 P5 拆片证据。保留现有 Claude hook/demo 入口，只有 marker 精确为 `1` 且五个 public API 全存在才消费 v1；fixture 至少覆盖完整 provider、aggregator 缺席以及 foundation/path/snapshot/signals/remove 任一模块缺席，所有 partial 状态必须走 legacy。SessionStart 按 source 建立或读取基线，UserPromptSubmit 检查漂移，SessionEnd 同步幂等清理；demo 在成功、受控失败和信号退出时只改自建 `mktemp` 子目录。产出：Claude `SessionStart`/`UserPromptSubmit`/`SessionEnd` 生命周期行为契约与 `tests/test-claude-session-lifecycle.sh`；不新增稳定公共 API。

### `04-runtime-resource-leases`

依据：report “验收强度与契约漂移”中只有文字约束、无运行时锁的结论，以及04 design round1的sizing/strict-state证据。实现跨进程组合租约：request TSV 每行为 `domain<TAB>canonical_id<TAB>mode`，`domain=workspace|android`，`mode=source|build|device|cvd`。任意 owner 对同一规范键的同/异 mode 都互斥；多资源按 `domain+canonical_id` 排序后以单一active record全部publish或全部unpublish。workspace ID 是调用PWD解析的 `realpath`；真实 device/CVD 上层显式传同一安全 `android-instance-id`，serial/CVD name绝不作key。owner固定为`EUID+$$+/proc starttime`；active/tombstone记录必须严格解码、拒绝重复JSON键与全局key重叠，工具/状态/I/O错误收敛为固定rc2，Python最低3.8，tombstone在后续受锁操作安全恢复。产出：`harness_lease_acquire <session-id> <wait-seconds> <request-tsv>` 和 `harness_lease_release <lease-token>`；acquire成功stdout唯一token+LF，release成功双流空；返回`0`成功、`2`协议/所有者/状态/I/O错、`3`占用/超时。基础测试必须真实覆盖source/CLI、完整重入与self-overlap、异owner占用、不相交、stale、规范输入、严格stored record、fake Python、tombstone与完整inventory；穷举主动反证由04a独占。

### `04a-runtime-resource-lease-assurance`

只在`common/.harness/lib/resource-leases.sh`替换deadline相邻两行：资源扫描后首次观测deadline到达时立即continue，下一轮完成最后一次无sleep锁尝试，并由既有锁后deadline检查在读取record或发布前返回3；不改变public API、文档、基础测试、成功/错误双流或状态格式。另新增默认发现且shfmt-clean的`tests/test-resource-leases-assurance.sh`，复制修复后的provider并通过生产文本唯一的`HARNESS_RESOURCE_LEASE_TEST_SEAM`注入确定性故障，穷举TSV/root形态、同owner子集/超集/部分重叠、反向多键barrier、PID复用与monotonic最终尝试、全部record字段/duplicate JSON/global overlap、open/write/fsync/replace/unlink/flock异常、closed output/fake Python、假adapter相同instance ID零命令执行及mutant自反证。provider物理缺席时默认、`all`与`--dependency-absent`走零active-case inert PASS；provider存在但类型、anchor、source/API或协议损坏必须fail closed。验收硬门为exact两文件、provider `2增2删`加assurance `396增0删`，新增+删除合计400行；只有dependency-present完整矩阵、full/depth-1/offline与回滚证据入ledger才能启动05/06/08，inert PASS不能解除门禁。在这些证据齐全前，规范ID `05-verifier-contract`（日期前缀由创建日决定）的spec目录、同名`spec/`分支/worktree、ledger execution BASE与dispatch记录五类资产必须物理缺席，之后才解除NEXT门。

### `05-verifier-contract`

依据：report “验收强度与契约漂移”、05 requirements round1 B1/round2 P-B1及design round1 B1–B4/I1–I2。定义boot、system_server、crash baseline、service、package五项断言及PASS/FAIL/SKIP/退出码；新增不与旧入口重叠的common canonical CLI。其私有`HARNESS_VERIFIER_QUERY_RUNNER`在真实模式预检绝对路径/EUID owner/普通非symlink/可执行，随后以`query-key -- adb -s serial argv...`逐query传递分离参数，捕获stdout、继承stderr并保留rc，使09无需改provider即可绑定06；未设置则直接ADB且抑制stderr。完整文档固定CLI优先级、六query、bytes/LF/CR grammar、runner信任边界、十二fixture及输出协议；base test只验证逐字demo/real主链、六/五query argv、runner双流/rc和代表preflight，显式安全清理后才PASS。三个旧入口在05中不改，09独占dispatcher、三个薄入口、legacy fallback及parity。产出exact3：`docs/verifier-contract.md`、`tests/test-verifier-contract.sh`与稳定CLI `common/.harness/bin/verify-sidebar.sh [--demo] [--since <epoch[.nsec]>] [--allow-skip]`；末行只能为`RESULT PASS|FAIL|INCOMPLETE`及受控可选解释，退出码分别为`0|1|2`。门③前必须以fixed-format runnable exact3 core prototype证明真实执行与added+removed≤400；05a全矩阵不得复制进本片。

### `05a-verifier-contract-assurance`

只新增默认发现、fixed-shfmt的`tests/test-verifier-contract-assurance.sh`，不修改05 provider/doc/base test。dependency-present时用repo外EUID自有0700空普通目录、长度保真argv日志和唯一case ID/manifest，逐case核完整五detail固定顺序、summary算术、terminal/rc、双流、精确调用次数/顺序/serial：覆盖六query failure、R4每个适用格、严格/探索SKIP、default/explicit baseline、btime零/多/畸形且零logcat、空/早期/header/前导空白/等于/晚于/纳秒/畸形ASCII数字/Unicode digit/非法UTF-8、LF/CRLF、全部ASCII service分隔/尾空白及非法Unicode/control、flag重复/help组合/since缺值多值非法/unknown/positional、serial缺失/非法/两个边界合法、runner absent/非法/spawn failure/diagnostic/rc；并机械比对help、doc中的query/fixture集合与production anchor，至少以删case、交换argv、放宽parser/grammar、cleanup前PASS四类mutant证明oracle自反证。provider物理缺席时default与`--dependency-absent`走零active-case inert PASS；provider/doc/base test任一存在但类型、symlink、anchor、接口或协议损坏均fail closed。显式清理及物理缺席后才打印`RESULT PASS  verifier contract assurance`；门③runnable exact1≤400。只有dependency-present完整manifest、fixed tools、candidate/full/depth-1/offline/rollback证据入ledger后才允许06/09启动，inert PASS不能解除。

### `06-resilient-command-runtime`

依据：report “ADB 可靠性与可诊断性”及 build/CVD 超时未处置项。实现分离参数的命令执行器：查询可有界重试，变更/build 只 fail-fast，reconnect 可有界等待；超时时终止子进程组；保留诊断；更新可执行流程和 build/CVD skill 代码块。产出：`harness_command_run <class> <timeout-seconds> <session-id> <wait-seconds> <lease-request-tsv|-> -- <argv...>`（`class=query|mutate|reconnect|build|cvd`）。当 `04` provider 存在且 request 不是 `-` 时，runtime 内部 acquire/release；provider 缺席时只在 `HARNESS_LEGACY_SINGLE_SESSION=1` 下告警并运行，否则返回 `2`。stdout 仅传透子命令 stdout，stderr 输出诊断，返回 `0`、子命令非零码、`124` 超时或 `2` 协议/租约错；配套 provider-present/provider-absent `tests/test-command-runtime.sh`。

### `07-feature-registry-resolver`

依据：report “工程形态与单一真相源”和“重复代码与扩展点”。将 client 发现改为声明式 registry，收敛 feature resolver、四列 manifest 和 branch contract；先保留 legacy schema 读适配，不迁移 hook/verifier。产出：`common/.harness/clients/<client>/client.conf`（`name`、`command`、`context`、`hook_adapter`），manifest `repo_path<TAB>expected_branch<TAB>build_target<TAB>verify_scope`，以及 `harness_resolve_contract --client <name> --root <path>`；stdout 为排序的 `key=value`，返回 `0` 成功、`2` 配置/schema 错、`1` 运行错。负向测试覆盖重名、缺键、非法 command/context、重复 repo 和畸形列，产出 `tests/test-registry-resolver.sh`。

### `08-client-session-adapters`

依据：report 中 wrapper/hook 重复与 session 漂移。Claude/Codex wrapper 与 Codex session hook 改为消费 `03d` 完整 feature/session API、`04` source/build lease 和 `07` resolver，保留旧命令/链接；Claude 的三个 hook及其生命周期测试由 `03e` 独占，08 不修改或包装这些文件。只有 `HARNESS_SESSION_STATE_PROVIDER_VERSION=1` 且五个 public API 全存在才启用新 provider；完整、aggregator 缺席及五种 missing-module partial fixture 都必须验证，任一不完整状态回退当前 legacy adapter并显式标记 `contract_version=legacy`。产出：`harness_client_launch <client> [--dry-run] -- <client-args...>`，透传客户端退出码，配置错返回 `2`。

### `09-verifier-adapters`

依据：report 中三套 verifier 重复与断言漂移。将三旧入口收敛到消费 `05` canonical CLI契约、`06` command runtime和`07` registry的公共dispatcher，保留旧路径且永不修改05的canonical文件。dispatcher自带与`01`等价、不依赖legacy文件的serial/SKIP前置层，并拥有05 provider、06 runtime或07 resolver任一物理缺席时使用的legacy fallback；三者齐全时三旧入口走v2，任一缺席时都走fallback，不得按文件内容猜版本。09独占的private runner adapter从dispatcher已校验的显式CLI控制参数生成并再次校验内部context，再调用`harness_command_run query ... -- <05传入的adb argv>`；不得直接信任调用环境中的session/wait/instance值。产出：`harness_verify <feature> [--session-id <safe-id>] [--lease-wait-seconds <0..300>] [--android-instance-id <safe-id>] [contract CLI args...]`；真实v2模式强制session/instance ID，demo模式可生成进程内唯一session ID；wait默认`0`、只接受显式CLI覆盖，不从未约束环境取值。缺少/非法控制参数在ADB/lease前返回`2`；中断必须释放lease。stdout/退出码与`05`相同；`tests/test-verifier-adapters.sh`在07 present下覆盖05×06四种present/absent组合，再独立覆盖07 absent/present、`01` present/absent、三入口parity、控制参数缺失/非法/环境注入、中断释放、未知feature、畸形registry和命令失败。

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
| `03a -> 03a1` | `_harness_session_path_core <project-id> <session-id>` + 三个生产文本唯一的mutation anchor；path+LF/0、OS错1、安全错2 | `03a1` 的private self-test/run-matrix只复制provider做only-anchor race oracle，不修改provider或发布API |
| `03a -> 03a2` | 同上；provider文件与三anchor结构是入口前置 | `03a2` 在provider缺席时inert，存在时先验anchor后才检查driver/core；损坏provider总是fail closed |
| `03a1 -> 03a2` | `session-path-race-driver-v1`；`protocol/self-test/run-matrix`私有CLI及`0|1|2`协议 | `03a2` 生成四列37-row TSV并调driver；driver物理缺席inert，存在但类型/protocol/执行损坏则fail closed |
| `03 -> 03b` | `harness_validate_feature_name <name>`：合法0/双流空，非法2/固定错误 | `03b`用其验证write feature；validate或path core任一缺席时source inert，不复制名称规则 |
| `03a -> 03b` | `_harness_session_path_core <project-id> <session-id>`：path+LF/0，OS错1，安全错2；无marker/public path | `03b`产出write core双流空`0|1|2|3|129|130|143`与read core成功feature+LF/0、失败双流空`1|2|3`；path export absent时source静默0且test走inert PASS |
| `03a2 -> 03b` | `test-session-path-races.sh` dependency-present的37-case默认运行证据；无运行时API | controller只在03a1/03a2 accepted HEAD与全PASS manifest均入ledger，且03a2九类计数证据齐全后启动03b；03b运行时仍直接消费03a core |
| `03b -> 03b1` | signal-aware snapshot write/read、八个确定性测试anchor及基础测试PASS证据 | `03b1`只复制provider做完整mutation/race/signal assurance，不修改运行时模块 |
| `03b -> 03c` | spawn-only worker直接在调用进程最终exec Python且PID稳定；worker write双流空`0|1|2|3|129|130|143`，worker read成功feature+LF/0、失败双流空`1|2|3` | `03c`直接background worker取得真实child PID并产出 `_harness_session_write_with_signals <project-id> <session-id> <feature>`；三个snapshot exports任一缺席时source inert |
| `03b1 -> 03c` | `test-session-snapshot-assurance.sh` dependency-present完整矩阵与全PASS ledger；无运行时API | controller只在03b1 accepted HEAD、exact1/400和完整active证据入ledger后启动03c；inert PASS不能替代 |
| `03c -> 03d` | `_harness_session_write_with_signals <project-id> <session-id> <feature>`：常规沿用write，信号`129|130|143` | `03d` 产出 `_harness_session_remove_core <project-id> <session-id>`和aggregator；signals export absent时remove inert、aggregator返回1，集成test验证legacy PASS |
| `03d -> 03e` | `session-state.sh` 完整 capability：marker精确`1` + validate/path/write/read/remove 全存在；常规 `0|1|2|3`、remove缺失0、write信号129/130/143 | Claude hook 只有 marker+五API 同时满足才启用；aggregator缺席或任一模块缺席都走legacy并输出compat marker |
| `03d -> 08` | 同上 | Codex/公共 adapter 同时检查 marker+五API；完整、aggregator缺席和五种missing-module fixture覆盖，partial/absent均走legacy并输出 `compat: session-provider=legacy` |
| `04 -> 04a` | request TSV + `harness_lease_acquire/release`、完整协议文档、唯一测试anchor及基础测试PASS证据 | `04a`先替换deadline相邻两行闭合最后一次无sleep锁尝试，再复制provider做完整mutation/I/O/concurrency assurance；不改API、文档或基础测试 |
| `04 -> 06` | request TSV + `harness_lease_acquire/release`；`0|2|3` 协议如 spec 详情 | `06` 内部 acquire/release；provider 缺席时只允许显式 legacy 单会话模式 |
| `04a -> 06` | deadline边界修复 + `test-resource-leases-assurance.sh` dependency-present完整矩阵与全PASS ledger；无新增运行时API | controller只在04a active证据、exact2/400与full/depth-1/offline/rollback证据齐全后启动06 |
| `04a -> 05` | 同一dependency-present验收与五类NEXT资产缺席门；无运行时API | controller只在04a证据齐全后创建05 spec/ref/worktree/ledger BASE/dispatch，inert PASS不能替代 |
| `04 -> 08` | 同上 | `08` 为 source/build 生成 workspace request；provider 缺席时 stderr 输出 `compat: lease-provider=legacy` |
| `04a -> 08` | 同04a到06的dependency-present证明协议 | controller只在04a验收后启动08；08运行时仍直接消费04 API，inert PASS不能替代验收证据 |
| `05 -> 05a` | canonical provider/doc/base test；五断言、private runner seam、demo fixture、末行`RESULT ...`与退出`0|1|2` | 05a只消费和穷举，不修改05 exact3；provider物理缺席时inert，partial/damaged fail closed |
| `05 -> 09` | `common/.harness/bin/verify-sidebar.sh` physical provider；五断言；private runner接收`query-key --`加完整ADB分离argv、传回stdout/stderr/rc | `09`不改provider；05/06/07齐全时把seam绑定09自有可信runner adapter并消费，05物理缺席走09 legacy fallback；回滚05不覆盖09 hunks |
| `05a -> 06` | `test-verifier-contract-assurance.sh` dependency-present完整manifest与全PASS ledger；无运行时API | controller只在05a accepted HEAD、exact1/400及full/depth-1/offline/rollback证据齐全后启动06；inert PASS不能替代 |
| `05a -> 09` | 同一verifier完整assurance证据；无运行时API | 09只能消费已经05a穷举的provider/seam；05a回滚不改变运行时，但失去重新验收09资格 |
| `06 -> 09` | `harness_command_run`；stdout 传透、stderr 诊断；`0|child|124|2` | `09`在05/06/07齐全时从自身CLI取已校验session ID、0..300秒wait和Android instance ID，由自有runner adapter再次校验内部context、生成lease request并传分离argv；06物理缺席走legacy verifier |
| `07 -> 08` | resolver stdout 固定 key 集 `contract_version,client,command,context,hook_adapter,feature,target_branch,manifest,workflow,verifier,repositories,contract_sha256`，键按 ASCII 排序，值禁止 LF/NUL/`=`；`0|1|2` | 按 key 解析，不依赖行号；provider 缺席时 stderr 输出 `compat: contract_version=legacy` |
| `07 -> 09` | 同上 | 按 registry 定位 verifier/feature；缺席时走 legacy verifier |
| `08 -> 10` | 稳定旧 wrapper 路径 + `contract_version=v2|legacy` capability marker | 文档同时描述两种 marker，不引内部 adapter 路径 |
| `09 -> 10` | 稳定旧 verifier 路径 + `contract_version=v2|legacy` capability marker | 文档同时描述两种 marker，不引内部 dispatcher 路径 |

## 独立回滚矩阵

| spec | 独立回滚路径 | 已合入消费者的行为 |
|---|---|---|
| `01` | 回退 serial/flag 补丁与安全测试 | `02` 只发现现存测试；`09` 的独立 preflight 继续拦截裸 ADB/真实 SKIP，并用 `01`-absent fixture 验证 |
| `02` | 删除根 gate/CI/`tests/COVERAGE.md` | `03–10`（含 `03a–03e`与assurance片）的独立test与判据均不调用`check.sh`，03d coverage位于独占fragment而不依赖该文件；`10`直接调用`check-docs.sh`/`test-docs.sh` |
| `03` | 删除 foundation 模块与独立测试，不改后序模块文件 | aggregator preflight/source 失败，marker 未设置且完整五API predicate 为 false；`03e/08` 的 missing-foundation fixture 自动转 legacy |
| `03a` | 删除 path 模块与独立测试，不改 foundation/后序模块 | aggregator preflight/source 失败，marker 未设置且完整五API predicate 为 false；`03e/08` 的 missing-path fixture 自动转 legacy |
| `03a1` | 删除private race driver，不改provider、03a2或后序模块 | `03a2`因driver物理缺席走inert PASS/0 case；03b运行时不变，但该状态不得重新验收03a2或新启动03b |
| `03a2` | 删除唯一root race entrypoint，不改provider/driver或后序模块 | private driver不被root gate默认发现；03b运行时不变，只失去穷举门禁证据 |
| `03b` | 删除 snapshot 模块与基础测试，不改03b1/后序模块 | 03b1与03c依赖缺席时inert；aggregator preflight/source失败，marker未设置且完整五API predicate为false；`03e/08`的missing-snapshot fixture自动转legacy |
| `03b1` | 删除唯一snapshot assurance入口，不改provider或后序模块 | snapshot及已合入03c运行时行为不变，但失去穷举门禁证据且不得重新验收或新启动03c |
| `03c` | 删除 signals 模块与独立测试，不改其他模块 | aggregator preflight/source 失败，marker 未设置且完整五API predicate 为 false；`03e/08` 的 missing-signals fixture 自动转 legacy |
| `03d` | 删除 remove模块、aggregator、集成测试和独占coverage fragment，不改前序私有模块或02文件 | marker未设置且完整五API predicate为false；foundation的public validate可单独存在，`03e/08`仍自动转legacy且不丢旧入口 |
| `03e` | 回退 Claude hook/settings/demo 接入 | `03d` 完整 provider与测试不依赖03e；08不修改03e独占hook |
| `04` | 删除provider、协议文档与基础测试，不改04a/后序文件 | `04a`因provider物理缺席走inert PASS/零active case；`06`只在`HARNESS_LEGACY_SINGLE_SESSION=1`下告警运行否则返2，`08`走legacy adapter；该状态不得重新验收04a或启动消费者 |
| `04a` | 删除lease assurance入口并精确回退provider的deadline两行修复，不改04文档、基础测试或后序模块 | 回到已验收04基线且基础测试保持绿色，但重新暴露已记录的最后一次无sleep锁尝试缺口；失去穷举门禁证据且不得重新验收或新启动05/06/08 |
| `05` | 删除canonical CLI、contract文档与base test，不修改05a、三个旧入口或09文件 | `05a`因provider物理缺席inert；`09`以canonical文件物理缺席无歧义走legacy fallback；dispatcher hunks不被05回滚覆盖，且该状态不得重新验收05a/06/09 |
| `05a` | 删除唯一verifier assurance入口，不改05 provider/doc/base test或后序模块 | runtime行为不变，但失去穷举门禁证据且不得重新验收或新启动06/09 |
| `06` | 回退 command runtime/skill 更新 | `09` 自动使用仍符合 `01` 基线的 legacy verifier |
| `07` | 回退 registry/resolver/schema，保留 legacy 数据 | `08/09` 的 legacy fixture 验证回退路径 |
| `08` | 回退 client/session adapter | `09` 不依赖 `08`；`10` 只引稳定入口 |
| `09` | 回退 verifier adapter | `08` 不依赖 `09`；`10` 的契约文档仍适用 legacy 入口 |
| `10` | 单独回退文档/check-docs | 不影响任何运行时和回归 |

每个存在可回滚 provider 依赖的 consumer 必须包含对应 present/absent fixture；对 session provider，`03e/08` 还必须逐个覆盖 foundation/path/snapshot/signals/remove 缺席以及 aggregator 缺席，断言 marker 与五API不会形成 partial capability。`01/02/10` 没有此类 provider 前置，不适用该要求。

session 模块的回滚验收命令固定如下；对应测试脚本必须实现这些 test-only 参数，默认无参数运行在真实依赖缺席时执行相同 inert 断言，所有成功摘要仍与 spec 表一致：

| 回滚目标 | 已合入后序测试必须保持绿色的命令 |
|---|---|
| `03` | `./tests/test-session-path.sh --dependency-absent && ./tests/test-session-path-races.sh --dependency-absent && ./tests/test-session-snapshot.sh --dependency-absent && ./tests/test-session-snapshot-assurance.sh --dependency-absent && ./tests/test-session-signals.sh --dependency-absent && ./tests/test-session-state.sh --session-provider-fixture missing-foundation && ./tests/test-claude-session-lifecycle.sh --session-provider-fixture missing-foundation && ./tests/test-client-session-adapters.sh --session-provider-fixture missing-foundation` |
| `03a` | `./tests/test-session-path-races.sh --dependency-absent && ./tests/test-session-snapshot.sh --dependency-absent && ./tests/test-session-snapshot-assurance.sh --dependency-absent && ./tests/test-session-signals.sh --dependency-absent && ./tests/test-session-state.sh --session-provider-fixture missing-path && ./tests/test-claude-session-lifecycle.sh --session-provider-fixture missing-path && ./tests/test-client-session-adapters.sh --session-provider-fixture missing-path` |
| `03a1` | 删除driver后 `./tests/test-session-path-races.sh && ./tests/test-session-path-races.sh --dependency-absent` 均inert PASS；已合入snapshot及后序运行时行为不变 |
| `03a2` | 删除root test后运行`python3 tests/lib/session-path-race-driver.py self-test common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh && bash ./scripts/check.sh --offline`，证明private driver仍PASS且root gate不再发现race entrypoint；不依赖尚未实现的03b文件 |
| `03b` | `./tests/test-session-snapshot-assurance.sh --dependency-absent && ./tests/test-session-signals.sh --dependency-absent && ./tests/test-session-state.sh --session-provider-fixture missing-snapshot && ./tests/test-claude-session-lifecycle.sh --session-provider-fixture missing-snapshot && ./tests/test-client-session-adapters.sh --session-provider-fixture missing-snapshot` |
| `03b1` | 删除assurance入口后运行`bash ./tests/test-session-snapshot.sh && bash ./scripts/check.sh --offline`，snapshot worker及后序运行时不变；该状态不得作为重新启动03c的门禁证据 |
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
| 源码/build/device/CVD 无租约 | `04` 实现、`04a`穷举保证，`06/08` 在两片验收后消费 |
| 文档断链/副本漂移 | `10` + `scripts/check-docs.sh` |

## 依赖图

```text
01 --> 02
01 --> 09
02 --> 03
03 --> 03a
03a --> 03a1
03a --> 03a2
03a1 --> 03a2
03 --> 03b
03a --> 03b
03a2 --> 03b
03b --> 03b1
03b --> 03c
03b1 --> 03c
03c --> 03d
03d --> 03e
02 --> 04
04 --> 04a
04a --> 05
02 --> 05
05 --> 05a
05a --> 06
05a --> 09
02 --> 07
03d --> 08
04 --> 06
04a --> 06
04 --> 08
04a --> 08
05 --> 09
06 --> 09
07 --> 08
07 --> 09
08 --> 10
09 --> 10
```

实施顺序固定为 `01 → 02 → 03 → 03a → 03a1 → 03a2 → 03b → 03b1 → 03c → 03d → 03e → 04 → 04a → 05 → 05a → 06 → 07 → 08 → 09 → 10`。`01`先关闭单点安全风险；`02`建防线；03a1/03a2先穷举path race，03b1再在signals facade前穷举snapshot mutation；`03–03c`逐个交付互不叠改的私有模块，`03d`才由aggregator原子发布完整五API capability，`03e`再接Claude生命周期；04交付完整租约运行时，04a在任何消费者前穷举状态/I/O/并发；05发布verifier语义与transport seam，05a穷举后再交付06执行时，最后收敛registry/session/verifier并更新文档。

## 资源冲突

- 20 个 spec 均为实现或验收代码片，必须按上述顺序串行。
- `01/05/05a/06/09`会触及verifier/设备路径，但05a只新增独立assurance；`03–03c`各自独占不同私有模块/test，03a1/03a2与03b1分别独占path/snapshot assurance资产，`03d`独占remove、aggregator、最终集成test和coverage fragment；04a因requirements前实跑暴露deadline边界缺口而对04 provider做唯一两行相邻修复，之后的05/06/08仍未启动，不形成并行叠改；`03e`独占Claude hook而`08`只修改wrapper/Codex hook；`07/08/09`触及resolver/adapter，不允许重叠实施。
- 真实运行时使用 `04` 的组合 lease：同一 canonical workspace 的 source/build 互斥，同一 Android instance 的 device/cvd 互斥；多租约按稳定键排序后全有或全无获取，不允许部分占有。`04a`串行替换provider唯一deadline相邻分支并新增独立assurance，所有消费者继续等待其验收。
- 所有测试使用独立 `mktemp` fixture/mock，不共享真实设备、CVD、AOSP tree 或外部环境。

## 待人审确认的口径

默认决定：保留三个顶层 Demo 和现有用户入口，但把可运行公共逻辑收敛到 `common/.harness`；Claude/Codex 只保留适配、上下文和兼容路径。如果三套必须继续可单独复制、无跨目录依赖，则 `07–09` 需改为“生成/同步共享逻辑”。
