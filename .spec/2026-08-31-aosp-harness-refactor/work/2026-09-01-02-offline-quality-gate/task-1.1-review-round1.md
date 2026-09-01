# Task 1.1 review — round 1

Verdict: **NEEDS_CHANGES**

Scope: only task 1.1 in the supplied brief and the supplied commit diff. No files or
validations were re-run.

## ① 规格符合性

| 简报条目 | 结论 | 依据 |
|---|---|---|
| 创建可清理的临时 Git fixture，保存并校验绝对可执行的 `host_bash` | ✅ | `tests/test-quality-gate.sh:4-6` 创建 fixture、注册清理 trap，并验证 `host_bash`。 |
| fixture helper 断言 rc、错误输出、两个 marker 和无总 PASS；覆盖三种 CLI 错误及逐个缺失十项命令 | ⚠️ | `:8-15` 覆盖了三种 CLI 情况与十项命令，并断言 rc/stderr/无 PASS；但 marker 不能实际记录执行，见重要 finding I1。 |
| `QUALITY_GATE_NESTED=1` 防递归分支 | ❌ | brief `:312` 明确要求；新增的测试中没有读取或处理该环境变量。 |
| 每个失败 case 放入非法 `.sh` 和写 marker 的根测试，并证明预检发生在二者之前 | ❌ | `:7, :9-10` 虽创建了文件并检查 marker 为空，但没有为 syntax marker 设置任何写入机制，且没有给测试进程传入 `TEST_MARKER`；该断言无法证明二者未运行。 |
| 红阶段：首错为指定的 no-argument 失败 | ✅ | 实现报告记录了指定命令、退出码 1 和指定首错。 |
| `check.sh` 唯一参数 parser、十项 `command -v` 预检、绝对 repo root、统一 stderr 协议错误 | ✅ | `scripts/check.sh:3-15` 与 brief `:331-344` 一致；错误出口为 2。 |
| 本片空 fixture 成功时输出精确总 PASS，错误仅写 stderr | ✅ | `scripts/check.sh:16` 输出精确字符串；`quality_protocol_error` 写 stderr。 |
| 绿阶段 13 个 preflight case、两入口可执行、语法/空白检查、行预算 | ✅ | 实现报告记录通过；diff 的 executable mode 与 16/20 行增量也符合 task 1.1 的 25/45 行上限。 |

⚠️ 项不能作为通过依据：I1 修复后应重新判定为 ✅ 或 ❌。

## ② 质量

| 检查项 | 结论 |
|---|---|
| YAGNI | ✅ 未见超出 task 1.1 的实现。`mode` 的保存是后续任务明确需要的接口准备。 |
| 验证真实性 | ❌ 契约测试的 marker 断言为空洞，不能检验“preflight 早于 syntax/root test”。 |
| 重复逻辑 | ✅ 无实质逐字重复；`run_error` 合理收敛了各失败 case。 |
| 错误路径 | ⚠️ CLI 和依赖错误路径处理正确；递归保护这一明确的错误/隔离边界缺失，见 I2。 |

## Findings

### 阻断（0）

无。

### 重要（2）

1. **I1 — 验证并未真实观察 syntax/root-test 是否执行。**
   - Diff: `tests/test-quality-gate.sh:7-10`。
   - `syntax_marker` 从未被任何 fake `bash -n` 写入；`tests/test-marker.sh` 虽使用 `$TEST_MARKER`，但 `run_error` 启动 gate 时没有传入该变量。因此 marker 始终为空，即使未来 gate 错误地在 preflight 前执行了语法或根测试，测试也可能仍然通过。
   - 建议：依 brief 建一个私有 fake `bash`，在参数为 `-n` 时写入 `SYNTAX_MARKER` 后委托保存的绝对 `host_bash`；启动 gate 时传入 `TEST_MARKER="$test_marker"`，并让根测试实际写该文件。保留每个失败 case 对两个 marker 为空的断言。

2. **I2 — 缺失必需的 `QUALITY_GATE_NESTED=1` 防递归分支。**
   - Diff: `tests/test-quality-gate.sh:1-20`。
   - brief `:312, :317-320` 要求该分支在本任务建立；后续根 gate 自动发现并执行本测试时，需要它来避免自递归。
   - 建议：在 fixture/setup 前加入分支：环境变量为 `1` 时仅打印精确 child PASS 并退出 0；并为该分支加入直接断言，防止后续改动移除它。

### 次要（0）

无。
