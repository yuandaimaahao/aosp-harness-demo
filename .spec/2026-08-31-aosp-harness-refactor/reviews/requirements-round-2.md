# 01-device-safety requirements review — round 2

## 结论

- 规格符合性与验收覆盖：`NEEDS_CHANGES`。R1–R3、R6、R7 已与 PLAN 对齐；R4 的需求范围已补齐 Claude/Codex，但错误优先级仍有一个未验收分支；R5 的 `SKIP` 输出也未被清单断言。
- 质量：`NEEDS_CHANGES`。无阻断项，发现 2 个重要、1 个次要问题。规格无内部矛盾、无 YAGNI，上一轮“只跑不验”的 diff 规模项已从产品验收移除并留在 PLAN 的 review-package 门中。

## 上一轮 findings 复核

| 项 | 复核结论 | 依据 |
|---|---|---|
| B1 | 行为已修复，验收未完全闭合 | R4 已同时覆盖 Claude/Codex，并规定 flag 错误先于 serial 校验；但清单只验证同时缺失 serial，未验证同时为非空非法 serial，见 I4 |
| I1 | 实质修复 | 已补合法 `A0._:-z`，以及前导 `._:`、`;`、`+` 等非法边界；每个拒绝例均绑定退出码、stderr、零 ADB。换行表示仍有次要歧义，见 M1 |
| I2 | 已修复 | 清单明确要求每个真机代码块先取值并执行完整正则校验，所有枚举命令使用分离参数 `adb -s "$device_serial"`，并禁止其他 target 变量和裸调用 |
| I3 | 已修复 | requirements 不再把仅打印 `git diff --numstat` 当作可执行不变量；8 文件/400 行限制仍由 PLAN 第 53 行规定在 review package 中机械统计和熔断，职责分层一致 |

## Findings

### 阻断（0）

无。

### 重要（2）

#### I4. R4 的“先于 serial 校验”仍可被不符合实现绕过

- R4 要求 flag 组合错误先于任何 serial 校验，语义同时覆盖缺失和非法 serial。
- 清单只写“即使同时缺失 serial”仍优先报 flag 错；实现可以仅对空 serial 特判，遇到 `ANDROID_SERIAL=-bad` 时先报 `ANDROID_SERIAL`，仍通过现有清单却违反 R4。
- 应为 Claude、Codex 各增加一次非空非法 serial + 真实模式 `--allow-skip`：退出 `2`、stderr 含 `--allow-skip requires --demo` 且不含 serial 主错误、fake ADB 日志为空。

#### I5. R5 要求输出 `SKIP`，验收清单却只检查退出码和末行

- R5 的探索语义包含三件事：输出 `SKIP`、末行 `RESULT PASS (SKIP allowed)`、退出 `0`。
- 当前清单只约束后两项；删除 `SKIP` 明细的实现仍会通过，不能证明结果明细语义被保留。
- 应对 Claude/Codex 的应用缺失 fixture 各断言至少一行以 `SKIP` 开头，并继续断言末行和退出码。

### 次要（1）

#### M1. `bad\nvalue` 未明确是实际 LF 还是两个字面的反斜杠字符

- Markdown 行内代码中的 `bad\nvalue` 可被实现者写成普通字符串；那只验证了反斜杠非法，未验证多行环境值。
- 在验收文字中注明 fixture 使用实际 LF（例如 Bash 的 `$'bad\nvalue'`）即可消除歧义。

## R1–R7 规格符合性与验收覆盖

| 需求 | 规格符合性 | 验收覆盖 |
|---|---|---|
| R1 | 符合 PLAN；目标、正则、调用范围和同一 serial 清楚 | 基本完整；合法/非法边界、成功调用前缀和末行均有，实际 LF 表示见 M1 |
| R2 | 符合 fail-closed 与零 ADB 不变量 | 基本完整；缺失和非法值均绑定 `2`、stderr、空日志 |
| R3 | 符合 `01` 文件边界和现有两个 Claude skill 的真实裸 ADB 风险 | 完整；校验顺序、完整正则、固定变量、分离参数和禁止裸调用均可静态判定 |
| R4 | 符合 PLAN 整体“真实 SKIP 不得成功”不变量，Claude/Codex 范围已补齐 | 部分；常规及缺失 serial 优先级有覆盖，非法 serial 组合缺失，见 I4 |
| R5 | 符合保留离线 Demo 探索入口的要求 | 部分；退出码和末行有覆盖，缺少 `SKIP` 行断言，见 I5 |
| R6 | 符合全程 fake ADB、禁止真实设备访问的全局约束 | 完整；拒绝路径空日志、成功路径 serial 前缀及私有 fake PATH 相互对应 |
| R7 | 符合保留三个顶层 Demo 和旧入口的不变量 | 完整；两个 verifier 用 `test -x`，三套旧回归均要求退出 `0` |

## 质量核对

- 矛盾：未发现。R4 的 flag 优先级消除了 R2/R4 同时触发时的语义冲突。
- 恒真/只跑不验：未发现新的恒真项；上一轮 I3 已移除，现有退出码、末行、stderr、日志、静态 skill 和旧回归检查均可失败。
- 错误路径：serial 缺失/非法和真实 `--allow-skip` 均 fail-closed；组合错误尚差 I4 的一个机械分支。
- YAGNI/范围：未发现。公共 runtime、lease、common verifier 对齐仍留给后续 spec。
- 不变量：真实 ADB 隔离、旧回归、旧入口均有对应判据；diff 规模继续由 PLAN 的实施前 review-package 门负责，不应重新塞入功能测试。
