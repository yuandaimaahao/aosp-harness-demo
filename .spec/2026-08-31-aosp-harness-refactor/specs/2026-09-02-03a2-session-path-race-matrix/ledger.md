# ledger — spec: 2026-09-02-03a2-session-path-race-matrix
# plan: .spec/2026-08-31-aosp-harness-refactor/PLAN.md v5.6
# worktree: 待execute时创建

> 会话压缩之后，「我刚做完什么」的记忆不可靠。这份文件和 git log 才是。
> `任务 N: 完成` 是唯一的恢复锚点。

---

## Requirements

- 选片：03a1 accepted HEAD、五行全PASS manifest与merge `bf489b0`已先入ledger/main，满足03a2启动顺序；用户已授权autopilot。
- requirements round 1 NEEDS_CHANGES blocker=0 important=3 minor=1 reviewer=review_plan_v5_2：entrypoint/controller self-test职责歧义；固定shfmt/ShellCheck缺argv与文件集；未验03a2自身删除回滚；provider/driver SHA比较对象不明。
- round 1 rewrite：入口exact一次protocol+一次run-matrix且绝不self-test，fake argv log机械验证；controller独立跑self-test；固定工具版本/argv/唯一entrypoint；隔离删除entrypoint后driver/offline回滚；每checkout当前tracked dependency测试前后SHA不变。
- requirements round 2 PASS blocker=0 important=0 minor=0 reviewer=review_plan_v5_2；R1-R10、matrix/provider/driver/core优先级、37/37、inert/fail-closed、full/depth-1、exact1/400、manifest与03b顺序门闭合。
- 自动通过: 门②（autopilot）。依据：round2独立review PASS，check-req/check-criteria/check-analyze/check-plan/git diff-check全PASS，round7 109/400可执行原型支撑文件/行为边界。

## Design

- design round 1 NEEDS_CHANGES blocker=0 important=1 minor=1 reviewer=review_design_03a_r1：概述把全部损坏组合误写为递归自证；错误处理表未遵守五列模板。
- round 1 rewrite：生产入口仅对matrix duplicate建立provider缺席的递归child；其他provider/driver/core损坏由`.spec` controller隔离夹具验收，不引入skip seam；时序参与者与五列错误表同步修正。
- design round 2 PASS blocker=0 important=0 minor=0 reviewer=review_design_03a_r1；R1-R10映射、组件/数据/时序/错误/测试边界、原型137/400及固定工具命令无新冲突。
- 自动通过: 门③（autopilot）。依据：round2独立review PASS，check-req/check-criteria/check-analyze/check-plan/git diff-check全PASS，扩展可执行prototype已实跑dependency-present、inert/fail-closed、rollback与full/depth-1。

## Tasks

- tasks round 1 NEEDS_CHANGES blocker=0 important=3 minor=1 reviewer=review_plan_v5_2：三片缺可落地代码骨架；Task 2 driver零调用不可观测；accepted-HEAD/双流/manifest/03b顺序门仍只是prose；一处笔误。
- round 1 rewrite：每片加入无省略号Bash骨架，分别止于`dependency classifier incomplete`、`race adapter incomplete`与终态adapter；全部anchor夹具改为fake argv零调用证据；加入固定验收资产、双仓full/depth-1/rollback/manifest/顺序命令。
- tasks round 2 NEEDS_CHANGES blocker=1 important=2 minor=0 reviewer=review_plan_v5_2：`execution-base.env`无owner使最终门确定性不能运行；Task 1三种provider-absent调用说明错位；accepted clean未复验且否定Git查询会把异常假报为缺席。
- round 2 rewrite：BASE改为Task 1派发前由controller锁定并显式传入的40位commit；Task 1自身在同一provider-absent root验no-arg/all/flag；主implementation双重clean，rollback复核offline末摘要及两个03b文件；worktree/show-ref只接受查询成功后的精确缺席。
- tasks round 3 PASS blocker=0 important=0 minor=0 reviewer=review_plan_v5_2；R1-R10并集、三段唯一红因、exact1/400、三行manifest、full/depth-1/rollback与03b fail-closed门可机械执行，无新承重问题。
- 自动通过: 门④（autopilot）。依据：round3独立review PASS，check-tasks/check-req/check-criteria/check-analyze/check-plan/git diff-check全PASS，三任务严格串行且每次独立review可在10分钟内完成。
