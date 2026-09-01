# Task 1 fix round 1

只修`task-1-review-round1.md`的三项，不实现task2功能，不派subagent。

工作树：`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a-session-path-safety`

要求：

1. 先增加自反证，使任一source fixture内部fail时外层测试必为非零；保存红阶段日志。
2. 四次source case都显式传播非零状态。
3. 隔离shell source前清理继承marker及需要归因本次source的public状态。
4. 比较foundation全部既有函数体，并精确断言after函数集合等于before加唯一`_harness_session_path_core`，能抓重定义和删除。
5. 只改两个path文件；累计仍须exact两文件且不超过150行。若无法在150行内保留oracle，报告BLOCKED，不删oracle。
6. 使用个人项目Conventional Commit；完整报告写`task-1-fix1-report.md`，包含Status、Commits、红证据、测试、累计numstat与顾虑。
