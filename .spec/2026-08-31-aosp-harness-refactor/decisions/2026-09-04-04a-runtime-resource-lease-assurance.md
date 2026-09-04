# 04a runtime resource lease assurance

结论：成立并通过门⑤验收。

交付：

- `common/.harness/lib/resource-leases.sh`：只替换deadline相邻两行，使扫描后到期路径进入最后一次无sleep锁尝试，并复用既有锁后deadline检查在读取record或发布前返回3。
- `tests/test-resource-leases-assurance.sh`：396行默认发现保证入口，覆盖CLI、absent/damaged provider、request/root/state/record、并发barrier、PID复用、I/O/helper/output、adapter与四类mutant自反证。

边界：不改变`resource-leases-v1` public API、状态格式、错误双流、文档或04基础测试；inert PASS不能替代dependency-present active证据。只有本片验收记录入库后，05/06/08的资源租约依赖门才解除。

验收：BASE `ffb05899c33d04b4c3d1c6605b3d39b1e6a05204` 到accepted HEAD `3f17cf66c1a13296d77ed1f900109fc1feb633c6` exact两文件，provider `2/2`加assurance `396/0`总churn400；candidate/full/depth-1/rollback、四行review manifest、fixed tools、四不变量、`check-converge.py`与05五类缺席门全部通过。实现已fast-forward合入main，未push。

证据：`work/2026-09-04-04a-runtime-resource-lease-assurance/acceptance/acceptance-report.md`。
