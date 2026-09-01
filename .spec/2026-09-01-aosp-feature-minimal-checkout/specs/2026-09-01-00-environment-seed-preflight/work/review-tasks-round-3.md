# tasks review — Round 3

## 结论

**FAIL**

- blocker: 2
- important: 2
- minor: 1

审查范围：当前 `tasks.md`、Round 2 tasks review、同片 `requirements.md` / `design.md` / `ledger.md`，以及项目 `PLAN.md` / `DECISIONS.md` / `STATE.md` / `config.yml`。未修改被审文件，未运行 AOSP `envsetup`、`lunch`、build、sync、fetch 或 download。

机器自查事实：`check-tasks.py`、`check-req.py`、`check-criteria.py`、`check-analyze.py`、`check-plan.py` 与 `git diff --check` 均 exit 0。任务五字段齐全，编号仅一级且无重复，`需求` 并集精确为 R1–R27，源码清单仍是 exact two paths。expanded matrix 已明确覆盖 duplicate JSON key、PLAN/DECISIONS/sizing、commit missing/extra/common path、ledger missing/duplicate/malformed/extra/multi-SHA/wrong-SHA，以及 post-revert helper 与 regression wrong-last-line；这些 Round 2 缺口已闭合。

## Round 2 四项闭合核对

| Round 2 finding | Round 3 结论 | 依据 |
|---|---|---|
| B1 tasks-time estimate / `<10 分钟` review | **部分闭合，仍阻断** | 已增加 75–95 / 150–190 / 150–190、总计 375–475 行和 2/4/4 分钟表，但这个估算与步骤 4–11 的实际接口和 case 数不相称，也没有把实现步骤拆到每步 2–5 分钟。见 B2。 |
| B2 review-fix / main-drift candidate 状态机 | **部分闭合，仍阻断** | eligible-candidate pre-commit 与 fresh-main rebuild 的方向正确；但 amend 分支仍用 `HEAD..index` 比较，单文件 fix 必然无法通过 exact two-path gate，且 actual line gate只会计算本轮 fix delta。见 B1。 |
| I1 exact shell / Python skeleton | **部分闭合，仍重要** | baseline/candidate/completion shell 与 main dispatch skeleton 已补；initial worktree 和 completion anchor仍以散文/占位 comment 表达，真实 accept 也未机器断言 exact channels。见 I1。 |
| I2 rejection matrix | **闭合** | tasks 步骤 10–11 已逐类固定 code，并补齐 Round 2 指出的 duplicate key、DECISIONS/sizing、missing/extra path、ledger grammar 与 post-revert helper。 |

## Findings

### B1 — amend 分支把 prospective candidate 错当成 `HEAD..index`，单文件 review fix 无法执行且 actual budget 可假绿

出处：`tasks.md:39`、`tasks.md:41-60`、`tasks.md:132-133`；`design.md` 的 eligible candidate / exact two-path / actual `<=800` contract。

初次 candidate 时 `HEAD == base`，所以当前 block 的

```bash
git diff --cached --check
test "$(git diff --cached --name-only | LC_ALL=C sort)" = "$(printf '%s\n' "${task_paths[@]}")"
```

碰巧等价于检查 `base..prospective index`。review FAIL 后却不再等价：此时 `HEAD` 已是旧 candidate。若 reviewer 只要求修改 `verify-supersession.py`，即使 `git add` 同时列出 manifest 和 validator，`git diff --cached --name-only` 仍只输出真正改变的 validator，因而与 manifest 中 exact two paths 不等并在 amend 前失败。若强行让两文件都发生无意义变化才通过，又违反最小修复。

同一基准错误也使步骤 13 的 `git diff --cached --numstat` 在 amend 轮只统计“旧 candidate→本轮 index”的 fix delta，不统计 frozen base→最终 prospective tree；累计修复后最终 two-path diff 即使超过 800 行仍可能通过 R24 actual gate。candidate block本身甚至没有落盘该 numstat gate，步骤 13 的自然语言无法修复其 amend 语义。

必须把 candidate 的 path/check/numstat 都固定为 **base tree 对 prospective index**，例如在 stage 后使用 `git diff --cached "$base_sha" --check`、`git diff --cached "$base_sha" --name-only` 和 `git diff --cached "$base_sha" --numstat`，然后从这份 full prospective diff 计算 `<=800`。初次、amend、main-drift rebuild 三条路径应运行同一个 base-relative block，并在每轮重新生成 report/summary 后再派全新 review。

### B2 — 375–475 行与 2/4/4 分钟是声明，不是可信的四条粒度证明

出处：`tasks.md:3-13`、`tasks.md:102-130`；tasks 细则“四条粒度判据”与“每步一个动作，2–5 分钟”。

表格解决了“没有 tasks-time estimate”的形式缺口，但内容仍无法支撑硬门：150–190 行 core 要同时容纳 argparse/单一输出通道、duplicate-aware closed nested schema、R1–R27 owner/DAG/budget/path validation、PLAN/DECISIONS/sizing/check-plan、Git base/common/candidate/commit inspection、exact ledger parser、temp worktree direct revert、三条回归及 cleanup；另 150–190 行 fixtures 要建立临时 Git/worktree/ledger/process inputs，并独立覆盖步骤 10–11 列出的约四十种 mutation。要在这个行数内完成只能高度压缩承重逻辑，反而使“4 分钟审 core + 4 分钟审全部 fixtures”更不可信。

