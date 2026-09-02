# 03b design 独立审查 round 3

结论：**PASS，可以进入 tasks。** Blocking 0、Important 0、Minor 0。

round2 B1 已闭合：requirements 与 design 明确 `close_all` 收集错误但继续尝试全部fd、temp close置于保证unlink执行的嵌套finally，并让已锁存首信号最终优先于cleanup错误。prototype runtime/base `a708ce6f0979c6644292b58b4a7b0d4afcdf821d`、assurance `cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e`与证据`9f0dfbc5bca35df8fe9ea9ba249050a8aa4547fd`实现并验证该契约。

确定性`signal+cleanup-close-error`行同时注入TERM与两个close EIO，核对owned temp、session和三层ancestor共五次close、rc143、无winner/temp。修复前`df2c3f9`短路mutant在当前assurance下rc1、仅记录2/5次close、报告temp残留且无PASS，证明oracle会拒绝回归。

八节与文件清单、R1–R9、逐字消费/产出、Bash worker/path core/final exec Python边界、rename前后信号时序、错误表、分层测试与exact2=400/400、assurance=308/400边界均通过。固定shfmt 3.14.0、ShellCheck 0.11.0、bash-n、diff-check、base与assurance实跑全绿；stdout各为唯一固定PASS，stderr为空。阶段边界也通过：无tasks、无03b implementation/03b1/03c branch、worktree或BASE，只有clean prototype worktree。
