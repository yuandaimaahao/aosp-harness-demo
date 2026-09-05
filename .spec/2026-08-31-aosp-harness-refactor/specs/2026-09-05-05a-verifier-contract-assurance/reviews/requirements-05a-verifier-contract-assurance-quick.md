# 05a requirements quick independent review

结论：**PASS — B0 / I0 / M0**。

## 审查范围

- `requirements.md` 的 R1–R10、验收清单和四条不变量。
- `PLAN.md` 的 05a 详情、`05 -> 05a`、`05a -> 06/09` 依赖和独立回滚边界。
- `DECISIONS.md` 的 05 验收、v6.1 seam/assurance 拆片及 quick-autopilot 裁定。
- 05 已验收 provider、contract doc、base test。
- 331 行 runnable prototype、SHA-256 和 ledger 中最新 recovery/quick active evidence。

## 复审结果

- R1–R10 均有可执行验收落点；唯一源码、exact1/400、上游保护、candidate/full/depth-1/offline/rollback、六列 manifest 与 NEXT 门均写明，未发现会阻止 design/execute 的缺口。
- runner 与 direct 都按 `argc + 每个 argv 的字节长度/hex` 比较完整分离参数；runner 独有 `query-key --`，direct 无该前缀且 stderr 抑制。实际调用日志与按 query/baseline 量化生成的 wanted 列表逐项相等，前置失败另断言零 query。
- provider 的 USAGE、runner command、service argv、SERVICE regex，以及 assurance 的 expected/executed case 和 cleanup anchor 均为唯一固定点；替换前检查唯一、替换后检查语法，四类 mutant 各有专属失败标签。
- `VC_ASSURANCE_CHILD=1` 只包围 mutant 生成块；child 仍从 `main()` 执行 readiness、264-case manifest、surface 与 hash/cleanup，因而不会递归生成 mutant，也没有借 child 模式跳过承重矩阵。
- prototype 实测为 331 行，SHA-256 为 `88f3abcd3f99e252c10e1134b98ea63212584ebd37bc6dfac2f9dd77dedc92ba`；静态重建 expected manifest 得 264 个 ID、264 个唯一值。
- ledger 已记录 dependency-present default active：rc0、stdout 41 bytes 固定摘要、stderr 0，且完整缺席 default/all/`--dependency-absent` 三路 PASS。quick 不重复 active `all` 的裁定成立：参数集合检查之后，default 与 `all` 没有任何行为分支；`all` 只在允许参数元组和 absent surface fixture 中出现，present 时与 default 进入同一个 `main()` 路径。
- 使用固定缓存工具机械复核：shfmt `v3.14.0`（`-d -i 2 -ci -bn`）、ShellCheck `0.11.0` warning、`bash -n` 全 PASS；prototype hash/行数与 ledger、requirements 一致。

## Findings

- Blocking: 0
- Important: 0
- Minor: 0

门② quick 独立复审通过，可以进入 design。
