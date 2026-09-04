---
id: 2026-09-04-04-runtime-resource-leases
依赖: [2026-09-01-02-offline-quality-gate]
消费: "scripts/check.sh --offline|--ci 的根测试自动发现约定：本片产出默认可执行的 tests/test-resource-leases.sh，由 gate 按 LC_ALL=C 字典序发现；成功时 scripts/check.sh --offline 退出 0 且 stdout 末行为 RESULT PASS  aosp-harness offline quality gate。本片不调用 check.sh 作为独立判据，也不修改 02 的 tests/COVERAGE.md。"
产出: "resource-leases-v1 —— source common/.harness/lib/resource-leases.sh 后 declare 可见 harness_lease_acquire <session-id> <wait-seconds> <request-tsv> 与 harness_lease_release <lease-token>；request-tsv 为至少一行的普通文件，每行 domain<TAB>canonical_id<TAB>mode；workspace canonical_id 以调用时 PWD 解析后的 realpath 绝对路径为键，android canonical_id 为安全单组件 android-instance-id（不是 serial 或 CVD name）；任意不同逻辑 owner 对同一 domain+canonical_id 的任意合法 mode 都互斥；逻辑 owner 为 EUID+$$+进程起始标识，请求按 C locale 规范化后取 SHA-256；acquire 成功 stdout 唯一 token+LF、release 成功双流空；两者 0 成功、2 协议/所有者/状态或 I/O 错、3 占用/超时；配套完整协议 docs/resource-leases.md 与 tests/test-resource-leases.sh 固定摘要 RESULT PASS  resource leases"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户已授权后续按autopilot执行；PLAN v5.8 lease assurance 拆片经三轮增量 review 最终 PASS（0/0/0），稳定 resource-leases-v1 public API 与本片 exact 三文件不变，完整 mutation/I/O/concurrency/adapter 穷举移交 04a；DECISIONS.md 2026-08-31 I1/I2 的 android-instance-id 与显式 wait 裁定保持；03e 验收已满足本片启动门
---

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并确认后续按 autopilot 执行。PLAN v5.8 要求本片实现跨进程组合租约并保留全部运行时正确性、完整协议与代表性基础合同测试；完整 TSV/root/stored-state/I/O/concurrency/adapter mutation 矩阵由紧随其后的 04a 独占。稳定 public API、request TSV、owner、bundle 原子性、wait/stale/release 与 `0|2|3` 协议不因拆片变化。

## 目标

交付 `resource-leases-v1`：新增 `common/.harness/lib/resource-leases.sh`、`docs/resource-leases.md`、`tests/test-resource-leases.sh` 三文件。source 库文件后 `declare` 可见 `harness_lease_acquire` 与 `harness_lease_release` 两个公开函数，签名分别为 `harness_lease_acquire <session-id> <wait-seconds> <request-tsv>` 与 `harness_lease_release <lease-token>`。request 的 `domain` 只允许 `workspace|android`，workspace 的 `canonical_id` 用调用时 `PWD` 与 `realpath` 规范化，android 的 `canonical_id` 是安全 instance ID；状态命名空间由 `HARNESS_RESOURCE_LEASE_ROOT` 或默认运行时根唯一选择。每个规范 `domain+canonical_id` 是跨逻辑 owner 完全独占的资源键，mode 只标识用途，不把同 mode 降级为共享。一个 request 作为单个 bundle 只在唯一 publish 点整体可见，释放也先在唯一 unpublish 点整体失效。acquire 成功 stdout 唯一 token+LF，release 成功双流空，返回码 `0|2|3`；provider 仅保留恰一个私有 no-op `HARNESS_RESOURCE_LEASE_TEST_SEAM` anchor，运行时不由环境激活。本片不 source 03 会话模块、不设置 `HARNESS_SESSION_STATE_PROVIDER_VERSION`、不调用真实 ADB/CVD/AOSP build、不修改 02 的 `tests/COVERAGE.md` 与 03e/session 既有文件；本片 accepted/dependency-present 证据入 ledger 后只可启动 04a，04a 缺席或 inert PASS 不得启动 05/06/08。

## 术语

