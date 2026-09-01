# 03a requirements review round 2

结论：NEEDS_CHANGES（blocker 0 / important 3 / minor 0）

1. fresh mkdir 成功到 open/fchmod 的替换窗口未覆盖；要求 root/project/session 三行 mkdir-success replacement，identity 成立后才能 fchmod。
2. 新 core 的 HARNESS/XDG/TMP/default 成功、优先级与 symlink parent physical 输出缺少明确 oracle。
3. 只证明 foundation predicate 存在，未证明 core 实际消费；要求 wrapper log project/session 并拒绝普通合法 ID，证明 Python/文件系统前 fail closed。

机械检查 check-req/check-criteria/check-analyze 均通过。
