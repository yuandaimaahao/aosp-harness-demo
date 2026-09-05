# 05a verifier contract assurance tasks quick independent review

## 结论

- 规格符合性：**PASS**
- 执行可行性：**PASS**
- Findings：**B=0 / I=0 / M=0**

本轮按 quick profile 审查当前 `tasks.md`，对照已通过门二/门三的 requirements、design、331 行 prototype 及 05 provider/doc/base test。复用相同 SHA-256 artifact 的 active 证据，未重跑 79.62 秒完整矩阵。

## 任务依赖与产出锚点

三任务是无分叉的串行链：

1. 任务1从无任务级消费开始，只产出 `tests/test-verifier-contract-assurance.sh`。
2. 任务2逐字消费任务1的源码路径，产出 `verifier-contract-assurance-checkouts-v1`。
3. 任务3逐字消费任务2的 checkout 证据锚点，产出固定终交付摘要 `RESULT PASS  verifier contract assurance`。

任务1实现、任务2/3零源码 delta 的边界清晰；每任务都声明文件、验收资产、消费、产出、需求、必需和状态，且每任务都有 brief、report、独立 diff review 与 manifest 完成锚点。

## R1–R10 与红阶段

- 需求栏并集机械提取为 R1–R10 全集：任务1承接 R1–R8，任务2加入 R9，任务3承接 R10 及最终闭环。
- 任务1的 red 是 BASE 上目标物理缺席导致 `cmp` 失败；当前 controller 上目标确实缺席。
- 任务2的 red 是 checkout green 证据未产生，任务3的 red 是 acceptance report 未产生；两者都与零源码验证任务的产出锚点直接对应，不会把已有源码 PASS 冒充本任务完成。

## exact1 机械交付

任务1明确要求用 apply_patch 逐字复制已审 prototype，设为 0755，不重新设计；同时核对 `cmp`、331 行、已固定 SHA-256、shfmt 3.14.0、ShellCheck 0.11.0、bash-n、BASE..HEAD exact1/`331/0`、05 exact3 hash 和 clean commit。任务2/3又在 candidate 和终门复核同一 exact1 边界。

当前 prototype 机械证据仍为 331 行，SHA-256 `88f3abcd3f99e252c10e1134b98ea63212584ebd37bc6dfac2f9dd77dedc92ba`；固定 shfmt/ShellCheck 和 bash-n 复核 PASS。因最终源码是唯一新增文件，`331/0` 满足 added+removed `<=400`。

## 验证、manifest 与收口

- 任务1以完整入口执行闭合 active default、264 个唯一 ID、41 surface、80 service 组合、runner/direct transport、child marker、四 mutant、hash 与 cleanup-before-summary；另核 complete-absent default/all/flag 及 present flag 拒绝。
- 任务2对 candidate、repo 外完整历史 checkout 和真实 depth-1 clone 串行跑 assurance、05 base 与 offline；depth-1 还核 commit-count=1、shallow marker、HEAD 和 target/prototype blob，并要求 clone clean 与物理清理。
- 任务3在 repo 外 rollback checkout 中只删除 TARGET，要求 tree 与 BASE 零 diff、assurance 发现数为 0，并回归 05/01/04/04a/03e/offline 和三个旧 demo。
- NEXT 门逐类核 06/09 的 spec、branch/worktree、execution BASE 和 dispatch 均缺席，`rg` 严格区分 rc1 与工具错误；inert PASS 被明确禁止代替 active 证据。
- 最终 manifest 要求三行、六列、首尾绑定、相邻连续、reviewer 非空和全 PASS；三任务均先独立 diff review，再 mark/ledger/sync。主验证、offline、fixed tools、converge、diff-check 和 clean 在进入 accept 前再收口。

## 机械检查

`python3 /home/zzh0838/.agents/skills/spec/scripts/check-tasks.py <tasks.md>` 实际退出 0；三个任务均有五个有序步骤，没有隐式并行写同一 worktree 或越过未审产出的依赖。

## 最终裁定

**PASS — B0 / I0 / M0。** 任务拆分与单文件 owner、331/400 机械交付、active/inert/damaged/manifest/mutant 证据、candidate/full/depth-1/rollback/NEXT 门和验收闭环一致，未发现会阻止 execute 的 blocking 或 important finding。
