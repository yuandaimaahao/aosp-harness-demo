# 00 environment seed preflight sizing result

结论：`REPLAN REQUIRED`。原 00 在不降低 requirements 的前提下预计产生 890–1310 行非生成 diff，超过 PLAN/R24 的 800 行人审上限。

| 原 combined 能力 | 实现估算 | 测试估算 | 合计 |
|---|---:|---:|---:|
| dispatcher、schema、RFC 8785、path/store/ref/publish recovery | 360–430 | 250–300 | 610–730 |
| Repo/source-state、cgroup resource、namespace/trace、lunch/gate | 480–620 | 140–200 | 620–820 |
| 合并后可共享部分 | -180–250 | -60–90 | -240–340 |
| 原 00 总量 | — | — | 890–1310 |

区间按 `610–730 + 620–820 - 240–340` 计算；最小值取两个下界减共享上界，最大值取两个上界减共享下界。估算基于 requirements 的 closed field/error/fault matrix，不包含生成的 golden JSON、trace 数据和 AOSP 运行输出。即使取 890 行下界，原 00 仍超过 800 行。

稳定切口：

- `00a-seed-contract-runtime` 产出 dispatcher、`verify-seed` direct ABI、schema/digest 与 recoverable state store；分配 330–390 行实现 + 250–300 行测试 + 30–40 行 wrapper，合计 610–730，review summary 100–140 行。
- `00b-environment-seed-probe` 消费 00a runtime，不重复 canonical/schema/path/publish/fault matrix；按剩余组件重新自底向上估算为 360–470 行实现 + 110–140 行测试 + 0–20 行 wrapper，区间合计 470–630，review summary 120–160 行。该区间是拆后重估，不再与 combined 表的共享扣减区间混算。

P1–P5：两片都有独立命令判据、独立 commit/revert、独立能力/知识产出、0 个新增用户问题；00a 高位 730、00b 高位 630，summary 高位分别 140/160，均在 800 行和 1 小时人审门内。实现类仍串行，00b 唯一依赖 00a。
