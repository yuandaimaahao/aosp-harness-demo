# 任务 2.2 审查（第 1 轮）

Status: PASS

Review scope: `fb161f9f..d1144174`（`d114417 fix(codex): reject allow-skip outside demo mode`）。按要求仅作静态 diff/source 审查，未修改实现、未重跑验证。

## ① 规格逐项符合性

| 核对项 | 结论 | 静态证据 |
|---|---|---|
| preflight 在 serial 前 | 符合 | 新增条件位于参数解析循环后、既有 `if ((demo == 0)); then` serial 读取与格式校验前。 |
| 缺失 serial 时 flag 错误优先 | 符合 | 非 demo 且 `allow_skip=1` 时立即向 stderr 输出 `error: --allow-skip requires --demo` 并 `exit 2`；尚未读取 `ANDROID_SERIAL`。 |
| 非法 `-bad` 时 flag 错误优先 | 符合 | 同一前置条件不依赖 serial 值，故在 `ANDROID_SERIAL=-bad` 时也会先退出，不会进入既有 regex 分支。 |
| exit 2 / 零次 adb | 符合 | 拒绝分支显式 `exit 2`；它位于首次 `ADB=(adb -s "$serial")` 构造和所有后续 `"${ADB[@]}"` 调用之前，因此该分支到达零次 ADB 调用。 |
| `--demo --allow-skip` 的 SKIP 语义 | 符合 | 条件仅匹配 `demo == 0`，Demo 组合不会进入新分支；diff 未修改既有 Demo 数据源、`skip()` 或汇总逻辑。 |
| 其余真实/Demo 验证逻辑不变 | 符合 | 相对于固定点，除该五行 preflight 外无其他 hunk。 |
| 入口与变更范围 | 符合 | 仅修改任务指定的 `codex/features/dev-sidebar/verify-sidebar.sh`；未删除入口，未触及 common verifier 或其他超出范围组件。 |

## ② 质量

新增代码直接采用任务简报指定的精确条件、错误文本和退出码；与现有 Bash 算术条件、stderr 输出和 fail-closed 控制流一致。没有新增依赖、抽象、重复逻辑或可见的 shell 可移植性问题。仓库 AGENTS 指令未包含与此 hunk 冲突的编码规范。

## Findings

- 阻断：0
- 重要：0
- 次要：0

结论：PASS。
