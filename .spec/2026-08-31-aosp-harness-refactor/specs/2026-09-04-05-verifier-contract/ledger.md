# ledger — spec: 2026-09-04-05-verifier-contract
# plan: .spec/2026-08-31-aosp-harness-refactor/PLAN.md v6.1
# worktree: 待门④后由 create-worktree.sh 创建

> 会话压缩之后，「我刚做完什么」的记忆不可靠。这份文件和 git log 才是。
> `任务 N: 完成` 是唯一的恢复锚点。

---

- 2026-09-04 requirements review round1 result=FAIL reviewer=review_05_requirements blocking=1 important=6 minor=1；发现05三入口矩阵与05/09 owner/400行边界冲突，以及stderr职责、crash早期记录、btime唯一性、六查询、判定语法和CLI优先级缺口。
- 裁定: PLAN v6.0先将05收窄为canonical provider/doc/test、09独占三旧入口；round2进一步证明既有common入口仍与09重叠，最终改为新增`common/.harness/bin/verify-sidebar.sh` physical provider，05回滚物理缺席、09自有fallback且永不改provider。若判断错误，代价是三入口漂移延至09闭合；若不改，代价是05/09同文件hunk和独立回滚失效。证据：`reviews/requirements-05-verifier-contract-round-{1,2}.md`。
- 2026-09-04 requirements review round2 result=FAIL reviewer=review_05_requirements blocking=2 important=2 minor=1；要求门③前runnable exact3/400硬门、完整五项grammar表、serial/help oracle与mandatory四路措辞。
- 2026-09-04 requirements review round3 result=PASS reviewer=review_05_requirements blocking=0 important=0 minor=0；PLAN physical provider/fallback、R1-R10、五项表、六查询、CLI、设计sizing门与四路验收全部闭合；check-plan/check-req/check-criteria/check-analyze/diff-check全0，结构化agent+human/autopilot review policy通过。
- 2026-09-04T23:59+08:00 自动通过: 门② — 依据：autopilot：requirements三轮原reviewer增量审查最终PASS B0/I0/M0；PLAN v6.0 physical provider边界、五项grammar/六查询、CLI、runnable exact3/400设计硬门与四路验收闭合，全部机械检查及agent+human policy通过
- 2026-09-05 design review round1 result=FAIL reviewer=review_05_design blocking=4 important=2 minor=0；B1暴露provider无法组合06逐query runtime，B2-B4暴露完整oracle/argv/cleanup/doc不足，I1-I2暴露bytes行首与whitespace grammar偏差。裁定：PLAN v6.1新增private runner seam，并按P5把05收窄为exact3 core、05a独占exact1穷举assurance；修订core prototype fixed-format 202+67+102=371/400且base test逐字PASS。
- 范围变化 profile 重评估已按规则尝试：`reassess-profile.py`以risk=normal、scope=cross-cutting、rollback=easy、criteria=clear、sensitive=no和`E-008`执行，因legacy research只有E00-E10章节、无可解析E-NNN EvidenceRecord而rc3 `悬空 evidence ID`；不伪造证据。当前profile继续balanced，且PLAN/requirements/design仍显式both review并将范围扩展交给全新reviewer。
- 2026-09-05 PLAN v6.1/requirements boundary review result=PASS reviewer=review_05_v61_boundary B0/I0/M0；审查中即时闭合fixed shfmt参数、doc scalar/terminal/runner-rc歧义、repo外temp realpath/普通目录/early-trap、05/06/07三者v2 readiness与rollback四态。最终prototype fixed-format 202+67+102=371/400，base、ShellCheck、shfmt、bash-n与全部requirements机械检查PASS；20节点/34直接边/顺序一致。结构化scope-change记录因legacy profile工具不支持而按上行留存失败事实，另以当前hash的`*-v61-final`兼容cycle完成agent+human autopilot review policy，不伪造profile assessment。
- 2026-09-05 design round2 fresh-scope review PASS B0/I0/M0；原reviewer round3增量复核为FAIL B0/I1/M0，仅指出单独help未挂runner spy证明零query。base已在help case注入self runner并核log为空，行数仍371/400，test hash更新后交原reviewer复核。
- 2026-09-05T00:56+08:00 自动通过: 门③ — 依据：autopilot：PLAN v6.1与requirements范围扩展fresh reviewer PASS；design fresh scope+原reviewer增量最终PASS B0/I0/M0；runnable fixed-format exact3 prototype 371/400，base/shfmt/ShellCheck/bash-n与机械检查全PASS
- 2026-09-05T01:03+08:00 自动通过: 门④ — 依据：autopilot：tasks round1 B2/I1已拆为六任务闭合，原reviewer round2 PASS B0/I0/M0；check-tasks/diff-check与R1-R10并集全绿
