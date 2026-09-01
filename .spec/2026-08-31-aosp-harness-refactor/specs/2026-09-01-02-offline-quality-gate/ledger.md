# ledger — spec: 2026-09-01-02-offline-quality-gate
# plan: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/PLAN.md v4
# worktree: 待执行阶段创建

> 会话压缩之后，「我刚做完什么」的记忆不可靠。这份文件和 git log 才是。
> `任务 N: 完成` 是唯一的恢复锚点。

---

## 需求阶段

- 00:41 select：按 PLAN 依赖与复盘结论选择 02-offline-quality-gate；workflow=requirements-first，mode=autopilot。
- 00:49 requirements draft：R1-R8 覆盖 offline/CI 分流、字典序自动发现、固定版本工具、增量静态 baseline、CI、coverage 矩阵与离线 contract 回归；问题预算 0/15。
- 00:49 裁定: 当前 30 个受管 Shell 入口在 ShellCheck 0.11.0 下产生 836 行诊断、在 shfmt 3.14.0 下产生 1835 行 diff；采用精确 `path + Git blob` baseline，只豁免未变化历史内容，新/变化脚本强制过工具。若判断错误，代价是历史静态债务不会在本片一次清零；若不做，8 文件/400 行硬预算内无法得到绿色 CI，且会越权修改后续 spec 的文件。
- 00:51 requirements review-dispatch round=1 model=gpt-5.6-sol reviewer=fresh-context report=.spec/2026-08-31-aosp-harness-refactor/reviews/requirements-02-round-1.md
- 01:05 requirements review round=1 NEEDS_CHANGES findings=1/7/2 issues=offline-dependencies+managed-set+baseline-authorization+gitleaks-semantics+missing-negative-criteria+source-labels+budget-placeholder+shfmt-evidence
- 01:12 requirements rewrite round=1：补齐 Python3/rg 等 offline 必需依赖；定义工作树受管集合、C locale 和 syntax 负向；baseline 锚定 main 快照并固定摘要/拒绝扩增；固定静态/Gitleaks argv 与错误码；补 CLI/CI/COVERAGE 判据；纠正来源并删除伪预算命令/伪精确 shfmt 数字。
- 01:14 requirements re-review-dispatch round=2 model=gpt-5.6-sol reviewer=fresh-context report=.spec/2026-08-31-aosp-harness-refactor/reviews/requirements-02-round-2.md
- 01:32 requirements review round=2 NEEDS_CHANGES findings=1/4/1 issues=gitleaks-empty-config+preflight-order+baseline-canonical-input+source-decisions+line-budget
- 01:39 requirements rewrite round=2：固定 Gitleaks default config 内容/摘要并增加真实 canary 自检；CLI/10依赖/6工具 case 均证明 syntax/test 零调用；baseline 锁 30 行 canonical 集合与摘要；默认来源/DECISIONS/资产名补齐；给 6 文件逐项行预算，总计 387/400。
- 01:41 requirements re-review-dispatch round=3 model=gpt-5.6-sol reviewer=fresh-context report=.spec/2026-08-31-aosp-harness-refactor/reviews/requirements-02-round-3.md
- 01:52 requirements review round=3 PASS findings=0/0/1；round2 的 1阻断/4重要/1次要全部闭合。
- 01:52 挂账 M1：design 必须明确 canary 与工作树扫描仅 target 不同、固定 flags/config 完全相同；canary 位于仓库外 `mktemp` 目录并由 trap 清理后再扫描工作树。
- 01:52 门②（autopilot）自动通过。依据：三轮全新上下文 requirements review 已完成，最终 0 阻断/0 重要；R1-R9、三条不变量、canonical baseline/config 摘要与 6 文件/387 行预算闭合；`check-req.py`、`check-criteria.py`、`check-analyze.py` 全部退出 0；用户已授权后续按 autopilot。

## 设计阶段

