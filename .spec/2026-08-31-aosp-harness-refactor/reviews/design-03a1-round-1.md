# 03a1 design review — round 1

Reviewer: `review_plan_v5_2`

Verdict: **NEEDS_CHANGES** — blocker 1 / important 1 / minor 0

1. R5的37-case完整对象oracle没有可实现allowed-delta数据结构，round4仅swap具完整签名/inventory；388/400只是未运行估算。必须定义九family delta表并让原型各跑一个完整代表case与self-disproof。
2. `CASE_ROW ||--|| HOOK_EXPECTATION`无法表达EEXIST的before_mkdir、after_eexist两个有序hook，需改一对多并含order/anchor/layer/name/phase/made/catch。

其余八节、接口、only-anchor、capability优先级、37算术、depth-1/manifest/03b顺序门无问题。
