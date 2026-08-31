# Task 2.1 Production Diff Review — Round 1

Reviewed range: `61e5fa8f..fb161f9f` (`fb161f9 fix: pin Claude verifier adb target`).

## ① 规格逐项符合性

| 判据 | 结论 | 证据 |
|---|---|---|
| 真实模式 `--allow-skip` 优先拒绝 | 符合 | 参数解析后首先判定 `DEMO=0 && ALLOW_SKIP=1`，向 stderr 输出规定错误并 `exit 2`；serial 尚未读取或校验。 |
| 缺失/非法 serial、regex、exit 2、零 ADB | 符合 | 非 Demo 分支读取 `${ANDROID_SERIAL-}`，使用精确 regex `^[A-Za-z0-9][A-Za-z0-9._:-]*$`；失败路径仅输出包含 `ANDROID_SERIAL` 的错误并退出，构造 ADB argv 前没有 ADB 调用。 |
| Claude real shell/logcat 统一固定目标 | 符合 | 仅在通过 preflight 的真实模式构造 `ADB=(adb -s "$serial")`；两个真实调用分别改为 `"${ADB[@]}" shell` 与 `"${ADB[@]}" logcat`。 |
| 数组仅 real mode 使用 | 符合 | `ADB` 只在 `DEMO=0` 时构造，且其两个引用都位于各自的 real-mode `else` 分支。 |
| Demo 语义不变 | 符合 | Demo 路径及其预置输出未改；`--demo --allow-skip` 仍可走既有 `SKIP` / `RESULT PASS (SKIP allowed)` 汇总。 |
| 旧 fake fixture 正确剥离 `-s` 且不放宽查询 | 符合 | fixture 精确要求 `$1=-s`、`$2=demo-serial` 后 `shift 2`，既有 `case "$*"` 的完整查询字面量未变化；真实 fixture 显式传入该 serial。 |

任务 2.1 的文件范围和既有入口均保持不变。R3/Codex/root-level 回归属于后续任务，不构成本任务 diff 的缺项。

## ② 质量

生产改动小而局部，Bash 数组保持 argv 分离，错误路径在任何 ADB 包装调用之前终止；未见未定义数组访问、裸 real-mode `adb` 调用或 fixture 宽松匹配。

## Findings

### 阻断

无（0）

### 重要

无（0）

### 次要

无（0）

### ⚠️

无（0）

## 结论

PASS — 阻断 0，重要 0，次要 0，⚠️ 0。
