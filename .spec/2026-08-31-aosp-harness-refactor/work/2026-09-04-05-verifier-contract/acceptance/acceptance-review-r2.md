# 发布前第8条裁定增量审查 r2

结论：FAIL — B=0 / I=1 / M=0。

范围仅为新增的临时 source ledger 镜像及 `assume-unchanged` 发布裁定。
r1 已核实的产品候选、exact3/371、R1–R10和四路验收结论不变；本次失败针对
发布裁定的风险披露，不能把它理解为产品测试回归，也不能据r1跳过该新增风险。

## I1：未披露 clean 检查的实际例外及 main 已前进后的恢复失败状态

位置：ledger 最后一条 `裁定:`、acceptance-report 第③块第8条。

本裁定已逐字进入报告，解释了 source/controller ledger 位置不一致、临时修改
范围、恢复方式和保留 feature branch/worktree 的失败策略。但其“仍由原producer
核……clean”及“如果错了……producer会拒绝”的表述未完整反映两个实际后果：

- 设置 `assume-unchanged` 后，该路径的工作树变化会被 porcelain clean检查隐藏。
  该路径已成为显式的clean检查例外，producer并没有独立验证镜像ledger与已测
  accepted commit的关系。恢复后再清flag和核clean，只能证明后置状态，不能
  证明发布调用时的该文件clean。
- ordinary producer在返回前执行 `git merge --ff-only`。若producer已成功推进
  main，随后反向patch、清flag或clean核验失败，main仍可能已指向feature提交。
  保留feature worktree/branch只能保存恢复材料，不能等价于“拒绝发布”或
  “main未变”。当前风险段没有向用户披露这个已发布但恢复未完成的状态。

请明确记录这是对单一已知ledger路径的clean检测例外，及main可能先前进、
后恢复失败的状态和停止线。至少说明设flag前独立验证原ledger字节等于HEAD、
没有既有隐藏flag；说明成功、producer失败及中断时由谁恢复字节并清flag，
恢复失败时保持证据且不清理分支/worktree，不把保留分支误作main回滚。
本 reviewer 没有执行该机制，也未验证其恢复脚本；这不是对此例外机制的运行背书。

## 只读核对

```text
DECISIONS_MATCH 8
HEAD=9e5edb45a3048e4c208e2d7fe135639768cc87db
source ledger ls-files -v: H .spec/2026-08-31-aosp-harness-refactor/specs/2026-09-04-05-verifier-contract/ledger.md
source git status --porcelain=v1 -uall: empty
```

全部8条裁定全文匹配成功。当前source ledger尚无assume-unchanged标记，候选
HEAD和clean未变。仅修改本审查报告，未修改源码、规格、index或发布状态。

最终 findings：Blocking 0、Important 1、Minor 0。
