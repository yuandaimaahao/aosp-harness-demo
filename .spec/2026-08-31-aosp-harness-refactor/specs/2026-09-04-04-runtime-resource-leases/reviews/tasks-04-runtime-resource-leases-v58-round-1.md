# Tasks review：04-runtime-resource-leases v5.8 round 1

- 规格符合性：**NEEDS_CHANGES**
- 任务设计质量：**NEEDS_CHANGES**
- Verdict：**NEEDS_CHANGES**
- Findings：Blocking **0** / Important **2** / Minor **0**
- 门④：**不可放行**

独立 reviewer `design_04_v58_review` 只读核对 tasks/requirements/design/PLAN 与任务细则。

## I1：源码范围与验收资产混淆

任务1.3把只读核验的provider/docs放入`文件`；四个controller零源码delta任务也把exact3写为`文件: 测试`。任务细则规定`文件`只列本任务预期BASE..HEAD源码改动，只读回归应进入验收资产。各任务还要求生成brief、package及capture/full/depth1/rollback日志，却未在验收资产字段声明精确路径。checker只拦`验证`前缀、未拦`测试`，故机械rc0是假阴性。

修复：1.3 `文件`只保留新增测试；2.1–2.4明确无源码修改；所有只读路径与实际生成的brief/red/log/report/package/manifest/acceptance资产逐项列入验收资产。

## I2：04a五类缺席门缺精确日期前缀命令

原步骤只写“find匹配真实spec目录/规范branch”，未钉死单层类型、`*-04a-runtime-resource-lease-assurance`日期前缀glob、`refs/heads/spec/YYYY-MM-DD-*` namespace及capture 0B断言。执行者若直译成无日期slug精确名，会漏掉真实资产。

修复：写出spec/work单层`find -name "*-$NEXT"`并先核find rc再核0B；branch/worktree porcelain按日期前缀正则；ledger/dispatch/execution-base限定清单先核find成功和非空，再在`set -e`循环逐文件拒绝NEXT，排除合法PLAN/requirements/design/tasks搜索域。

## 已通过

7任务≤8；五字段/二级编号/需求并集R1–R10/产出链/机械exact3与assurance不落最终/candidate/full/depth1/rollback/manifest结构均成立。四项checker与diff-check rc0。
