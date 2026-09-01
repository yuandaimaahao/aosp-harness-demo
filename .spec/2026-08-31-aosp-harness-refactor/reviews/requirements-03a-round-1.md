# 03a requirements review round 1

结论：NEEDS_CHANGES（blocker 0 / important 3 / minor 0）

1. 分层 owner 与 name↔fd identity oracle 可假绿：单次未指定层级的 EXPECTED_EUID/MANAGED mutation 不能证明 root/project/session 都执行校验。要求改为三层表驱动，唯一 marker 的硬编码 replacement 按目标 name 命中并写独立 sentinel。
2. fresh absent→EEXIST 竞争未闭合：增加安全 winner 复验后 0、不安全 winner 2、winner 消失/普通竞态 OS 1 的固定分类与确定性 provider-copy oracle。
3. source 只新增函数/零副作用不够可失败：present 与三个 missing-export fixture 在同一隔离 shell 同时比较状态变量 declare-p、marker unset、仍存在 foundation 函数 declare-f、rc/双流和 inventory。

机械检查 check-req/check-criteria/check-analyze 均通过；exact 2 files/400 与六列 manifest 可执行，无 owner 越界。
