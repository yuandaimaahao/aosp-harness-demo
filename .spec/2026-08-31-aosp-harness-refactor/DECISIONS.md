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
