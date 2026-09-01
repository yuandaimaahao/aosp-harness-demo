# Task 1.5 diff review — round 2

结论：**PASS**

计数：阻断 0，重要 0，次要 0，⚠️ 0。

审查边界：仅阅读 task brief、round1 review、fix1 report、`5f31ceb2..7b9a0bb9` review package 与 review 规则；只复审 round1 I1/I2/I3 的修复 diff、既有回归/预算证据及 canary token zero-match 证据。未修改实现，未重跑报告中的验证；唯一写入是本审查报告。

## Findings

无。

## Round1 findings 闭合

| Round1 finding | 结论 | 证据 / 判断 |
|---|---|---|
| I1：环境变量断言未先制造污染 | ✅ 已闭合 | `run_static` 在启动 fixture gate 的同一环境赋值中分别注入非空 `GITLEAKS_CONFIG=poison-primary` 与 `GITLEAKS_CONFIG_TOML=poison-toml`；既有 fake 仍精确要求两次调用均记录两个变量为 `unset`。删掉任一 `unset` 后对应 poison 会进入日志，断言不再可能假绿。 |
| I2：canary 写入/rc/清理错误处理与 trap | ✅ 已闭合 | trap 提前到 repo 内目录判定之前注册；repo 内拒绝路径和正常路径的显式 `rm -rf` 均以 `|| quality_protocol_error` 处理失败；canary 写入也显式处理失败；Gitleaks rc 改用 `if ...; then rc=0; else rc=$?; fi`，不再依赖 OR-list 对 `errexit` 的抑制；只有显式清理成功才 `trap - EXIT`。任何写入/清理协议错都会在工作树扫描前退出，trap 仍保底。新增 source oracle 对三处关键结构做可失败断言，fix report 的红阶段首错正是 `explicit secret failure handling`，绿阶段恢复。 |
| I3：新增失败 cases 未断言无总 PASS | ✅ 已闭合 | 新增 `no_total_pass`，并覆盖 config bytes/digest/empty-rules/global-allowlist、canary rc 0/2、repo 内 TMPDIR、worktree rc 7；每类失败的 rc/调用断言均与“stdout 不含总 PASS”组成同一失败条件。 |

## ① 规格符合性

| 要求 | 结论 | 证据 / 判断 |
|---|---|---|
| poison 环境下清除 `GITLEAKS_CONFIG` / `GITLEAKS_CONFIG_TOML` | ✅ | 两个不同非空 poison 在 gate 启动边界注入，两次 fake Gitleaks 记录仍必须精确为 `unset`，回归真实约束 gate 的 `unset`。 |
| canary 显式写入、rc 捕获、清理错误处理及 trap 保底 | ✅ | 写入与两条显式清理路径均处理失败；rc 捕获独立于 `set -e` 调用上下文；trap 在可能产生/拒绝 canary 的错误路径上保持有效，且仅在正常清理成功后解除。 |
| config/canary/TMPDIR/worktree 各失败无总 PASS | ✅ | 四类 config 协议错、两类 canary rc 协议错、repo 内 TMPDIR 协议错和工作树 finding 均调用 `no_total_pass`；成功 case 仍精确要求总 PASS 末行。 |
| 回归证据 | ✅ | fix report 记录 contract test rc 0、末行精确 `RESULT PASS  offline quality gate contract`；真实 offline gate rc 0、末行精确 `RESULT PASS  aosp-harness offline quality gate`；另记录 config SHA、两份 Bash 语法、全文件空白及 `git diff --check` 均通过。按 review 禁令未重跑。 |
| 任务与累计预算 | ✅ | fix report 给出最终任务 test/gate/config 为 `23/20/2`，分别不超过 `24/20/2`；累计文件行数 `118/73/2`，分别不超过 `169/105/2`。fix package 只改 gate 与 contract test，stat 为 19 additions / 14 deletions，没有越出任务文件范围。 |
| 完整 canary token 未进入 tracked working tree | ✅（报告证据） | fix report 明确给出查询词只在运行时由 `AKIA` 与 `ABCDEFGHIJKLMNOP` 两片拼接的 `git grep -F` 命令，结果 rc `1`，整个 tracked working tree 零匹配。该证据解决 round1 的 ⚠️；按“不重跑”约束直接采用报告证据。 |

## ② 质量

- YAGNI：✅ fix 仅修改 `scripts/check.sh` 与 `tests/test-quality-gate.sh`，内容逐项对应 I1/I2/I3；未触碰 workflow、coverage 或任务 2.1。
- 验证是否真的在验：✅ poison 使 env 清除断言可失败；`no_total_pass` 直接检查失败输出；关键错误处理 source oracle 在红阶段确实失败，修复后转绿；原有 argv、调用顺序、target 与清理行为 oracle 保持不变。
- 逐字复制：✅ 未新增重复逻辑块；失败签名检查复用单一 `no_total_pass`，固定 Gitleaks 参数继续复用同一数组。
- 错误路径：✅ canary 写入、rc 分类、repo 内目录拒绝、显式清理与 trap 生命周期均被处理；工作树 Gitleaks 非零仍归一为 `1`，协议错误仍为 `2`，各失败不打印总 PASS。

## 结论

**PASS**。round1 的 3 个重要 finding 全部闭合；canary token zero-match 的原 ⚠️ 已由 fix report 的 tracked-tree 零匹配证据解决，本轮无残留 finding 或 ⚠️。