- 「安全单组件」：长度 1–128 的 ASCII 串，匹配 `^[A-Za-z0-9][A-Za-z0-9._-]*$`，并拒绝空串、控制字节、`.` / `..` 组件与 `/`。`session-id` 与 android 的 `canonical_id`（即 `android-instance-id`）都必须满足。本片在 lease 库内独立实现该谓词，不 source `session-state-foundation.sh`。
- 「合法 domain/mode 对」仅四组：`workspace+source`、`workspace+build`、`android+device`、`android+cvd`。
- 「逻辑 owner」：调用时的 `EUID`、Bash `$$` 与 Linux `/proc/$$/stat` 进程起始时间三元组；不使用 command substitution 内会变化的 `BASHPID`。因 Bash command substitution 保留 `$$`，`token=$(harness_lease_acquire ...)` 返回后同一逻辑 owner 可在父 shell 释放。PID 存在但起始时间不匹配等同原 owner 已死亡，防止 PID 复用。
- 「stale-owner」：持有 bundle 记录中的 `EUID+PID+起始时间` 不再匹配当前进程表；三元组仍匹配则为存活 owner。
- 「规范 request」：输入必须是至少一行、以 LF 结尾的非空 POSIX 文本；禁止空行、CR、NUL 与非三列行。每行先校验，workspace 相对路径以函数调用时 `PWD` 为基准做 `realpath`；`realpath` 结果中任一 ASCII 控制字节 `0x00..0x1f` 或 `0x7f` 都使整个 request 非法，不做转义。合法行再以 `domain<TAB>canonical_id<TAB>mode<LF>` 序列化，按 `LC_ALL=C` 的 domain、canonical_id 排序。规范化后任意两行的 `domain+canonical_id` 相同即为 request 内冲突，包括重复三元组、workspace 原始别名与 android 的 device/cvd 异名。
- 「request hash」：对规范 request 完整字节串计算的小写十六进制 SHA-256。输入行顺序不影响摘要。
- 「状态根」：显式非空 `HARNESS_RESOURCE_LEASE_ROOT` 优先，否则是 `${XDG_RUNTIME_DIR:-/tmp}/aosp-harness-resource-leases-$EUID`。路径必须是绝对路径；库可创建末级目录，但已有根必须是不跟随软链的 EUID 自有 `0700` 真目录，否则 fail closed 为 rc 2。所有合作进程必须使用同一状态根；测试只把该变量指向自建 `mktemp -d` 私有根。

## 需求

R1. [计划] 当调用方 source `common/.harness/lib/resource-leases.sh` 时，系统必须返回 0、定义且仅新增 `harness_lease_acquire` 与 `harness_lease_release` 两个公开函数（均可 `declare`），不得定义会话状态四 API、不得设置 `HARNESS_SESSION_STATE_PROVIDER_VERSION`、不得 source 03 会话模块。（依据 PLAN.md:82 独占「lease 公共库」与 PLAN.md:138 产出两函数签名）

R2. [计划] 当调用 `harness_lease_acquire <session-id> <wait-seconds> <request-tsv>` 时，系统必须把第三参当作普通文件路径读取 TSV：每行恰好 `domain<TAB>canonical_id<TAB>mode` 三列；`domain` 只能是 `workspace` 或 `android`；只接受四组合法 domain/mode 对；workspace 行必须以 `realpath` 成功得到且不含 ASCII 控制字节的绝对路径作为 `canonical_id` 键；android 行必须以安全单组件 `android-instance-id` 作为 `canonical_id` 键，ADB serial 与 CVD name 不得作为 lease key。（依据 PLAN.md:138 与 DECISIONS.md 2026-08-31 I1）

R3. [计划] 当一次 request 含一行或多行时，系统必须先生成术语所定的规范 request 与 SHA-256，再把整个 request 作为单个 bundle 在一个 publish 点全有或全无地对其他 owner 可见；任一失败路径不得留下 active 的部分 bundle。不同逻辑 owner 只要 request 与已有 bundle 的任一 `domain+canonical_id` 相交，无论两边 session 是否相同、mode 相同或不同，都是占用；同一 request 内规范键重复则在 publish 前返回 2。（依据 PLAN.md:55,138 「跨会话独占租约」「多资源按 domain+canonical_id 排序后全部获取或全部释放」）

