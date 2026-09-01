# 03a1 requirements review — round 1

Reviewer: `review_plan_v5_2`

Verdict: **NEEDS_CHANGES** — blocker 2 / important 2 / minor 0

1. provider存在但foundation/core不可用时缺inert分支，违反03回滚后的offline绿色要求。
2. “所有注入都命中layer/phase/name/made”与layer-independent OS_ERROR冲突，且269行原型使用若干非anchor needle，未证明only-anchor约束可实施。
3. 完整对象签名漏写symlink `readlink` target。
4. 03b consumer前置只有散文，没有controller/ledger顺序门。

37-case算术与rc映射、19-case原型、provider文件缺席、depth-1、单文件400行和机械检查无其他问题。
