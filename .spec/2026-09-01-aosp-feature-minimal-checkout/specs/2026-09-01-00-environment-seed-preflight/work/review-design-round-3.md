# design 独立审查 — Round 3

审查对象：`2026-09-01-00-environment-seed-preflight/design.md` 当前磁盘版本，作为 R24 触发后的知识终止片设计。

完整读取：`PLAN.md` v6、`DECISIONS.md`、原 00 `requirements.md`、`design.md`、`sizing-prototype.md`、`ledger.md`、Round 2 design review，以及 spec `references/04-design.md`、`references/07-review.md`。另运行路由与静态 checker，并以当前 Git HEAD/固定 base 核对设计中的提交、范围和回滚契约。未运行 AOSP、envsetup、lunch、build、sync、download 或网络操作。

## 结论摘要

- 结论：**不通过**。Findings 为 **1 个阻断、3 个重要、1 个次要**。
- Round 2 的 I1 已关闭：00a fixture 语法现为 positional `FILE`，fixture stdout 精确 `SEED ABI PASS`；ref 分支与 public stdout 也与 PLAN v6 一致。
- Round 2 的 I2 在文档结构上大幅收敛：已经分成 `self-test`、`pre-commit`、`accept` 三个不重叠模式，accept 固定 single-parent SHA、working-ledger anchor、exact commit path set 与 isolated direct revert；mandatory mutations 也已列齐五类。但固定 base 已被共享分支推进所淘汰，导致两个成功模式在当前仓库必然失败；负向 mutation 的 exact code/schema 仍未闭合。
- Round 2 的 M1 路径问题已关闭：当前 task source-diff 是 19 个完整 repo-relative exact path，无 glob/ellipsis；review 报告明确列为验收资产并排除在 task commit 之外。仅 `create/modify` 操作类型仍与 base tree 不符，形成新的次要 finding。

## 规格符合性

| 审查项 | 结论 | 说明 |
|---|---|---|
| 八节 + 文件清单 | ✅ | 九个固定标题各出现一次；无 TBD/TODO/待定占位符。 |
| R1–R27 owner matrix | ✅ | 27 行完整且顺序为 R1–R27；当前片只承接 R24，其余迁移到 00a/00b，与 PLAN v6 owner 切口一致。 |
| 00a verifier CLI/stdout | ✅ | `verify-seed FILE` + `SEED ABI PASS` 与 PLAN v6 独立判据一致；public ref 分支为 `--ref REF --artifact-store STORE [--require-public-real]`，public success 为 `SEED ABI PASS public_aosp17_cuttlefish`。 |
| validator 三模式 | ❌ | 参数、PASS oracle、ledger 与 isolated revert 时点已固定；但硬编码 base 已不是 HEAD，pre-commit 与 accept 当前都不可成功，见 B1。 |
| mandatory negative mutations | ❌ | 五类 mutation 已列出，但其中三个没有 exact expected failure code，且主输出 manifest 的嵌套 schema 不完整，见 I1/I2。 |
| exact task source-diff | ✅ | 19 个路径均完整、唯一、无 `*`/`...`；process review reports 被明确排除。操作类型标签另见 M1。 |
| PLAN/requirements/DECISIONS 一致性 | ❌ | owner/public gate/sizing 一致；当前终止片的 task commit 与全局 exact merge commit/R25 文案仍冲突，见 I3。 |
| lifecycle | ✅ | 明确走 design → tasks → execute → task diff review → accept → retro → select/new-spec 00a，没有从 design 直跳 retro。 |
| errors/tests/rollback | ❌ | 错误矩阵、分层测试和 direct revert 均存在；B1 使成功/回滚路径当前不可执行，I1 使部分负向 oracle 不唯一。 |
| Mermaid | ✅ | `graph TB`、`erDiagram`、`sequenceDiagram` 结构静态可成立；本轮未引入渲染器依赖。 |
| YAGNI/范围 | ✅ | 当前片不写 `common/`、不运行 AOSP，不提前发明公开 Python API或 minor-version 下限。 |

