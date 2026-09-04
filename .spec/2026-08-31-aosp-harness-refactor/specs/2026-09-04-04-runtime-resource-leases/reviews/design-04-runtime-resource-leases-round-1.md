# Review: 04-runtime-resource-leases design round 1

verdict: **NEEDS_CHANGES**  
阻断: **1** / 重要: **4** / 次要: **1**

审查范围仅为本片 `design.md`、同目录 `requirements.md` 与 `prototypes/` 三文件，并对照 `PLAN.md`、`DECISIONS.md`；未修改被审文件。

## ① 规格符合性

**NEEDS_CHANGES。** 纸面映射与边界基本正确：R1–R10 在 `design.md:15-20` 全覆盖；`requirements.md:4-5` 的 `消费`/`产出` 与 `design.md:45,49` 经逐字程序比较均完全相同（长度分别 254/645）；三交付文件与 `PLAN.md:82,138` 一致；NEXT `05-verifier-contract` 的五类资产当前物理缺席，`design.md:180,209` 的顺序门也与 R10 一致。owner 采用 Bash `$$` 而非 `BASHPID`，`/proc/<pid>/stat` field 22 索引正确，token 公式在正常记录上确实绑定 owner/session/request-hash/nonce；单 active JSON record 加同一 `.lock` 下 rename 的正常路径也能给出 bundle 级 publish/unpublish 线性化点。

但 R10 的门③不是“行数相加即可”，而是要用真实 runnable prototype 证明完整设计可在 exact3/400 内实施。当前原型虽确为 267+7+113=387 行、`bash -n`/ShellCheck 0.9.0/默认实跑也均通过且输出恰 29 bytes，但它尚未实现若干核心 fail-closed/I/O 机制，113 行测试也未执行 R9 的多数承重 oracle，且已有可复现假绿。因此 `design.md:195-199` 的 feasibility 结论不成立，按 `requirements.md:47,67` 与 `PLAN.md:67` 必须回流拆片或先给出修复后仍 ≤400 的完整 runnable 证明。

## ② 设计质量

**NEEDS_CHANGES。** “短 flock + 单 bundle record + monotonic wait + `EUID/$$/starttime` owner”是合适的主架构，正常 acquire/reentry/contention/stale/release 路径也可运行。问题集中在安全边界和证明闭环：strict record 实际并不 strict；worker 外层没有把工具失败收敛到 public 协议；墓碑恢复状态机只写在设计里；Python 版本下限与所用 API 矛盾；测试与文档尚未达到它们声称的完整性。继续直接进入 tasks 会把这些机制和大量主动反证挤进仅 13 行名义余量，风险不是普通实现偏差，而是再次触发 PLAN 的 400 行/P5 熔断。

## Findings

### 阻断

- **[阻断 B1] `design.md:186-199` 的 387/400 runnable sizing 证明不成立，R10 要求的回流条件已经触发。** 证据：算术和基础运行结果真实（267+7+113=387；默认测试 rc0、stderr 0、stdout 精确 `RESULT PASS  resource leases\n`），但 `prototypes/tests/test-resource-leases.sh:3-6` 只检查 `$1`，实际运行 `bash .../test-resource-leases.sh all extra` 得到 **rc0 和 PASS**，直接违反 R9/`design.md:168`；`:21-23` 仍用会吞末 LF 的 command substitution 核成功流，与 `design.md:184` 自己的字节级策略相反；`:58` 只查三类 glob，不做完整 before/after inventory；`:69-78` 只做 owner/session/request/hash 的浅表改值，未覆盖 token/nonce、他人 sentinel、acquire 遇损坏 record；整份测试没有反向多键 barrier、PID-reuse、live positive timeout、完整同-owner 子/超/部分重叠矩阵、root 类型/owner/mode 矩阵、open/write/fsync/replace/unlink 注入、假 adapter command-count、docs 对应关系、default/all/unknown/extra/library-absent 矩阵。更重要的是，production prototype 本身还需要下列 I1–I4 的实质修复。后果：现有 13 行余量既没有覆盖完整 R9，也未包含使 runtime 达到其数据模型/错误表所需的机制；`design.md:199` 所称“只收敛重复 capture block 即可补齐完整性/失败全矩阵”没有 runnable 证据支撑。修法：依 R10/PLAN:67 回 PLAN 拆片，优先采用“04 runtime+协议+基础测试 / 后继 assurance 片独占完整 mutation、I/O、并发矩阵，并在 06/08 前设 dependency-present 门”的既有 03b/03b1 模式；若坚持单片，则必须先提交修复 I1–I4、覆盖完整 R9 且 fixed-shfmt 后仍 exact3/≤400 的新 runnable prototype，不能以压缩承重 oracle 换行数。

