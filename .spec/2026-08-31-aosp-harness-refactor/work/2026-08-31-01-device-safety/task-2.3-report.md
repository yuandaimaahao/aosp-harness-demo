# Task 2.3 report — 固定 Claude skill 真机代码块的设备目标

Status: DONE_WITH_CONCERNS

Commits:

- `d956617 fix(claude): pin skill adb targets`

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-2.3-red-stage.log`

## 改动

- `build-services-jar` 的唯一真机代码块现在先读取并完整校验 `ANDROID_SERIAL`，四条 `root`、`remount`、`push`、`reboot` 均为独立的 `adb -s "$device_serial"` 行。
- `build-sepolicy` 的行内 ADB 验证改为唯一 fenced Bash 真机代码块，采用同一 preflight；两条 `shell` 调用均固定到 `device_serial`。

## 验证

- `DEVICE_SAFETY_TEST_SCOPE=skills bash ./tests/test-device-safety.sh`：exit 0；生产 skill contract 通过，并验证两个 skill 各自的 regex 与裸 ADB 两类 mutation（共四个）均被拒绝。
- `for file in ./tests/test-device-safety.sh ./claude-code/features/dev-sidebar/verify-sidebar.sh ./codex/features/dev-sidebar/verify-sidebar.sh ./claude-code/features/.harness/tests/test-harness.sh; do bash -n "$file" || exit; done`：exit 0。
- `bash ./tests/test-device-safety.sh`：exit 0；stdout 精确末行为 `RESULT PASS  device safety`。
- `git diff --check`：exit 0。

最终聚合命令 stdout：

```text
PASS  demo harness startup, process layer, and strict verification
PASS  Codex feature context selection and branch checks
RESULT PASS  shared Harness regression suite
RESULT PASS  device safety
```

## 顾虑

- worktree 在本任务开始前已有未跟踪文件 `.red-evidence-task-2.2.txt`；未修改或纳入本任务提交。
