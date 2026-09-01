# Task 1 diff review round 1

结论：NEEDS_CHANGES（blocker 1 / important 2 / minor 0）

- blocker：四次`source_case`没有传播内层非零；fixture输出FAIL后总脚本仍可rc0/PASS。必须显式传播，并加入自反证证明任一fixture fail都会使总测试非零。
- important：函数保护只比较三个依赖，漏`_harness_component_is_safe`，也未精确比较source前后函数集合。必须比较foundation全部函数体，并断言after集合=before+唯一core，覆盖重定义与删除。
- important：隔离fixture未先unset继承的provider marker；外部export会让正确provider假失败。每个隔离shell先清marker及需要归因本次source的public状态。

其余provider行为、红证据、exact2/115、foundation diff、clean与定向回归通过。

reviewer: `review_design_03a_r1`