### 重要

- **[重要 I1] `design.md:89-101,161` 宣称的 strict active-record fail-closed 并未由原型实现。** `prototypes/common/.harness/lib/resource-leases.sh:116-141` 用默认 `json.load`（重复 JSON key 会静默取最后值），只重算 base64/hash/token；对 stored request 使用 `request.rstrip(b"\n").split(...)`，因而不要求“恰一个终结 LF”，也不重新验证四组 domain/mode、安全 android ID、workspace 绝对/控制字节、C 顺序和 canonical bytes；owner/session 的精确类型/值域以及 active 文件为 nofollow regular 也未完整验证，跨 record 重叠这一全局不变量亦未检查。定点探针把一个 live record 改成自洽的 `android<TAB>bad<TAB>bogus`（无末 LF），同步重算 hash/token/文件名后，再 acquire 不相交资源，实测 **rc0、33-byte token、active_count=2**，而不是全局 rc2。后果：损坏状态可被当作合法 live/stale 状态继续使用或释放，违背 R5/R6 及 DECISIONS 2026-09-04 的“任一非法 schema/hash/token/owner record fail closed”。修法：设计并原型化单一 strict decoder：拒绝 duplicate JSON keys；逐字段做非 bool 的精确类型/范围检查；base64 解码后验证非空、恰一末 LF、三列、合法 pair、安全/绝对 ID、控制字节、排序、唯一键、重新序列化逐字节相等；nofollow+fstat active 文件；扫描完全部 record 后再验证全局 key 不重叠，之后才允许 stale/matrix/release 变更。

- **[重要 I2] public facade 没有把 Python/tool/output I/O 失败收敛为承诺的 `0|2|3` 固定双流，也没有保护“失败不留 active”后置条件。** `design.md:53,158-165` 写的是固定错误出口；但 prototype `:9-13` 只用 `command -v` 后直接执行 `python3`，原样透传解释器退出状态。把 PATH 首个 `python3` 指向 `/usr/bin/false`，实测 acquire **rc1、双流空**，而不是 rc2+固定 operation-failed。另一个定点探针在关闭 stdout 后调用 acquire：`.lock` 的 `os.open` 复用了 fd 1，`:185/:213` 的 `os.write(1, token)` 把 token 写进 `.lock`，函数 rc0 且 active_count=1，调用者却没有收到 token；这也显示 worker 把数字 1/2 当稳定输出通道的假设未被 preflight。后果：工具损坏可泄漏任意 rc/输出；输出通道异常可在 publish 后形成不可由调用者释放的成功租约，违反 R4/R5。修法：给 facade/worker 定义可验证的内部结果协议，执行前验证并固定 stdio fd，捕获 worker 输出与状态后只允许白名单形状/rc，再由 facade 发 public 输出；任何非协议 worker 结果统一 rc2。还需明确并实现 publish 后 public token 输出失败时的回滚/后置条件，或回 requirements 明确受支持的 stdio 前置条件；相应 fake-python、closed/broken-output probe 必须进入测试。