静态验证记录：

- `check-plan.py PLAN.md`：exit 0。
- `check-req.py`、`check-criteria.py`、`check-analyze.py requirements.md`：均 exit 0。
- 固定标题：9/9；owner matrix：R1–R27 共 27 行；current path rows：19/19，唯一且无 glob/ellipsis。
- 设计固定 base：`2c198d7e1b2ee4a5aaa75fcf8d68cc35050452af`；审查时 HEAD：`fa06386906721d0f911e8438e4e15ec3725256dc`。
- `git diff --name-only 2c198d7e... -- common` 非空，返回 `common/.harness/lib/session-state-path.sh`；该差异来自固定 base 之后已进入 main 的其他已提交工作，而不是本终止片。
- `git ls-tree -r --name-only 2c198d7e... -- .spec/2026-09-01-aosp-feature-minimal-checkout` 为空；当前 19 个 task path 相对该 base 均为 create。

## Findings

### 阻断

#### B1 — 硬编码 base 已被共享 main 推进淘汰，pre-commit 与 accept 在当前仓库必然失败

- **位置：** `design.md:11,58,68-69,155-157`。
- **证据：** 设计硬编码 base `2c198d7e...`，并要求 pre-commit 的 tracked `BASE..worktree` `common/` diff 为空、task commit 的唯一 parent 精确等于该 base。审查时 HEAD 已是 `fa06386...`；`2c198d7e..HEAD` 已包含已合入的 `common/.harness/lib/session-state-path.sh` 114 行改动。因此 pre-commit 的 common-scope 检查必然报 `COMMON_SCOPE_VIOLATION`。若从当前 HEAD 正常创建 task commit，其唯一 parent 又会是 `fa06386...` 而非 `2c198d7e...`，accept 必然报 `COMMIT_TYPE_INVALID`。同时满足两条只能丢弃/绕开 main 上其他已合入工作或创建一条从旧 base 分叉的非正常 commit，不是本 spec 获准的动作。
- **影响：** 这是本终止片唯一的实施与验收主链；两种成功模式都不可达，无法进入门⑤/retro，也不能用 isolated revert 证明 rollback。
- **必须修复：** 不要把共享分支的历史 HEAD 写死为永久 base。可在 execute/pre-commit 开始时读取并冻结当时 HEAD 到 manifest，要求 pre-commit 时 HEAD 等于该 manifest base、task commit 的唯一 parent 等于同一冻结值，accept 只信 manifest/显式参数中的同一值；或使用一个明确隔离且从该 base 启动的 spec worktree。无论选哪种，都要保证不会把 base 之后的无关 main 改动计成本片 `common/` diff，也不得通过 reset/revert 他人改动来满足检查。

### 重要

#### I1 — 五类 mandatory mutation 尚未各自固定 exact failure code/oracle

- **位置：** `design.md:67,136-142,150`。
- **依据：** self-test 已列 missing replacement、missing R27 owner、budget 801、fake ledger SHA、injected `common/evil` 五类，但只声明“各自产生 named failure code”。错误表可确定后两类大致为 `LEDGER_SHA_MISMATCH`/`COMMIT_SCOPE_MISMATCH`，前三类只有泛化的 `RESULT FAIL supersession CODE`、`PLAN_INVALID` 或“exact failed assertion”，没有唯一 code 映射；也未固定 self-test 是必须穿过公开 mode/CLI 还是可直接测任意 helper。
- **影响：** 实现者仍需临时决定三种 code 和测试层级；self-test 可能只断言“某处失败”，错误优先级错、恒定失败或 mutation 未到目标校验点仍可假 PASS。
- **必须修复：** 为五类 mutation 逐项列 exact exit/stdout/stderr（至少 exact last line/code），并规定 fake-ledger/common-path 两项通过临时 Git fixture 调用真实 `accept` 路径，replacement/owner/budget 三项通过真实 manifest validator 路径；每项还应断言实际 code 等于目标 code而不只是非零。

#### I2 — `supersession/v1` 只固定了顶层字段，没有形成可独立实现的 exact schema

