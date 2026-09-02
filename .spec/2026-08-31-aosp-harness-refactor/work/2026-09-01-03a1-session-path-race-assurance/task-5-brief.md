# 任务 5：闭合14项自反证与 candidate-HEAD 验收

这是本spec最后一个实现任务，不派subagent。实现worktree为`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a1-session-path-race-assurance`，只修改driver；证据/report写controller主仓本brief同目录。`TASK_BASE=f72aaefddd4fa6e06c6c156ff1f3df58b5f27ca9`，execution BASE仍为`c959efaf9887808621852aff28073cf1f8789ca7`。

完整依据是requirements/design/tasks任务5。当前driver已物理/numstat 400/400，必须在不删除或放松R1–R6任何stream/hook/signature/inventory/delta/path/log oracle的前提下，按round7最终400行蓝图重构等量空间，删除唯一`self-disproof incomplete`红缝并加入14项active self-disproof。超过400立即报告BLOCKED，不得压掉承重检查换行数。

## 红阶段

运行主self-test，必须在37 rows和全部既有oracle之后精确因`self-disproof incomplete`返回rc1、stdout 0B、无PASS；保存`task-5-red.log`。

## 14项active self-disproof

只在self-test分支依次真实破坏并要求对应oracle抛`AssertionError`，名称/顺序逐字为：

1. `protected signature`
2. `unexpected inventory`
3. `allowed changed paths`
4. `symlink readlink target`
5. `regular file hash`
6. `mode`
7. `inode`
8. `EEXIST second hook`
9. `marker count`
10. `sentinel`
11. `phase`
12. `made`
13. `catch`
14. `case invocation`

必须使用tasks步骤2给出的真实probe/callback，不得用统一假callback或仅比较名称列表。`must_reject`只捕获`AssertionError`；未抛、未知异常、缺项、重复或乱序均不得PASS。`run-matrix`不得执行这些反证。

## Green与主动mutation

主self-test必须rc0、stdout精确`RESULT PASS  session path race driver\n`（38B）、stderr0B；protocol仍0/28B/0B。合法1/2/37-row external matrix仍成功且仅执行输入rows。

运行tasks步骤3的14-copy隔离mutation harness：每个精确label在source的`must_reject`或`reject_field` call site只命中一次；逐份把该site替换为`must_reject(lambda: None, label)`，14份copy的self-test各必须rc1、stdout0B、无PASS；记录14/14结果与production driver/provider SHA不变。另保留Task2 path/log反例、Task3/4 oracle mutants和provider-hash-before-log ordering反证。

## 提交后 candidate HEAD 验收

运行Python3.8 grammar/compile、03 foundation、03a path、`bash ./scripts/check.sh --offline`、provider SHA、`git diff --check`、execution BASE exact只新增driver且numstat/物理行均`<=400`、03/03a零diff。提交消息固定`test(session): close race driver assurance`，确认worktree clean。

提交后以该candidate HEAD建立一个完整临时checkout和真实`git clone --depth 1 file://...` checkout；两处分别运行protocol、主self-test和offline gate，验证精确rc/双流，depth-1必须只有1 commit且不查询固定历史SHA。若任何门失败，在同一任务修复提交后对新HEAD重跑全部门。

写`task-5-report.md`，包括红证据、14/14 mutation、full/depth-1、回归、TASK_BASE/TASK_HEAD、task/cumulative numstat、driver物理行和clean状态；不要写manifest或ledger，controller在独立review最终PASS后处理。
