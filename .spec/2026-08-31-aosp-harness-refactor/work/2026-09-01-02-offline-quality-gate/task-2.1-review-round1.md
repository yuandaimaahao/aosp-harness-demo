# Task 2.1 diff review — round 1

Status: **NEEDS_CHANGES**

Findings: **阻断 0 / 重要 2 / 次要 0 / ⚠️ 2**

## Findings

### 重要 1 — workflow oracle 校验“字符串出现”，没有校验它们属于可执行的 workflow/install step

位置：`tests/test-quality-gate.sh`，review package L81-L94。

`w.index(...)`、`in w` 和全局 `count` 只证明文本存在。当前过滤仅删除整行注释，因此把 URL、SHA、`tar`、`install` 等文本放进内联 shell 注释（例如 `: # curl ...`）、无关 YAML scalar/env，仍可满足出现及先后顺序。trigger/runner 也可出现在无关键值中。oracle 还没有断言 `set -euo pipefail`，也没有验证 YAML/step 结构；一个保留全部字符串但不执行校验/安装，甚至结构无效的 workflow，可能假绿。

当前 `.github/workflows/quality.yml` 本身按 diff 人工检查是有效的 GitHub Actions YAML，并且命令顺序正确；问题在于回归并不能可靠守住这个行为，违反“验证是真的在验”的质量要求。

建议改动：在 package L81-L94 对应代码处，不再全文件搜索散落 substring。对这个仅 26 行、已固定的 workflow，优先断言一个完整 canonical YAML/完整 install `run: |` block（含 `set -euo pipefail` 为首条命令、三组 download→SHA→解包/直接资产→`install -m 0755` 的精确连续顺序、最后写 `GITHUB_PATH`），再单独锁定唯一 quality step。若不做全文 canonical，至少按行锚定顶层 `on`、job、runner、两个 step 及 install block，拒绝内联注释/无关 scalar 命中，并加入 YAML 结构有效性检查。

### 重要 2 — coverage parser 对未知/重复行和数字 coverage 宣称存在可构造漏检

位置：`tests/test-quality-gate.sh`，review package L97-L104。

`if not line.startswith('|')` 会忽略前置 1–3 个空格的 Markdown 表格行；这种行仍可渲染为表格内容，所以缩进后的重复或未知 `tests/test-*.sh` 行不会进入 `rows`。数字宣称正则只匹配“coverage/line/branch 在数字之前、且相距不超过 20 字符”，例如 `100% branch coverage` 会漏过。因而“拒绝重复、未知、数字宣称”没有被完整落实。

建议改动：在 package L97-L104 对应代码处，先按允许的 Markdown 前导空格统一解析，并拒绝表外/无法识别但包含 ``tests/test-*.sh`` 的行；更稳妥的是当前小文档只允许固定 header、separator 和合法数据行。数字宣称检测应同时覆盖数字在术语前后两种顺序，并避免固定 20 字符窗口造成逃逸。应补最小负例覆盖：缩进重复行、缩进未知行、`100% branch coverage`，确认 oracle 非零并落到 `FAIL  workflow quality contract`。

## ① 规格符合性

- ✅ 三个 trigger：`push`、`pull_request`、`workflow_dispatch` 均在 workflow 顶层声明；runner 为 `ubuntu-24.04`。
- ✅ ShellCheck：tag `v0.11.0`，asset `shellcheck-v0.11.0.linux.x86_64.tar.xz`，URL 与 SHA `8c3be12b...27198` 精确；先校验，再从下载 tar.xz 解到 `$root`，由 `$root/shellcheck-v0.11.0/shellcheck` 安装到 `$bin/shellcheck`。
- ✅ shfmt：tag `v3.14.0`，asset `shfmt_v3.14.0_linux_amd64`，URL 与 SHA `fe42021c...0b66` 精确；该资产无需解包，校验后由下载文件安装到 `$bin/shfmt`。
- ✅ Gitleaks：tag `v8.30.1`，asset `gitleaks_8.30.1_linux_x64.tar.gz`，URL 与 SHA `551f6fc8...70eb` 精确；先校验，再从下载 tar.gz 解到 `$root`，由 `$root/gitleaks` 安装到 `$bin/gitleaks`。
- ✅ install step 有 `set -euo pipefail`；三工具均按 download→SHA→解包（如需）→install 排列，且三个 install 之后才追加 `$GITHUB_PATH`。
- ✅ 独立 `Quality gate` step 的 `run` 值唯一且仅为 `./scripts/check.sh --ci`；全 diff 中该命令只出现一次。
- ✅ 当前 `tests/COVERAGE.md` 是固定五列表头；两条数据行五列非空、Status 均精确为 `active`，两个当前根测试各出现一次且集合相等；当前文档没有数字覆盖率宣称。
- ❌ coverage oracle 的拒绝边界不完整，缩进未知/重复行和数字在术语前的宣称可漏检，见重要 2。
- ✅ `quality_docs_oracle ... || fail 'workflow quality contract'` 使 oracle 失败可传播为 contract 失败。
- ❌ workflow oracle 没有从执行结构上证明 trigger/runner、安装命令、顺序、`set -euo pipefail` 与 YAML 有效性，存在假绿，见重要 1。
- ⚠️ 六文件四路 scope 无法从本轮三文件 diff 判断。报告称已覆盖 branch-base committed、用户 index staged、tracked working、untracked，并排除 `.spec/`；简报中的自查草案确实含 `git_with_index diff --cached --name-only -z`，未见“漏 staged”的设计问题，也含备用 index 第七文件负测且不应触碰用户 index。但实际执行、用户 index 未变只能依赖 report，package 没有相应 diff/日志证据。
- ⚠️ `73/30/2/26/4/148`、逐文件 caps `105/30/2/42/8/200`、总计 `283`，以及两个公开命令的 rc=0/精确末行，均由 report 陈述，不能由本轮 package 独立确认；按指令未重跑验证。package 能直接确认的本提交是 3 文件、60 additions。

## ② 质量

- YAGNI：✅ 本轮只新增 workflow、coverage 和对应 contract oracle，未见简报外功能。
- 验证真实性：❌ 两个 oracle 边界缺口见重要 1、重要 2。
- 逐字复制：✅ 未见新增逻辑块逐字复制。
- 错误路径：✅ Python assertion 非零经 shell `|| fail` 进入公开失败标签；当前实际 workflow 使用 `set -euo pipefail`，下载/摘要/解包/安装失败会在写入 `GITHUB_PATH` 前停止。
- YAML 有效性：✅ 当前 workflow 按 diff 可判为结构/缩进有效；❌ contract 没有守住 YAML 结构有效性。

最终结论：**NEEDS_CHANGES**。修复两项重要 contract 假绿后应由全新 reviewer 做范围受限 re-review。
