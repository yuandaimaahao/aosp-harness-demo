# tasks review — Round 1

## 结论

**FAIL**

- blocker: 3
- important: 4
- minor: 0

审查范围：`tasks.md`、同片 `requirements.md` / `design.md` / `ledger.md`、项目 `PLAN.md` / `DECISIONS.md`，并核对 `config.yml`、当前 Git tree 与 spec skill 的 tasks/review/execute 契约。未运行 AOSP `envsetup`、`lunch`、build、sync 或 download。

机器自查事实：`check-tasks.py` exit 0；任务五字段齐全；编号只有一级且不重复；`需求` 并集精确为 R1–R27；`文件` 恰为 19 个 exact path；3 个 evidence 文件和 3 个只读回归路径均在“验收资产”而非源码清单；无通配符/省略号；已有明确红阶段、绿阶段、commit 和 ledger 步骤。这些机械项通过，但不能覆盖下列可执行性缺口。

## Findings

### B1 — 当前单任务必然越过 R24 与 `<10 分钟 review` 硬门，且单上下文/步骤粒度不成立

出处：`tasks.md:3-21`，尤其 `tasks.md:5`、`tasks.md:14-18`；`requirements.md:74`、`requirements.md:165-183`；`design.md:220-244`。

19 个源码路径中目前已经存在的 17 个文件合计 **4615 行**，尚未计入待实现的 `supersession.json` 与 `verify-supersession.py`。这些路径相对当前 HEAD 均为 create，因此任务 diff review 会看到至少 4615 行；这既不可能让人 `<10 分钟` review，也已经超过 R24 的 800 行 non-generated diff 上限。与此同时，步骤 3–7 分别把 CLI、closed schema、五类 subprocess fixture、Git worktree/scope、ledger、revert 与三项回归揉成单步，显然不是 2–5 分钟动作，也不是一次上下文可稳妥实现和审完的颗粒度。

这是 tasks 门本身的硬失败，不能以“这些文档先前审过”绕过：`文件` 字段定义的是 BASE..HEAD 源码 diff，19 路径又被 manifest/accept 强制成 task commit 的完整 path set。

建议修正：回到 design/requirements 裁定 task commit 的真正实现边界。至少把已经审过的项目过程材料与 terminal task source diff 分离，使本任务只提交可独立回滚、可在预算内 review 的 supersession 交付物；重新计算 actual line/review budget。若仍保留 19-path 单 commit，则必须明确修改 R24/四条粒度判据并给出获批例外，当前文档没有该例外。

### B2 — `isolation: worktree` 下实现者拿不到 19-path 输入，任务无法按 brief 重现

出处：`config.yml` 的 `isolation: worktree`；`tasks.md:5`、`tasks.md:12`；`design.md:11`、`design.md:220-244`。

当前 `git ls-tree -r HEAD -- .spec/2026-09-01-aosp-feature-minimal-checkout` 为空，19 个任务路径中的既有 17 个文件全是主工作区 untracked。按 execute 规则从 HEAD 创建隔离 worktree 后，这些文件不会出现；而任务要求把它们原样纳入 manifest/commit，却没有定义从控制器工作区向隔离 worktree 传递这些已审内容的 artifact、校验值或复制步骤。实现者 brief 即便含 requirements/design/tasks，也不会凭空包含 PLAN-history、DECISIONS、三份 raw research 等全部 exact bytes。

因此动态 frozen base 本身合理，但现有任务没有可执行的隔离开工路径；直接留在 main 实现又违反项目的 worktree 隔离配置。

建议修正：在 tasks/执行合同中固定一个可重现的 bootstrap：控制器先创建隔离 worktree，再以明确源、exact 19-path allowlist 和 digest 把预审文件复制进去，随后实现者只在该 worktree 工作；或者先把过程材料作为不属于 terminal task 的已审基线提交，再从新 HEAD 冻结。不能静默改为 main/none。

### B3 — completion/ledger/accept 放在独立 diff review 之前，且 `sync-ledger.py` 根本不会写 ledger

出处：`tasks.md:20-21`；`design.md:60`；execute 契约“收报告→diff review→记 ledger”。

步骤 10 声称“以 `sync-ledger.py` 写入 `任务 1: 完成`”，但该脚本是只读一致性检查器，只会核对 ledger/tasks/git，不会写入任何行。更关键的是，步骤 10 要实现者在独立 task diff review 前就 mark done、写 completion anchor 并运行 acceptance，而 design 明确顺序是 `task diff review → accept`，execute 契约也规定 completion anchor 由控制器在 report/review 后记录。

这还让正常 review 修复循环无路可走：reviewer 若要求修复，新增 fix commit 会破坏“唯一 parent=base 的 exact task commit”；若 amend，则旧 ledger SHA 与 acceptance evidence 立即失效，而任务没有定义 amend/重写 SHA/重跑 review 与 accept 的时序。

建议修正：实现任务在绿测和创建候选 single-parent commit/report 后结束；全新 reviewer PASS 后，由控制器执行 `mark-task-done.py <tasks.md> 1`，以固定格式手工追加 completion/report/review/`commits=[40hex]` 行，再运行 `sync-ledger.py <ledger.md> --repo <root>` 作验证，最后进入 accept 并运行 validator。修复轮必须明确 amend/squash 回一个 single-parent commit、更新 SHA 并重新 review；未 PASS 不写完成锚点。