R4. [计划] 当 `harness_lease_acquire` 参数合法且目标资源可立即持有或在等待窗口内可持有时，系统必须返回 0、stderr 空，并向 stdout 只打印当前 active bundle 中唯一的 token 加一个 LF。只有「逻辑 owner 相同 + `session-id` 相同 + request hash 相同」的完整重入才必须幂等返回既有 token/0；同 owner 对已持有键的任何其他部分重叠、子集、超集、session 变化或 request 变化都必须立即返回 2，不进入等待；同 owner 的不相交 request 可分别持有。（依据 PLAN.md:138「acquire stdout 唯一 token」「token 必须与 owner/session/request hash 同时匹配」）

R5. [计划] 如果发生参数个数错、`session-id` 非安全单组件、`wait-seconds` 非 `0..300` 十进制整数、request 非可读普通文件或不符合规范 request、domain/mode 非法、workspace `realpath` 失败或结果含 `0x00..0x1f`/`0x7f`、android instance ID 非法、同 owner 持有键上发生非完整重入，或逻辑 owner、SHA-256、状态根、状态完整性、必需工具、时钟与 I/O 任一无法安全判定，系统必须 fail closed 返回 2，stdout 空且 stderr 逐字节为 `error: resource lease operation failed\n`。acquire 的该类失败不得发布新 active bundle；清理未发布临时资产失败仍返回 2，其残留不得被解析为 active 租约。（依据 PLAN.md:138 返回码 2=协议/所有者错且只允许 `0|2|3`、DECISIONS.md 2026-08-31 I1/I2）

R6. [计划] 当调用 `harness_lease_release <lease-token>` 且 active bundle 记录的 token、owner 三元组、session 与由存储的规范 request 重算的 hash 全部自洽且当前逻辑 owner 匹配时，系统必须先在单一 unpublish 点使整个 bundle 对其他 acquire 失效，再清理其状态，成功返回 0 且双流空。缺参/多参、token 不存在或重复释放、owner 不匹配、session/request/hash 元数据被篡改、状态或 I/O 失败必须返回 2 与 R5 的固定双流，且不得 unpublish 任何无法完整验证或属于其他 owner 的 bundle。（依据 PLAN.md:138「release 成功无 stdout」「token 必须与 owner/session/request hash 同时匹配」）

R7. [计划] 在有界等待与持有期间，系统必须使 `wait-seconds=0` 只尝试一次，正值从首次尝试前的 monotonic 时钟计算 deadline，在 deadline 到达时做最后一次无 sleep 尝试后停止。不同存活 owner 的任意键相交都不得抢占：窗口耗尽返回 3，stdout 空且 stderr 逐字节为 `error: resource lease unavailable\n`；stale-owner bundle 必须先整体 unpublish 再允许新 owner 获取。同 owner 重叠且不是 R4 完整重入时按 R5 立即返回 2，不等待自己。（依据 PLAN.md:138「有界等待、主动释放和 stale-owner 回收，不抢占存活 owner」）

R8. [计划] 系统必须提供 `docs/resource-leases.md`，正文必须完整记载两函数签名、TSV 三列与四组合法对、android 键为 `android-instance-id` 而非 serial/CVD name、状态根选择与安全条件、逻辑 owner/PID 复用/command substitution 语义、规范 request 字节串与 SHA-256、键级完全独占与 R4 重入矩阵、bundle 全有全无、monotonic 有界等待、stale 回收、release unpublish/清理后置条件，以及 `0|2|3` 的固定 stdout/stderr 错误表。（依据 PLAN.md:82 独占「lease 协议文档」及 PLAN.md:189-190 后序消费边）

