# Task 1.4 fix1 report

Status: DONE

Commits: [9be78e07d4e3a722a9c034423cc1ce6372a1e52e]

## Review 意见符合性

- I1：static fixture 新增一个文件名同时含真实 LF 与空格的受管 `.sh`；byte-level oracle 从 NUL 日志逐条还原 argv，精确断言 ShellCheck/shfmt 各把该路径作为单个参数调用，且 baseline exact-pair 只豁免未变化的 canonical 文件。
- I2：ShellCheck 与 shfmt failure 分 case 运行。每个 case 分别断言 rc `1`、失败点的精确 argv 日志、失败后候选/工具零调用、Gitleaks 日志为空，以及 stdout 不含总 PASS；首个失败候选即 LF+空格路径。
- I3：`append-current` 仍把当前 pair 追加为第 31 行并显式断言行数；`non-anchor` 改为替换第一条 canonical pair 的 blob，保持 30 行、格式、C 序和 path/blob 唯一，独立 fixture validator 通过后再断言 gate rc `2` 且三工具零调用。
- M1：finding case 的 rc、调用序列、Gitleaks 零调用、无总 PASS 均拆为独立且包含 `shellcheck`/`shfmt` 标签的失败断言；baseline mutation 的 rc 与工具调用也使用独立、带 mutation 标签的断言。
- 仅重排 `tests/test-quality-gate.sh`；`scripts/check.sh`、canonical baseline 及后续 Gitleaks/config/workflow 均未修改。
- 本轮相对 BASE `d497a87dfcfa793f8856f00a20859cfbb7414b62` 为 test 26 additions/24 deletions；task 1.4 相对 `d3de28378dbac7c2582e025e74eaaa1a31378ada` 累计 test 34/1、gate 13/0、baseline 30/0，新增+删除分别为 35/13/30，满足 35/15/30。

## 红阶段

- 命令：`bash ./tests/test-quality-gate.sh`
- 退出码：1
- 首个新增 contract 失败：`FAIL  baseline static argv contract`
- 原始 byte 日志显示 `candidate\n with space.sh` 是单个 argv 元素，但 round0 oracle 未包含它。
- 红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/task-1.4-fix1-red-stage.log

## 绿阶段

- `bash ./tests/test-quality-gate.sh`：rc 0，末行 `RESULT PASS  offline quality gate contract`。
- `bash ./scripts/check.sh --offline`：rc 0，末行 `RESULT PASS  aosp-harness offline quality gate`。
- canonical baseline 30 行且 SHA-256 为 `62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f`。
- `bash -n`、三个任务文件全文件空白检查、`git diff --check`、fix 文件范围与累计预算检查：均通过。

## Numstat

| Scope / file | Additions / deletions |
|---|---:|
| fix1 `tests/test-quality-gate.sh` | 26 / 24 |
| cumulative `tests/test-quality-gate.sh` | 34 / 1 |
| cumulative `scripts/check.sh` | 13 / 0 |
| cumulative `scripts/shell-quality-baseline.tsv` | 30 / 0 |

顾虑：无。使用普通 Conventional Commit；未 push 或 merge。
