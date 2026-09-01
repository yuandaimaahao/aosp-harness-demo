# PLAN v5.4 增量 review round 1

结论：NEEDS_CHANGES（blocker 0 / important 2 / minor 0）

- 03a requirements frontmatter仍称core仅供03b/03d消费，未把三个唯一mutation anchor与三phase checkpoint锁成03a1直接消费契约，也未同步v5.4确认依据。
- foundation `03` 的固定回滚命令遗漏新增`test-session-path-races.sh --dependency-absent`，不能机械证明foundation回滚后03a1测试仍绿。

P1/P3/P4/P5及03a/03a1运行时回滚设计通过；spec表、依赖表、图、顺序、owner与原型机械检查其余一致。

reviewer: `review_design_03a_r1`
