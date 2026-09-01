# tasks review — Round 2

## 结论

**FAIL**

- blocker: 2
- important: 2
- minor: 0

审查范围：`tasks.md`、Round 1 tasks review、同片 `requirements.md` / `design.md` / `ledger.md`、项目 `PLAN.md` / `DECISIONS.md` / `STATE.md` / `config.yml`，并核对当前 Git tree 与 spec skill 的 tasks/review 契约。未修改被审文件，未运行 AOSP `envsetup`、`lunch`、build、sync、fetch 或 download。

机器自查事实：`check-tasks.py`、`check-req.py`、`check-criteria.py`、`check-plan.py` 与 `git diff --check` 均 exit 0；任务五字段齐全，编号仅一级且无重复；`需求` 并集精确为 R1–R27；源码清单已从 Round 1 的 19 paths 收窄为 exact two paths，3 个 evidence 与 3 条只读回归路径留在验收资产；当前项目仍未进入 Git tree，当前 HEAD 为 `fa06386906721d0f911e8438e4e15ec3725256dc`，所以门④后的 process-baseline commit 确为隔离 worktree 获取输入所必需。

## Round 1 七项闭合核对

| Round 1 finding | Round 2 结论 | 依据 |
|---|---|---|
| B1 task diff / 预算 / review 粒度 | **部分闭合，仍阻断** | task source diff 已是 exact two paths；但 tasks 门没有给两文件的 estimate，只在实现后检查 actual `<=800/160`，且步骤 3–7 仍不是 2–5 分钟动作，无法证明 `<10 分钟 review`。见 B1。 |
| B2 worktree 缺 19-path 输入 | **闭合** | 门④后先提交已审 process baseline，再从 exact HEAD 创建隔离 worktree；任务 commit 只含后续新建的 two paths。 |
| B3 review / completion / ledger / accept 顺序 | **部分闭合，仍阻断** | candidate→独立 review→controller mark/ledger/sync→accept 的主顺序已修正，`sync-ledger.py` 也改为只读核对；但 FAIL 后 amend/re-review 与 pre-commit 的 `HEAD=base` 条件不可同时执行。见 B2。 |
| I1 shell 变量跨步失效 | **闭合** | manifest 创建后每次验证均重新读取 `base_commit`，不再依赖跨 shell 的 `$FROZEN_HEAD_SHA`。 |
| I2 untracked whitespace 假绿 | **闭合** | exact paths stage 后运行 `git diff --cached --check`，并比较 cached path set。 |
| I3 closed rejection matrix | **部分闭合，仍重要** | matrix 已大幅扩展，但 DECISIONS/sizing、accept missing/non-common path、JSON duplicate object key 与 post-revert helper 注入仍无闭合 oracle。见 I2。 |
| I4 函数边界 / exact 命令 / ledger grammar | **部分闭合，仍重要** | 顶层函数和 ledger 行 grammar 已固定；baseline/candidate/controller 命令仍是散文，步骤 4–7 仍无代码骨架。见 I1。 |

## Findings

### B1 — R24 的 tasks-time estimate 仍不存在，四条粒度硬门不能由“two paths”替代

出处：`tasks.md:9-16`、`tasks.md:20-59`、`tasks.md:62`；`requirements.md:74`、`requirements.md:167`、`requirements.md:183`；tasks 细则“四条粒度判据”与“每步一个动作，2–5 分钟”。

Round 2 正确地把 task commit 限定成 manifest 与 validator 两个文件，这解决了 4615+ 行过程文档进入 task diff 的问题；但文件数不是行数或 review 成本。当前 tasks 没有给 `supersession.json`、validator、自测代码和 review summary 的估算区间。步骤 9 的 `git diff --cached --numstat <=800` 是实现完成后的 actual gate，不能满足 R24 明写的“tasks estimate 在 implementation 前判定”；也不能证明人审该任务 `<10 分钟`。

同时，步骤 3–7 每一步仍把多个实现动作揉在一起：CLI/错误通道、nested closed schema、PLAN/DECISIONS/sizing、Git scope、commit/ledger/revert、17 行 mutation matrix 与多个临时 repo fixture。它们明显不是单个 2–5 分钟动作。一个 reviewer 即使只看不超过 160 行 summary，也仍须审真实 validator/test diff，summary 不能替代 task diff review。

建议修正：在 tasks 顶部落盘 estimate，至少逐文件列出 non-generated low/high 与 self-test/review-summary high，合计 high 必须 `<=800/160`；说明 `<10 分钟` review 的具体分包/阅读面。把步骤 3–7 拆成单动作、含可执行骨架的细步骤。若 dense validator 仍无法在单任务和 `<10 分钟` 人审内成立，应回 design 调整交付边界，而不是等步骤 9 才发现超限。

### B2 — review FAIL 后无法按声明“amend + 完整 pre-commit”，main 漂移时 amend 也不能改变 parent

出处：`tasks.md:5-7`、`tasks.md:37`、`tasks.md:61-63`；`design.md` 的 dynamic frozen-base 与 single-parent contract。

初次流程在 baseline HEAD 上运行 pre-commit 后创建 candidate，是可执行的。但 candidate 创建后，当前 HEAD 已是 candidate，而 pre-commit 明确要求：explicit base = manifest base = **当前 HEAD**。因此 reviewer FAIL 后无论在 amend 前还是 amend 后重跑“完整验证”，当前 HEAD 都不是 manifest base，必然得到 `BASE_HEAD_MISMATCH`。任务没有定义如何在保留修复 bytes 的同时回到 baseline state 运行 pre-commit，再重建 candidate。

同一行还说 main 漂移时“以新 baseline 重新生成/amend 候选 commit”。`git commit --amend` 会保留原 parent，不能把 candidate 的 parent 改成新 baseline；这与 accept 要求唯一 parent=manifest base 冲突。

