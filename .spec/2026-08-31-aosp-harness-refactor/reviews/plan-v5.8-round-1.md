# PLAN v5.8 independent review — round 1

结论：**NEEDS_CHANGES**。Blocking **2**，Important **1**，Minor **0**。

审查范围是 PLAN v5.8 相对 v5.7 的增量及其受影响边；完整阅读了 `research/report.md`、`PLAN.md`、`PLAN-history.md`、当前 04 的 `requirements.md`、`design.md`、design round 1 review 和 `prototypes/` 当前四文件。除本报告外未修改仓库文件。

## Blocking

1. **04 core 仍未修复 design round 1 的 I2，因而 `306+7+79=392/400` 不是“全部生产正确性留在 core”的可行性证明。** `PLAN.md:10,141` 与 `PLAN-history.md:65` 声称工具/输出 I/O 已收敛为固定 `0|2|3` 协议；但 provider 在 `prototypes/common/.harness/lib/resource-leases.sh:9-17` 只先跑一次 Python 版本探针，随后把第二次 `python3` 的 stdout、stderr 和退出码直接暴露给 public facade，`277-290` 的异常收敛也只存在于 embedded program 内。定点探针令假 `python3` 对 `-c` 返回 0、对真正 worker 调用打印 `evil`/`bad` 并返回 17，实测 public `harness_lease_release` 返回 **17** 且输出 **`badevil`**，而非 rc2、stdout 空、固定 operation-failed stderr；现有 fake-Python case `prototypes/tests/test-resource-leases.sh:74-77` 只覆盖“版本探针立即 exit 1”，所以是假绿。基础测试还在 `34-35` 用 command substitution 核成功 token，无法证明 token+LF 的 33 字节 framing；`78` 只查 `active-*`，不是 PLAN 所称完整 before/after inventory。精确修法：把 design review I2 要求的内部 worker 结果协议、输出通道校验和 malformed-worker 白名单收敛留在 04 provider；至少加入“版本探针通过但 worker 任意 rc/双流”的 fake Python、成功 token 33 字节和全 inventory 基础回归，并证明 publish 后 public 输出失败的 active/tombstone 后置条件。修完后重新固定 shfmt 并证明 exact3/≤400；若超门，继续沿不泄露半成品 public capability 的稳定私有切口拆 core，不能把生产错误收敛移给 04a。

2. **04a 的 307/400 原型能运行，但没有覆盖 PLAN 自己列出的 active family，也没有使用所宣称的唯一 seam，不能证明 P5。** `PLAN.md:85,145,196` 把稳定切口写成“04a 只复制 provider，并只通过唯一 `HARNESS_RESOURCE_LEASE_TEST_SEAM` 注入”；实际 assurance 文件从未查 anchor 的存在/唯一性，也未替换该 anchor，而是在 `prototypes/assurance/tests/test-resource-leases-assurance.sh:272-287` 逐字匹配并改写五处 production 实现语句。这使 04a 依赖内部缩进/实现文本，接口切口并不稳定。其矩阵还缺 PLAN 明列的关键证明：`197-212` 的反向 request waiter 没有在 barrier 中观察 active set，无法反证部分 bundle；没有 monotonic 最终尝试注入；stored-state 只测 duplicate/invalid-request/global-overlap，未逐字段覆盖 version/token/nonce/owner/session/hash/request/文件名与缺/多键；I/O 没有 flock；TSV/root 没有 control-byte symlink target、alias、non-regular request、wrong-owner 等完整形态；没有 mutant 自反证。`--dependency-absent` 也实测 rc1/无摘要，直接不符 `PLAN.md:145` 的 inert PASS 协议。当前 default/all 虽 rc0 且摘要正确，仍只证明这份不完整子集可放入 307 行，剩余 93 行能容纳全部承重 oracle 没有证据。精确修法：原型必须先机械断言 seam 恰一次，并且只替换该 seam 注入 fault dispatcher；补齐上述 family、每类精确状态/双流/inventory oracle与能杀死相应 mutant 的自反证计数，同时补 default/`--dependency-absent` 同一零-active inert 路径。再以完整 active-family 的 fixed-shfmt exact1/≤400、实跑与固定工具结果证明 P5；若超门，继续拆 assurance，不得删 oracle 压行数。

