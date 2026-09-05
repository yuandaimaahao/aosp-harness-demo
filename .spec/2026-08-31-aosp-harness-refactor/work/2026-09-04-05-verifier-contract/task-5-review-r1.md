# Task 5 独立 Diff Review r1 — full/depth-1 checkout（zero-source-delta）

## 结论

**PASS — B=0 / I=0 / M=0。**

本审查只覆盖 task 5 对 accepted candidate
`9e5edb45a3048e4c208e2d7fe135639768cc87db` 的 full-history / 真正
`file://` depth-1 checkout 验证及其零源码 delta；未重跑报告已经执行的
contract、offline 或 clone 命令。

只读 Git 核对显示 worktree 的 `HEAD` 正是该 accepted commit，porcelain
为空，`git diff --name-status ACCEPTED_HEAD HEAD` 为空，且所给
`review-9e5edb45-9e5edb45.md` 的 commit/stat/patch 也均为空。因此 task 5
没有新增提交、源码改动或额外回滚面。作为候选本体的交叉核对，
`65d67b52..HEAD` 只有 canonical provider、contract 文档、base test 三个路径，
`202 + 67 + 102 = 371`；这与 task 5 的「对 accepted HEAD 自身」零 delta
并不矛盾。

## 规格符合性（R → E）

| R | Evidence | 结论 | Finding |
|---|---|---|---|
| R9：以 `ACCEPTED_HEAD` 为 candidate，HEAD 一致、clean 且 task 5 不产生源码 delta。 | `task-5-report.md` 固定 accepted SHA；只读 `rev-parse HEAD` 同为该 SHA、porcelain 为 0 字节，`ACCEPTED_HEAD..HEAD` name-status 为空；提供的同 SHA review 包亦为空。 | ✅ | — |
| R9：repo 外 full-history `file://` clone 必须为真实 clone、HEAD 一致、历史非单提交、exact3/clean/diff-check 以及 contract/offline 通过。 | 报告明确记录 real `git clone file://...`、同一 HEAD、more-than-one reachable commit、clean、`git diff --check`、相对 `65d67b52...` 的 exact3，并给出 base 的 rc=0、stderr=0 B、stdout 精确值和 offline 的 rc=0/stderr=0 B/final-line 精确值。当前候选的 base 到 HEAD 也只读复核为这 exact3/371。 | ✅ | — |
| R9：repo 外真正 `git clone --depth 1 file://...` 必须 HEAD 一致、count=1 且 shallow marker 存在，并执行同一 contract/offline。 | 报告逐项记录 depth-1 的真实 file URL clone、同一 HEAD、`rev-list --count HEAD = 1`、`rev-parse --is-shallow-repository = true` 和非空 `.git/shallow`，及两项命令的精确 rc/双流/末行断言。depth checkout 故意没有 base object；报告正确以同 HEAD 的 full clone 而非伪造 shallow diff 证明 exact3。 | ✅ | — |
| R9：rollback 回归、隔离 converge、后续 05a/06–10 执行资产缺席。 | 这些均不属于 task 5 的步骤；brief 将 rollback/NEXT/converge 明确交给 task 6。task 5 没有把它们误报为完成，也没有新增任何源码或后续资产。 | ⚠️（task 6 后续验收） | — |
| R10：前置或验证失败不能被包装为 verifier PASS，且失败/成功路径不遗留受管状态。 | red evidence 记录 report 缺席时 `test -s` 的 rc=1、stdout/stderr 都为 0 B；报告没有把它当成功。报告说明 cloned tree 和 captured outputs 专属于 `/tmp/verifier-contract-task5.S7XCKN`，所有断言后显式删除。只读检查该路径当前不存在；候选 worktree 仍 clean，task 5 diff 为空。 | ✅ | — |

`⚠️` 仅标出仍由 task 6 负责的 R9 子验收，不是 task 5 finding，也不构成对
rollback 或最终收敛的提前批准。

## 质量

- **clone 真实性与断言：通过。** 报告不是笼统的“green”声明：它限定
  `file://` transport、两个 clone 类型、同 SHA、full history 条件，以及 shallow
  clone 的 count、repository shallow truth value 和 marker。它还保留 shallow 无法
  持有 base object 的正确理由，未将不可执行的 base diff 作为断言。
- **HEAD / count / shallow：通过。** 当前 repository 可独立确认 accepted HEAD
  和祖先关系（BASE 到 HEAD 为三 commits）；已清理的 checkout 的 count/shallow 是
  task report 的逐项执行证据。依据“不重跑报告已有证据”的审查限制，未重新建 clone。
- **清理：通过。** 报告给出受控、唯一的 repo 外临时目录和显式删除；该精确目录当前
  缺席。没有观察到候选 worktree 污染。
- **零 delta：通过。** 当前 accepted-head 自差、review package 均为空；源候选的
  BASE..HEAD exact3/371 也与既定 core 边界一致。`review-manifest` 与 ledger 是
  controller 独占状态（ledger 的 task-5 dispatch 已明确此责任），其第 5 行应只在本
  review PASS 后由 controller 追加，故当前缺席不是实现者的范围缺陷。

## Findings

- Blocking (B): 0
- Important (I): 0
- Minor (M): 0

## 审查后条件

本 PASS 允许 controller 写入 task 5 的 manifest/ledger 完成锚点并使
`verifier-checkout-v1` 可供 task 6 消费；它不替代 task 6 的 rollback、NEXT、
converge 或最终 R9/R10 验收。
