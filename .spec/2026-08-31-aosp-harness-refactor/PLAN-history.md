# 2026-08-31-aosp-harness-refactor 拆分计划变更史

> 每次变更必须写明**触发它的证据**（哪个 spec 的哪条发现，带出处）。
> 不接受「经过考虑觉得应该调整」。没有这条，计划会在一次次微调里
> 漂移到和最初目标无关的地方，而且没人说得清是哪一步开始偏的。

## v1 — 2026-08-31

首版。基于 research/report.md。

## v2 — 2026-08-31

由 `reviews/plan-round-1.md` 触发：原 canonical-core spec 超过 P5，且缺少独立回滚、消费协议、资源租约及部分遗留项去向。拆为 registry/session/verifier 适配片，增加 lease、回滚矩阵和协议表。

## v3 — 2026-08-31

由 `reviews/plan-round-2.md` 触发：`01/02/04` 回滚不可执行、直接依赖边不一致、lease 未跨类型互斥、docs check 未进入根 gate。改为单一直接边集，定义组合 lease，新增 `tests/test-docs.sh` 插件，并设 8 文件/400 行审查上限。

## v4 — 2026-08-31

由 `reviews/plan-round-3.md` I1/I2/M1 触发：Android instance 别名可绕过 device/CVD 互斥，`09 -> 06` 缺 session/wait 参数来源，回滚矩阵误列 `06` 消费 `05`。熔断裁定见 `DECISIONS.md`：真实 Android 操作强制显式 instance ID，verifier CLI 显式接收 session/wait/instance ID，并删除错误依赖。

## v4.1 — 2026-09-01

由 `03-session-state-safety` requirements 首轮独立 review 阻断项 I2 触发：原 `03 -> 08` 只公开 feature 校验和状态路径，未公开安全快照读、写、删除，`08` 无法在不复制原子/owner/link 检查的前提下实现薄适配。保持 spec 拆分、顺序和验收判据不变，只把 03 的稳定 provider 契约补全为 validate/path/write/read/remove 五个 API；行为细节见 03 requirements 与 `DECISIONS.md`。

## v5 — 2026-09-01

由 `03-session-state-safety` ledger 的 Design round 1 B3 与 round 2 B2（`specs/2026-09-01-03-session-state-safety/ledger.md`）触发：五 API 的 fd 安全内核、确定性攻击/信号 oracle、Claude 三类 hook 与 demo 生命周期接入无法在 8 文件/400 行内同时给出可信实现和测试。沿已经闭合的五 API 稳定接口拆为 `03-session-state-safety`（provider + API/攻击测试）和 `03b-claude-session-lifecycle`（Claude hook/settings/demo + 生命周期测试），两片串行且各有独立判据、回滚和 provider-present/absent 路径；`03b` 独占 Claude hook，`08` 只改 wrapper/Codex hook，不形成叠改依赖。

## v5.1 — 2026-09-01

由收窄版 `03-session-state-safety` requirements review round 3 I2 触发：原 PLAN/API 常规返回只列 `0/1/2/3`，未定义 write 被信号中断的可观察结果，可能出现清理成功却 rc `0` 的假成功。保持 v5 拆片、顺序、判据和文件边界不变，只把 HUP/INT/TERM 的 shell 惯例退出码 `129/130/143` 加入 03 provider 契约；熔断裁定与错判代价见 03 ledger/DECISIONS。

## v5.2 — 2026-09-01

由 `03-session-state-safety` task 1.1/1.2 的真实实现和独立 diff review 触发：仅 validate、根选择、fresh fd 链及其可反证测试已占 373 行，原 sizing prototype 声称完整五 API 只需 359 行已被证伪。拆出 path foundation 会让主线短暂暴露未完成 existing-object hardening 的 public API，因此不改变五 API 内聚边界；03 改为 design 目标 1200、3 文件/1400 行硬门，并以 16 个小任务、每任务独立 review 维持审查粒度。其他 spec 仍用默认 8 文件/400 行。

## v5.3 — 2026-09-01

由 v5.2 增量 PLAN review 的 P5 阻断触发：1400 行聚合包即使逐任务 review，也没有“全部产出一小时内审完”的证据。初版按安全完成边界拆为 foundation、fully-hardened path、snapshot write/read、write interrupts、remove/prune、Claude lifecycle 六片；两轮独立 v5.3 review 又指出连续规格若叠改同一provider/test、共改02的coverage或不处理上游回滚后的自动测试，会破坏P2并让消费者观测partial provider。最终每片独占foundation/path/snapshot/signals/remove模块与测试，03d独占aggregator/集成测试/coverage fragment；每条私有边写死签名和present/absent inert契约，aggregator只有五模块私有接口完整时才设置marker并发布五API，03e/08对每种missing-module状态都回退legacy。每片仍执行默认400行门，controller用六列首尾绑定review manifest机械证明提交链无未审缺口。

