# Review: tasks 03d-session-remove-prune round 1
verdict: NEEDS_CHANGES
阻断: 1 / 重要: 2 / 次要: 1

## findings

- [B1] 任务 1.3 步骤 6 (ii)（tasks.md:113）换入注入代码块 `os.rename(name, name + ".held", dir_fd=parent_fd, dst_dir_fd=parent_fd)` 无法运行。依据：Python `os.rename` 只接受 `src_dir_fd`/`dst_dir_fd` 两个关键字，无 `dir_fd` 参数；我在 `mktemp` 内实测 `os.rename("a","a.held",dir_fd=fd,dst_dir_fd=fd)` 确定性抛 `TypeError: 'dir_fd' is an invalid keyword argument for rename()`。该 TypeError 不被生产模块的 `UnsafeState`/`OSError` 捕获链接住，正确模块 + (ii) 注入会产生 traceback 而非预期的 rc2 + `error: unsafe session state\n`——oracle 在正确实现上假红；mutant (a) 叠加 (ii) 的注入同样失效。步骤 6 的「按候选实际命名对齐」只豁免变量名，不豁免非法关键字。建议修法：改为 `os.rename(name, name + ".held", src_dir_fd=parent_fd, dst_dir_fd=parent_fd)`（(iii) 的 `os.mkdir(..., dir_fd=parent_fd)` 合法，无需改）。
- [I1] 裁定 4（tasks.md:38）明文承诺「仍以 `! rg -q 'setsid'` 对三个 shell 交付文件负向断言防回归」，但任务 1.3（步骤 2/4）从未对 `tests/test-session-state.sh` 执行该断言——只有任务 1.1 步骤 2（remove）与 1.2 步骤 2（aggregator）落实。本片测试无 process-group 行（裁定 4 理由成立），恰因如此该负向断言才有意义且不能缺第三环。建议修法：任务 1.3 步骤 2 或步骤 4 增加 `! rg -q 'setsid' tests/test-session-state.sh`。
- [I2] 任务 1.1 步骤 5 / 1.2 步骤 6 / 1.3 步骤 8 的提交流程照抄 03c 的 `git add -N <file>` 后直接 `git commit`。依据：我在 /tmp 临时仓库实测，`git add -N` 只登记 intent-to-add，`git commit` 拒绝执行（"no changes added to commit"，无提交产生，HEAD 不动）；且 03c `task-1.1-report.md:35` 明确记录「`git add -N` 仅登记 intent-to-add，`git commit` 不会收录该文件（首次提交尝试实测被 git 拒绝）……改为先 `git add` 再 `git commit`」——这是 03c 已付过成本的执行期教训，03d tasks 自述吸收了 03c 执行期教训（报告契约、4 参签名都已修订），却原样保留了这一已知必失败的命令序列。建议修法：working-tree 断言保留 `git add -N`，在 `git commit` 前补 `git add <交付文件>`（或按 03c 报告口径显式注明该偏离）。
- [M1] 任务 1.3 步骤 6 (iii)（tasks.md:117）oracle 写「前后完整 namespace inventory 逐字比较仅差被删的 session 目录且 `concurrent` 目录保留」。依据：design 测试策略节只承诺「只差被删空目录」；该行 feature 若存在则也被 unlink，inventory 若覆盖文件则 diff 不止 session 目录。建议修法：明确 inventory 口径为目录集合，或改写为「仅差被删 feature 与被删的 session 目录」，与任务 1.3 候选结构段的「前后完整 namespace inventory 逐字比较」对齐。

## 核对记录