### I1 — `$FROZEN_HEAD_SHA` 只存在于单个 shell，后续步骤的命令不可独立执行

出处：`tasks.md:12`、`tasks.md:19-20`；`design.md:214-216`。

步骤 1 的 `FROZEN_HEAD_SHA=$(git rev-parse HEAD)` 不会跨独立 shell/tool call 保留，步骤 8/9 却直接引用它。tasks 规则要求每步是独立、可执行动作；按通常执行方式，后两步会把空值传给 validator 或比较失败。

建议修正：把 base 的持久来源固定为 `supersession.json.base_commit`，每个命令都重新以明确命令读取并校验；或者给出单个 `bash -lc 'set -euo pipefail; ...'` 的完整原子命令。不要依赖隐式会话环境。

### I2 — `git diff --check` 在 stage 前看不到这 19 个 untracked 文件，当前绿门是空检查

出处：`tasks.md:19-20`；当前 Git 状态显示项目路径均 untracked。

步骤 8 在 stage 前运行普通 `git diff --check`。Git 不把 untracked 文件纳入该 diff，因此即使 19 个任务文件有 whitespace error，这条命令仍可 exit 0；步骤 9 stage 后又没有跑 `git diff --cached --check`。

建议修正：stage exact manifest paths 后、commit 前执行 `git diff --cached --check`，并在同一步再次验证 cached path set；若不允许提前 stage，则逐个以可覆盖 untracked 文件的检查方式验证。

### I3 — 五个承重 mutation 走了真实公开 mode，但 closed contract 的其余错误面没有可判定验证

出处：`tasks.md:14-18`；`design.md:91-145`、`design.md:186-212`。

五个指定 mutation 的公开路径、rc/stdout/stderr oracle 写得清楚，这是优点。但步骤 4 还要求实现所有 object missing/unknown key、array duplicate/out-of-order、bool/negative integer、owner enum/order、DAG、base/path grammar、tracked/untracked common、commit type、rollback mismatch 等大量承重拒绝；步骤 5/8 的 self-test 只对其中五例做负测，合法 manifest 的 pre-commit 不能证明其余拒绝真的存在。一个忽略 unknown key、接受 bool、漏查 `..`/glob 或不检查 merge commit 的 validator 仍可能通过现有绿门。

建议修正：给 self-test 增加表驱动 closed-schema/path/base/commit-type/pre-commit-scope negative matrix，每例固定 public mode、期望 code、rc=1、stdout empty、exact stderr；至少逐项覆盖 design 声明的每类 rejection，而非只在实现散文中提到。

### I4 — 代码步骤没有给可执行骨架，且关键 ledger/commit 命令与字节格式仍是散文

出处：`tasks.md:14-21`；tasks 细则“描述做什么但不给怎么做的步骤（代码步骤必须给代码块）”与“每步一个动作”。

步骤 3–7 都是代码实现步骤，却没有代码块、函数/模块边界或最小可执行骨架；步骤 9 没给 exact stage/compare/commit 命令；步骤 10 没给 `mark-task-done.py`、`sync-ledger.py`、`accept` 的完整参数，也没有固定 ledger 中 task SHA 的唯一行 grammar。accept 若只做全文子串匹配，旧 SHA、review SHA 或其他 40-hex 都可能被误认成 task anchor。

建议修正：至少给 validator 顶层函数/argparse dispatch/错误 emitter/subprocess oracle 的代码骨架，以及 exact shell 命令；固定 ledger 行，例如 `- 任务 1: 完成 commits=[<40-lower-hex>]`（或与 execute ledger 格式一致的另一唯一 grammar），accept 只解析该行并拒绝重复/多 SHA。

## 四条粒度判据

| 判据 | 结论 | 依据 |
|---|---|---|
| 一个 subagent、一次上下文装得下 | ❌ | 单任务同时承载 19-path/4615+ 行过程材料、validator、Git fixtures、accept/revert |
| 一条命令/事实可判定成败 | ⚠️ | 三个 public mode 与 exact output 已定义，但 closed error matrix、untracked diff 与 ledger 写入有假绿/不可执行缺口 |
| 失败能独立回滚 | ⚠️ | direct isolated revert 设计合理；但 review fix commit/amend 与 ledger SHA 更新时序未闭合 |
| 人 review `<10 分钟` | ❌ | 当前已知 create diff 4615 行，未计新增 manifest/validator |

## 规格符合性与质量结论

- 规格符合性：R1–R27 的机械追溯全集成立，当前 R24 supersession 终交付物也没有孤儿；但实际 task diff 已超过 R24 上限，执行时序与 design 生命周期冲突，因此不能通过。
- 任务质量：19 个 exact source paths 与 acceptance assets 分离正确；red→实现→green→commit 的大方向正确；五个指定 mutation 和 isolated direct revert 的目标 oracle 足够具体。阻塞点集中在任务规模、worktree 输入搬运、review 后 completion/ledger/accept 闭环，以及若干会产生假绿的命令/测试缺口。