## v5.3.1 — 2026-09-01

由 `reviews/design-03a-round-1.md` important 2 触发：03a 的 fail-fast 设计实际需要调用 foundation 已公开的 `harness_validate_feature_name <name>`，但 v5.3 的说明曾把依赖概括成“两 private path exports”，使 source guard 和调用证据无法从边契约机械推出。本版把这个既存 public 签名连同两个 private export 一并写入原 `03 -> 03a` 边；不新增边，不改变顺序、文件 owner、返回协议、400 行门或回滚拓扑。

## v5.4 — 2026-09-01

由 `reviews/design-03a-round-2.md` blocker 触发：311行可执行原型只实际运行一条fresh路径，其余51条只是case inventory，无法证明复杂三层mutation fixture能进入剩余89行，重现foundation执行期才发现sizing失真的风险。03a保留完整private provider与source/root/static/代表性root race验收；新增仅拥有`test-session-path-races.sh`的03a1穷举三层mutation，且03b必须等待03a与03a1均PASS。provider在03a1前没有消费者或public capability；03a1缺席不改变运行时，03a回滚时03a1走inert PASS。每片继续执行400行门。

## v5.5 — 2026-09-01

由03a `task-4-fix1-report.md`的执行期实测触发：当前未格式化provider+test为397行，但按仓库pinned shfmt格式化后为527行；只把project/session race拆到03a1仍不足，靠压缩会牺牲可读性或oracle。03a保留完整private provider、source/root/static、非anchor确定性错误分类probe与anchor occurrence/phase位置结构测试；全部root/project/session anchor-driven provider-copy mutation移到已规划的03a1，并继续强制03a1 PASS后才开始任何consumer 03b。两片都必须shfmt-clean且各自不超过400行。

## v5.6 — 2026-09-02

由03a1 `round6-sizing-report.md`与`round7-sizing-report.md`触发：round6将完整37-case、九类完整delta oracle和14项active self-disproof纳入单一shfmt-clean文件后实测411/400，原边界BLOCKED；round7真实拆为不进入默认发现的private Python driver 400/400与root shell matrix 109/400，37/37、14项自反证、物理路径隔离、损坏态、full/depth-1 offline均PASS。保留当前03a1 id拥有driver/self-test，新增03a2拥有37-row默认入口；driver缺席时03a2 inert，存在但损坏则fail closed。03b只在两片验收记录齐全且03a2提供dependency-present 37-case证据后才能启动。

## v5.7 — 2026-09-02

由03b requirements round1 B2/B3触发：原拆法把owned temp与publish点封在03b Python worker，却要求不改03b的03c负责其信号清理，扩展seam不可实现；同时259行代表原型没有覆盖完整publish/mutation oracle。将Python child HUP/INT/TERM cleanup与`TEMP_BEFORE_PUBLISH`归还03b，03c只保留Bash转发facade；新增独占`tests/test-session-snapshot-assurance.sh`的03b1穷举held capture、managed/snapshot mutation、wrong-owner、short-read、EIO、missing-symbol/ENOSYS、EEXIST winner生命周期和child信号。03c同时消费03b运行时接口与03b1 dependency-present验收证据。复审先后增加spawn-only worker/child latch、四态source/strict worker、source rc/完整inventory/export属性、held capture结构、managed disappearance/suffix、字节级read oracle、第二波并发winner指纹、静态攻击整树delta、failure stdout、换入对象身份/shape与EEXIST全oracle前temp清理及完整winner指纹；内部exec/dispatch改为worker调用进程内临时定义，使source只留下三个约定export。最终03b prototype `7ffc213ee773abe88d25436998e71f9ff08f270a`固定格式199+198=397/400，运行、shfmt与exact2 ShellCheck全PASS；同commit的03b1完整active-family prototype固定格式exact1=274/400、227项调用/状态delta，三种首信号与二次信号、shfmt/ShellCheck/bash-n/实跑全PASS，证明单文件边界可实施并保留126行整合余量；证据commit为`ba3cdb51c35572bf0c96bb99a7b5366c9af02ff2`。
