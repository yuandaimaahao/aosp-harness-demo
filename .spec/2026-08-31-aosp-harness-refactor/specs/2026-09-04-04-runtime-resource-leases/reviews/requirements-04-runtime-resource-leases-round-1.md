# Review: 04-runtime-resource-leases requirements round 1

verdict: NEEDS_CHANGES  
阻断: 2 / 重要: 5 / 次要: 2

审查范围：已完整核对当前 `requirements.md`、`PLAN.md` 的 04 详情/文件边界/直接边/回滚矩阵/串行约束、`DECISIONS.md` I1/I2 及 03e 验收裁决，并回看 `research/report.md` 的运行时锁缺口。机械 checker 已由上游说明通过，本轮未重跑，也不重复纯格式结论。

## Findings

### 阻断

- [阻断 B1] `owner` 没有可执行的身份定义，且重入与 release 的主体条件互相打架。证据：`requirements.md:21` 只用“进程是否存在”定义 stale，`requirements.md:32` 却只要“同一 session+同一 request”就必须返回旧 token，`requirements.md:36` 又要求 release 同时匹配 owner/session/request hash，`requirements.md:38` 仍以存活 owner 作抢占边界；`PLAN.md:138,189` 只固定了三要素和 06 内部 acquire/release，没有补这个缺口。后果：Bash 消费者为了取得唯一 stdout token 自然会写 `token=$(harness_lease_acquire ...)`，函数因而在 command-substitution subshell 中执行；若 owner 是实际执行 PID/`BASHPID`，acquire 返回后 owner 立即消失且父 shell 无权 release；若只用 `$$`，又未规定 PID 复用/进程起始身份和同 session 异 owner 的语义。中心 API 无法唯一实现，stale 也可被误判。建议修法：定义“逻辑调用 owner”的精确 PID+起始身份，明文保证 command substitution 获取 token 后由同一逻辑 owner release 可行；把幂等条件改为“同 owner+同 session+同规范 request”，并固定同 session 异 owner、同 owner 异 session、PID 已复用各自是 `2` 还是 `3`。

- [阻断 B2] 跨会话“独占”没有完整冲突矩阵，同 mode 可被合理实现成共享。证据：`requirements.md:30` 只写 workspace `source`/`build` 互斥和 android `device`/`cvd` 互斥，`requirements.md:32` 只定义一种幂等重入，`requirements.md:34` 只将“本 session 已持有互斥资源”列为 `2`，`requirements.md:38` 的占用语义也未点名同 mode；而 `PLAN.md:55,138` 的目标是“跨会话独占租约”。后果：实现 A 可以对每个 `domain+canonical_id` 只放一个 owner，实现 B 也可以允许两个 session 同时 `workspace+source` 或 `android+device`，两者都符合字面的“source/build 互斥”，但 B 直接穿透 PLAN 的跨会话独占目标。同时，同 owner/session 的部分重叠 request、子集/超集 request、异 owner 复用 session-id 的 `2|3` 也没有唯一答案。建议修法：用表格钉死至少“当前 owner 是否相同×session 是否相同×request 是否完全相同×mode 相同/异名”的结果；对不同 owner/session 的同 `domain+canonical_id` 固定任意合法 mode 都占用/`3`，只豁免同 owner+session+完全相同 request 的幂等返回。

### 重要

- [重要 I1] `0|2|3` 错误表漏掉租约状态的普通 I/O/工具/时钟失败，也没有定义 rollback/release 中途失败后的状态。证据：`requirements.md:34` 将 `2` 限定为参数/协议类，`requirements.md:36` 要求 release 释放“全部资源”并返回 0，`requirements.md:38` 只将占用/超时映射为 `3`，但租约必须执行创建状态根、写 owner 元数据、hash/排序、重命名或删除等操作；`PLAN.md:138` 同样只允许 `0|2|3`。后果：权限拒绝、ENOSPC、hash 工具缺失、状态损坏、删除一半失败时，实现可以泄漏原始 rc、误报占用、误报协议错，甚至在部分锁仍在时返回 0。建议修法：为每个可达错误路径固定 rc/双流/持有集合后置条件。若需增加普通运行错 `1`，必须先回 PLAN 门修改 `PLAN.md:138,189`；若坚持只用 `2`，要明文将状态/工具/I/O 损坏归为 fail-closed `2`。同时明确“全部释放”是外部可观测原子性，还是尽力清理后失败；前者需有可实现的单线性化点。

