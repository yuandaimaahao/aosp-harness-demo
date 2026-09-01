# Task 2 fix round 1

只修`task-2-review-round1.md`三项，不实现task3/4，不派subagent。

工作树：`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a-session-path-safety`

要求：

- 先为三项分别保存能反证当前实现的红证据。
- 拆开mkdir与post-mkdir stat；后者消失/普通OSError为operation/1，初始root parent/base缺席仍unsafe/2。
- 增加XDG/TMP危险/缺席及优先级case；2×2显式七目录expected list/count并逐项验证exists/nonlink/EUID/0700。
- inventory加入dev/inode，link victim逐例比较sentinel内容hash、victim inode/mode。
- 只改两个path文件，不加入task3 anchor/mutation，不fchmod；累计BASE diff必须仍exact两文件且`<=280`。允许压缩共享helper/表数据，但不得删现有oracle/comment或拼接不可读逻辑；做不到则Status=BLOCKED并说明需回tasks/PLAN。
- Conventional Commit；完整报告写`task-2-fix1-report.md`，含Status/Commits/红证据/测试/累计numstat/顾虑。
