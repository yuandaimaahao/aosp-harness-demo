# Task 1 scope-limited re-review — r2

## 复审范围

本轮仅复核 r1 finding 1 的任务归属；不重审 r1 已通过的 R1–R8、源码 diff 或质量项，也未重跑测试。当前没有源码修复 diff。

## 归属核对

- 控制器明确 task 1 的 `需求:` 仅为 R1–R8，负责 exact-one 源码机械交付与 active/absent 入口证据。
- `task-2-brief.md` 的任务段明确：task 2 消费 task 1 的 assurance，产出 `verifier-contract-assurance-checkouts-v1`，需求包含 R9；步骤 2–4 负责 candidate、完整历史 checkout、真实 depth-1 clone、offline、diff-check、converge/clean 等验收。因此 r1 所列 E9 属于 task 2。
- `task-3-brief.md` 的任务段明确：task 3 消费 task 2 的 checkout 产出，需求包含 R10；步骤 2–3 负责 rollback 零 diff、回归测试以及 06/09 资产缺席门禁。因此 r1 所列 E10 属于 task 3。
- task 2/3 均依赖 task 1 accepted HEAD；要求它们在 task 1 接受前完成会形成逆向依赖，不应作为 task 1 的阻断条件。

## Finding 1 处置

**已撤销。** E9/E10 对 task 1 应标记为 **⚠️ 外层串行 gate、非阻断**，而不是 task 1 缺证。它们仍是整个 05a 交付的必需验收项，但应分别在 task 2、task 3 的报告和独立 review 中闭合。

## 结论

**PASS — B/I/M = 0/0/0。**

r1 已确认通过的 task 1 范围 R1–R8 维持原结论；在控制器澄清的任务边界下，没有遗留的 task 1 finding，也无需修改源码。
