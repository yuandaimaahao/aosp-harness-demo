# Task 3 diff review round 2

结论：NEEDS_CHANGES（blocker 0 / important 1 / minor 0）

`expect_scope`只比较允许路径集合与provider签名，未逐例固定允许对象完整签名；允许路径`hit`换成symlink仍假绿，mkdir replacement未断言current type，swap file未断言content hash。需逐例比较完整签名或明确允许变化，补replacement type/hash oracle。

其余mkdir分类、made状态、unexpected路径、occurrence、回归、exact2/370与scope通过。

reviewer: `review_plan_v5_3`
