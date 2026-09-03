# Review: task 2.5 03d-session-remove-prune round 1
verdict: PASS
阻断: 0 / 重要: 0 / 次要: 1

## findings
- [次要] 报告记载 scoped rg 文件数 17（10 ledger + 7 execution-base.env），该数字与仓库根主 checkout 复跑一致；但 brief 步骤 2 要求「在 implementation worktree 运行」，worktree 内复跑为 16 份（03d 的 `execution-base.env` 未 tracked、不在 worktree checkout 中）。即 controller 实际是在仓库根跑的 scoped rg，报告未注明执行位置。两处我均独立复跑、对 NEXT 字面全名均零匹配，门结论不受影响，仅记录口径差异供 controller 知悉。

## 核对记录

NEXT 字面确认：PLAN.md 第 54 行为 03e 片行，与 brief 步骤 2 定义一致。全程 `shopt nullglob` 确认 off 后复跑。

- 门 1/2（spec/work 目录缺席）：仓库根与 implementation worktree 两处各跑 `! ls -d "$PROJECT"/specs/*"$NEXT"` 与 `! ls -d "$PROJECT"/work/*"$NEXT"`，ls 均 rc2、`!` 判定 PASS，两处均缺席。
- 门 3（分支零匹配）：`git show-ref | rg "refs/heads/spec/.*$NEXT"` rc1 零匹配，PASS。
- 门 4（worktree 零匹配）：`git worktree list --porcelain | rg "$NEXT"` rc1 零匹配，PASS（现有 10 个 worktree 无一命中）。
- 门 5（scoped rg）：仓库根 `files=$(ls ...)` rc2（dispatch.tsv 类无匹配属预期，未 `&&` 链），逐个点名 17 份 = 10 份 ledger.md + 7 份 execution-base.env + 0 份 dispatch.tsv，与报告声称完全一致；`rg -l "$NEXT" $files` rc1 零匹配。worktree 内同跑 16 份亦 rc1。重点项：03d 自己的 ledger 在 git status 中为 ` M`（未提交 working-tree 版本），scoped rg 读的是磁盘现行内容，对其零命中成立；人工抽读 ledger 确认只写「NEXT顺序门目标为03e下一切片（规范ID全名见PLAN第54行，本片ledger不逐字记录）」「03e/08」式间接字样。
- 报告契约：red 记录恰六行字段 + assertion 一行，rc=1 与「报告缺席」一致；green 报告结构与 task-2.4 既定先例逐节对应；`cat -A` 核「红阶段证据: 」路径独占一行、`$` 紧跟路径、零尾随空白；evidence.tsv 4 行逐行重算 sha256+size 全 fresh（4/4 OK）；order-gate.log 五门逐条记录完整、NEXT 以占位间接形式出现。
- 字面禁令：`rg` 对 `task-2.5-report.md`、`task-2.5-red.txt`、`order-gate.log` 三文件搜 NEXT 字面全名 rc1 零命中——报告/日志/红文件均未内联展开值，符合裁定 6 的间接记录要求。
- 反证抽查：注意 `.spec` 被 gitignore，默认 rg 全域会静默漏掉整个域——用 `rg -uu` 重跑，命中 21 份文件：PLAN.md（主 checkout + 两个 worktree 副本）、03d 的 requirements.md/tasks.md/reviews 三份、8 份任务 brief。全部命中均为 PLAN/requirements/tasks/reviews/brief 类 spec 文档（豁免域）；无任何 ledger.md / dispatch.tsv / execution-base.env 命中，域边界未被扩大。

结论：五门机械核对全部独立复跑通过，报告/evidence/日志契约合规，顺序边界成立。