- [重要 I2] 状态根/命名空间/测试隔离契约缺失，R9 的 inventory 无从执行。证据：`requirements.md:42,57-58,67-68` 要求核对租约文件数、原 token 持有不变和 stale 回收，但 `requirements.md:13-44` 没有规定生产状态根如何选择，也没有受管的 fixture override；`PLAN.md:37` 要求新回归只用 `mktemp` 隔离。后果：测试要么猜实现私有路径，要么触碰开发机共享租约；实现也可在 `${TMPDIR}`、`XDG_RUNTIME_DIR` 或 workspace 内各自选位置，不能保证真的跨会话命名空间相同。状态根若已是 symlink/异 owner/宽权限目录时的行为也未定义。建议修法：固定生产 root 选择、同 EUID 私有权限/对象类型要求与一个仅用于受管测试的 root override，并让 R9 对该隔离 root 做完整 before/after inventory。

- [重要 I3] request 的规范化字节串与“冲突别名”没有唯一定义。证据：`requirements.md:22` 只说“稳定摘要”，没有 hash 算法、规范记录结束 LF 或字节级序列化；`requirements.md:28-30` 不规定空文件/空行/CRLF/末行无 LF，也未说 workspace 相对路径按哪个 cwd 解析；“重复三元组”和“冲突别名”同时出现，但术语章 `requirements.md:17-22` 没定义后者。特别地，android TSV 本身只有 instance ID，无 serial/name 字段，因而不存在第二个可供检测的“别名”。后果：同一 request 可得到不同 hash/token，workspace 软链/相对路径重合行是按原文还是 realpath 后判重不明，空 request 甚至可“成功获取零个资源”。建议修法：固定 request 至少一行，逐行先验证/对 workspace 做 realpath，再按 C locale 排序；规定任意两行规范化后 `domain+canonical_id` 相同就是 request 内冲突/`2`（包含同 mode 重复、workspace 原始别名、android device/cvd 异名）；将有终结 LF 的规范 TSV 字节串和 SHA-256（或其他选定算法）写死，并固定 cwd 是函数调用时工作目录。

- [重要 I4] R9/验收清单的关键 oracle 不能证明所声称的 serial/name 隔离、排序和 token 三要素。证据：`requirements.md:42,54` 要求用“不同 serial/CVD name 作命令参数”验证同 instance 互斥，但本片唯一 API `requirements.md:28` 不接收命令 argv/serial/name，且 `requirements.md:73,76` 明确不实现 06 command runtime 或调用 device/CVD；`requirements.md:55` 的“按 C locale 排序后全有或全无”只能证明组合结果，不能排除全局大锁、输入顺序取锁或未排序恰好未死锁的 mutant；`requirements.md:57` 只测错 token/他人 token，未规定如何分别反证 session 与 request-hash 绑定。后果：测试可以在标签里写两个 serial/name 但从不把它们传到任何受测路径，也可用一个过度串行的全局锁取得绿灯；排序和 hash 绑定是否真实存在无法判定。建议修法：在 test 内定义明确的假上层 adapter，将 serial/name 仅记录为 argv，将同一 instance ID 生成两个 request，并对“命令零次执行+后到者 rc3”做双 oracle；另加逆序多资源并发 barrier 或受控 trace 来反证未排序/部分持有，并用独立的 owner/session/request 维度损坏 fixture 反证三要素。

- [重要 I5] `docs/resource-leases.md` 被称为“租约协议文档”，但 R8 只验一小部分接口，无法作为 06/08 的稳定消费契约。证据：`requirements.md:40,59` 只要求签名、三列、四组对、互斥、返回码与 instance ID 声明；却没有要求文档说明 `requirements.md:22,30-38` 的规范化/hash、组合全有全无、幂等重入、owner 匹配、有界等待、stale 回收、存活 owner 不抢占、release 后置条件和错误双流。`PLAN.md:82,189-190` 则将该文档/两函数作为 04 的全部边界交给 06/08。后果：本片测试即使全绿，后序实现者仍必须阅读本期内部 requirements 或猜测运行协议，文档会在交付时已经不完整。建议修法：让 R8/验收清单覆盖完整的 public contract，特别是 B1/B2/I1 修正后的主体矩阵和全错误表。

