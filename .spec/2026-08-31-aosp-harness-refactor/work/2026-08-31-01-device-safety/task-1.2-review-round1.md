# 任务 1.2 Diff 审查（第 1 轮）

审查范围：`782387ab..6d0ade26`，仅 `tests/test-device-safety.sh` 的 Claude 非法 serial 矩阵。

## 结论：PASS

Findings：阻断 0，重要 0，次要 0；⚠️ 待核实项 0。

## ① 规格符合性

- ✅ 仅修改指定的 `tests/test-device-safety.sh`，新增产出函数 `device_safety_run_claude_invalid_serial_matrix`，并注册 `claude-invalid-serial` scope。
- ✅ 非法输入矩阵逐项匹配简报：`__UNSET__`、4 个非法首字符、路径、空格、实际 LF、分号与加号，共 10 项。`$'bad\nvalue'` 是 Bash ANSI-C 引号，传入值包含实际 LF，而非字面量反斜杠加 `n`。
- ✅ `__UNSET__` 走 `env -u ANDROID_SERIAL`；其他输入以 `ANDROID_SERIAL="$serial"` 的独立环境赋值传入子进程。
- ✅ 每例均调用 `device_safety_fake_adb_install` 创建独立 fixture 和新置空的 ADB 日志，并以该 fixture 的私有 fake-ADB 目录置于 `PATH` 首位运行 Claude 真实 verifier。
- ✅ 每例都断言精确退出码 `2`、stderr 包含 `ANDROID_SERIAL`、fake ADB 日志大小为零；rc 失败时的缺陷标签按要求形成 `FAIL  claude <case> ANDROID_SERIAL: expected rc=2 and zero adb calls`。
- ✅ 红阶段的 scope 名称、预期首错及原始日志证据均已在实现报告中记录；报告所列 `bash -n`、fixture scope 与 `git diff --check` 成功，符合本任务应有的验证边界。

## ② 质量

- ✅ YAGNI：40 行改动仅实现该矩阵、注册入口及所需局部变量，没有提前加入生产 serial 校验、公共运行时或其他任务的正向/flag/skill 检查。
- ✅ Oracle 真伪：退出码、stderr 和 fake ADB 日志是相互独立的三个观察面；当前裸 `adb` 会先被 fake ADB 写入日志，故不能通过只返回错误码来伪装“零 ADB 调用”。
- ✅ 隔离：每个 case 有独立临时目录和日志；子进程的 `PATH` 以私有 fake ADB 开头，未使用开发机真实 ADB 的普通命令解析路径。
- ✅ 实际 LF / 缺失 env：实际 LF 使用 `$'...'` 生成；缺失变量以 `env -u` 处理，未把空字符串误当成缺失分支。
- ✅ 日志污染：每个 fixture 在调用前以 `: >"$ADB_LOG"` 置空，且 fixture 路径按 case 序号隔离；前一例记录无法影响后一例的零调用断言。
- ✅ 错误路径：verifier 非零退出没有因 `set -e` 被测试脚本提前中断（脚本仅设 `set -u`）；返回码立即保存并继续执行三个失败判据，能够汇总多个 case 的缺陷。

## Findings

### 阻断

无。

### 重要

无。

### 次要

无。

### ⚠️ 需核实项

无。此审查未重跑实现者已报告的验证；结论基于任务简报、实现报告与提交 diff 的静态核对。
