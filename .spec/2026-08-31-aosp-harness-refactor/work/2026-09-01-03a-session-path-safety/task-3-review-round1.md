# Task 3 diff review round 1

结论：NEEDS_CHANGES（blocker 0 / important 3 / minor 1）

- mkdirat除EEXIST外的ENOENT/普通OSError仍经path_error错分unsafe/2，应为operation/1；selector parent/base缺席仍unsafe/2。
- existing/before_mkdir/after_eexist注入未断言`not made`；把初值改true仍假PASS。
- mutation缺完整scoped inventory；额外`unexpected`对象可假绿，swap link/file replacement的inode/mode/target未固定。
- marker/phase唯一性用`grep -c`计行而非occurrence，同一行重复可漏检。

其余真实注入、0/2/1、sentinel、范围与累计357/370通过。修复必须守370行门。

reviewer: `review_design_03a_r1`
