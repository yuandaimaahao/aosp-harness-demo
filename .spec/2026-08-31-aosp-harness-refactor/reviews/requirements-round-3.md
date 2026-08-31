# 01-device-safety requirements review — round 3

## 结论

- 规格符合性与验收覆盖：`NEEDS_CHANGES`。R1–R3、R5–R7 已与 PLAN 和直接源码边界对齐；R4 的行为要求正确，但错误优先级仍未对 Claude、Codex 两个独立实现各自闭环取证。
- 质量：`NEEDS_CHANGES`。发现 0 个阻断、1 个重要、0 个次要问题；无占位符、内部矛盾、YAGNI、新的恒真/只跑不验项或范围漂移。

## 上一轮 findings 复核

| 项 | 复核结论 | 依据 |
|---|---|---|
| I4 | 未完全修复 | 验收清单新增了非空非法 `-bad`，但“两个入口分别以 serial 缺失和非空非法”通常只要求每个入口取一种状态，不能证明两个实现都覆盖两种状态 |
| I5 | 已修复 | Claude/Codex 的应用缺失 fixture 均要求至少一行以 `SKIP  ` 开头，并同时约束退出 `0` 和精确末行 |
| M1 | 已修复 | 非法 serial 清单已明确“含实际 LF 的 Bash 值 `$'bad\nvalue'`” |

## Findings

### 阻断（0）

无。

### 重要（1）

#### I4. R4 的优先级验收仍把两种 serial 状态分摊给两个独立入口

- R4 要求 Claude 与 Codex 各自在 serial 校验前拒绝真实模式 `--allow-skip`；两个脚本是独立实现，任一脚本都可能只对空 serial 特判、对非空非法 serial 先报 `ANDROID_SERIAL`。
- 清单第 44 行写“两个入口分别以 serial 缺失和非空非法 `-bad` 组合取证”，按通常语义只需一个入口测缺失、另一个入口测 `-bad`。该矩阵仍允许上述错误实现通过。
- 应改成“Claude 与 Codex 每个入口均分别以 serial 缺失和非空非法 `-bad` 取证”，四个组合都断言退出 `2`、stderr 含 `--allow-skip requires --demo` 且不含 `ANDROID_SERIAL`、fake ADB 日志为空。

### 次要（0）

无。

## R1–R7 全量复核

| 需求 | 规格符合性 | 验收覆盖 |
|---|---|---|
| R1 | 符合 PLAN；Claude 真实 verifier 的 `shell`/`logcat` 裸 ADB 风险与源码一致 | 完整：正反字符边界、同一 serial 前缀及成功末行均有 |
| R2 | 符合首次 ADB 前 fail-closed 不变量 | 完整：缺失及各类非法值均绑定退出 `2`、stderr 和零 ADB |
| R3 | 符合 `01` 文件边界；两个 Claude skill 的 root/remount/push/reboot/shell 命令与枚举一致 | 完整：首条 ADB 前取值/完整校验、固定变量、分离参数及禁裸调用均可静态判定 |
| R4 | 符合真实模式必需断言不得以 SKIP 成功的不变量 | 部分：行为及优先级明确，但两个实现各自的缺失/非法矩阵未闭合，见 I4 |
| R5 | 符合保留离线 Demo 探索语义 | 完整：两个入口均约束 `SKIP  ` 明细、退出码和精确末行 |
| R6 | 符合私有 mock、禁止真实设备访问的全局约束 | 完整：拒绝路径空日志、成功路径 serial 前缀和 fake `PATH` 相互对应 |
| R7 | 符合保留旧入口及三套回归的不变量 | 完整：两个 verifier 可执行路径和三套旧回归均有判据 |

## 质量核对

- 直接事实抽查：Claude verifier 当前真实路径有裸 `adb shell`/`adb logcat`；Codex 已校验 serial 但真实模式仍接受 `--allow-skip`；两个 Claude skill 的 ADB 子命令与 R3 枚举一致。
- 可执行性：除 I4 的组合矩阵缺口外，退出码、stdout 末行、stderr、fake ADB 日志、静态 skill 约束和旧回归都有可失败判据。
- 范围：未提前引入 common runtime、lease、超时/重试或 verifier 断言收敛；这些仍留给 `04`、`05`、`06`、`09`。
- 审查限制：按任务要求未运行实现验证，仅进行文档与直接源码静态核对。
