# design 独立审查 — Round 2

审查对象：原 `2026-09-01-00-environment-seed-preflight/design.md` 当前磁盘版本，按 R24 触发后的知识终止/拆分设计审查。

完整读取：当前 `PLAN.md` v6、`PLAN-history.md`、`DECISIONS.md`、原 00 的 `requirements.md`、`design.md`、`sizing-prototype.md`、`ledger.md`、Round 1 design review、PLAN v6 incremental Round 2，以及 spec `references/04-design.md`、`references/07-review.md`。另以当前 `STATE.md`/路由状态核对生命周期。未运行 AOSP、lunch、build、sync、download 或网络安装。

## 结论摘要

- 结论：**不通过**。Findings 为 **0 个阻断、2 个重要、1 个次要**。
- Round 1 的 B1、B2、I2、I3、I4、M1、M2 已关闭：design 已固定 `tasks -> execute -> accept -> retro`，R1–R27 owner 矩阵与 PLAN v6 闭合，ER 使用 ARTIFACT discriminator + XOR，不再增加 Python minor 下限，sizing 明确是拆后重估。
- Round 1 的 B3 已补上 validator、固定 base、isolated revert 与 exact PASS 行，但 pre/post-commit 模式和 ledger SHA 时点仍未形成唯一可实现契约，降为本轮 I2。
- Round 1 的 I1 大部分已修复，但 00a `verify-seed` 的 fixture CLI/输出与已批准 PLAN v6 仍不一致，形成本轮 I1。

## 规格符合性

| 审查项 | 结论 | 说明 |
|---|---|---|
| 八节 + 文件清单 | ✅ | 九个固定标题顺序齐全；当前片与 successor owner 清单均存在。 |
| R1–R27 owner matrix | ✅ | 共 27 行且逐条覆盖；R6 direct owner=00b，R19/R20 publisher+provider 分工，R23 preflight parity=00b，R25 拆为 00a/00b 各自 rollback，均与 PLAN v6 一致。 |
| lifecycle | ✅ | `design review -> tasks -> execute -> task diff review -> accept -> retro -> select/new-spec 00a` 是合法主链，不再从 design 直接跳 retro。 |
| current supersession acceptance | ❌ | 有真实脚本/manifest/固定 base/rollback 方案，但 pre-commit 与 acceptance 的参数、ledger SHA 时点、候选 commit 边界尚不精确，见 I2。 |
| successor frontmatter/CLI | ❌ | 00b 闭合；00a fixture verifier 与 PLAN v6 的 exact command/output 冲突，见 I1。 |
| successor file/error/test owner | ✅ | dispatcher/schema/store/ref/verify-seed 归 00a，preflight/provider/test 归 00b；runtime unavailable、exit 20、exit 30 与 public gate 已分配。I1 所述 verifier CLI 除外。 |
| ER XOR | ✅ | `ARTIFACT.kind` 与 `REF.kind` discriminator 配合文字 XOR invariant，已消除“一条 ref 同时指向两类 artifact”的旧冲突。 |
| Python/YAGNI | ✅ | 仅要求 Python 3 stdlib，不再凭空固定 3.11+，也没有重新引入未审核的公开 Python publisher API。 |
| sizing 措辞 | ✅ | 890–1310 明确是门③估算；00b `470–630` 明确是拆后自底向上重估，不再声称与 combined 扣减式相等。 |
| Mermaid | ✅ | `graph TB`、`erDiagram`、`sequenceDiagram` 三块结构和关系语义静态核对可成立；本机无 `mmdc`，未作渲染器执行。 |

静态验证记录：

- `check-plan.py PLAN.md`：exit 0，无输出。
- 固定设计标题：9/9。
- owner matrix：R1–R27 共 27 行。
- 固定 base `2c198d7e1b2ee4a5aaa75fcf8d68cc35050452af^{commit}`：可解析；当前相对该 base 的 tracked `common/` diff 为空。

## Findings

### 阻断

无。

### 重要

#### I1 — 00a fixture `verify-seed` 的 exact CLI 与输出静默偏离 PLAN v6