- 01:56 design draft：八节与 6 文件清单完成；offline/CI 分层、NUL+C-locale 发现、immutable baseline、仓库外 canary 清理时序、nested contract 与 387 行预算已锁定。
- 01:56 design review-dispatch round=1 model=gpt-5.6-sol reviewer=fresh-context report=.spec/2026-08-31-aosp-harness-refactor/reviews/design-02-round-1.md
- 02:11 design review round=1 NEEDS_CHANGES findings=0/2/2 issues=config-error-order+workflow-PATH+discovery-edge-oracle+canary-bytes
- 02:15 design rewrite round=1：拆开 baseline/config 错误时序；固定 RUNNER_TEMP/bin、GITHUB_PATH 跨 step 与三种 artifact 解包/安装映射；补空格/LF/symlink/locale oracle；canary 固定为运行时拼接 `AKIA` + 16 字符片段。
- 02:16 design re-review-dispatch round=2 model=gpt-5.6-sol reviewer=fresh-context report=.spec/2026-08-31-aosp-harness-refactor/reviews/design-02-round-2.md
- 02:27 design review round=2 PASS findings=0/0/0；round1 的 2 重要/2 次要全部闭合，八节、R1-R9 映射、接口签名、三张 Mermaid 与 6 文件/387 行预算均通过独立复审。
- 02:28 门③（autopilot）自动通过。依据：用户已授权后续按 autopilot；全新上下文 design reviewer 最终规格符合性与质量均 PASS，0 阻断/0 重要/0 次要；requirements 三项机械检查、design 九节结构/R1-R9 映射与 `git diff --check` 全部退出 0。

## 任务阶段

- 02:41 tasks draft：拆为 6 个必需 vertical slices；每片都有红绿命令，按 CLI/core/CI preflight/baseline/static/Gitleaks/workflow+coverage 逐级接线，R1-R9 并集完整且总预算保持 6 文件/387 行。
- 02:41 tasks self-check：`check-tasks.py` 与 `git diff --check` 均退出 0；编号最多两级、五字段、失败确认、需求全集、签名消费和无孤儿产出机械检查通过。
- 02:41 tasks review-dispatch round=1 model=inherit reviewer=fresh-context report=.spec/2026-08-31-aosp-harness-refactor/reviews/tasks-02-round-1.md
- 02:51 tasks review round=1 NEEDS_CHANGES findings=1/2/0 issues=untracked-budget-false-green+missing-bash-host-launch+managed-set-observability
- 02:56 tasks rewrite round=1：最终门改为六文件逐项 `wc -l` + 总和、全文件 no-index whitespace 与 base/HEAD/working/untracked 的 NUL 精确集合；缺 bash case 固定绝对 host Bash 启动；fake Bash 逐个 NUL 记录 `-n` 并断言特殊路径纳入、symlink/.git/.spec 排除及 syntax-before-tests。
- 02:56 tasks re-review-dispatch round=2 model=inherit reviewer=fresh-context report=.spec/2026-08-31-aosp-harness-refactor/reviews/tasks-02-round-2.md
- 03:09 tasks review round=2 NEEDS_CHANGES findings=1/2/0 issues=range-gate-misses-index-and-spec-baseline+nested-protocol-not-activated+code-steps-without-blocks；round1 三项均闭合。
- 03:22 tasks rewrite round=2：范围门补齐 committed/index/working/untracked 四路、排除 `.spec/`、备用 index 暂存第七文件负测；正常 gate 对 child root test 显式设置 `QUALITY_GATE_NESTED=1`，contract 以 30 秒有界普通入口证明仅一次 child；六任务的测试/实现步骤均加入可直接落地的精确代码块。
- 03:22 tasks re-review-dispatch round=3 model=inherit reviewer=fresh-context report=.spec/2026-08-31-aosp-harness-refactor/reviews/tasks-02-round-3.md
- 03:35 tasks review round=3 NEEDS_CHANGES findings=0/3/1 issues=mode-and-nul-argv-block+repo-root-cwd+workflow-coverage-oracle+canary-tmpdir；round2 三项均闭合，四路 scope、备用 index 负测、防递归与预算已确认通过；达到 `fix_loop_max=3`，进入熔断裁定，不再追加 review 轮次。
- 03:42 熔断裁定 I1（承重）：采纳 reviewer 解法，在 parser 块落 `mode="$1"`，固定 argv oracle 改为 Python 逐字节解析 NUL 数组并逐索引比较。若判断错误，代价是 CI mode 未定义或静态参数 contract 永久假红，任务 1.3/1.4 无法完成。
- 03:42 熔断裁定 I2（承重）：采纳 reviewer 解法，在求得 `repo_root` 后立即 `cd`，新增从无关 cwd 调用且 caller poison 零执行的 oracle。若判断错误，代价是 gate 可能扫描/执行调用方目录而不是仓库，破坏 R1/R3 并带来非预期脚本执行。
- 03:42 熔断裁定 I3（承重）：采纳 reviewer 解法，加入 29 行表驱动 Python 结构 oracle，逐映射核对 URL/摘要/解包源/安装目标/顺序与独立 quality step，并把 coverage 解析为严格五字段 active path 集合；Gitleaks test 累计压到 169 行，为该 oracle 保留 31 行且最终仍为 200。若判断错误，代价是 workflow 或 coverage 可假绿，或实现时触发 200 行硬门而必须回 PLAN 拆片。
- 03:42 熔断裁定 M1（非承重但即时修复）：canonicalize `mktemp` 目录并拒绝 `repo_root` 前缀，增加 repo 内 TMPDIR 返回 2/Gitleaks 零调用负测。若判断错误，代价是在非常规 TMPDIR 下 canary 落入工作树并污染最终秘密扫描。
- 03:42 tasks post-fuse self-check：`check-tasks.py`、`git diff --check`、占位符扫描均退出 0；6 个任务、R1-R9 并集、线性签名、31 行 docs oracle 与 169+31=200 test 预算已人工复核。
- 03:42 门④（autopilot）自动通过。依据：用户授权后续 autopilot；三轮全新上下文 tasks review 已执行到 `fix_loop_max=3`，前两轮 findings 全闭合，第三轮 3 重要/1 次要逐条按熔断规则给出解法与判断错误代价并已落盘；机械检查全绿，六任务保持 6 文件/387 行硬门。门④不存在新的用户选择。

