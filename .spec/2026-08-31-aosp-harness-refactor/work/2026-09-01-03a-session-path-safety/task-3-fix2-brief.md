# Task 3 fix round 2

只修round2唯一finding，不做task4/03a1，不派subagent。

- 先保存允许路径`hit`换symlink、mkdir replacement类型错误、swap file同路径内容替换的红证据。
- 对每例允许对象比较完整type/dev/inode/mode/link/hash签名，或逐项声明唯一允许变化；固定mkdir current replacement类型和swap file content hash。
- 只改两path文件，累计BASE exact2且`<=370`；必须通过共享helper/表数据等行压缩，不删任何已验收oracle/comment，不拼不可读逻辑。做不到则BLOCKED并回tasks/PLAN。
- Conventional Commit，报告写`task-3-fix2-report.md`。
