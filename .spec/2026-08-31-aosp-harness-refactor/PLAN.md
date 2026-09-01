# 2026-08-31-aosp-harness-refactor 拆分计划 v4

> 上游：`research/report.md`
> v4 依据：调研结论及 `reviews/plan-round-1.md`、`plan-round-2.md`、`plan-round-3.md`。三轮 review 后按熔断规则裁定剩余协议：真实 device/CVD 共用显式 Android instance ID，verifier CLI 显式接收 session/lease wait/instance ID。

## 总目标

在保留 `claude-code/`、`codex/`、`common/` 现有入口和离线 Demo 能力的前提下，将安全、设备/进程调用、资源租约、验收契约和 feature/session 基础能力收敛为公共内核，并用单一离线门禁阻止三套实现再次漂移。

整体验收：

- `./scripts/check.sh --offline` 退出 `0`，末行为 `RESULT PASS  aosp-harness offline quality gate`。
- `./tests/test-device-safety.sh && ./tests/test-session-state.sh && ./tests/test-resource-leases.sh && ./tests/test-verifier-contract.sh && ./tests/test-command-runtime.sh && ./tests/test-registry-resolver.sh && ./tests/test-client-session-adapters.sh && ./tests/test-verifier-adapters.sh` 全部退出 `0`。
- Claude、Codex、common 三套旧回归全部退出 `0`；`git diff --check` 退出 `0`。
- 默认验收全程不连真实 ADB/CVD，不跑 AOSP build，不改被跟踪的 `CURRENT_FEATURE`，不残留 session/lease 文件。

整体不变量：

- 三个顶层目录和已文档化的 wrapper/demo/test 路径保留；可改为薄适配，但不删入口。
- 真实模式在首次 ADB 调用前必须固定安全 serial；无/非法 serial、查询失败或必需断言 SKIP 时不得退出 `0`。
- 严格 PASS 至少覆盖 boot、system_server、crash baseline、service、package 五项，不降低现有 Codex 负向测试强度。
- 每个存在可回滚 provider 依赖的 consumer，都要在 fixture 中验证 provider-present/provider-absent 两条路径，并保留上一版兼容 fallback。
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
| `03-session-state-safety` | 用攻击/并发探针收敛 feature 输入和 session 状态未知风险 | `02-offline-quality-gate` | `./tests/test-session-state.sh` 输出 `RESULT PASS  session state` | ⬜ 未开始 |
| `04-runtime-resource-leases` | 为源码、build、device、CVD 提供跨会话独占租约 | `02-offline-quality-gate` | `./tests/test-resource-leases.sh` 输出 `RESULT PASS  resource leases` | ⬜ 未开始 |
| `05-verifier-contract` | 对齐三套 verifier 的断言和 PASS/FAIL/SKIP 契约 | `02-offline-quality-gate` | `./tests/test-verifier-contract.sh` 输出 `RESULT PASS  verifier contract` | ⬜ 未开始 |
| `06-resilient-command-runtime` | 为 ADB/build/CVD 步骤增加超时、诊断、取消和 fail-fast | `04-runtime-resource-leases` | `./tests/test-command-runtime.sh` 输出 `RESULT PASS  command runtime` | ⬜ 未开始 |
| `07-feature-registry-resolver` | 收敛 client registry、manifest schema、resolver 和 branch contract | `02-offline-quality-gate` | `./tests/test-registry-resolver.sh` 输出 `RESULT PASS  registry resolver` | ⬜ 未开始 |
| `08-client-session-adapters` | 将 Claude/Codex wrapper 和 session hook 转为公共内核的薄适配 | `03-session-state-safety`, `04-runtime-resource-leases`, `07-feature-registry-resolver` | `./tests/test-client-session-adapters.sh` 输出统一 PASS | ⬜ 未开始 |
| `09-verifier-adapters` | 将三套 verifier 入口收敛到共用 contract/runtime | `01-device-safety`, `05-verifier-contract`, `06-resilient-command-runtime`, `07-feature-registry-resolver` | `./tests/test-verifier-adapters.sh` 输出统一 PASS | ⬜ 未开始 |
| `10-docs-and-readiness` | 修复文档漂移并固化环境、安全、验收和未验证边界 | `08-client-session-adapters`, `09-verifier-adapters` | `./scripts/check-docs.sh && ./tests/test-docs.sh` 均退出 `0` | ⬜ 未开始 |

状态：⬜ 未开始 / ⏳ 进行中 / ✅ 完成 / ❌ 不成立

## 审查规模与文件边界