## 执行阶段

- 03:45 execution-base：main 先提交规格证据 `8145561504cfe1270fde2eef9271cf35d1d54d20`；创建隔离 worktree `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-02-offline-quality-gate`，branch=`spec/2026-09-01-02-offline-quality-gate`，BASE=`8145561504cfe1270fde2eef9271cf35d1d54d20`。
- 03:47 task 1.1 dispatch model=gpt-5.6-terra/high base=8145561504cfe1270fde2eef9271cf35d1d54d20 brief=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/task-1.1-brief.md implement-worktree=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-02-offline-quality-gate
- 03:55 task 1.1 report=NEEDS_CONTEXT commits=[] tests=contract/offline/syntax/whitespace/report-pass diff=tests:20,scripts:16 blocker=Transsion commit hook requires real AR or open JIRA BUG ID；源码已暂存于隔离 worktree，未绕过 hook、未编造 ID。
- 09:18 用户裁定：该仓库是个人项目，不适用公司 Transsion 五段式提交规范；后续任务统一使用普通 Conventional Commit。若判断错误，代价是提交信息不会满足公司服务端 hook，但本仓库不向公司 Gerrit 推送且用户已明确排除该约束。
- 09:18 task 1.1 resume-context：补充提交规范上下文，唤回原实现者完成普通提交与 DONE 报告；不重做已通过的红绿实现。
- 09:20 task 1.1 report=DONE commits=[5aa1a26bb7301f680b40fe7176a00e957181c99b] tests=contract/offline/syntax/whitespace/report-pass concerns=none
- 09:20 task 1.1 review-dispatch round=1 reviewer=gpt-5.6-terra/high package=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/review-81455615-5aa1a26b.md
- 09:24 task 1.1 review round=1 NEEDS_CHANGES findings=0/2/0 warnings=2 issues=marker-oracle-not-observable+nested-branch-missing
- 09:24 task 1.1 fix-dispatch round=1 implementer=original model=gpt-5.6-terra/high base=5aa1a26bb7301f680b40fe7176a00e957181c99b scope=review-I1-I2
- 09:28 task 1.1 fix-report round=1 DONE commit=6b6f749242b4c52280bc38d620c1c4a0476ab58d tests=contract/offline/syntax/whitespace/report-pass concerns=none
- 09:28 task 1.1 re-review-dispatch round=2 reviewer=gpt-5.6-terra/high package=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/review-5aa1a26b-6b6f7492.md scope=fix-diff
- 09:31 task 1.1 review round=2 PASS findings=0/0/0 warnings=0；I1 marker oracle 与 I2 nested 分支闭合，无越权或回归。
- 任务 1.1: 完成
- 09:32 task 1.2 dispatch model=gpt-5.6-terra/high base=6b6f749242b4c52280bc38d620c1c4a0476ab58d brief=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/task-1.2-brief.md implement-worktree=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-02-offline-quality-gate
- 09:43 task 1.2 report=DONE commit=7c0d1b12b4bd06f3dcd60dfa4b8bdb7cfe7d2f88 tests=contract+real-offline-pass concerns=none
- 09:43 task 1.2 review-dispatch round=1 reviewer=gpt-5.6-terra/high package=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/review-6b6f7492-7c0d1b12.md
- 09:47 task 1.2 review round=1 NEEDS_CHANGES findings=0/2/0 warnings=0 issues=syntax-before-first-root-not-observed+unrelated-cwd-oracle-missing
- 09:47 task 1.2 fix-dispatch round=1 implementer=original model=gpt-5.6-terra/high base=7c0d1b12b4bd06f3dcd60dfa4b8bdb7cfe7d2f88 scope=review-I1-I2
- 09:51 task 1.2 fix-report round=1 DONE commit=c7ef909b259e8044fbc48d3750192003da36b2cb tests=contract/offline/syntax/whitespace/budget/report-pass concerns=none
- 09:51 task 1.2 re-review-dispatch round=2 reviewer=gpt-5.6-terra/high package=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/review-7c0d1b12-c7ef909b.md scope=fix-diff
- 09:54 task 1.2 review round=2 PASS findings=0/0/0 warnings=0；shared NUL event 时序与 unrelated cwd poison 均闭合。
- 任务 1.2: 完成
- 09:54 task 1.3 dispatch model=gpt-5.6-terra/high base=c7ef909b259e8044fbc48d3750192003da36b2cb brief=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/task-1.3-brief.md implement-worktree=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-02-offline-quality-gate
- 10:04 task 1.3 report=DONE commit=b814ecfbb9eec8a4aa874734f7eb278f3a12faa6 tests=ci-six-preflight/offline/syntax/whitespace/report-pass concerns=none
- 10:04 task 1.3 review-dispatch round=1 reviewer=gpt-5.6-terra/high package=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/review-c7ef909b-b814ecfb.md
- 10:07 task 1.3 review round=1 NEEDS_CHANGES findings=0/1/0 warnings=1 issue=all-correct-ci-tools-positive-path-missing
- 10:07 task 1.3 fix-dispatch round=1 implementer=original model=gpt-5.6-terra/high base=b814ecfbb9eec8a4aa874734f7eb278f3a12faa6 scope=review-I1
- 10:10 task 1.3 fix-report round=1 DONE commit=d3de28378dbac7c2582e025e74eaaa1a31378ada tests=ci-positive/full-contract/offline/syntax/whitespace/budget/report-pass concerns=none
- 10:10 task 1.3 re-review-dispatch round=2 reviewer=gpt-5.6-terra/high package=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/review-b814ecfb-d3de2837.md scope=fix-diff
- 10:13 task 1.3 review round=2 PASS findings=0/0/0 warnings=0；正确三工具组合穿透 preflight 的正向证据闭合。
- 任务 1.3: 完成
- 10:14 task 1.4 dispatch model=gpt-5.6-sol/high base=d3de28378dbac7c2582e025e74eaaa1a31378ada brief=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/task-1.4-brief.md implement-worktree=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-02-offline-quality-gate
- 10:26 task 1.4 report=DONE commit=d497a87dfcfa793f8856f00a20859cfbb7414b62 tests=contract/offline/canonical-sha/syntax/whitespace/budget-pass concerns=none
- 10:26 task 1.4 review-dispatch round=1 reviewer=gpt-5.6-sol/high package=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/review-d3de2837-d497a87d.md
- 10:31 task 1.4 review round=1 NEEDS_CHANGES findings=0/3/1 warnings=1 issues=static-lf-nul-uncovered+static-failfast-secret-unobserved+non-anchor-duplicates-append+failure-locality；warning=reviewer 未读取指定绝对 07-review 路径，控制器已按已加载规则核对，未产生额外 finding。
- 10:31 task 1.4 fix-dispatch round=1 implementer=original model=gpt-5.6-sol/high base=d497a87dfcfa793f8856f00a20859cfbb7414b62 scope=review-I1-I3-M1
- 10:42 task 1.4 fix-report round=1 DONE commit=9be78e07d4e3a722a9c034423cc1ce6372a1e52e tests=contract/offline/baseline-sha/syntax/whitespace/35-15-30-budget-pass concerns=none
- 10:42 task 1.4 re-review-dispatch round=2 reviewer=gpt-5.6-sol/high package=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/review-d497a87d-9be78e07.md scope=fix-diff
- 10:48 task 1.4 review round=2 PASS findings=0/0/1 warnings=0；round1 I1/I2/I3/M1 全闭合；挂账 minor=contract baseline validator 与生产 awk predicate 相似，验收回看同错同绿风险。
- 任务 1.4: 完成
- 10:48 task 1.5 dispatch model=gpt-5.6-sol/high base=9be78e07d4e3a722a9c034423cc1ce6372a1e52e brief=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/task-1.5-brief.md implement-worktree=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-02-offline-quality-gate
- 11:00 task 1.5 report=DONE commit=5f31ceb29d1be97323035a4b3a9176e6d2d3649c tests=contract/offline/config-sha/syntax/whitespace/budget/report-pass concerns=none
- 11:00 task 1.5 review-dispatch round=1 reviewer=gpt-5.6-sol/high package=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/review-9be78e07-5f31ceb2.md
- 11:05 task 1.5 review round=1 NEEDS_CHANGES findings=0/3/0 warnings=1 issues=env-unset-oracle-unpoisoned+errexit-canary-write-cleanup-unsafe+failure-total-pass-unchecked；warning=full canary token tracked-tree absence 需跨任务证据闭合。
- 11:05 task 1.5 fix-dispatch round=1 implementer=original model=gpt-5.6-sol/xhigh base=5f31ceb29d1be97323035a4b3a9176e6d2d3649c scope=review-I1-I3
- 11:16 task 1.5 fix-report round=1 DONE commit=7b9a0bb9892792593144da2284b4bb763a16721a tests=full-contract/offline/SHA/syntax/whitespace/budget/canary-zero-match/report-pass concerns=none
- 11:16 task 1.5 re-review-dispatch round=2 reviewer=gpt-5.6-sol/high package=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/review-5f31ceb2-7b9a0bb9.md scope=fix-diff
- 11:20 task 1.5 review round=2 PASS findings=0/0/0 warnings=0；I1/I2/I3 与 full-token zero-match 均闭合。
- 任务 1.5: 完成
- 11:20 task 2.1 dispatch model=gpt-5.6-sol/high base=7b9a0bb9892792593144da2284b4bb763a16721a brief=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/task-2.1-brief.md implement-worktree=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-02-offline-quality-gate
- 11:25 task 2.1 report=DONE commit=7b09181ccaf6f731fcec6a9fe048e0899ac46baa tests=contract/offline/syntax/whitespace/six-file-scope/283-of-387/alternate-index-pass concerns=none
- 11:25 task 2.1 review-dispatch round=1 reviewer=gpt-5.6-sol/high package=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/review-7b9a0bb9-7b09181c.md
- 11:29 task 2.1 review round=1 NEEDS_CHANGES findings=0/2/0 warnings=2 issues=workflow-global-string-oracle-false-green+coverage-indent-and-number-order-escape；warnings=six-file-scope/283-budget/public-lines 由实现报告支持，待 re-review/acceptance 闭合。
- 11:29 task 2.1 fix-dispatch round=1 implementer=original model=gpt-5.6-sol/high base=7b09181ccaf6f731fcec6a9fe048e0899ac46baa scope=review-I1-I2
- 11:34 task 2.1 fix-report round=1 DONE commit=83eac79c013cd50216b8638005105fb98bcd2977 tests=contract/offline/public-lines/syntax/whitespace/six-files-289-of-387/four-scope/alternate-index/report-pass concerns=none
- 11:34 task 2.1 re-review-dispatch round=2 reviewer=gpt-5.6-sol/high package=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/review-7b09181c-83eac79c.md scope=fix-diff
- 11:38 task 2.1 review round=2 PASS findings=0/0/0 warnings=2；I1/I2 闭合；四路 scope 与六文件/caps/公开末行的 diff-不可判项已由 fix report 和红阶段日志闭合。
- 任务 2.1: 完成
- 11:38 execution-complete：任务 1.1-1.5、2.1 均有实现报告、红阶段证据、提交与全新上下文独立 diff review；所有重要 finding 已修复并通过 re-review，挂账仅 task1.4 baseline validator 近似生产 predicate 的 minor，留验收裁定。