- **位置：** `design.md:70-76`；对照 `PLAN.md:66`。
- **依据：** PLAN v6 的独立判据是 `./common/.harness/bin/feature-closure verify-seed common/tests/fixtures/aosp17-services/seed.golden.json`，输出 `SEED ABI PASS`。design 改成 `commands.d/verify-seed --file FILE`，并把 exact stdout 改成 `SEED ABI PASS fixture_only`。`--ref ... --artifact-store ... --require-public-real` 分支与 PLAN 一致，但 fixture 分支的参数语法和 oracle 不一致。
- **影响：** 00a 起草者无法同时逐字复制 PLAN 和 design；按 design 实现会使 PLAN v6 的独立判据不可执行或输出不匹配，按 PLAN 实现则违反 design 的 exact successor interface。
- **必须修复：** 以已批准 PLAN v6 为准统一 fixture 参数与 exact stdout；若确需 `--file` 和 scope suffix，必须先显式修订并复审 PLAN，而不能在 design 中静默改 ABI。

#### I2 — supersession validator 尚未给出无歧义的 pre-commit / acceptance / rollback 时点契约

- **位置：** `design.md:10,60,64-68,132-136,141-152`。
- **依据：** 生命周期规定先运行 pre-merge check、再提交 exact commit；错误表又要求 validator 在 accept 前检查 ledger 同时含 `任务 1: 完成` 和 exact SHA。pre-merge exact command只有 `--self-test --project-root --base-commit`，组件接口没有定义 `--self-test` 是否免除 ledger/SHA 检查，也没有声明独立的 pre-commit/acceptance mode。正文交替使用 “exact commit”“exact merge SHA”“Post-merge”，但流程的 accept 发生在合入 main 之前；若参数是普通 task commit，`git revert --no-edit SHA` 可用，若真是 merge commit，则还缺 mainline `-m` 语义。组件接口行还漏了仓根下的 `.spec/2026-09-01-aosp-feature-minimal-checkout/` 路径，而测试策略中的命令包含该路径。
- **非空验证风险：** `git diff --quiet BASE -- common` 没有固定右端为 ledger 中的 candidate SHA，也不观察 untracked `common/`；设计也未要求用损坏 replacement、缺失 R owner、越界 budget、伪 ledger SHA 或注入 common path 的负向 mutation 证明 validator 不是固定 PASS。
- **影响：** tasks 实现者仍需临时决定哪个模式检查 ledger、SHA 究竟是哪类 commit、rollback 应怎样调用；不同决定可能让 pre-commit 永远因 SHA 尚不存在而失败，或让 acceptance/rollback 验到 dirty worktree 而不是 exact task diff。
- **必须修复：** 固定两个不重叠的模式及 exact 参数/oracle：pre-commit 只验 manifest/PLAN/DECISIONS/sizing 与候选树范围；acceptance 接收 ledger 中的 single-parent task commit SHA，按 `BASE..TASK_SHA` 验范围并在隔离 worktree revert；若选择 merge commit则明确 parent/mainline。补至少一组 exact mutation negative controls，并统一脚本的仓根相对路径。

### 次要

#### M1 — 当前终止片的文件清单仍使用省略路径和 glob

- **位置：** `design.md:154-165`。
- **依据：** 当前片清单写成 `.spec/.../PLAN.md`、`.spec/.../specs/...` 与 `work/review-*.md`，不是 references/04 要求用于锁定 BASE..HEAD 拆分的精确文件路径；successor owner 表反而给出了精确 `common/` family。
- **影响：** 不改变架构，但 validator/tasks 仍要自行展开哪些 review/ledger 文件属于 exact commit，增加 I2 所述候选 diff 边界歧义。
- **建议：** 展开为项目根相对的 exact paths；对 reviewer 产物若不是 task source diff，移到明确的验收资产列表。

## 质量结论

- **范围/YAGNI：** 没有 `common/` 实现或 AOSP 执行范围偷跑；Python 3.11+ 与公开 `seed_contract.publish(...)` 均已删除。
- **空验证：** 已从“相对 index 的空 diff”进步为固定 base 与自测脚本，但 exact candidate SHA 和 mandatory mutation controls 仍不足，故 I2 未关闭。
- **独立回滚：** 方案已具备 isolated worktree 和旧 harness 回归，但 commit 类型/时点必须先定死才能称为 exact rollback。
- **伪完成：** design 明确 00a/00b actual 要在各自 tasks/acceptance 重算，没有把 sizing 或 successor implementation 冒充已完成。

VERDICT: FAIL