每片的实现 diff 上限是 8 个非生成文件、400 行新增+删除（用 review package 中的 `git diff --numstat` 机械统计），因此人工可在 1 小时内逐文件审完。任一片超限，或实际审查者判断无法在 1 小时内审完，必须在实施前回到 PLAN 门拆片，不得以超限 diff 进入任务验收。

| spec | 独占文件/接口边界 |
|---|---|
| `01` | Claude verifier + build/sepolicy skill、Codex verifier flag、device-safety test |
| `02` | root gate、CI workflow、`tests/COVERAGE.md`、gate test |
| `03` | feature/session 公共库、Claude hook/demo 适配、session-state test |
| `04` | lease 公共库、lease 协议文档、resource-leases test |
| `05` | verifier contract 文档、common verifier 断言、contract test |
| `06` | command runtime 库、ADB/build/CVD 执行代码块、runtime test |
| `07` | client registry、resolver/branch checker、manifest adapter、registry test |
| `08` | common client launcher、Claude/Codex wrapper/session hook 薄适配、adapter test |
| `09` | common verifier dispatcher、三个薄 verifier 入口、adapter test |
| `10` | root/clients README、受管长文、docs checker 与 `tests/test-docs.sh` |

## spec 详情

### `01-device-safety`

依据：report “安全与结果语义”。为 Claude verifier/build/sepolicy 部署增加 `ANDROID_SERIAL` 校验，所有 ADB 强制同一 `-s "$serial"`；Codex 真实模式拒绝 `--allow-skip`；mock 证明校验失败时零次 ADB 调用。产出：serial/SKIP 行为契约与 `tests/test-device-safety.sh`。

### `02-offline-quality-gate`

依据：report “工程门禁、可复现性与当前基线”。新建 `scripts/check.sh`：`--offline` 只运行仓库内核心检查，不检测/跳过可选工具，语义跨环境一致；`--ci` 强制固定版本的 ShellCheck/shfmt/有限秘密扫描，少任一工具立即失败。CI 先安装锁定版本再跑 `--ci`。门禁按字典序自动发现存在的 `tests/test-*.sh`，不硬编码任一 provider 文件。产出：根门禁、CI 配置和 `tests/COVERAGE.md` 需求→测试矩阵；数字行/分支覆盖率明确为本轮非目标。

### `03-session-state-safety`

依据：report “安全与结果语义”、“资源生命周期”及未确认的路径/软链/并发风险。统一 feature-name 校验；用按项目/session 隔离的 `0700` 目录、`0600` 文件、原子替换和 owner/link 检查替代固定快照；增加结束/信号清理；Claude demo 只改 fixture。攻击/并发测试覆盖路径逃逸、软链跟随、权限错误、双会话和中断。产出：`harness_validate_feature_name <name>`、`harness_session_state_path <project-id> <session-id>` 及 `tests/test-session-state.sh`。

### `04-runtime-resource-leases`

依据：report “验收强度与契约漂移”中只有文字约束、无运行时锁的结论。实现跨进程组合租约：request TSV 每行为 `domain<TAB>canonical_id<TAB>mode`，`domain=workspace|android`，`mode=source|build|device|cvd`。`workspace` 的 source/build 互斥，`android` 的 device/cvd 互斥；多资源按 `domain+canonical_id` 排序后全部获取或全部释放。workspace ID 是 `realpath` 结果；所有真实 device/CVD 调用必须由上层显式传入同一 `android-instance-id`（安全单组件，不是 serial 或 CVD name），ADB serial/CVD name 只作命令参数、绝不作 lease key；缺少/非法 instance ID 在任一命令前返回 `2`。fixture 使用不同 serial/name+同一 instance ID 验证互斥，并拒绝同一 request 中同 instance 的冲突别名。租约支持有界等待、主动释放和 stale-owner 回收，不抢占存活 owner。产出：`harness_lease_acquire <session-id> <wait-seconds> <request-tsv>` 和 `harness_lease_release <lease-token>`；acquire stdout 唯一 token，release 成功无 stdout；两者返回 `0` 成功、`2` 协议/所有者错、`3` 占用/超时。token 必须与 owner/session/request hash 同时匹配；配套 `tests/test-resource-leases.sh`。

### `05-verifier-contract`