- **需求并集**：逐任务核对——1.1(R1-R4) + 1.2(R5-R7) + 1.3(R1-R9) + 2.1/2.2/2.3(R10) + 2.4/2.5(R11) + 2.6(R10,R11)，并集恰为 R1–R11，无漏无扩；1.1 挂 R3/R4 但由 1.3 封闭行为矩阵（候选结构段已声明），映射合理。
- **孤儿产出/签名链**：session-remove-core-runtime-v1(1.1→1.2) → session-state-aggregator-runtime-v1(1.2→1.3) → session-state-matrix-v1(1.3→2.1) → provider-accepted-head-v1(2.1→2.2) → provider-full-checkout-v1(2.2→2.3) → provider-depth1-checkout-v1(2.3→2.4) → provider-rollback-v1(2.4→2.5) → provider-order-gate-v1(2.5→2.6)，逐环「消费」在更早任务「产出」逐字找到；2.6 产出 `tests/test-session-state.sh` 在 requirements 验收标准节「主验证命令」行逐字出现（裁定 5 依据成立）。`check-tasks.py` 亲跑 rc=0，`git diff --check` 干净。
- **裁定 2**：03 系列摘要字面亲核——`tests/test-session-state-foundation.sh:274` 为 `RESULT PASS  session state foundation`，故 offline 计数 `rg -c 'RESULT PASS  session state$'` 的 `$` 行尾锚必要且正确（无锚会把 foundation 行算入，=1 断言假红；2.4 负向断言同理避免假命中）；不破坏其它入口计数（snapshot/signals/races 摘要均不含 "session state" 前缀）。printf 字面量恰 2 处、rindex/index 双探针、`${checks:-0}` 防 unbound 均与 03c 裁定 2 同构正确。
- **裁定 3**：双 mutant 确定性论证成立（(a) 直接 rmdir + 换入 → 新旧目录保留 oracle FAIL；(b) ENOENT 分支直接返回 → 空层级残留 oracle FAIL）；mktemp 内整棵 lib 树 provider 副本注入机制可行，tasks 内无 `SIGNALS_MODULE` 式 env override 残留（仅裁定 3 解释性提及）；不另设 aggregator mutant 的替代（1.2 步骤 3 python 文本顺序核对 `last_check < first_def < marker && last_def < marker`）确实能抓住「边 source 边定义」类 mutant（任何 source 循环中的提前定义会使 last_check < first_def 不成立）。
- **裁定 4**：与 design 分层节（不引入 mktemp/rm/setsid）、round2 错误表（无 129|130|143 for remove）一致；唯落实缺第三文件，见 I1。
- **裁定 6/7**：scoped rg 域（ledger/dispatch/execution-base）、NEXT 全名禁令豁免 spec 文档、inert 不解除顺序门均与 03c 裁定 6/7 及 R11 逐字同构；亲核 03c ledger 先例（只写「03d 顺序门」）且当前 `$PROJECT/specs/*/ledger.md`+dispatch+execution-base.env 对 `03e-claude-session-lifecycle` 零命中，门初态可满足。
- **任务 2.5**：NEXT=`03e-claude-session-lifecycle` 与 PLAN:54 spec 表行一致；五类资产机械核对命令（nullglob off、`ls -d` rc2 判缺席、show-ref/worktree list、scoped rg）与 03c 任务 2.5 同构。
- **模块源码先例**：path:94 `pass  # HARNESS_TEST_MARKER_OS_ERROR` 与 snapshot:158-159 `def os_checkpoint(): pass  # ...` anchor 先例属实，EIO anchor 命名同字面；9 个预期 export 名单与 foundation/path/snapshot/signals 真实函数表逐一核对相符；signals 模块为早返回 guard + 顶层函数定义写法，任务 1.1 步骤 2 的 `^[a-z_0-9]+\(\)` 唯一函数门与之兼容。
- **M2 落实**：任务 1.3 候选结构段 + 步骤 2「创建后立即核行数、fixture 循环与注入区段实际行数入 green 报告、超 205/400 停手上报回 PLAN 拆片、禁止压缩 oracle」正面落实门③ M2。
- **门②/门③ findings 遵守**：aggregator-absent fixture 不断言双流空（1.3 候选段与 requirements 清单第 5 条一致）；rollback 只删恰四文件后跑 03b/03b1/03c/offline（摘要字面与真实测试逐字相符）。
- **工具用法**：`task-brief.py` 任务号 `1.1`（不带 `task-` 前缀）与 `_tasks.py` 的 id 解析（`### 任务 1.1:` → id `1.1`，精确匹配）一致；`review-package.sh` 真实签名 4 参 `<BASE> <HEAD> <work> <spec-id>` 与 tasks 写法一致（03c 的 2 参确为笔误）；TOOLS pin 路径存在，`shfmt v3.14.0`/`shellcheck version: 0.11.0` 实测通过，版本门可执行。
- **粒度/步骤可执行性**：组1 三任务拆分理由（两个独立生产模块各有独立 source 契约与静态门、fragment 无独立验证面并入 1.3）成立；每任务有命令判成败、可独立回滚。「按候选实际命名对齐」判定不构成占位符（注入机制由 anchor + design 数据流节变量名完全决定，实现者即候选作者）；任务 1.3 步骤 7 的 `$tmp` 未在本步显式赋值，系 03c 同款既有风格（03c round2 已作范围外观察备案），不另立 finding。
- **UPSTREAM9/EXACT4**：九上游文件逐一核对物理存在且与 DECISIONS 2026-09-02 03b1 上游集合裁定（六件 + 03b1 assurance + 03c signals/测试累加）一致；sizing 110+50+205+25=390 ≤ 400 保留 10 行余量与 design 一致。
