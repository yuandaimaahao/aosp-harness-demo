# 04a tasks review — round 2

## 结论

**PASS**

计数：Blocking **0** / Important **0** / Minor **0**

本轮按 `reuse_reviewer=true` 只增量复核 round 1 的 B1/I1 修订，并检查原已闭合项无回归。审查对象 `tasks.md` SHA-256 为 `1e38e545bfef34d94e847cb3b97f152e7e43a082bf95c69c497d9ef9325822f6`；未修改 tasks、源码或 prototype。

## Round 1 finding 闭合

| Round 1 finding | 结论 | 独立证据 |
|---|---|---|
| B1：任务1同构树遗漏 docs/base-test，monotonic oracle不可到达 | **已闭合** | `tasks.md:34,37` 现逐一点名 production/patched provider、prototype assurance、accepted docs、accepted base test 四文件，要求真实顶层 `common/.harness/lib`、`tests`、`docs` 布局；临时树固定 `/tmp/aosp-harness-lease-assurance-task1.XXXXXX`，先核绝对前缀/repo外边界，结束删除并核物理缺席。独立四文件 red 得 rc1，首个专属错误为 `FAIL monotonic attempt count`；同布局换 patched provider 后得 rc0、唯一固定 PASS。两次外层树均物理删除。 |
| I1：depth-1要求exact2却无法访问BASE object | **已闭合** | `tasks.md:68-70` 现把 BASE..HEAD name-only/numstat exact2/400 固定在 candidate 与 full clone；depth-1 明确禁止引用不存在的 BASE，改为两个交付文件逐一 `cmp` prototype，并把两个交付 blob、docs、base-test 四项 SHA-256 与 candidate 记录比较，再核 HEAD、commit-count=1、shallow marker、运行结果和 clean。独立构造含本片 exact2 的 accepted commit 并做真实 file-URL depth-1 clone，全部替代判据通过。 |

## 独立执行结果

```text
check-tasks.py: PASS
four-file production red: rc=1
first dedicated failure: FAIL monotonic attempt count
four-file patched green: rc=0
stdout: RESULT PASS  resource lease assurance
outer temporary tree after red/green: physically absent
depth-1 no-BASE criterion: PASS
depth-1 commit-count=1, shallow=true, prototype cmp=2, candidate SHA match=4, clean=true
```

red 的第二行仍是 provider 既有固定 operation-failed 输出；任务要求的是“首个专属错误”逐字为 monotonic 标签，与本次实跑一致。一次 `flock` 的诊断证据继续由同一 accepted provider 上已入库的 `requirements-prototype-boundary.md` 提供；修订未改变该 provider 或 prototype monotonic fixture。

## 回归检查

- 仍为四个必需任务，每项一次上下文可完成且具有具体命令/事实；任务1/2机械 blob 安装，任务3/4零源码 delta，独立 review 均可在 10 分钟内核窄 diff、blob identity 或证据 hash。
- 源码清单仍 exact2：只修改 `common/.harness/lib/resource-leases.sh`、只创建 `tests/test-resource-leases-assurance.sh`；provider `2/2`、assurance `396/0`、churn `2+2+396=400` 未漂移。
- 需求并集仍为 R1–R10，三段内部消费/产出链及终交付摘要连续，无孤儿产出。
- full clone、depth-1、rollback 的职责没有混淆：full 重算 BASE exact2/400；depth-1 验 HEAD/tree/blob；rollback 用可达 BASE 恢复 provider、删除 assurance并验证源码树、04基础、03e、offline和入口发现0。
- 任务4仍覆盖 05 的 spec目录、branch、worktree、ledger execution BASE、dispatch 五类物理缺席门；四行六列 manifest awk 的首尾/相邻/reviewer/PASS约束未变化。
- 个人项目仍只要求清晰本地 commit，没有引入组织 commit 模板或五段式字段。

## 最终裁定

**PASS — B=0, I=0, M=0。** Round 1 两项 finding 均以可执行命令闭合，既有 exact2/400、需求追溯、manifest、rollback/NEXT 顺序门和提交约束无回归，可以进入门④后续流程。