依据：report “验收强度与契约漂移”。定义 boot、system_server、crash baseline、service、package 五项断言及 PASS/FAIL/SKIP/退出码；补齐 common 的 crash/package/baseline；同一 mock 矩阵验证三入口的成功、命令失败、业务缺失、SKIP 和时间边界。产出：`docs/verifier-contract.md`、`tests/test-verifier-contract.sh` 与稳定 CLI `verify-sidebar.sh [--demo] [--since <epoch[.nsec]>] [--allow-skip]`；末行只能为 `RESULT PASS|FAIL|INCOMPLETE` 及可选解释，退出码分别为 `0|1|2`。

### `06-resilient-command-runtime`

依据：report “ADB 可靠性与可诊断性”及 build/CVD 超时未处置项。实现分离参数的命令执行器：查询可有界重试，变更/build 只 fail-fast，reconnect 可有界等待；超时时终止子进程组；保留诊断；更新可执行流程和 build/CVD skill 代码块。产出：`harness_command_run <class> <timeout-seconds> <session-id> <wait-seconds> <lease-request-tsv|-> -- <argv...>`（`class=query|mutate|reconnect|build|cvd`）。当 `04` provider 存在且 request 不是 `-` 时，runtime 内部 acquire/release；provider 缺席时只在 `HARNESS_LEGACY_SINGLE_SESSION=1` 下告警并运行，否则返回 `2`。stdout 仅传透子命令 stdout，stderr 输出诊断，返回 `0`、子命令非零码、`124` 超时或 `2` 协议/租约错；配套 provider-present/provider-absent `tests/test-command-runtime.sh`。

### `07-feature-registry-resolver`

依据：report “工程形态与单一真相源”和“重复代码与扩展点”。将 client 发现改为声明式 registry，收敛 feature resolver、四列 manifest 和 branch contract；先保留 legacy schema 读适配，不迁移 hook/verifier。产出：`common/.harness/clients/<client>/client.conf`（`name`、`command`、`context`、`hook_adapter`），manifest `repo_path<TAB>expected_branch<TAB>build_target<TAB>verify_scope`，以及 `harness_resolve_contract --client <name> --root <path>`；stdout 为排序的 `key=value`，返回 `0` 成功、`2` 配置/schema 错、`1` 运行错。负向测试覆盖重名、缺键、非法 command/context、重复 repo 和畸形列，产出 `tests/test-registry-resolver.sh`。

### `08-client-session-adapters`

依据：report 中 wrapper/hook 重复与 session 漂移。Claude/Codex wrapper 和 session hook 改为消费 `03` feature/session API、`04` source/build lease 和 `07` resolver，保留旧命令/链接；当 v2 provider 缺席时回退到当前 legacy adapter 并显式标记 `contract_version=legacy`。产出：`harness_client_launch <client> [--dry-run] -- <client-args...>`，透传客户端退出码，配置错返回 `2`；配套 `tests/test-client-session-adapters.sh`，分别在 v2/legacy fixture 运行。

### `09-verifier-adapters`

依据：report 中三套 verifier 重复与断言漂移。将三入口收敛到消费 `05` CLI 契约、`06` command runtime 和 `07` registry 的公共 dispatcher，保留旧路径。dispatcher 自带与 `01` 等价、不依赖 legacy 文件的 serial/SKIP 前置层。产出：`harness_verify <feature> [--session-id <safe-id>] [--lease-wait-seconds <0..300>] [--android-instance-id <safe-id>] [contract CLI args...]`；真实 v2 模式强制 session/instance ID，demo 模式可生成进程内唯一 session ID；wait 默认 `0`、只接受显式 CLI 覆盖，不从未约束环境取值。缺少/非法控制参数在 ADB/lease 前返回 `2`；中断必须释放 lease。stdout/退出码与 `05` 相同；`tests/test-verifier-adapters.sh` 覆盖 v2/legacy、`01` present/absent、控制参数缺失/非法、中断释放、未知 feature、畸形 registry 和命令失败。

### `10-docs-and-readiness`

依据：report “文档漂移”与“我没能确认的”。重写定位/快速开始，区分离线 Demo 和真机；文档化环境、gate、serial/租约/超时/严格 PASS；修链接/不存在 skill；为长文设主副本/同步检查；记录未验证真机、跨平台和数字覆盖率。文档同时说明 legacy/v2 capability marker，只引稳定入口，因此允许 `08/09` 回滚。产出：README/契约文档、`scripts/check-docs.sh` 和自动发现包装 `tests/test-docs.sh`；后者保证 `check.sh --offline` 持续阻止链接/副本漂移，但 `10` 的独立验收不依赖 `02` 存在。

## 依赖契约

以下只列直接边，与 spec 表及 Mermaid 一一相等：

