# 04 runtime resource leases

结论：成立并通过门⑤验收。

交付：

- `common/.harness/lib/resource-leases.sh`：`harness_lease_acquire` / `harness_lease_release`，提供规范 request、跨 owner 完全独占、bundle 原子发布/撤销、有界等待与 stale/tombstone 恢复。
- `docs/resource-leases.md`：`resource-leases-v1` 完整协议。
- `tests/test-resource-leases.sh`：默认发现的基础合同矩阵，固定摘要 `RESULT PASS  resource leases`。

边界：完整 mutation、I/O、并发、adapter assurance 由后序 `04a-runtime-resource-lease-assurance` 独占；在其 dependency-present active 证据前，05/06/08 仍不得启动。

验收：BASE `692d52d00b56df9609760aa33a6f9aa3c38095a3` 到 accepted HEAD `f7cfcb202d1fd2934d07cc90e333a4205b563243` exact 三文件、`336+7+57=400/400`；candidate/full/depth-1/rollback、七行 review manifest、fixed tools、四不变量、后序缺席门与 `check-converge.py` 全部通过。

证据：`work/2026-09-04-04-runtime-resource-leases/acceptance/acceptance-report.md`。