### 次要

- [次要 S1] 有界等待的时间语义不够抗抖动。证据：`requirements.md:38,58` 写“最多等待该整数秒/窗口耗尽”，却未固定 monotonic 截止时间、最后一次尝试边界和测试容差。后果：基于 `sleep 1`/wall clock 的实现可超窗，严格耗时断言又会在负载下闪断。建议修法：固定 monotonic deadline，说明 deadline 前释放是否必须做最后一次尝试，并给验收时间只用于防挂死的宽容差，主 oracle 用 barrier/状态而不是精确 wall-time。

- [次要 S2] exact3/400 和 NEXT 05 顺序门在文字上自洽，但 400 行可实施性尚无任何 sizing 证据。证据：`requirements.md:15,44,62,66` 与 `PLAN.md:29,55-56,67,82` 对齐了严格串行、三文件、总 numstat `<=400` 和 04 后才启动 05；`DECISIONS.md:47` 也证明 03e 门已满足。但本需求同时要求跨进程组合租约库、完整协议文档与并发/wait/stale/token/inventory 测试；相邻切片中仅 snapshot 库+基础测试已用满 400 行（`DECISIONS.md:41`）。后果：本轮不必因为尚未进入 design 就判定超门，但若不在 design 有 runnable fixed-format prototype，极易执行期再次回流 PLAN。建议修法：在 design 门用真实 shfmt 后三文件原型证明 `<=400`；不足时按 PLAN:67 先拆片，不删减承重 oracle 强行过门。

## ① 规格符合性

**NEEDS_CHANGES。** R1/R2 的两函数公共面、三列 TSV、四组 domain/mode、workspace `realpath`、android-instance-id 而非 serial/name、`0|2|3`、三文件边界、04→06/08 直接边、rollback 方向与不调真实 ADB/CVD/build 都与 `PLAN.md:82,138,173,189-190,213` 和 `DECISIONS.md:9-10` 对齐，未发现把 06/08 实现偷渡进 04。exact3/400 和 NEXT=05 的物理缺席门也与全局严格串行及 03e 已验收状态一致。

但 B1/B2 使最核心的 owner 生命周期、幂等性和跨会话独占不具备唯一语义；I1-I4 又使实际错误路径、状态隔离、request hash 与验收反证无法闭环。因而不能依当前文本进入 design。

## ② 文档质量

**NEEDS_CHANGES。** 文档结构清楚，R1-R10、验收清单、不变量和超出范围有较好的表面对应，且引用的 PLAN/DECISIONS 主体真实。但 owner/冲突矩阵、request canonical bytes、状态根、完整错误表均未在术语或协议需求中定义，R8 要求的最终文档也不包含多数承重语义；R9 若按字面实现，可以产生无法反证 mutant 的假绿。修复 B1/B2 后应同步重写术语、R4-R9 和验收清单，避免各处重复但仍留白。

## 已核对通过的重点

- android lease key 是显式安全 `android-instance-id`，serial/CVD name 不作 key，与 `DECISIONS.md:9` 一致。
- wait 由参数显式传入且限制 `0..300`，没有猜测未约束环境变量，与 `DECISIONS.md:10` 及 `PLAN.md:158` 的后序控制面一致。
- `requirements.md:44,62,66` 的 exact3/400、candidate/full/depth-1/rollback 与 six-column manifest 意图对齐 `PLAN.md:67,82`；本轮仅保留 S2 的 sizing 风险，不将其误判为已超门。
- NEXT 05 虽然直接依赖仅是 02，但 `PLAN.md:29,55-56` 另有实现类 spec 严格串行；因而 R10 在 04 dependency-present 验收证据入 ledger 前禁止创建 05 执行资产是自洽的。
- 未发现调研外范围产品功能、真实设备/网络依赖、修改 02/03e 或提前实现 06/08 的范围偷渡。
