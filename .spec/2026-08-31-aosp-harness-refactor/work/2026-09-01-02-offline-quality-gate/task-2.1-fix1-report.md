# Task 2.1 fix1 report

Status: DONE

Commits: [83eac79c013cd50216b8638005105fb98bcd2977]

## Review findings 逐项符合性

- I1 workflow oracle：已移除全局 substring/index 判定。oracle 对 `.github/workflows/quality.yml` 原始字节固定 canonical SHA-256 `fe394030c377c2b4949bbfa127fa4957209ff42c078682f5ec42e14778b154bc`，并逐行锚定顶层 `on`、quality job、`ubuntu-24.04` runner、checkout/install step、以 `set -euo pipefail` 开始的完整连续三组 download→SHA→extract/install 命令、最后写入 `GITHUB_PATH`，以及独立且唯一命令的 quality step。
- I1 mutation selftest：把顶层 `on` 改成 `events` 并把原 trigger 文本移入无关 scalar；oracle 必须拒绝，否则外层统一落到 `FAIL  workflow quality contract`。canonical 原始字节摘要同时拒绝内联注释、删 `set -e`、命令重排或结构破坏。
- I2 coverage parser：统一接受并解析 0–3 个前导空格；任何非空行都必须是唯一 header、唯一 separator 或合法五列数据，数据五列非空、Status 精确 `active`，测试路径集合与当前普通根 `tests/test-*.sh` 精确相等且不得重复/未知。
- I2 数字宣称：正则覆盖中英文行/分支/coverage 术语在数字之前或之后的两种顺序，不再使用 20 字符窗口。
- I2 mutation selftest：缩进重复行、缩进未知测试行、把保护行为改成 `100% branch coverage` 三个负例均必须被 oracle 拒绝；任何假绿均由同一 shell 边界输出 `FAIL  workflow quality contract`。
- 仅修改 `tests/test-quality-gate.sh`；已确认正确的 workflow 与 COVERAGE 内容未改动。

## 红阶段

- 命令：`bash ./tests/test-quality-gate.sh`
- 退出码：1
- 首个新增失败标签：`FAIL  workflow quality contract`
- 红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/task-2.1-fix1-red-stage.log

## 绿阶段

- `bash ./tests/test-quality-gate.sh`：rc 0，公开末行精确为 `RESULT PASS  offline quality gate contract`。
- `bash ./scripts/check.sh --offline`：rc 0，公开末行精确为 `RESULT PASS  aosp-harness offline quality gate`。
- `bash -n scripts/check.sh`、`bash -n tests/test-quality-gate.sh`、六个完整文件的 `git diff --no-index --check` 与 `git diff --check`：均通过。
- 最终四路 scope 覆盖 branch-base committed、用户 index、tracked working、untracked，并排除 `.spec/`；集合精确为 `scripts/check.sh`、`scripts/shell-quality-baseline.tsv`、`.gitleaks.toml`、`.github/workflows/quality.yml`、`tests/COVERAGE.md`、`tests/test-quality-gate.sh`。
- 六文件行数依次为 `73/30/2/26/4/154`，逐项满足 caps `105/30/2/42/8/200`，总计 `289 <= 387`。
- 备用 `GIT_INDEX_FILE` 暂存第七文件 `.quality-range-canary` 后范围门按预期失败；用户 index 未被触碰且提交后保持为空，工作树 clean。
- 提交后重复执行完整 contract、真实 offline、语法/空白、四路 scope、caps 与备用 index 负测：全部通过。

## Numstat

| File | Additions / deletions |
|---|---:|
| `tests/test-quality-gate.sh` | 31 / 25 |

六文件 review package 相对 `git merge-base main HEAD` 为 289 additions、0 deletions。

顾虑：无。未改 workflow/COVERAGE 交付内容，未联网或运行真实 CI；使用普通 Conventional Commit，未 push 或 merge。
