# Task 1.4 report

Status: DONE

Commits: [d497a87dfcfa793f8856f00a20859cfbb7414b62]

## 简报符合性

- 仅修改 `tests/test-quality-gate.sh`、`scripts/check.sh` 并创建 `scripts/shell-quality-baseline.tsv`；未实现 Gitleaks config/扫描、workflow 或 coverage。
- canonical baseline 只由锚点 `b143821925e279401334d09a788ba9a969df5c7c` Git tree 按受管 Shell 规则生成；文件为 30 行、C 序 `path<TAB>git-blob`，SHA-256 精确为 `62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f`，并与生成预览逐字比较通过。
- `--ci` 在 core 成功后先校验 baseline 固定摘要，再校验 30 行、严格 C 序、path/blob 唯一和 40 位小写 blob；协议错误写 stderr 并返回 rc `2`，运行时不读取锚点历史。
- 当前受管 Shell 只有 path 与 `git hash-object` 的 exact pair 命中才豁免；新增文件与已批准路径内容变化均逐文件调用 `shellcheck -x --severity=warning` 和 `shfmt -d -i 2 -ci -bn`，任一 finding 归一为 rc `1`。
- contract 覆盖原始 pair 豁免、新增/变化候选完整 argv、ShellCheck/shfmt 各自失败、append-current/wrong-digest/duplicate/unsorted/malformed/non-anchor 六类 baseline 变异，以及协议错误前静态/秘密扫描零调用。
- 任务增量为 test 32 additions/1 deletion、gate 13 additions/0 deletions、baseline 30 additions/0 deletions，分别满足 35/15/30；相对锚点累计为 test 97/0、gate 55/0、baseline 30/0，满足 145/85/30。

## 红阶段

- 命令：`bash ./tests/test-quality-gate.sh`
- 退出码：1
- 首错：`FAIL  baseline canonical digest mismatch`
- 红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/task-1.4-red-stage.log

## 绿阶段

- `bash ./tests/test-quality-gate.sh`：rc 0，末行 `RESULT PASS  offline quality gate contract`。
- `bash ./scripts/check.sh --offline`：rc 0，末行 `RESULT PASS  aosp-harness offline quality gate`；contract 内真实 offline poison 边界、`GIT_ALLOW_PROTOCOL=file` 和 CURRENT_FEATURE hash 不变断言通过。
- baseline 30 行、固定 SHA、锚点生成预览逐字比较、`bash -n`、三个文件全文件空白检查及 `git diff --check`：均通过。
- 提交后重复运行 contract、真实 offline、baseline 校验、语法和工作树清洁检查：均通过。

## Numstat

| File | Additions / deletions |
|---|---:|
| `scripts/check.sh` | 13 / 0 |
| `scripts/shell-quality-baseline.tsv` | 30 / 0 |
| `tests/test-quality-gate.sh` | 32 / 1 |

顾虑：无。本任务按简报使用 fake 工具验证固定 argv 与失败传播，不联网、不调用真实外部工具；使用普通 Conventional Commit，未 push 或 merge。