任务步骤也仍不满足 2–5 分钟动作：步骤 5 同时实现 PLAN、DECISIONS、sizing、checker 四类解析；步骤 9 同时实现两个 helper、temp worktree、revert、三回归与可靠 cleanup；步骤 10/11 各要求一次写完十余到二十余独立 case。它们不是单动作。summary 不能替代 reviewer 阅读真实 validator/test diff，`<=800` 也不自动推出 `<10 分钟`。

这是门④的硬条件，不是实现后可补的统计项。应按稳定可验接口拆任务或进一步缩小 terminal validator 职责，并给每个 review slice 可核对的函数/case 边界与实际阅读预算；若坚持单文件密集实现，则应承认 `<10 分钟` 不成立并回 design/PLAN 重新切片。

### I1 — completion/accept block仍不是 exact executable oracle

出处：`tasks.md:76-89`、`tasks.md:126`、`tasks.md:131-134`。

block 计算了 `task_sha` / `base_sha`，但没有计算 `base12` / `sha12`，也没有生成或验证真实 review report path；唯一 completion anchor 仍写在 comment 中，包含 `TASK_SHA`、`BASE12`、`SHA12` 符号值。因而“controller uses apply_patch once”仍依赖临场替换，不能由 block 自证写入的是 parser 所要求的唯一 exact grammar，也没有 `test -f` 证明 review evidence 存在。

此外，candidate/completion blocks 直接运行 self-test/pre-commit/accept，只凭 `set -e` 检查 rc；它们没有 capture 并逐字比较 stdout，也没有证明 stderr 为空。步骤 12 的自然语言要求 exact channels，但主执行 block 可以在 validator 多打印一行时继续。应固定动态 prefix 的生成、唯一 anchor 的受控写入/匹配、review/report existence，并以临时 stdout/stderr 或 shell substitution 对三个 public PASS line做 exact one-line/empty-stderr断言。

### I2 — initial isolated worktree 与 main-drift rebuild 仍有未固定的执行边界

出处：`tasks.md:39`、`tasks.md:63-74`。

baseline block结束后只用一句“以该 commit exact SHA 创建 isolated worktree/branch”，没有 exact `git worktree add`、branch/path、HEAD equality 和 clean index/worktree检查；candidate block却假定 `$PWD` 已是该 worktree根。main-drift block也只创建 worktree并 `cherry-pick -n`，把修改 manifest base、切入 rebuild root、重跑 full candidate/report/review和失败清理留给散文。由于这些步骤决定 `project_root`、parent和隔离边界，应补成闭合命令，至少断言 rebuild HEAD=`new_base`、prospective diff exact two paths、无冲突，并明确 subsequent block在 `$rebuild_dir` 执行。

### M1 — main-drift 临时 worktree/branch没有成功或失败清理规则

出处：`tasks.md:65-74`。

`mktemp -d` 后 `git worktree add -b` 会把临时 worktree和固定前缀 branch留在仓库；同一 `new_base` 重试时 branch name冲突，失败路径也会留下注册项。该问题不改变 candidate bytes，但会使 autopilot 重试不幂等。应给 rebuild worktree明确 ownership，并在切换到最终 candidate或失败后用可恢复的 cleanup删除 worktree/branch；不要依赖人工清理。

## 四条粒度判据

| 判据 | 结论 | 依据 |
|---|---|---|
| 一个 subagent、一次上下文装得下 | ⚠️ | two-path scope能装入一次上下文，但单任务同时承载 schema、文档解析、Git状态机、ledger、revert、三回归和约四十个 mutation，步骤没有按可独立验证 slice拆开。 |
| 一条命令/事实可判定成败 | ❌ | public modes明确，但 review-fix 的 exact path/numstat基准错误，completion exact channels也未被 block断言。 |
| 失败能独立回滚 | ⚠️ | final single-parent direct revert设计成立；review-fix单文件修改无法按现 block重建，main-drift temp worktree也不具备幂等 cleanup。 |
| 人 review `<10 分钟` | ❌ | 2/4/4 分钟没有由函数/case复杂度支持，密集的 300–380 行 Python core+self-test不可能只靠 summary替代真实 diff review。 |

## 规格符合性与任务质量

- 规格符合性：R1–R27 机械追溯全集、current R24 terminal 与 00a/00b owner migration、PLAN v6 DAG、DECISIONS single-parent exception均一致；expanded rejection matrix已闭合。阻断点是 R24 的 implementation-before review budget仍不可信，以及 actual gate在 amend路径比较了错误的 Git基准。
- 任务质量：baseline先落盘 process inputs、task源码 exact two paths、candidate先独立 review、completion后置、working ledger exact grammar和 public mutation codes方向正确。剩余缺口集中在 base-relative prospective index、真正可执行的 completion oracle、initial/rebuild worktree边界，以及符合 2–5 分钟/10 分钟硬规则的拆分。
