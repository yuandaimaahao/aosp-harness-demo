# 03a requirements v5.5 review — round 1

Reviewer: `review_plan_v5_2`

Verdict: **NEEDS_CHANGES** — blocker 1 / important 3 / minor 1

## Findings

1. Blocker：不变量仍要求03a验证wrong-owner/stat→open replacement，与动态provider-copy已移03a1冲突。
2. Important：需统一“全部dynamic”与“全部provider-copy dynamic”的边界，并明确非anchor post-mkdir probe归03a。
3. Important：验收清单缺真实foundation文件缺席的default与显式入口双流证据。
4. Important：pinned工具未固定版本断言、argv与exact两文件集合。
5. Minor：主输出只检查末行，弱于精确单行+LF要求。

机械check-req/check-criteria/check-analyze/check-plan与diff-check均PASS。
