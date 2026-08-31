# 任务 1.3 报告：Claude 合法 serial 正向矩阵

## Status

完成。已新增 `claude-valid-serial` scope，覆盖 `demo-serial` 与 `A0._:-z` 两个合法 serial；每个 fixture 均隔离 stdout、stderr 与 fake ADB 日志，并检查每条日志记录的固定 `adb -s <serial> ` 前缀、非空日志和精确成功末行。

## Commits

- `f31464d test: add Claude valid serial matrix`

## 改动文件

- `tests/test-device-safety.sh`

## 红阶段证据

红阶段证据: task-1.3-red-stage.log

绝对路径: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-1.3-red-stage.log`

命令：

```bash
DEVICE_SAFETY_TEST_SCOPE=claude-valid-serial bash ./tests/test-device-safety.sh
```

退出码：`1`。

关键输出（stderr，首错）：

```text
FAIL  claude demo-serial: expected adb -s prefix on every call
FAIL  claude demo-serial: expected rc=0 and RESULT PASS
FAIL  claude A0._:-z: expected adb -s prefix on every call
FAIL  claude A0._:-z: expected rc=0 and RESULT PASS
```

完整 stdout/stderr 与退出码已持久化到上述证据文件。运行期 fake ADB 日志仍由既有 EXIT trap 清理；红灯证明当前 Claude verifier 的裸 ADB 调用已被私有 fake ADB 捕获，未访问真实 ADB。

## 验证

- `bash -n ./tests/test-device-safety.sh`：退出 `0`。
- `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh`：退出 `0`。
- `git diff --check`：退出 `0`。

## 顾虑

无。任务按计划刻意停在生产修复前的红阶段；Claude verifier 尚未固定 serial，因此正向 scope 当前预期失败，后续任务 2.1 应将其转绿。
