# 05 verifier contract

结论：成立并通过门⑤验收。

交付：

- `common/.harness/bin/verify-sidebar.sh`：独立 canonical verifier CLI，固定五项断言、六 query runner 协议、strict/exploratory SKIP 和 `PASS/FAIL/INCOMPLETE` 终态。
- `docs/verifier-contract.md`：定义 CLI、输入 grammar、runner 信任边界、fixture 和输出/退出码协议。
- `tests/test-verifier-contract.sh`：覆盖 demo/real 主链、逐 query argv、runner 双流/rc 和代表性 preflight。

边界：不修改三个旧 verifier 入口、session 或 resource-lease public surface；05a 独占完整 grammar/CLI/argv/failure/mutant assurance，且在其 dependency-present active 证据入库前禁止启动 06/09。

验收：BASE `65d67b52e5b34d0d9d2add587083ebf2fadcd3ea` 到 accepted HEAD `9e5edb45a3048e4c208e2d7fe135639768cc87db` exact 三文件 `202+67+102=371/400`；六任务 manifest、candidate/full/depth-1/rollback、fixed tools、四不变量、21 资产 converge 与后序缺席门全部通过。实现已 ordinary fast-forward 合入 main，post-merge contract/offline 回归通过，未 push。

证据：`work/2026-09-04-05-verifier-contract/acceptance/acceptance-report.md`。