建议修正：把每轮修复定义成可复现的新 candidate 生成过程，例如在 fresh isolated worktree/branch 上从 exact baseline 开始，应用仅 two-path fix，写入该 baseline SHA，运行 self-test/pre-commit，随后创建新的 single-parent candidate；旧 candidate 只作 review evidence，不在其 HEAD 上跑 pre-commit。main 漂移时必须以新 HEAD 建新 baseline并**重建/rebase** candidate，不能称为 amend；然后重新生成报告并派全新 reviewer。把 candidate→review→controller mark/ledger/sync→accept 的 PASS 路径原样保留。

### I1 — exact stage/commit/controller 命令和代码步骤仍未落盘

出处：`tasks.md:5-7`、`tasks.md:20-38`、`tasks.md:61-63`；tasks 细则“描述做什么但不给怎么做的步骤（代码步骤必须给代码块）”。

已固定的接口列表与 ledger 行 grammar 是有效修复，但下列承重动作仍只有自然语言：

- process baseline 如何枚举“process documents/review evidence”、如何排除 task/evidence/common、如何逐字比较 cached path set、如何 commit；
- candidate 如何从 manifest 读取 two paths、以 `git add --` stage、比较 expected/actual、计算 numstat、确认 parent 后 commit；
- controller 如何调用 `mark-task-done.py`、以哪个 exact ledger 路径调用 `sync-ledger.py --repo`、如何把真实 SHA/base12/sha12替换进唯一 ledger 行，以及最终 `accept` 的完整参数与 oracle；
- 步骤 4–7 的 schema/Git/ledger/revert 实现没有最小可执行 Python 骨架；函数名清单和 mutation 表不等于代码步骤。

这会让 baseline path set、SHA substitution、accept 路径和失败行为取决于实现者临场解释。建议给出 `set -euo pipefail` 的 exact shell blocks与最小 Python dispatch/error/test skeleton；动态值可以从 manifest/Git读取，但其生成和逐字比较命令必须固定。

### I2 — self-test 尚未覆盖任务自己声明的完整拒绝面

出处：`tasks.md:36-59`、`tasks.md:22-34`；`requirements.md` 的“所有 JSON 拒绝 duplicate key”；`design.md` 的 closed manifest、DECISIONS/sizing、exact commit/ledger/revert contract。

现有 matrix 比 Round 1 完整很多，并且五个承重 mutation 已明确穿过真实 public mode；不过仍有可假绿缺口：

- 步骤 4 要验证 DECISIONS 与 sizing 的对应裁定，但 matrix 只有 PLAN mutation，没有 DECISIONS/sizing 缺失或值漂移；实现者完全跳过这两项仍可绿。
- manifest path mutation 覆盖 extra path，accept temp repo 只覆盖 extra `common/evil`；没有 task commit 缺少一个 exact path或增加一个非-`common/` path的 public accept case，不能证明 commit set 是“逐字等于”而不只是“无 common”。
- “所有 JSON”要求拒绝 duplicate object key；matrix 的 duplicate/out-of-order 只写 array，Python 标准 `json.load` 默认会静默采用重复 key 的最后值。
- `ROLLBACK_MISMATCH` 行要求“direct call of the same post-revert checker”，但已固定函数边界只有同时执行 revert 的 `validate_isolated_revert(...)`，没有可注入 leftover 的 post-revert checker 接口，测试路径与代码边界不一致。
- ledger 声称“只接受唯一 exact completion grammar”，负测只有 missing/duplicate line 和 fake SHA；未固定 malformed completion 行或额外字段/额外 SHA 如何被拒绝，容易退化为全文子串匹配。

建议把上述每类补成独立 mutation，固定调用的 public mode/helper、rc=1、stdout empty、exact stderr；若要 direct-call post-revert checker，就把该 checker 加入函数边界。组合单元格中的每个 mutation 也应明确为独立 case，而不是只要求任选一个。

## 四条粒度判据

| 判据 | 结论 | 依据 |
|---|---|---|
| 一个 subagent、一次上下文装得下 | ⚠️ | two-path scope 已显著缩小，但 dense validator 同时承担 schema/PLAN/Git/ledger/worktree/revert 与完整 fixtures；没有 tasks-time line estimate，步骤仍过粗。 |
| 一条命令/事实可判定成败 | ⚠️ | 三个 public mode 与 PASS/FAIL 通道明确；修复轮 pre-commit 不可执行，matrix 仍可漏实现 DECISIONS/sizing/exact commit set。 |
| 失败能独立回滚 | ⚠️ | initial candidate 的 single-parent/direct revert 合理；review FAIL/main drift 的 candidate 重建流程不闭合。 |
| 人 review `<10 分钟` | ❌ | 只有 actual 上限与 summary 上限，没有 tasks-time diff estimate或可审分包；`<=800` 本身不证明 `<10 分钟`。 |

## 规格符合性与任务质量

- 规格符合性：R1–R27 机械追溯全集成立；requirements 已声明当前片只真实实现 R24、其余为 owner migration，manifest owner rows使该追溯不成为孤儿。PLAN v6 的 00a/00b DAG、public gate、single-parent terminal exception与 DECISIONS 口径一致。当前不符合点是 R24 的 tasks-time estimate缺失，以及 review fix loop无法维持 dynamic-base/single-parent invariant。
- 任务质量：exact two-path source scope、process baseline、cached whitespace、候选先独立 review、controller 后写 completion、`sync-ledger.py` 只读核对、每轮从 manifest 取 base 等 Round 1 修复方向正确。剩余缺口集中在可执行的修复轮状态机、tasks-time review budget、exact commands/code skeleton和 rejection oracle闭包。