R9. [计划] 系统必须提供默认发现且 shfmt-clean 的 `tests/test-resource-leases.sh`，只接受无参数或 `all`，并把 `HARNESS_RESOURCE_LEASE_ROOT` 指向独立 `mktemp -d` 的 `0700` 绝对路径。默认/all 的基础合同矩阵必须逐字验证：source surface；acquire 33-byte token framing 与逆序 request 的同 token 完整重入；同 owner 换 session 立即 rc2；不同 owner 相交 rc3；不相交 bundle 可同时持有；死 owner stale 回收；非法空 request rc2；自洽但非法 stored request 导致全局 rc2；合法 tombstone 在下一受锁操作恢复；版本探针通过但 worker 返回任意 rc/双流的假 Python仍收敛固定 rc2；最终完整 inventory 只允许可选持久 `.lock`、不得有 active/tmp/trash 或未知资产。生产库必须含恰一个 `HARNESS_RESOURCE_LEASE_TEST_SEAM` 私有 no-op anchor，供 04a 复制 provider 后唯一替换；本片测试不得启用该 seam。库缺席不得打印成功摘要；成功唯一摘要为 `RESULT PASS  resource leases\n`，unknown/extra/flag 带值返回 1 且无摘要。完整 control/root/self-overlap/barrier/PID-reuse/monotonic/全 record 字段/I/O/closed-output/双 adapter/mutant 矩阵属于 04a，不得为扩充本片基础测试而删除运行时机制或突破 exact3/400。（依据 PLAN v5.8 04/04a 文件独占与 P5 拆片）

R10. [计划] 当本片进入验收时，系统必须在 candidate、完整历史 checkout 和真实 `git clone --depth 1 file://...` 中分别运行默认 lease 测试与 `bash ./scripts/check.sh --offline`，自动发现本入口恰好一次；controller 必须先逐字验证 shfmt `v3.14.0` 与 ShellCheck version field `0.11.0`，再只对本片两个 shell 文件运行 `shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning` 与 `bash -n`；execution BASE 到 accepted HEAD 必须 exact 只新增上述三文件、numstat 总和 `<=400`；从 accepted HEAD 建立隔离临时分支提交 exact 只回退这三文件的 rollback commit 后，既有 03e 生命周期入口与 offline 全绿且本入口发现 0 次。门③必须以真实可运行且 fixed-shfmt 后的三文件 prototype 给出 exact3/`<=400` 证据；当前批准基线为 `336+7+57=400/400`，任何超门都必须再次回流 PLAN，不删运行时机制或基础 oracle。controller 只有在本片 accepted HEAD、dependency-present 证据、exact3/400 与全 PASS manifest 入 ledger 后，才可创建规范 ID `04a-runtime-resource-lease-assurance`（日期前缀由创建日决定）的 spec 目录、同名 `spec/` 分支/worktree、ledger execution BASE 或 dispatch 记录；此前这五类资产必须物理缺席；requirements/design/tasks 与本片 `prototypes/assurance/` sizing 资产允许出现 NEXT 全名，禁令只针对 04a 的真实 spec/ref/worktree/ledger/dispatch；05/06/08 继续由 PLAN 的 04a dependency-present 门阻止。（依据 PLAN v5.8 审查规模、NEXT、04a 回滚与依赖边）

## 验收标准

主验证命令: bash ./tests/test-resource-leases.sh
期望输出: 退出码为 `0`、stderr 空，stdout 逐字节精确为 `RESULT PASS  resource leases\n`

验收清单:

