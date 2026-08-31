# 任务 1.4 报告：flag 优先级与 Demo SKIP 矩阵

## Status

DONE

## Commits

- `c411726 test: add flag priority and demo skip matrix`

## 改动

- 在 `tests/test-device-safety.sh` 添加 `device_safety_run_flag_and_demo_matrix` 及 Claude/Codex 独立 scope。
- 四个真实模式组合精确覆盖 `claude|__UNSET__`、`claude|-bad`、`codex|__UNSET__`、`codex|-bad`；每例用独立私有 fake ADB fixture，验证 rc=2、`--allow-skip requires --demo`、无 `ANDROID_SERIAL` 提示与零次 fake ADB 调用。
- 两个 Demo 缺应用组合均验证 rc=0、`SKIP  ` 明细、精确 `RESULT PASS (SKIP allowed)` 末行及零次 fake ADB 调用。
- 已断言两个既有 verifier 路径均可执行，并注册 `claude-flag-demo`、`codex-flag-demo`、`flag-demo` scope。

## 红阶段证据

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-1.4-red-stage.log

命令：

```bash
DEVICE_SAFETY_TEST_SCOPE=flag-demo bash ./tests/test-device-safety.sh
```

退出码：`1`。

关键 stderr（首错）：

```text
FAIL  claude real allow-skip missing serial: expected flag error before ANDROID_SERIAL
```

完整输出在证据文件。所有 fixture 均将临时 fake `adb` 置于 `PATH` 首位；没有访问真实 ADB。

## 验证

- `bash -n ./tests/test-device-safety.sh`：rc `0`。
- `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh`：rc `0`。
- `git diff --check`：rc `0`（提交前）。
- `DEVICE_SAFETY_TEST_SCOPE=claude-invalid-serial bash ./tests/test-device-safety.sh`：rc `1`，保持任务 1.2 的既有生产修复前红阶段。
- `DEVICE_SAFETY_TEST_SCOPE=claude-valid-serial bash ./tests/test-device-safety.sh`：rc `1`，保持任务 1.3 的既有生产修复前红阶段。
- `DEVICE_SAFETY_TEST_SCOPE=flag-demo bash ./tests/test-device-safety.sh`：rc `1`，符合本任务指定的生产修复前红阶段；Demo 子用例没有新增失败。

## 顾虑

无。当前三个 verifier safety scope 的红灯均由后续生产任务（2.1/2.2）尚未落地引起；本任务只交付测试判据，未修改生产 verifier。
