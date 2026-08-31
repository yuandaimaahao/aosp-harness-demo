# 任务 2.2 报告

Status: PASS

Commits: d114417 fix(codex): reject allow-skip outside demo mode

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-2.2-red-stage.log

验证:

- `bash -n ./codex/features/dev-sidebar/verify-sidebar.sh`：通过。
- `DEVICE_SAFETY_TEST_SCOPE=codex-flag-demo bash ./tests/test-device-safety.sh`：通过。
- `git diff --check`：通过。

摘要: 在 Codex verifier 参数解析完成后、现有 `ANDROID_SERIAL` 校验前，加入 `--allow-skip` 仅允许 Demo 模式的 fail-closed preflight；拒绝时 stderr 输出 `--allow-skip requires --demo` 并退出 2。Demo 缺失应用的既有 SKIP 语义未改动。

Concerns: 未运行完整 device-safety、三套旧回归或真实设备；本任务约束为仅使用私有 fake ADB 的 Codex 专项回归。