- [ ] source `common/.harness/lib/resource-leases.sh` 后 `declare` 可见 `harness_lease_acquire` 与 `harness_lease_release`，不可见四个会话状态 public API，且 `HARNESS_SESSION_STATE_PROVIDER_VERSION` 未被本库设置。
- [ ] 合法 workspace key 等于以调用时 `PWD` 解析的 `realpath`；android key 等于安全 instance ID，serial/CVD name 不进入 provider key；完整双 adapter 主动反证由 04a 独占。
- [ ] 规范 request 至少一行并以 LF 结尾，无空行/CR/NUL；workspace `realpath` 结果含任一 ASCII 控制字节时 rc 2；逆序的同一组行得到同一 hash/token；任一规范 `domain+canonical_id` 重复（同 mode、异 mode 或 workspace 原始别名）均在 publish 前返回 2。
- [ ] 不同 owner 对同 key 的同 mode/异 mode 都返回 3；同 owner+session+hash 完整重入返回既有 token/0，其余键重叠立即返回 2；不相交 bundle 可同时持有，反向多键并发无 active 部分 bundle。
- [ ] 参数/request/状态根/状态完整性/工具/时钟/I/O 无法安全判定均 rc 2、stdout 空且 stderr 为固定 operation-failed 行，不发布新 active bundle；占用/超时 rc 3 且 stderr 为固定 unavailable 行。
- [ ] acquire 成功 stdout 恰好 token+LF 且 stderr 空；release 成功在单一点使 bundle 整体失效，rc 0 且双流空；错误/他人/重复 token 及 owner/session/request/hash 任一篡改返回 2，不释放其他 bundle。
- [ ] wait=0 只尝试一次；正值使用 monotonic deadline 且有最后一次无 sleep 尝试；stale-owner 和 PID 复用记录整体回收；存活 owner 超时后原 token 仍可正常 release。耗时只用宽容 outer timeout 防卡死，主 oracle 用 barrier 与状态。
- [ ] 状态根默认选择与显式 override 均一致；软链/非目录/异 owner/非 0700 根 fail closed；每次测试只使用独立 `mktemp -d` 根，成功 release 后 active/临时/墓碑记录均为 0，前后完整 inventory 相同。
- [ ] `docs/resource-leases.md` 含 R8 所列完整 public contract，不需阅读本 requirements 即可实现 06/08 的 provider-present consumer。
- [ ] 默认与 `all` 得到唯一固定摘要 `RESULT PASS  resource leases\n`；unknown/extra 返回 1 且无该摘要；库文件缺席时无该摘要；provider 内 `HARNESS_RESOURCE_LEASE_TEST_SEAM` 恰一处且本片测试不启用。
- [ ] candidate/full/depth-1 的默认入口与 `bash ./scripts/check.sh --offline` 退出 0，offline 发现本入口恰好一次，depth-1 commit-count=1 且 shallow marker 非空。
- [ ] 门③真实可运行、fixed-shfmt 三文件 prototype 为 exact3=`336+7+57=400/400`；验收时 BASE..HEAD exact 三文件且 numstat 总和 `<=400`，rollback 只回退这三文件后 03e 入口与 offline 全绿、本入口发现 0；04a 的真实 spec/ref/worktree/BASE/dispatch 按 R10 机械查缺席。

不变量（不许劣化，2-4 项）:

- execution BASE..HEAD 除 `common/.harness/lib/resource-leases.sh`、`docs/resource-leases.md`、`tests/test-resource-leases.sh` 外的变更文件数 ≤ `0`，验证: `git diff --name-only "$BASE" "$HEAD"`。
- 对存活 owner 的抢占次数 ≤ `0`，验证: `bash ./tests/test-resource-leases.sh` 中不同 owner 的相交 request 返回 3，原 holder token 仍可 release；同/异 mode 与正值超时穷举由 04a 继续反证。
- 成功 `harness_lease_release` 之后 active/临时/墓碑记录总数 ≤ `0`，验证: `bash ./tests/test-resource-leases.sh` 在私有状态根 release 前后做完整 inventory。
- 既有 Claude 生命周期与离线门禁失败数 ≤ `0`，验证: `bash ./tests/test-claude-session-lifecycle.sh` 与 `bash ./scripts/check.sh --offline`。

## 超出范围

- 不实现 06 的 `harness_command_run`、不实现 08 的 wrapper/`compat: lease-provider=legacy` 输出；provider 缺席时 06/08 的 absent fixture 由那两片各自交付。
- 不修改 02 的 `tests/COVERAGE.md`、`scripts/check.sh` 或 CI workflow；不新增 coverage fragment（PLAN.md:82 对 04 只列三文件）。
- 不修改 03e 独占六文件与 session 上游十二 tracked 文件；不 source 03 会话模块。
- 不调用真实 ADB、CVD、AOSP build、Claude/Codex 客户端或外部网络；lease 库本身不发起 device/CVD 命令。
- 不交付 `tests/test-resource-leases-assurance.sh`，不在本片启用 test seam；完整 assurance 只由 04a 新增单文件。
- 不创建 04a 的真实 spec 目录、`spec/` 分支、worktree、ledger execution BASE 或 dispatch 记录，直到本片 dependency-present 证据入 ledger；不创建 05/06/08，直到 04a active 验收门通过。
- 不发布、不 push。
