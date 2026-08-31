---
id: 2026-08-31-01-device-safety
依赖: []
消费: 无
产出: "tests/test-device-safety.sh —— 无参数；全部通过时退出 0 且 stdout 末行为 RESULT PASS  device safety，任一断言失败时退出非零"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户通过 PLAN v4 并明确要求后续按 autopilot 执行；门②由 autopilot 按已确认 PLAN 自动通过
---

> 用户原话：
> “$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；用户已通过 PLAN v4，并要求后续按 autopilot 执行。

## 目标

通过强制 `ANDROID_SERIAL` 来固定 ADB 的 `shell`、`logcat`、`root`、`remount`、`push`、`reboot` 目标，消除独立 Claude Demo 可操作错设备、以及独立 Codex verifier 可把真实模式 SKIP 判为成功的两个最高风险缺口，同时保留离线 Demo 和现有用户入口。

## 需求

R1. [计划] 当 Claude verifier 在真实模式启动时，系统必须在第一次 ADB 调用前要求 `ANDROID_SERIAL` 匹配 `^[A-Za-z0-9][A-Za-z0-9._:-]*$`，并使所有 `shell` 与 `logcat` 调用通过同一 `adb -s "$serial"` 目标执行。

R2. [计划] 如果发生 Claude 真实 verifier 缺少 `ANDROID_SERIAL` 或 serial 不符合安全格式，系统必须在零次 ADB 调用后向 stderr 输出包含 `ANDROID_SERIAL` 的错误，并以退出码 `2` 结束。

R3. [计划] 当 Claude `build-services-jar` 部署流程或 `build-sepolicy` 真机验证流程被按文档执行时，系统必须先读取并校验显式 `ANDROID_SERIAL`，且每条 `root`、`remount`、`push`、`reboot`、`shell` 命令必须使用 `adb -s "$device_serial"`。

R4. [计划] 当 Claude 或 Codex verifier 在非 demo 模式收到 `--allow-skip` 时，系统必须先于 serial 校验拒绝该组合，在零次 ADB 调用后向 stderr 输出 `--allow-skip requires --demo`，并以退出码 `2` 结束。

R5. [计划] 当 Claude 或 Codex verifier 以 `--demo --allow-skip` 运行且应用缺失时，系统必须保留现有探索语义：输出 `SKIP`、末行输出 `RESULT PASS (SKIP allowed)` 并退出 `0`。

R6. [计划] 在本 spec 的隔离回归期间，系统必须仅使用临时 fake `adb` 取证，必须证明安全拒绝路径不执行 fake `adb`、成功路径每次调用均携带预期 serial，且不得访问开发机真实 ADB server。

R7. [计划] 系统必须保留 `claude-code/features/dev-sidebar/verify-sidebar.sh`、`codex/features/dev-sidebar/verify-sidebar.sh` 和三套旧回归入口的现有路径。

## 验收标准

主验证命令: bash ./tests/test-device-safety.sh
期望输出: stdout 末行精确为 `RESULT PASS  device safety`，退出码为 `0`

验收清单:

- [ ] Claude 真实 verifier 对 serial 缺失、`-bad`、`.bad`、`_bad`、`:bad`、`bad/path`、`bad value`、含实际 LF 的 Bash 值 `$'bad\nvalue'`、`bad;value`、`bad+value` 均返回 `2`，stderr 包含 `ANDROID_SERIAL`，fake ADB 日志为空。
- [ ] Claude 真实 verifier 分别接受 `demo-serial`、`A0._:-z`，fake ADB 每条记录都以对应 `adb -s <serial> ` 开头，且末行为 `RESULT PASS`。
- [ ] Claude 两个流程 skill 的每个真机代码块都在首条 ADB 前从 `ANDROID_SERIAL` 取值并执行完整安全格式校验，枚举出的每条 ADB 命令都精确以分离参数 `adb -s "$device_serial"` 开头，不存在其他 target 变量或裸调用。
- [ ] Claude 与 Codex 每个入口在真实模式传 `--allow-skip` 时，均分别以 serial 缺失和非空非法 `-bad` 取证（共四个组合）；每个组合都返回 `2`、stderr 含 `--allow-skip requires --demo` 且不含 `ANDROID_SERIAL`、fake ADB 日志为空，证明 flag 错误恒先于 serial 校验。
- [ ] Claude 与 Codex 的应用缺失 `--demo --allow-skip` fixture 均至少输出一行以 `SKIP  ` 开头的明细，退出 `0`，且末行为 `RESULT PASS (SKIP allowed)`。
- [ ] `bash -n` 对本 spec 修改的 shell 文件全部退出 `0`，Claude、Codex、common 三套旧回归均退出 `0`。

不变量（不许劣化，2-4 项）:

- 开发机真实 ADB 调用数 ≤ `0`，验证: `bash ./tests/test-device-safety.sh`在私有 fake-ADB `PATH` 下运行且日志只含 fixture 记录。
- 三套旧回归失败数 ≤ `0`，验证: `bash ./claude-code/features/.harness/tests/test-harness.sh && ./codex/tests/test-harness.sh && ./common/tests/test-harness.sh`。
- 既有 verifier 用户入口删除数 ≤ `0`，验证: `test -x claude-code/features/dev-sidebar/verify-sidebar.sh && test -x codex/features/dev-sidebar/verify-sidebar.sh`。

## 超出范围

- 不在本 spec 引入公共 ADB command runtime、超时、重试、stderr 诊断或 lease；这些由 `04`、`06` 及 `09` 处理。
- 不收敛三套 verifier 断言集，不修改 common verifier；由 `05` 处理。
- 不执行真实 ADB、CVD、AOSP build、网络访问、发布、提交或推送。

## autopilot 裁定

- 必答问题 `0` 个，带推荐问题 `0` 个；现状、预期、不应变均已被 PLAN 和源码证据覆盖。
- 已定告知：安全 serial 格式与现有 Codex/common 对齐；用法/安全拒绝返回 `2`；`--allow-skip` 仅 demo 可用；本 spec 只做最小安全补丁，不提前引入后续公共内核。
