# Task 2.1 diff review — round 2 (fix1)

Status: **PASS**

Findings: **阻断 0 / 重要 0 / 次要 0 / ⚠️ 2**

审查范围：只审 `7b09181c..83eac79c` 的 fix1 diff、round1 的 I1/I2、实现者报告及已有红/绿/预算证据；遵照指令未重跑验证。

## Findings

本轮没有阻断、重要或次要 finding。round1 的两项重要 finding 均已闭合。

### ⚠️ 1 — 六文件四路 scope 不能由本轮单文件 fix package 独立判断；报告证据已闭合

fix package 直接证明本轮只修改 `tests/test-quality-gate.sh`，为 `31 insertions / 25 deletions`；它不包含 branch-base committed、用户 index staged、tracked working、untracked 四路集合的执行日志，因而无法单靠 package 判断最终六文件 scope。

fix1 report 明确记录：四路 scope 均已覆盖、排除 `.spec/` 后集合精确为 `scripts/check.sh`、`scripts/shell-quality-baseline.tsv`、`.gitleaks.toml`、`.github/workflows/quality.yml`、`tests/COVERAGE.md`、`tests/test-quality-gate.sh`；备用 `GIT_INDEX_FILE` 暂存第七文件时范围门按预期失败，且用户 index 未被触碰、提交后为空、工作树 clean；提交后又重复执行该检查。该证据与简报给定的四路 NUL 安全 scope 自查脚本一致，也没有与 fix package 冲突，故此 ⚠️ 由报告闭合，不形成残余缺口。

### ⚠️ 2 — 六文件行数、caps 与两个公开末行不能由 fix package 独立判断；报告证据已闭合

fix1 report 记录六文件行数为 `73/30/2/26/4/154`，逐项低于 `105/30/2/42/8/200`，合计 `289 <= 387`；同时记录：

- `bash ./tests/test-quality-gate.sh`：rc `0`，末行精确为 `RESULT PASS  offline quality gate contract`；
- `bash ./scripts/check.sh --offline`：rc `0`，末行精确为 `RESULT PASS  aosp-harness offline quality gate`；
- 提交后完整 contract、真实 offline、语法、空白、scope、caps 和备用 index 负测均再次通过。

现有证据内部一致：round1 为 test `148` 行、总计 `283`，本轮 package 为 `31/25`、净增 `6`，恰好对应 fix1 report 的 test `154` 行、总计 `289`；红阶段日志也直接记录首错 `FAIL  workflow quality contract` 和 `RED_STAGE_RC=1`。按 review 规则且遵照“不重跑”，此 ⚠️ 由报告与已有日志闭合，不形成残余缺口。

## ① 规格符合性

- ✅ **I1 / canonical workflow**：新 oracle 先对 workflow 原始字节校验固定 SHA-256，再精确断言顶层 trigger、quality job、runner、checkout/install step、完整连续 install `run` 命令块及唯一 quality step。round1 已确认该 workflow 本体 YAML 结构有效；摘要现在把这份已确认的 canonical 字节精确钉住，因此把命令藏进内联注释或无关 scalar、删除 `set -euo pipefail`、重排下载/摘要/解包/安装、破坏结构都会失败，原来的 substring 假绿已消除。
- ✅ **I1 / mutation 与失败传播**：把顶层 `on` 改为 `events`、再把原 trigger 文本放入无关 scalar 的负例必须被 `rejects(check_workflow, ...)` 拒绝；任一 Python oracle 失败继续经 shell 的 `|| fail 'workflow quality contract'` 传播到公开失败标签。canonical 摘要是实际承重守卫，逐行断言进一步表达所保护的结构与顺序。
- ✅ **I1 / 三工具结构与顺序**：完整连续命令元组锁定 `set -euo pipefail` 首行、RUNNER_TEMP root/bin、三个官方 URL/tag/asset、三个裁定 SHA、ShellCheck/Gitleaks 解包、shfmt 直接安装、三次 `install -m 0755`，且最后才写 `GITHUB_PATH`；独立 quality step 仅允许一次 `./scripts/check.sh --ci`。
- ✅ **I2 / coverage 行解析**：parser 显式接受并剥离 `0–3` 个前导空格，拒绝更深缩进；每个非空行必须是唯一五列表头、唯一 separator 或合法五列数据行。数据要求五列非空、Status 精确为 `active`、首列精确匹配根级测试路径，最终要求 rows 无重复且集合与当前普通 `tests/test-*.sh` 完全相等，因此缩进重复和缩进未知行不再能逃逸。
- ✅ **I2 / 数字 coverage 宣称**：正则同时覆盖“行/分支/coverage 术语在数字前”和“数字在术语前”两种顺序，且不再有 20 字符窗口；`100% branch coverage` 负例被显式 mutation selftest 拒绝。
- ✅ **I2 / 三个要求的负例**：新增的缩进重复行、缩进未知测试行、`100% branch coverage` 三个 mutation 均由同一真实 `check_coverage` 执行，并要求 oracle 拒绝；若任一 mutation 假绿，`rejects` 会显式抛错，最终落到 `FAIL  workflow quality contract`。
- ✅ **R7/R8/R9 回归边界**：本轮只强化 contract oracle，未改已在 round1 确认正确的 workflow/COVERAGE 交付内容；失败边界和公开成功契约由已有红/绿证据覆盖。
- ⚠️ **scope / caps / 公开末行**：package 不足以独立判断；已分别由上述报告证据闭合。

## ② 质量

- YAGNI：✅ 仅修改 `tests/test-quality-gate.sh` 中与 round1 I1/I2 直接对应的 oracle 和最小 mutation selftest，没有修改交付 workflow/COVERAGE，也没有引入任务外行为。
- 验证真实性：✅ workflow 不再依赖散落 substring；原始字节摘要与精确结构共同拒绝注释/scalar/重排/结构破坏。coverage parser 不再跳过可渲染的缩进行，三个指定负例真实调用同一 oracle，并以“必须拒绝”作为断言。
- 逐字复制：✅ 未见新增逻辑块逐字复制；`check_*` 与 `rejects` 将正向校验和 mutation 复用在同一实现上。
- 错误路径：✅ 预期的 mutation 拒绝只捕获 `AssertionError`；mutation 被错误接受时显式抛出 `AssertionError('mutation accepted')`，其他异常不会被吞掉；最外层仍统一传播为 `FAIL  workflow quality contract`。

最终结论：**PASS**。round1 的 I1/I2 均已修复；两项 package 外的 ⚠️ 已由 fix1 report 与红阶段日志闭合，无需进入下一轮修复。
