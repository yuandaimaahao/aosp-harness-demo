# Task 2.1 report

Status: DONE

Commits: [7b09181ccaf6f731fcec6a9fe048e0899ac46baa]

## 简报符合性

- 仅修改 `tests/test-quality-gate.sh`，创建 `.github/workflows/quality.yml` 与 `tests/COVERAGE.md`；本片未修改其他实现文件。
- workflow 精确声明 `push`、`pull_request`、`workflow_dispatch` 三个 trigger，runner 为 `ubuntu-24.04`，checkout 后在独立安装 step 使用 `set -euo pipefail`。
- ShellCheck `0.11.0`、shfmt `3.14.0`、Gitleaks `8.30.1` 均使用简报固定的官方 URL、asset 与 SHA-256；逐份校验后按裁定解包源执行 `install -m 0755` 到 `$RUNNER_TEMP/aosp-harness-quality/bin`。
- 三个工具全部下载、校验、解包并安装成功后才追加 `$GITHUB_PATH`；独立 `Quality gate` step 唯一一次调用 `./scripts/check.sh --ci`。
- coverage 使用固定五列表头，自动发现的 `tests/test-device-safety.sh` 与 `tests/test-quality-gate.sh` 各精确出现一次，五列非空且 Status 均为 `active`；没有数字行/分支覆盖率宣称。
- contract 静态 oracle 校验三 trigger/runner、三组 URL/摘要/映射、安装与 PATH 时序、唯一 CI gate 调用，以及 coverage 的精确根测试集合、唯一性、字段、状态和禁止性文本。
- 最终六文件行数为 `73/30/2/26/4/148`，逐项满足 `105/30/2/42/8/200`，总计 `283 <= 387`；范围门覆盖 committed、index、tracked working 与 untracked，排除 `.spec/`，且备用 index 第七文件负测真实失败，用户 index 保持为空。

## 红阶段

- 命令：`bash ./tests/test-quality-gate.sh`
- 退出码：1
- 首个新增失败标签：`FAIL  workflow quality contract`
- 红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/task-2.1-red-stage.log

## 绿阶段

- `bash ./tests/test-quality-gate.sh`：rc 0，末行 `RESULT PASS  offline quality gate contract`。
- `bash ./scripts/check.sh --offline`：rc 0，末行 `RESULT PASS  aosp-harness offline quality gate`；contract 内的 poison PATH、`GIT_ALLOW_PROTOCOL=file`、CURRENT_FEATURE hash 不变边界一并通过。
- workflow/COVERAGE 静态 oracle、两个 Bash 文件语法、六个完整文件空白、`git diff --check`、六文件精确范围与全部行预算：均通过。
- 备用 `GIT_INDEX_FILE` 暂存 `.quality-range-canary` 后范围门按预期失败，随后工作树 clean、用户 index 为空。
- 提交后重复运行完整 contract、真实 offline 与上述最终硬门：均通过；未下载网络工具或执行真实 CI。

## Numstat

| File | Additions / deletions |
|---|---:|
| `.github/workflows/quality.yml` | 26 / 0 |
| `tests/COVERAGE.md` | 4 / 0 |
| `tests/test-quality-gate.sh` | 30 / 0 |

六文件 review package 相对 `git merge-base main HEAD` 的 numstat 为 `26+2+73+30+4+148 = 283` additions、`0` deletions。

顾虑：无。workflow 仅由静态 contract 验证，遵守本任务不联网、不运行真实 CI 的边界；使用普通 Conventional Commit，未 push 或 merge。
