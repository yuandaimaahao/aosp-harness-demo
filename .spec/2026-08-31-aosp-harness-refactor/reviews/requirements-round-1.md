# 01-device-safety requirements review — round 1

## 结论

- 规格符合性：`NEEDS_CHANGES`。R1–R7 的主要来源和范围基本正确，但 R4 漏掉 Claude 真实模式的同类假成功路径，违反 PLAN 的整体不变量；R1/R2/R3 的部分行为也缺少足以约束实现的验收边界。
- 质量：`NEEDS_CHANGES`。无占位符、无明显 YAGNI、无错误文件路径；发现 1 个阻断、3 个重要问题、0 个次要问题。主要风险是范围遗漏、边界覆盖不足及只输出不判定的验收命令。

## Findings

### 阻断（1）

#### B1. R4 只禁止 Codex 的真实模式 `--allow-skip`，Claude 仍可把必需断言的 SKIP 判为成功

- PLAN 整体不变量要求“真实模式……必需断言 SKIP 时不得退出 `0`”，并非只约束 Codex。
- Claude verifier 当前无 demo 限制地解析 `--allow-skip`，应用缺失时只要 `ALLOW_SKIP=1` 就输出 `RESULT PASS (SKIP allowed)`；增加 serial 后该假成功仍会存在。
- requirements 的 R4 和验收清单只覆盖 Codex，R5 又明确把 Claude/Codex 的 allow-skip 合法场景限定为 `--demo --allow-skip`。因此当前规格无法完成上游真实模式 fail-closed 不变量。
- 必须将真实模式拒绝 `--allow-skip` 的行为扩展到 Claude，并为 Claude/Codex 各设零次 ADB、stderr、退出码 `2` 的验收；同时明确 `--allow-skip` 与缺失/非法 serial 同时出现时的错误优先级，避免 R2 与新增规则歧义。

### 重要（3）

#### I1. R1/R2 的 serial 正反边界未被验收完整覆盖

- 契约明确为 `^[A-Za-z0-9][A-Za-z0-9._:-]*$`，但成功 fixture 只有 `demo-serial`，不能证明合法的 `. _ :`（非首位）会被接受，也不能防止实现收窄合法集合。
- 非法 fixture 只有缺失、前导 `-`、`/`、空白和换行，未覆盖前导 `. _ :` 及无空白元字符（如 `;`、`+`），弱正则仍可能通过清单。
- 应增加合法字符边界与非法首字符/非法字符表驱动用例，或用等价的机械属性测试覆盖整个字符类；每个拒绝例都要继续断言退出 `2`、stderr 含 `ANDROID_SERIAL`、fake ADB 日志为空。

#### I2. R3 的验收不能机械保证每条 ADB 命令使用同一个 `"$device_serial"`

- R3 要求两个 skill 先读取并校验显式 `ANDROID_SERIAL`，且每条 `root/remount/push/reboot/shell` 都使用 `adb -s "$device_serial"`。
- 清单只写“先定义安全 `device_serial`”和“不存在裸 adb”，错误实现如 `adb -s "$other" shell ...`、仅判非空而未按安全格式校验，仍可能满足该文字检查。
- 应明确静态验收：每个真机代码块在首条 ADB 前包含读取与完整正则校验；枚举出的每条 ADB 命令均以分离参数 `adb -s "$device_serial"` 调用；禁止其他 target 变量与裸调用。

#### I3. diff 规模不变量是“只跑不验”

- 不变量要求非生成变更不超过 8 个文件且新增+删除不超过 400 行，但验证仅写 `git diff --numstat`。
- 该命令无论是否超限通常都退出 `0`，只打印数据，不会使主验收失败，属于不可执行的人工观察项。
- 应提供会按同一基线排除生成物、统计文件数与增删总和并对阈值断言的命令/测试；超限必须非零退出。

### 次要（0）

无。

## R1–R7 规格符合性

| 需求 | 来源正确性 | EARS/可执行性 | 验收覆盖 | 范围 |
|---|---|---|---|---|
| R1 | 正确：Claude 当前真实路径存在裸 `adb shell/logcat` | When/shall 清楚 | 部分，见 I1 | 符合 spec 01 |
| R2 | 正确：PLAN 要求首次 ADB 前 fail-closed，退出 `2` 与既有安全口径一致 | If/shall 清楚 | 部分，见 I1 | 符合 spec 01 |
| R3 | 正确：两个 Claude skill 当前存在裸 root/remount/push/reboot/shell | When/shall 清楚，Markdown 需静态判定 | 部分，见 I2 | PLAN 明确属于 01 |
| R4 | Codex 来源正确，但相对 PLAN 整体不变量范围不完整 | When/shall 本身清楚 | Codex 有对应项；Claude 缺失，见 B1 | 不完整 |
| R5 | 正确：两 verifier 当前 demo 缺应用时保留探索语义 | When/shall 清楚 | Claude/Codex 均有对应 fixture | 无越界 |
| R6 | 正确：来自 PLAN 的离线 mock/零真实设备约束 | During/shall 清楚 | fake PATH、空日志及成功调用记录对应覆盖 | 无越界 |
| R7 | 正确：来自 PLAN 的旧入口保留不变量 | Ubiquitous shall，可执行 | 两 verifier `test -x` 加三套旧回归对应覆盖 | 无越界 |

## 随机源码事实核对

1. Claude verifier 的真实 `shell` 与 `logcat` 分别直接调用裸 `adb`，与 R1/R2 的问题陈述一致。
2. Claude verifier 接受任意模式的 `--allow-skip`，最终在仅有 SKIP 时退出 `0`，证明 B1 是现实路径而非推测。
3. Codex verifier 已按同一正则校验 `ANDROID_SERIAL` 并构造 `ADB=(adb -s "$serial")`，但参数解析后没有拒绝真实模式 `--allow-skip`，与 R4 来源一致。
4. `build-services-jar` 含裸 root/remount/push/reboot；`build-sepolicy` 含两条裸 shell，R3 枚举与源码吻合。
5. 两个 verifier 路径及 Claude、Codex、common 三套旧回归入口当前均存在，R7 路径没有写错。

## 其他质量检查

- 占位符：未发现。
- 明显矛盾：requirements 内部当前无直接互斥条款；但 R4 的 Claude 遗漏与 PLAN 整体不变量冲突，见 B1。
- 恒真/只跑不验：除 I3 外，主 PASS 末行、退出码、stderr 与 fake ADB 空/前缀断言均可机械验证。
- 错误路径：R2/R4 已要求错误在零次 ADB 后退出 `2`；补齐 B1 和 I1 后才完整。
- YAGNI/越界：未发现；公共 runtime、重试、诊断、common 收敛均明确留给后续 spec。
- 不变量：入口和旧回归可执行；真实 ADB 隔离口径合理；diff 规模不变量需按 I3 修正。
