# Task 1.5 report

Status: DONE

Commits: [5f31ceb29d1be97323035a4b3a9176e6d2d3649c]

## 简报符合性

- 仅修改 `tests/test-quality-gate.sh`、`scripts/check.sh` 并创建 `.gitleaks.toml`；未修改 workflow、coverage 或其他实现文件。
- `.gitleaks.toml` 字节精确为 `[extend]\nuseDefault = true\n`，共两行，SHA-256 精确为 `27630a96d6c55755cc37620f3933d5cab94b1eb78a726a32e11212972525d76e`；gate 在静态检查成功后验证固定摘要，错误返回 rc `2` 且不调用 Gitleaks。
- gate 清除 `GITLEAKS_CONFIG` 与 `GITLEAKS_CONFIG_TOML`，使用绝对 config 路径和固定 `dir --no-banner --redact --exit-code 1 --config <config>` argv；canary 与工作树两次调用只有末尾 target 不同。
- canary 使用 `mktemp -d` 在 repo 外创建，并由分片 `AKIA` 与 `ABCDEFGHIJKLMNOP` 在运行时拼接；仓库内 `TMPDIR` 被拒绝为 rc `2` 且 Gitleaks 零调用。
- canary 必须精确返回 rc `1`；返回 `0` 或 `2` 均为协议错误 rc `2` 且不扫工作树。canary 在最终扫描前显式清理并解除 trap；工作树 Gitleaks 任意非零统一返回 rc `1`。
- contract fake 记录并逐字验证两次 NUL argv、两个配置环境变量、外部/工作树 target、canary 内容与清理时序；同时覆盖 config bytes、固定 digest、空规则、全局 allowlist、canary rc、工作树失败与成功总签名。
- 任务增量为 test 19 additions/5 deletions、gate 19 additions/1 deletion、config 2 additions/0 deletions，分别为 `24/20/2`；最终累计行数为 `113/73/2`，满足 `169/105/2`。

## 红阶段

- 命令：`bash ./tests/test-quality-gate.sh`
- 退出码：1
- 首个新增失败标签：`FAIL  gitleaks config contract`
- 红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/task-1.5-red-stage.log

## 绿阶段

- `bash ./tests/test-quality-gate.sh`：rc 0，末行 `RESULT PASS  offline quality gate contract`。
- `bash ./scripts/check.sh --offline`：rc 0，末行 `RESULT PASS  aosp-harness offline quality gate`；真实 offline poison 边界、`GIT_ALLOW_PROTOCOL=file` 与 CURRENT_FEATURE hash 不变断言通过。
- config SHA/两行、完整 canary 不落盘检索、两个 Bash 文件语法、全文件空白、`git diff --check`、任务/累计预算与三文件范围检查：均通过。
- 提交后重复运行 contract、真实 offline、config 签名、语法、空白和工作树清洁检查：均通过。

## Numstat

| File | Additions / deletions |
|---|---:|
| `.gitleaks.toml` | 2 / 0 |
| `scripts/check.sh` | 19 / 1 |
| `tests/test-quality-gate.sh` | 19 / 5 |

顾虑：无。本任务所有 Gitleaks contract 回归使用 fake 工具，不联网、不调用真实外部工具；使用普通 Conventional Commit，未 push 或 merge。
