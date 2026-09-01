# Task 2 diff review round 1

结论：NEEDS_CHANGES（blocker 0 / important 3 / minor 0）

1. mkdir成功后的name stat消失当前被初始`path_error`映射unsafe/2；必须拆开并映射operation/1，parent/base缺席仍unsafe/2。
2. dangerous roots只覆盖HARNESS，漏XDG/TMP危险/缺席/优先级；2×2只核输出，未明确断言root+2project+4session七目录。
3. victim inventory漏dev/inode与内容hash；同长度篡改可假绿。每个link case需比较sentinel hash/content及victim inode/mode。

其余root selector、managed nofollow/identity/EUID/0700/final stat、错误分类、无fchmod/scope、红证据和累计exact2/280通过。修复必须同步压缩且不得删除现有oracle。

reviewer: `review_design_03a_r1`
