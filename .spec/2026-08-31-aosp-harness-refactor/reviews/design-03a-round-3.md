# 03a design review round 3

结论：PASS（blocker 0 / important 0 / minor 0）

- 八节、文件清单和R1–R7映射齐全；接口与requirements/PLAN v5.4一致。
- 40 cases都真实执行，只有`expect()`完成rc/stdout/stderr逐字断言后才计数。
- 动态换入link/file以`ELOOP|ENOTDIR`映射unsafe/2；EEXIST winner消失以operation/1映射。
- 无`fchmod`，replacement保持0755；public validate真实顺序调用且fake python3为0。
- 03a跑root代表性mutation，project/session穷举归03a1且在03b前强制PASS。
- runnable sizing为`136+175=311`，余89行用途明确，exact2/400与380停止扩展阈值闭合。
- 全部mechanical checks、prototype syntax/实跑和`git diff --check`通过。

reviewer: `review_plan_v5_2`
