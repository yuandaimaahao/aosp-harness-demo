# 2026-08-31-aosp-harness-refactor 项目口径

> 前面的 spec 确认过的口径记在这里，后续 spec 起草 requirements 前先读。
> 已被本文件覆盖的条目不许再标 [推断] 去问用户。

| 日期 | 来自 spec | 口径 |
|---|---|---|
| 2026-08-31 | — | 调研范围已确认：按 STATE.md 中所列“查/不查”边界执行工程审查与后续重构。 |
| 2026-08-31 | PLAN review 熔断 I1 | 三轮 review 后裁定：所有真实 device/CVD 调用必须显式传同一安全 `android-instance-id`，serial/CVD name 不得作 lease key。若判断错误，代价是需要额外配置 instance ID；若不做，代价是同一 CVD 可被 device/cvd 两种别名并发操作。 |
| 2026-08-31 | PLAN review 熔断 I2 | 三轮 review 后裁定：`harness_verify` 显式接收 `--session-id`、`--lease-wait-seconds`、`--android-instance-id`；wait 默认 0，只接受 CLI 覆盖，真实 v2 模式缺 session/instance ID 就返回 2。若判断错误，代价是 CLI 更繁琐；若不做，代价是实现者自行猜环境变量/默认值，导致租约无法可重现地获取。 |
| 2026-08-31 | PLAN review 熔断 M1 | 删除回滚矩阵中 `06` 消费 `05` 的错误引用。该项不承重；若仍有隐性依赖，代价是 `06` 将缺少明确契约，但当前三份直接边集均证明不存在该边。 |
| 2026-08-31 | 门① | 用户通过 PLAN v4 及默认 canonical-core 口径，并要求后续所有 spec 按 autopilot 模式执行。 |
| 2026-08-31 | 01-device-safety | 选择 `requirements-first` + `autopilot`：两个当前/预期安全行为及验收已明确，无需在 requirements 前做架构选型；autopilot 由用户显式指定。 |
| 2026-08-31 | 01 requirements review 熔断 I4 | R4 的验收矩阵固定为 Claude、Codex 每个入口各覆盖 serial 缺失与非空非法 `-bad`，共四个组合，并统一断言 flag 错误优先于 serial 校验。若判断错误，代价仅是增加两组离线 fixture；若不做，两个独立实现之一仍可能在非法 serial 下错误地先报 `ANDROID_SERIAL`。 |
| 2026-08-31 | 01 tasks review 熔断 I1-I3 | 测试任务最终拆成 fixture、非法/合法 serial、flag+Demo、skill block 提取、contract、mutation、legacy 聚合八片，生产改动拆成 Claude、Codex、skills 三片；代码步骤内嵌最小 Bash 骨架并显式串联全部消费。若判断错误，代价是 tasks 更长、调度步骤更多；若不做，复杂 oracle 仍可能空跑且独立执行者无法在快速 review 窗口内复现设计。 |
| 2026-09-01 | 01-device-safety 验收 | Claude 真实 verifier 的 serial 契约固定为显式 `ANDROID_SERIAL` 且匹配 `^[A-Za-z0-9][A-Za-z0-9._:-]*$`；缺失/非法值在零 ADB 后返回 `2`。Claude/Codex 的 `--allow-skip` 仅允许 Demo，真实模式的 flag 错误先于 serial 校验。两个部署 skill 的真机块采用唯一 preflight、固定 `adb -s "$device_serial"` 和保守单行 allowlist。后续公共 runtime/adapter 必须保持这些前置契约。证据：`work/2026-08-31-01-device-safety/acceptance-report.md`。 |
| 2026-09-01 | 02-offline-quality-gate 选片 | 选择 `requirements-first` + `autopilot`：PLAN 已确定 offline/CI 分流、自动测试发现和固定工具策略，不需要先做架构原型；autopilot 沿用用户对后续规格的显式授权。 |
| 2026-09-01 | 02 requirements 默认口径 | Offline 必需依赖包含现有回归实际使用的 Bash、Git、Python 3、ripgrep 与基础文本/coreutils 命令；缺失在检查前返回 `2`。CI 固定 ShellCheck 0.11.0、shfmt 3.14.0、Gitleaks 8.30.1，固定 `ubuntu-24.04` x86_64 官方资产并校验 requirements 所列 SHA-256；工具实际执行后的非零统一为检查失败 `1`。 |
| 2026-09-01 | 02 requirements baseline 裁定 | 受管 Shell 集合固定为工作树内排除 `.git/.spec` 的普通 `.sh` 或 Bash-shebang 文件，C locale 排序且不跟随软链。历史静态债务以锚点 `b143821925e279401334d09a788ba9a969df5c7c` 的批准 `path + git-blob` 集合豁免，baseline SHA-256 同时钉在 gate/test；新/变化内容不得扩增豁免。若判断错误，代价是历史债务延后清理；若不做，02 的 400 行预算无法形成绿色 CI。 |
| 2026-09-01 | 02 requirements contract 裁定 | Gate CLI 只接受唯一 `--offline`/`--ci`；依赖与 CI 工具预检必须早于 syntax/test。ShellCheck 参数固定为 `-x --severity=warning`，shfmt 固定为 `-d -i 2 -ci -bn`；`.gitleaks.toml` 精确继承默认规则且摘要为 `27630a...d76e`，CI 每次用运行时拼接的 AWS canary 证明真实规则有效，再扫描工作树。COVERAGE 固定五列和 active 状态。若判断错误，代价是 gate 协议更严格、fixture 更多；若不固定，空配置或参数漂移可制造假绿。 |
| 2026-09-01 | 02 requirements baseline 集合 | Canonical baseline 是锚点提交的全部 30 个受管入口，C-locale `path<TAB>blob` 文件摘要为 `62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f`；运行时不读取历史提交，以便 shallow CI 一致执行。 |
