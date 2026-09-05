# 05 verifier contract tasks review — accept green asset

## 结论

- 规格符合性：**PASS**
- 任务质量：**PASS**
- Findings：**B=0 / I=0 / M=0**

本次是 accept 期的独立增量审查，只核当前 `tasks.md` 中任务 6 的验收资产
单行新增：`$WORK/evidence/task-6-green.txt`。没有修改任务、需求、设计、源码或
accepted HEAD，也没有把此前的执行日志当作本次源码变更。该声明把终验实际依赖的
原始 green 日志纳入可收敛的验收资产集合，范围、引用和路径均闭合。

## 增量与五字段

任务 6 的源码字段仍为“无”；消费仍为 `verifier-checkout-v1`；产出仍为
`bash ./tests/test-verifier-contract.sh`；需求仍为 R9、R10；必需仍为“是”。状态仍为
“完成”，四个既有步骤及其 rollback、NEXT、converge 和 manifest 收口语义未变。
唯一增量位于“验收资产（不纳入源码文件清单）”：在既有 brief、red、report、manifest、
acceptance draft 之外声明 green 日志。故没有把验收记录误列为源码文件，也没有增加
实现文件、放宽门槛或改变 accepted candidate。

任务 1--6 的需求并集仍为 R1--R10：任务 1 覆盖 R7/R10，任务 2 覆盖 R1--R6，任务
3 覆盖 R8，任务 4--6 覆盖 R9/R10。产消链仍连续：base test → provider → contract
→ accepted head → checkout → rollback/NEXT/terminal convergence；任务 6 新增的是其
终验输入记录，不是新的生产依赖或消费者。

## 验收资产与收敛对账

固定 `WORK` 展开后，当前声明有 26 个条目、去重后恰为 21 个普通可读文件：六份
brief、六份 red、六份 report、共享 `review-manifest.tsv`、acceptance draft 和任务 6
green 日志。21 个文件均实际存在；共享 manifest 被任务 1--6 重复声明但只计一个物理
资产。

新增的 green 文件实际为
`work/2026-09-04-05-verifier-contract/evidence/task-6-green.txt`，大小 9,121 bytes，
SHA-256 为
`d45cf2343db20fa803b47c4cd1baa1e663a58dc36f37a057b44f1c5d8048ca16`。任务 6 report
以相对链接 `evidence/task-6-green.txt` 引用同一文件并记录相同 hash；task-6 review r1
和 r2 也交叉引用该路径。因此“声明 → 文件 → report 原始日志引用”可追溯且无悬空项。

green §4 所载的旧隔离 `check-converge` fixture 只复制了修订前的 20 个资产；这是一份
历史执行记录，不能被解释为已经验证当前 21 资产集合。它不是本次 tasks 声明的缺陷：
任务 6 步骤 4 已要求最终 converge，且 r2 已正确限定 controller 终验必须将 green
一并复制并按当前声明运行。进入 accept 前的 controller 收敛检查必须以 21 个去重资产
为输入；旧的 20 资产成功结果不得替代该检查。

## 源码边界与 accepted HEAD

implementation worktree 仍在 accepted HEAD
`9e5edb45a3048e4c208e2d7fe135639768cc87db` 且 clean。execution BASE
`65d67b52e5b34d0d9d2add587083ebf2fadcd3ea` 到该 HEAD 仅有 exact3：
`common/.harness/bin/verify-sidebar.sh`（202 行）、`docs/verifier-contract.md`（67 行）
和 `tests/test-verifier-contract.sh`（102 行），合计 371。新增验收资产不在该源码 diff
中，也不触及三个旧 verifier、session/resource-lease 边界或任何 05a--10 源码。

## Findings

无。

最终裁定：**规格符合性 PASS；任务质量 PASS；B=0 / I=0 / M=0。** 本 PASS 只认可
tasks 的增量声明和其现有引用闭合；不替代 controller 以当前 21 资产集合执行的最终
`check-converge`，也不解除 05a/06/09 的既有顺序门。
