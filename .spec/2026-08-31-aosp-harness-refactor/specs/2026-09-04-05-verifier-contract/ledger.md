# ledger — spec: 2026-09-04-05-verifier-contract
# plan: .spec/2026-08-31-aosp-harness-refactor/PLAN.md v6.0
# worktree: 待门④后由 create-worktree.sh 创建

> 会话压缩之后，「我刚做完什么」的记忆不可靠。这份文件和 git log 才是。
> `任务 N: 完成` 是唯一的恢复锚点。

---

- 2026-09-04 requirements review round1 result=FAIL reviewer=review_05_requirements blocking=1 important=6 minor=1；发现05三入口矩阵与05/09 owner/400行边界冲突，以及stderr职责、crash早期记录、btime唯一性、六查询、判定语法和CLI优先级缺口。
- 裁定: PLAN v6.0先将05收窄为canonical provider/doc/test、09独占三旧入口；round2进一步证明既有common入口仍与09重叠，最终改为新增`common/.harness/bin/verify-sidebar.sh` physical provider，05回滚物理缺席、09自有fallback且永不改provider。若判断错误，代价是三入口漂移延至09闭合；若不改，代价是05/09同文件hunk和独立回滚失效。证据：`reviews/requirements-05-verifier-contract-round-{1,2}.md`。
- 2026-09-04 requirements review round2 result=FAIL reviewer=review_05_requirements blocking=2 important=2 minor=1；要求门③前runnable exact3/400硬门、完整五项grammar表、serial/help oracle与mandatory四路措辞。
- 2026-09-04 requirements review round3 result=PASS reviewer=review_05_requirements blocking=0 important=0 minor=0；PLAN physical provider/fallback、R1-R10、五项表、六查询、CLI、设计sizing门与四路验收全部闭合；check-plan/check-req/check-criteria/check-analyze/diff-check全0，结构化agent+human/autopilot review policy通过。
- 2026-09-04T23:59+08:00 自动通过: 门② — 依据：autopilot：requirements三轮原reviewer增量审查最终PASS B0/I0/M0；PLAN v6.0 physical provider边界、五项grammar/六查询、CLI、runnable exact3/400设计硬门与四路验收闭合，全部机械检查及agent+human policy通过