## Important

1. **“04 → 04a → 05”的 NEXT 门只写进历史/顺序，尚未形成可执行闭环。** `PLAN.md:10` 和 `PLAN-history.md:65` 都说 04a 守住 05，但 `PLAN.md:145,198-200` 只规定 04a 验收后才可启动 06/08，没有写 05 五类资产的物理缺席/解除条件；当前 04 `requirements.md:47,82` 与 `design.md:180,209` 仍明确允许 04 accepted 后直接创建 05。固定顺序 `PLAN.md:297` 表达了意图，却挡不住当前 spec 的旧 R10 被照章执行。精确修法：在 PLAN 的 04 回流说明中明确把当前 NEXT 从 05 改为 04a；在 04a 详情中写死 05 spec/ref/worktree/ledger BASE/dispatch 在 dependency-present、exact1/400、full/depth-1/offline/rollback 证据入 ledger 前物理缺席，之后才解除。PLAN 通过后必须回到当前 04 requirements/design/tasks 重走 review 并替换旧 R9/R10/NEXT；若选择让依赖图承载这条非运行时门，则同时把 `04a -> 05` 加到 spec 表、直接边和文本图，不能只加其中一处。

## P1–P5 与受影响边结论

- 04/04a 在纸面上满足 P1–P4：各自有独立命令判据；04 提供完整 runtime capability，04a 增加可审计 assurance 知识；文件 owner 分别是 04 三文件与 04a 单一测试，回滚方向也不要求反改另一片；无新增用户问题。P5 因 Blocking 1/2 未成立。
- `resource-leases-v1` 两个 public 函数、request TSV 和 `0|2|3` API 切口保持不变；I1 strict record/global overlap、I3 Python 3.8 `Path.resolve(strict=True)`、I4 tombstone recovery 都位于 core prototype，I2 工具/输出协议仍未真正位于 core。
- spec 表、直接边表与文本依赖图均为 30 条且集合相同；19-spec 固定顺序对全部边拓扑合法；资源冲突和文件独占文字与表一致。06/08 都同时保留 `04 -> consumer` 的运行时 API 边与 `04a -> consumer` 的 active-evidence 边，inert PASS 不能解除消费者门，方向正确。
- 04 回滚时 04a 默认 provider-absent 模拟确能 inert PASS，04a 回滚不影响 04 runtime；但显式 `--dependency-absent` 与 NEXT 05 的机械门仍须按上文补齐，才可称回滚/顺序验收完整可执行。

## 只读探针

- `check-plan.py PLAN.md`：rc0。
- 自编集合探针：spec 表/直接边/文本图各 30 条、集合完全相等；19 项顺序无逆拓扑边。
- core prototype：default/all 均 rc0、stdout 为固定 PASS；`all extra` rc1/无输出。assurance prototype：default/all 均 rc0、stdout 为固定 PASS；`all extra` rc1/无输出；`--dependency-absent` rc1/无输出。
- 两个 prototype 联跑、`bash -n` 与本机 ShellCheck 0.9.0 warning 级均通过；本机 PATH 没有 shfmt，也没有固定 ShellCheck 0.11.0，因此未把 PLAN/ledger 记载的固定工具结果冒充为本 reviewer 独立复现。
- 欺骗 fake-Python 探针：rc17，合并可见输出 `badevil`，稳定复现 Blocking 1。

## 已核对通过

- v5.8 的拆片触发证据准确指向 design round 1 B1/I1-I4，未借增量复盘重审或改写无关旧计划。
- 04a 已进入总验收命令链、spec 表、文件 owner、回滚矩阵、遗留项去向、依赖图、固定顺序和 19-spec 资源冲突计数。
- 06/08 的运行时依赖与 assurance 证据依赖没有混为新的 public API；04a 不发布 capability 的方向正确。
