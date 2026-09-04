# 05 verifier contract tasks review — round 2

## 结论

- 规格符合性：**PASS**
- 任务质量：**PASS**
- Findings：**B=0 / I=0 / M=0**

本轮以最新磁盘版本为准，只读复核 round 1 的 B1/B2/I1 修复，并重新检查任务依赖、红因、R1–R10 并集、提交/review、四路验收、NEXT 与 manifest。三项 finding 均已闭合，没有新增回归。

## Round 1 findings 闭合

| Finding | 状态 | 当前证据 |
|---|---|---|
| B1：doc 提交前不可能得到 `BASE..HEAD` exact3/371 | **已闭合** | 任务3步骤2只复制并核doc；步骤3先提交doc，再运行三文件prototype `cmp`、exact3 name-only和`BASE..HEAD` numstat=371。HEAD时间点正确。 |
| B2：rollback clone不能证明controller NEXT资产缺席 | **已闭合** | 任务6步骤2只在rollback clone验证exact3删除及旧回归；步骤3明确回到controller主工作树检查05a源码及05a/06/07/08/09/10的spec、branch、worktree、execution BASE、dispatch五类资产。观察域正确。 |
| I1：task3混合doc diff review与整片controller验收 | **已闭合** | 任务3现在只安装/提交/review doc；任务4独立审计candidate并固定accepted HEAD，任务5独立验证full/depth-1，任务6独立验证rollback/NEXT/终收敛。三个零源码delta均有自己的brief、red、report、独立review和manifest行。 |

## 完整性复核

- 粒度与顺序：六任务中前三个源码任务仍严格为test → provider → doc，每个只创建一个exact3文件；后三个按candidate → full/depth-1 → rollback/NEXT分离，单轮review范围可控。
- 红因：任务1的入口缺席rc127与安装后provider缺席、任务2/3的目标prototype `cmp`缺席，以及任务4–6报告尚未生成，均是与各任务当前未完成状态直接绑定的真实红证据；没有恒真成功断言。
- 需求并集：任务1覆盖R7/R10，任务2覆盖R1–R6，任务3覆盖R8，任务4–6覆盖R9/R10，并集完整覆盖R1–R10。
- 规模与文件：exact3固定为provider 202、doc 67、test 102，总churn 371/400；任务3提交后才核BASE..HEAD exact name-only/numstat。
- 提交与review：三个源码文件各一个提交、各自独立diff review；任务4–6明确为零源码diff并各自独立review，manifest预期六行、六列、首尾相邻连续、reviewer非空且全PASS。
- 四路验收：任务4绑定candidate/accepted HEAD；任务5从该HEAD验证full与真实file-URL depth-1、单commit/shallow marker；任务6验证exact rollback、01/02/04/04a及三个旧verifier demo、NEXT和converge。
- rollback/NEXT：rollback只删除05 exact3；05a及后序资产缺席在controller主工作树检查，且05a没有任何提前创建动作。只有任务6独立review、manifest第6行、mark/ledger sync之后才进入accept。
- 验收资产：任务4–6均显式声明各自brief/red/report/manifest，任务6另声明acceptance report；没有把这些资产误计入源码exact3。

## 机械检查

- `python3 /home/zzh0838/.codex/skills/spec/scripts/check-tasks.py .../tasks.md`：rc `0`。
- `git diff --check`：rc `0`。

最终裁定：**PASS — B0 / I0 / M0**。
