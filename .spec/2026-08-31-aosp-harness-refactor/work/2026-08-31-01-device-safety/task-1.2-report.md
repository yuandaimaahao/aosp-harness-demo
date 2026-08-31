# 任务 1.2 报告：Claude 非法 serial 矩阵

Status: DONE

Commits:

- `6d0ade261589c123fe5c8d6704cdc076e288f91e` — `test: add Claude invalid serial matrix`

改动文件:

- `tests/test-device-safety.sh`：新增 `device_safety_run_claude_invalid_serial_matrix`，覆盖缺失 serial 及 9 个非法 serial；每例使用独立私有 fake-ADB fixture，并断言退出码、stderr 及零 ADB 调用。

红阶段证据: task-1.2-red-stage.log

- 命令：`DEVICE_SAFETY_TEST_SCOPE=claude-invalid-serial bash ./tests/test-device-safety.sh`
- 退出码：`1`（生产 verifier 尚未实施本 spec 的 serial 前置拒绝，符合任务要求的红阶段）。
- 关键输出：`FAIL  claude missing ANDROID_SERIAL: expected rc=2 and zero adb calls`。
- 原始证据路径：`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-1.2-red-stage.log`。该日志还显示缺失 serial 时的 stderr 断言失败和 fake ADB 日志非空，证明 oracle 捕获了当前裸 ADB 调用。

验证:

- `bash -n ./tests/test-device-safety.sh`：退出 `0`。
- `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh`：退出 `0`。
- `git diff --check`：退出 `0`。

顾虑:

- `claude-invalid-serial` scope 当前应为红灯；待任务 2.1 为 Claude verifier 加入 flag/serial 前置检查与固定 ADB argv 后才应转绿。本任务未修改生产 verifier。
