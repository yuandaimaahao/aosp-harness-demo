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
