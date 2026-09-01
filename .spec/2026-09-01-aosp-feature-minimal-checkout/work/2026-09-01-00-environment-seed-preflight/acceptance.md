# 门⑤验收 — 2026-09-01-00-environment-seed-preflight

日期：2026-09-02

## ① 判据执行结果

```text
[self-test] rc=0
RESULT PASS environment-seed-preflight-supersession-self-test
[pre-commit-complete] rc=0
RESULT PASS environment-seed-preflight-supersession-pre-commit
[accept-main] rc=0
RESULT PASS environment-seed-preflight-supersession-acceptance
[structure] PASS branch=main merge=a79edb650066bf47d6908fe00ec22c0d6749ef14 parents=2 tasks=4 paths=6 common_delta=0 lines=744/800
[requirements] PASS owner_rows=27/27 R24=['current']
[summaries] PASS max_lines=41/160 details={'task-1-report.md': 41, 'task-2-report.md': 16, 'task-3-report.md': 32, 'task-4-report.md': 26}
[git-ops] PASS no MERGE_HEAD/REBASE_HEAD/rebase-merge/rebase-apply/CHERRY_PICK_HEAD
```

静态 checker：`check-plan.py`、`check-req.py`、`check-criteria.py`、`check-analyze.py`、`check-tasks.py` 串行运行，exit 0、stdout/stderr 为空。`sync-ledger.py` exit 0。

`check-converge.py` 以 repo root 直接运行时 exit 1：它无条件排除 `.spec/` diff，并把 design 同节中的 00a/00b 后继文件误报为本片欠账。保留该原始失败后，以当前 `tasks.md` 的临时 spec-root 相对投影、真实 base/head、真实 spec Git 子目录运行同一 checker：

```text
CHECK_CONVERGE PASS mode=spec-root-relative actual-base-head=true paths=6
```

独立结构 gate 同时证明 manifest 六路径与 `7b46dfb..a79edb6` 路径逐字相等，因此没有用投影掩盖文件缺口。

## ② 逐条对照 requirements 与不变量

- R1、R2、R3、R4、R6、R7、R9、R10、R11、R12、R13、R14、R15、R16、R17、R18、R19、R20、R26：manifest 唯一 owner 为 `00b`。
- R5、R8、R22：manifest 唯一 owner 为 `00a`。
- R21、R23、R25、R27：manifest owner 为 `00a`、`00b`，顺序与 closed schema 一致。
- R24：唯一 owner 为 `current`；本片已证明 PLAN v6 replacement、27/27 owner、预算、四任务链、two-parent merge、ledger、回滚和旧 harness 回归。
- 27 个 requirement id 与 manifest owner id 集合逐字相等；missing/duplicate/unknown/order/owner/budget/path mutation 均由公开 self-test fail closed。
- 当前 terminal 不实现 00a/00b runtime，因此 requirements 明文标注的 `pre-merge`、`source-unchanged`、`digest-immutability`、`offline-command-guard`、`failure-ref-rules` 是后继 migration criteria，本片禁止执行，未将 fixture 结果冒充 AOSP 真实证据。
- 当前不变量：`common/` 增量 0；无 AOSP source write/network/sync/download/build/package 命令；实现路径仅 6 个；744 ≤ 800；报告最大 41 ≤ 160；隔离 `git revert -m 1` 后三项旧 harness 回归 PASS。

## ③ 执行期裁定（按判断错误代价排序，原文）

1. 裁定: task3第三轮换fresh gpt-5.6-sol/high重构accept.py，在不削弱round1/2 finding下去重并以cumulative<=640为目标，为task4保留其160行估算下界；依据=fix_loop第3轮升档规则+R24硬上限；如果判断错了，代价是第三轮仍不收敛并必须回PLAN进一步拆分，但不会接受超800实现。
2. 裁定: 保留failed merge 052ecb9d与旧task branch，从task2创建隔离recovery branch，task3只修exact tracked/index path与untracked sibling/pycache分类，再原样replay task4并分别fresh review；不reset main、不覆盖其他spec dirty changes；如果判断错了，代价是recovery merge仍会被acceptance拒绝，但失败merge与旧tip均保留可审计和回退。
3. 裁定: main切换前保留failed merge安全分支，并仅在old/new tree差异与现有dirty路径不相交时使用git reset --keep；依据=隔离accept已PASS且--keep遇重叠会中止；如果判断错了，代价是main ref需要从安全分支恢复，但未提交用户内容仍由--keep保护。
4. 裁定: `check-converge.py`默认repo-root模式无条件过滤`.spec/`并把design文件清单中的00a/00b后继路径算成本片，原始调用exit1；门⑤用当前tasks的临时spec-root相对投影、真实base/head和同一checker重跑exit0，同时独立确认manifest六路径等于base..merge六路径。若判断错，代价是通用checker仍不能直接覆盖`.spec`内产品路径，后续同类terminal需修复skill而不能复用默认调用。
5. 裁定: execute报告/红证据/review统一使用skill强制的`.spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/`，不使用tasks旧版`spec/evidence`路径；实现尚未开始，补充process baseline后重建worktree。若判断错，代价是`check-task-report.py`找不到canonical report或ledger链接失效。
6. 裁定: process baseline的`git diff --check`排除`research/raw/**`，因为两份raw evidence保留Markdown hard-break与命令转录尾空白；其余process文件和后续六个implementation paths仍严格检查。若判断错，代价是raw evidence格式被误当产品源码质量问题；implementation whitespace仍由task gate覆盖。

## ④ 跳过的门禁

`STATE.md` 的 SKIPPED 表为空。本片没有跳过 G-VERIFY、独立 task diff review 或 acceptance。00a/00b migration criteria 尚未进入其执行阶段，不属于跳过。

## ⑤ 挂账 findings

- task 4：R-owner mutation 依赖当前列表位置；owners 排序重构时需同步更新负例。
- task 4：self-test failure 只报告 case name 与 actual tuple，定位 fixture 偏差时诊断偏简。
- task 4：`_pre_fixture()` 返回的 `base` 未消费，仅有维护噪音。
- recovery task 3：pycache fixture 用固定 pyc 名称文本模拟；真实 main acceptance 已覆盖当前解释器生成路径。

## ⑥ 结论

建议验收通过。R24-only terminal 的交付、预算、精确通道、Git 结构、ledger/artifacts、隔离回滚和旧 harness 回归均已在本轮真实运行通过；没有把 00a/00b 尚未实现的 AOSP 探针判据伪装成已完成。下一步进入 large-spec retro，选择并创建 `2026-09-01-00a-seed-contract-runtime`。