## 验收阶段

- 11:45 acceptance：本轮重新执行 `scripts/check.sh --offline`、quality contract、device-safety 均 exit 0 且末行精确；BASE..HEAD 恰好六文件、行数 `73/30/2/26/4/154` 总 `289/387`；baseline/config SHA 精确；canary tracked-tree 零匹配；CURRENT_FEATURE diff 零；`check-converge.py` 与全部 spec mechanics exit 0。证据=`work/2026-09-01-02-offline-quality-gate/acceptance-report.md`。
- 11:45 挂账 minor 裁定：不为 task1.4 baseline validator 与生产 predicate 相似追加修复；固定 canonical SHA 是独立字节 oracle，六类 mutation 真实失败。若判断错误，代价是两侧同错时可能放过格式回归；baseline 变更仍需重走 PLAN/DECISIONS。
- 11:45 门⑤（autopilot）自动通过。依据：R1-R9、三条不变量、公开末行、六文件范围、单项/总预算、摘要、收敛检查均在本轮重跑通过；无阻断/重要 finding，唯一 minor 已显式裁定并记录错误代价。
- 11:47 merge：source branch `spec/2026-09-01-02-offline-quality-gate` 已 fast-forward 合入 main，source HEAD=`83eac79c013cd50216b8638005105fb98bcd2977`。
- 11:48 archive：本 spec 的 `work/2026-09-01-02-offline-quality-gate/` 已单独提交为 `b33b67096c84cdf23687c45bf3c36b0831d5f705`；`git show --name-only` 核对未包含该路径之外文件。

## 复盘

- 11:51 五问均否：02 未推翻后续前提；未暴露 PLAN 外工作；03-10 仍满足既有 P1-P5；依赖顺序无需调整；没有当前上下文无法回答的新问题。task1.4 minor 由固定摘要与 mutation 覆盖，不新增独立 spec；下一片仍为 `03-session-state-safety`。
