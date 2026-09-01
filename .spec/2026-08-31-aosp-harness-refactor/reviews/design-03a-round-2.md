# 03a design review round 2

结论：NEEDS_CHANGES（blocker 1 / important 1 / minor 0）

- blocker：runnable sizing 虽为 `136+175=311`，test 实际只执行 fresh 路径；51 条其余内容只是去重计数，不能证明 source/inert、静态攻击与复杂 mutation dispatch 可在剩余 89 行内实现。应让原型实际运行承重 group；超 400 则回 PLAN 拆片。
- important：Linux 上 `O_DIRECTORY|O_NOFOLLOW` 打开换入的 symlink/普通文件都可能返回 `ENOTDIR`；managed open 必须将 `ELOOP|ENOTDIR` 映射 unsafe/2，保留 `ENOENT` 等消失竞争为 operation/1，并增加动态换入 link/non-dir oracle。

其余八节、R1–R7、public validate、inert、multi-phase marker、no-fchmod 与 runtime 边界通过；原型与机械检查均退出0。

reviewer: `review_plan_v5_3`
