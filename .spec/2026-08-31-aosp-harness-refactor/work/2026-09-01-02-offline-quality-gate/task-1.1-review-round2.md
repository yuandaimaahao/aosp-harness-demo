# Task 1.1 review — round 2

Verdict: **PASS**

Scope: re-review only of fix commit `6b6f749` against `5aa1a26`, specifically
round-1 findings I1/I2 and their affected brief items. The supplied diff and
reports were inspected; no files were modified and no validation was re-run.

## ① 规格符合性

| 受影响简报项 / finding | 结论 | 依据 |
|---|---|---|
| I1：每个 CLI/缺失依赖失败 case 要证明预检早于 syntax/root test | ✅ | `prepare_path` 为所有非缺失-`bash` case 创建私有 `bash`：遇到 `-n` 写入 `SYNTAX_MARKER` 后才委托绝对 `HOST_BASH`；`run_error` 给每次 gate 调用传入 `SYNTAX_MARKER` 和 `TEST_MARKER`，并仍要求两者为空。fixture 的根测试实际向 `TEST_MARKER` 写入。因而 syntax 或根测试若在预检前运行，断言会失败，不再是恒真空 marker。缺失 `bash` case 则保持 PATH 中无 `bash`，符合预检必须先失败的被测条件。 |
| I1：marker 机制自身应可观察 | ✅ | 修复在进入成功 case 前直接执行 fake `bash -n bad.sh`，断言语法失败退出 `2` 且 syntax marker 非空；也直接执行 root marker test 并断言 test marker 非空。这验证两种观测装置均能写入。 |
| I2：`QUALITY_GATE_NESTED=1` 防递归 | ✅ | 分支位于 fixture 创建、`git init` 和任何测试设置之前，精确输出 `RESULT PASS  offline quality gate child` 并 `exit 0`；契约以该环境变量直接调用自身并精确断言输出。 |
| 原 task 1.1 的 CLI/十项依赖预检、错误协议与空 fixture 成功行为 | ✅ | `scripts/check.sh` 未在本轮 diff 中变化；修复保留原有 3 个 CLI case、10 个逐项缺失 case、rc/stderr/no-total-PASS 断言，以及最终 offline success 断言，未改变既有受测契约。 |

⚠️：0。上述结论均可由本轮 diff 与 round-1 finding 的闭合关系判断，不需要以未重跑的验证替代证据。

## ② 质量

| 检查项 | 结论 |
|---|---|
| YAGNI / 越权 | ✅ | 仅改动 `tests/test-quality-gate.sh`，新增内容均直接服务 I1 的可观测 marker 或 I2 的递归隔离；未扩展 gate 行为或触及后续任务。 |
| 验证真实性 | ✅ | fake Bash 和 root test 都先被正向自检，再被 13 个预检失败 case 使用；marker 空断言因而实际能捕获错误执行顺序。 |
| 重复 | ✅ | PATH fixture 的 fake Bash 创建集中在既有 `prepare_path`，环境注入集中在既有 `run_error`；没有新增逐 case 的复制块。 |
| 错误路径 | ✅ | fake Bash 对 `-n` 记录后完整委托原 Bash，保留真实语法退出码；nested 分支在副作用前成功退出。既有 CLI/依赖错误路径未改。 |

## Findings

### 阻断（0）

无。

### 重要（0）

无。

### 次要（0）

无。
