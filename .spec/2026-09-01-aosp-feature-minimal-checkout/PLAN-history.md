# 2026-09-01-aosp-feature-minimal-checkout 拆分计划变更史

> 每次变更必须写明**触发它的证据**（哪个 spec 的哪条发现，带出处）。
> 不接受「经过考虑觉得应该调整」。没有这条，计划会在一次次微调里
> 漂移到和最初目标无关的地方，而且没人说得清是哪一步开始偏的。

## v1 — 2026-09-01

首版。基于 research/report.md。

## v2 — 2026-09-01

触发证据：`work/plan-review-round-1.md` 的 B1–B3、I1–I5、M1–M2。

- 把成功范围从不存在真实源码的 `dev-sidebar` 收窄到公开 `frameworks/base -> services`。
- 前置 environment/seed preflight，增加版本化契约、回滚矩阵、全角色 witness、ClosureKey 变异矩阵和人审预算。

## v3 — 2026-09-01

触发证据：`work/plan-review-round-2.md` 的 B1–B2、I1–I4。

- 固定 candidate→materialize→probe→prove→verify-proof→repo-unit 的 CLI 与输入/输出。
- 增加 `aosp17-services` resolver/Claude/Codex 成功正例，保留 `dev-sidebar` 失败边界。
- 固定 dispatcher/command owner、artifact store 和 lock/closure/proof digest 分层。

## v4 — 2026-09-01

触发证据：`work/plan-review-round-3.md` 的 B1–B2、I1–I3、M1；该轮达到 `fix_loop_max=3`，后续依 `PLAN.md` 的「Review 熔断裁定」逐条决策。

- 以 previous-event hash chain + final-lock + audit-root 消除 closure digest 自引用。
- 将 proof store/ref 移到所有 worktree 之外的项目级 `AOSP_HARNESS_STATE_DIR`，固定原子发布、留存和 cleanup owner。
- 固定 exit 0/10/20/30/40 及 ref kind，为 dispatcher 回滚保留 direct recovery ABI，并增加 `build-feature aosp17-services` 等价验收。

## v5 — 2026-09-01

触发证据：`specs/2026-09-01-00-environment-seed-preflight/work/review-requirements-round-3.md` 的 B1–B2、I1–I6、M1–M2；requirements review 达到 `fix_loop_max=3` 后逐条熔断裁定。

- 将 preflight input 改为独立 `seed-request/v1`，固定 public seed ref，02/03b 通过 `--descriptor-ref` 消费并重算 real-source object。
- local LK7K 仅作本机实现验证；只有 real public seed exit 0 可进入 01，缺失/exit 20 回 PLAN。
- seed identity 与调度相关 run evidence 解耦，固定 trace/source-state signed/path/per-project ABI 和可恢复 publish commit-point 状态机。

## v6 — 2026-09-01

触发证据：原 `00-environment-seed-preflight` 的 requirements R24 与门③ sizing；dispatcher/schema/store/resource/repo/trace/lunch 和 fault tests 估算 890–1310 行非生成 diff，超过 800 行人审上限。

- 沿稳定 seed/store ABI 拆成 `00a-seed-contract-runtime` 与 `00b-environment-seed-probe`。
- 00a 以纯 fixture 独立验 dispatcher/schema/digest/path/publish/recovery，高位 730 行；00b 复用 runtime 并负责真实 local/public evidence 与 gate，高位 630 行。
- 01 依赖改为 00b；dispatcher/runtime 归 00a，preflight provider 归 00b，回滚边界随 owner 分开。