- **位置：** `design.md:91`。
- **依据：** 数据模型给出顶层 fields 和若干语义，但没有固定 `replacements` 元素是 string 还是包含 dependency 的 object、`requirement_owners` 是 map 还是 ordered rows及其 value enum、`line_budgets` 的 exact nested keys/min/max/summary 表示。`commit_paths` 只固定为 sorted exact array。该 manifest 是当前片唯一机器产出，validator又需要按它验证 DAG/owner/budget，嵌套形态不是非承重实现细节。
- **影响：** tasks/实现必须现场设计主 artifact bytes；不同实现可表达相同文字语义却互不兼容，self-test fixture和accept无法由 design 唯一推出。
- **必须修复：** 写出完整 JSON shape（每个 object 的 exact key set、array item type/order、owner enum、budget min/max keys与整数边界、unknown/missing field policy），或提供一份 canonical manifest fixture并声明逐字 schema。

#### I3 — 当前终止片的提交类型仍与自身概述、requirements R25 和 PLAN 全局 rollback 契约冲突

- **位置：** `design.md:10,58,69,152,157`；对照 `requirements.md:74,168,178`、`PLAN.md:190`。
- **依据：** 设计概述仍称 ledger 保存 “exact merge SHA”；原 R25/验收和 PLAN v6 全局规则也要求每个 spec 的 exact merge commit。三模式实现则明确接收 single-parent task commit，直接 `git revert --no-edit SHA` 且禁止 merge `-m`。这次虽只把原 R25 的 successor responsibility 迁移给 00a/00b，但 design 没有在 PLAN/DECISIONS 中声明知识终止片是全局“每个 spec 使用独立 merge commit”的例外，正文自身也仍混用 merge/task。
- **影响：** closeout/ledger 到底记录 task SHA 还是 merge SHA仍有两个合法解释；后续自动化按 PLAN 读取 merge SHA时会拒绝当前 accept anchor，或按 design 读取 task SHA时违反已批准全局回滚契约。
- **必须修复：** 选定一种提交类型并全局统一。若当前知识终止片必须使用 single-parent task commit，应在 PLAN/DECISIONS 明确这是 superseded terminal 的唯一例外并删除本 design 的 merge wording；若仍遵循 merge contract，则 accept 必须定义 exact merge SHA、parents/mainline 与 `git revert -m` 语义。

### 次要

#### M1 — exact 路径表的 create/modify 列与固定 base tree 不一致

- **位置：** `design.md:165-183`。
- **依据：** `git ls-tree` 证明固定 base（当前 HEAD 亦同）完全不存在该 project 目录，因此 19 个 task paths 相对 BASE..TASK 全部是 create；表中 PLAN/PLAN-history/DECISIONS/STATE/design/tasks/ledger 被标为 modify。
- **影响：** 路径 set 本身已经精确，不影响 scope validator；但 references/04 要求文件清单同时锁定创建/修改，错误操作标签会使任务简报或 review package 对新增文件作“修改”解释。
- **建议：** 将 19 行都按实际 BASE..TASK 语义标为 create；如果希望表达“当前工作区已存在并继续编辑”，另用说明文字，不要混入 Git diff operation。

## 质量结论

- **范围/YAGNI：** 通过。没有 `common/` 实现偷跑、没有 AOSP 操作、没有与 successor 无关的重构。
- **验证真实性：** 三模式与五类 mutation 比 Round 2 明显增强，但 B1 使 success path 实际不可达，I1 仍容许错误原因假 PASS。
- **独立回滚：** direct single-parent revert 的技术语义本身清楚；阻塞点是 base/commit 无法形成以及与上游 merge contract 未统一。
- **文件边界：** exact 19-path set 已闭合，review evidence 排除合理；仅 create/modify 标签需校正。
- **伪完成：** 通过。design 明确当前只终止原 00，00a/00b actual 仍在各自 tasks/acceptance 重算，没有把 sizing 或迁移矩阵冒充 successor 实现。

VERDICT: FAIL