- **[重要 I3] `design.md:39` 的 Python 3.8+ 下限与 runnable prototype 不兼容。** prototype `:78` 调用 `os.path.realpath(candidate, strict=True)`；`strict` 参数从 Python 3.10 才加入，Python 3.8/3.9 会在每个 workspace request 上抛 `TypeError` 并固定失败。当前机器是 Python 3.12，所以默认 prototype 绿不能证明声明的 3.8 下限。后果：文档化支持环境上的核心 workspace lease 全部 rc2。修法：改用 Python 3.8 已支持的 `pathlib.Path(...).resolve(strict=True)`（并验证 bytes/surrogateescape 语义保持一致），或将技术下限提升到 3.10 并同时对齐 02/requirements/文档；增加 3.8/3.9 语法与 workspace 行为证据，至少不能继续用 3.12 单点运行声明 3.8 兼容。

- **[重要 I4] unpublish 后 unlink 失败的恢复状态机只存在于设计文字，prototype 永远不重试 tombstone。** `design.md:101,167` 明确承诺 release 已逻辑失效但留下 `.trash-*` 时“下次受锁操作在安全验后重试清理”；而 prototype `:142-152` 只枚举 `active-*`，`:153-156` 当次 rename 后 unlink，后续 acquire/release 没有任何 `.trash-*` 扫描、验证或重试。相同 helper 还用于 stale 回收，但错误表 `design.md:164` 写“对调用方透明”、`:167` 又只描述 release unlink failure，没有定义 stale unpublish 成功而 unlink 失败应 rc2 还是继续 acquire。后果：一次 unlink EIO/EPERM 会永久残留墓碑，R9 的完整 inventory 后置条件无法恢复，错误表与实际状态机也不唯一。修法：在持锁变更前加入严格验证的 tombstone recovery（只清理可证明由协议产生且已不 active 的普通文件），定义任一清理失败的 rc/active-set 后置条件；把 release 与 stale 两条 unlink-failure 行分别写进错误表并用 monkeypatch probe 证明。

### 次要

- **[次要 S1] 7 行 prototype 协议文档仍缺 R8 要求的 release/cleanup 后置条件。** `prototypes/docs/resource-leases.md:6-7` 只说 release 验证后 unpublish，并把所有 I/O 失败概括为 rc2；没有说明 active→trash 已发生但 unlink 失败时租约已经逻辑失效、重复 release 仍失败、墓碑由后续锁操作安全重试，也没有区分 stale cleanup 的同类失败。后序 06/08 因而无法仅凭该文档判断 release rc2 后是否仍需阻止命令或重试。修法：在 I4 状态机定稿后把两个线性化点和各 I/O 窗口的 active/tombstone 后置条件写进最终 docs，并让结构测试与实现常量/错误表对应。

## 已核对通过的重点

- `requirements.md:4-5` 与 `design.md:45,49` 的消费/产出逐字一致；R1–R10 映射无缺项。
- Bash command substitution 中 `$$` 保持外层 shell PID，prototype 默认路径实际证明父 shell可 release；`/proc/<pid>/stat` 在最后 `)` 后的索引 `[19]` 对应 field 22 starttime，PID-reuse 方向正确。
- token 正常路径确实按 JSON `[owner, session, hash, nonce]` 的 SHA-256 前 32 hex 生成并在 decode 时重算；nonce 为 32 lower-hex。I1 指的是 decoder 没有先证明这些输入是完整规范状态，不是否认该绑定公式。
- 合作进程模型下，所有正常 active 扫描/冲突判定/rename 都在同一 exclusive flock 内；单 record 承载完整 request，正常路径没有逐 key 的部分 publish 窗口。
- root 选择、绝对路径、现有根 `lstat`/EUID/0700、`.lock` `O_NOFOLLOW`/regular/EUID/0600 的纸面设计与 R5 一致；本轮未把同 EUID 恶意进程任意改写纳入超出威胁边界的要求。
- 三文件路径、PLAN 独占边界、rollback 方向和 NEXT 05 五类资产缺席门一致；当前仓库未发现提前创建的 05 spec/ref/worktree/BASE/dispatch 资产。

## 结论与回流建议

本轮结论为 **NEEDS_CHANGES（1 阻断 / 4 重要 / 1 次要）**。先处理 B1：按 PLAN 门拆出 assurance 片，或拿出包含 I1–I4 和完整 R9 的新 fixed-format runnable ≤400 证据；在此之前不应进入 implementation，也不得解除 NEXT 05 顺序门。
