# Task 4 fix round 1

只修round1三项，不加03a1或新功能，不派subagent。

- 保存真实临时删除foundation时默认/flag失败、ShellCheck/shfmt失败、额外LF被吞的红证据。
- 全局只要求path provider；foundation存在默认跑三个功能组，真实缺席时默认与`--dependency-absent`跑all-missing inert并同摘要PASS。
- 修ShellCheck警告；执行shfmt并保持语义。如格式化使最终超过400，先压缩共享helper但不删oracle/comment；做不到BLOCKED回PLAN。不得虚报静态检查。
- 默认child stdout用`cmp`精确匹配一行SUMMARY+LF，stderr空，传播child失败。
- 最终BASE exact2/<=400、foundation diff空、worktree clean；Conventional Commit。报告`task-4-fix1-report.md`。
