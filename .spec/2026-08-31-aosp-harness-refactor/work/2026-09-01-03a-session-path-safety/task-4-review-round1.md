# Task 4 diff review round 1

结论：NEEDS_CHANGES（blocker 1 / important 1 / minor 1）

- blocker：测试全局先强制foundation存在，真实删除foundation后默认与`--dependency-absent`均失败，未进入all-missing inert。只应全局要求path provider；foundation存在时默认跑三功能组，缺席时默认/flag跑真实all-missing。
- important：报告所称ShellCheck/shfmt PASS不实；SC2034/SC2053且shfmt有diff。修正或如实处理，最终仍须<=400。
- minor：默认child stdout用command substitution会吞尾部额外LF，不能证明唯一摘要；改用`cmp`精确比较`SUMMARY\n`。

其余case传播、继承状态、unknown CLI、cleanup、foundation diff、exact2/397与offline通过。

reviewer: `review_plan_v5_3_1`