| 直接边 | provider 产出协议 | consumer 消费方式 |
|---|---|---|
| `01 -> 02` | serial/SKIP 行为；无新 API | `02` 按字典序发现实际存在的 `tests/test-*.sh` |
| `01 -> 09` | fail-closed 行为契约 | `09` 自带等价 preflight，不 source `01` 代码；返回 `2` 代表 serial/flag 协议错 |
| `02 -> 03` | gate 插件约定 `tests/test-*.sh`；`0` PASS/非零 FAIL | `03` 产出可独立执行的 `tests/test-session-state.sh` |
| `02 -> 04` | 同上 | `04` 产出 `tests/test-resource-leases.sh` |
| `02 -> 05` | 同上 | `05` 产出 `tests/test-verifier-contract.sh` |
| `02 -> 07` | 同上 | `07` 产出 `tests/test-registry-resolver.sh` |
| `03 -> 08` | `harness_validate_feature_name <name>`：成功无 stdout/stderr、返回 `0`，非法名称在 stderr 输出 `error: invalid feature name`并返回 `2`；`harness_session_state_path <project-id> <session-id>`：成功 stdout 唯一绝对路径并返回 `0`，协议/安全错返回 `2` | source API；provider 缺席时走 legacy fixture，stderr 输出 `compat: session-provider=legacy` |
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
| `02` | 删除根 gate/CI/矩阵 | `03–10` 的独立 test 与独立判据均不调用 `check.sh`；`10` 直接调用 `check-docs.sh`/`test-docs.sh` |
| `03` | 回退 feature/session provider | `08` fixture 验证自动转 legacy adapter，不丢失旧入口 |
| `04` | 回退 lease provider | `06` 只在 `HARNESS_LEGACY_SINGLE_SESSION=1` 下告警运行，否则返回 `2`；`08` 走已保留的 legacy adapter；两者均有 provider-absent fixture |
| `05` | 回退 contract 文档/共用断言 | `09` 的 legacy fixture 保持旧 verifier 入口可运行 |
| `06` | 回退 command runtime/skill 更新 | `09` 自动使用仍符合 `01` 基线的 legacy verifier |
| `07` | 回退 registry/resolver/schema，保留 legacy 数据 | `08/09` 的 legacy fixture 验证回退路径 |
| `08` | 回退 client/session adapter | `09` 不依赖 `08`；`10` 只引稳定入口 |
| `09` | 回退 verifier adapter | `08` 不依赖 `09`；`10` 的契约文档仍适用 legacy 入口 |
| `10` | 单独回退文档/check-docs | 不影响任何运行时和回归 |

每个存在可回滚 provider 依赖的 consumer 必须包含对应 present/absent fixture；`01/02/10` 没有此类 provider 前置，不适用该要求。

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
| 路径逃逸/软链/并发竞争未实测 | `03` 提前执行攻击/并发探针 |
| 源码/build/device/CVD 无租约 | `04` 实现，`06/08` 消费 |
| 文档断链/副本漂移 | `10` + `scripts/check-docs.sh` |

## 依赖图

```text
01 --> 02
01 --> 09
02 --> 03
02 --> 04
02 --> 05
02 --> 07
03 --> 08
04 --> 06
04 --> 08
05 --> 09
06 --> 09
07 --> 08
07 --> 09
08 --> 10
09 --> 10
```

实施顺序固定为 `01 → 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09 → 10`。`01` 先关闭单点安全风险；`02` 建防线；`03` 紧接着消除调研未复现的高不确定性；然后锁定资源、交付语义和执行时；最后分三个可审小片收敛 registry/session/verifier 并更新文档。

## 资源冲突

- 10 个 spec 均为实现类，必须按上述顺序串行。
- `01/05/06/09` 会触及 verifier/设备路径；`03/08` 触及 hook/session；`07/08/09` 触及 resolver/adapter，不允许重叠实施。
- 真实运行时使用 `04` 的组合 lease：同一 canonical workspace 的 source/build 互斥，同一 Android instance 的 device/cvd 互斥；多租约按稳定键排序后全有或全无获取，不允许部分占有。
- 所有测试使用独立 `mktemp` fixture/mock，不共享真实设备、CVD、AOSP tree 或外部环境。

## 待人审确认的口径

默认决定：保留三个顶层 Demo 和现有用户入口，但把可运行公共逻辑收敛到 `common/.harness`；Claude/Codex 只保留适配、上下文和兼容路径。如果三套必须继续可单独复制、无跨目录依赖，则 `07–09` 需改为“生成/同步共享逻辑”。
