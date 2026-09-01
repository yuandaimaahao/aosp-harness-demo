# 03a1 design review — round 2

Reviewer: `review_plan_v5_2`

Verdict: **NEEDS_CHANGES** — blocker 1 / important 1 / minor 0

1. existing swap表漏target/victim subtree重键的added/removed，mkdir replacement未记录刚创建original完整签名并与`.old`比较，allowed-delta blocker未完全闭合。
2. 382/400投影尚未支付marker count、case invocation、sentinel、made/catch等requirements强制self-disproof。

EEXIST一对多有序hook已闭合；其余only-anchor、损坏优先级、37算术和顺序门无新问题。
