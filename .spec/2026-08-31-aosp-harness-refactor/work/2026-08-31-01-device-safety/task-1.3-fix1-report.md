# 任务 1.3 修复报告 1

## Status

完成。Claude 合法 serial 矩阵的 fake ADB 日志检查已从“行内包含前缀”收紧为“每行必须以精确 `adb -s <serial> ` 前缀开头”。原有非空日志断言和失败标签均保留。

## Commits

- `3e4a0e2 test: anchor Claude adb log prefix checks`

## 修复证据

红阶段证据: task-1.3-fix1-red-stage.log

绝对路径: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-1.3-fix1-red-stage.log`

局部负向取证使用如下单行（`adb` 前有垃圾 token）：

```text
unexpected adb -s demo-serial shell getprop sys.boot_completed
```

结果：

```text
old_contains_nonmatching=0
new_line_start_nonmatching=1
```

这证明旧 `grep -Fvc` 的行内包含逻辑会放过该样本，而新的 `awk 'index($0, prefix) != 1'` 行首检查会拒绝它。

## 验证

- `bash -n ./tests/test-device-safety.sh`：退出 `0`。
- `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh`：退出 `0`。
- `DEVICE_SAFETY_TEST_SCOPE=claude-valid-serial bash ./tests/test-device-safety.sh`：预期红灯，退出 `1`；首错仍为 `FAIL  claude demo-serial: expected adb -s prefix on every call`。
- `git diff --check`：退出 `0`。

## 顾虑

无。合法 serial scope 仍会在 Claude verifier 的生产修复前红灯，这是任务 1.3 的既定阶段行为。
