# requirements 独立审查 · round 3

审查对象：`specs/2026-09-01-00-environment-seed-preflight/requirements.md`

依据：`PLAN.md` v4、`DECISIONS.md`、round 1/round 2 requirements review、当前 `requirements.md`、`references/03-requirements.md` 与 `references/07-review.md`。本轮只读审查规格；只运行三项静态 checker，没有运行主验证、真实 AOSP lunch、编译、下载、源码修改或 state-dir 写入。

## 结论摘要

- 最终结论：`NEEDS_CHANGES`。
- Findings：2 个阻断、6 个重要、2 个次要。
- 三项静态 checker：`check-req.py`、`check-criteria.py`、`check-analyze.py` 均 exit 0；它们没有覆盖跨文档 producer/consumer、POSIX 发布语义、证据 payload 可表示性和实际资源算法。
- round 2 的 POSIX commit-point 主问题已关闭：当前规格允许 object orphan，并承认 ref rename 后 durability uncertain；没有再要求不可实现的全量回滚，也明确禁止 dangling ref。
- round 2 的 public owner 和 closed schema 仍未闭合：00 虽被命名为双 scope owner，但批准的 PLAN 命令仍把同一个 `seed.json` 同时当 preflight 输入与后序 seed 消费物，当前验收又只要求 public `fixture_only` golden；同时 trace 的负 syscall result 与“所有 integer 均 unsigned”直接冲突，per-project `source_state_digest` 也没有定义算法。
- 未发现把 closure extract/materialize/prove/build 提前塞入 00 的 YAGNI 扩张；主要问题是已经纳入范围的 ABI 和 gate 仍有断点。

## round 2 findings 逐项复核（3 blocker / 7 important / 2 minor）

| round 2 finding | 状态 | round 3 结论 |
|---|---|---|
| B1 public AOSP17 seed producer→consumer 无 owner | ⚠️ 部分关闭 | R7/R11 已把两类 scope 和 00 owner 写入，但 PLAN 的 preflight input path、requirements 的 `seed-request/v1` input、后序 `seed/v1` consumer path仍互相冲突；00 的 gate 也可在没有 real public seed 时通过。见 B1。 |
| B2 POSIX publish fault 不可实现 | ✅ 核心关闭 | R22 与 commit-point matrix 允许 orphan object、区分 ref rename 前后并禁止 dangling ref，符合 DECISIONS。剩余问题是 publish/`REF_CORRUPT` 的错误 ABI及并发 ref 状态不闭合，降为 I1。 |
| B3 seed/source-state/trace/journal schema 未 closed | ⚠️ 部分关闭 | 顶层字段、domain separator、排序和 ref bytes 已大幅补齐；但 trace 的有符号 result 无法进入全局 unsigned integer schema，project digest 有悬空字段，trace path/argv 仍不足以独立重算承重分类。见 B2、I4。 |
| I1 dispatcher/direct/path 签名不完整 | ⚠️ 部分关闭 | direct argv 与 command regex 已固定，`.repo/repo` 已纳入枚举；但 stable out-ref namespace/confinement 没有成为规范，dispatcher 的 `commands.d` 基准目录也未固定。见 I2。 |
| I2 reason/error priority 不确定 | ⚠️ 部分关闭 | validation/environment priority 与 terminal ordering 已列出；但 output digest 产生后才能发现的 collision 被放到 pre-environment validation，`REF_CORRUPT` 未进入封闭状态机，publish exit 30 的 stdout/stderr 未固定。见 I1。 |
| I3 resource oracle 可错误 PASS | ⚠️ 部分关闭 | disk bytes、cgroup remaining 与 rational CPU 已补；但 request 的 memory/CPU minimum、32 GiB/8 默认、estimated disk upper bound 与 pass 算法没有闭合，cpuset/cgroup fallback 仍有多解。见 I3。 |
| I4 source-state/ignored coverage 不完整 | ⚠️ 部分关闭 | recursive untracked 和 observed ignored inputs 已纳入；但双路径 syscall、ignored symlink target 内容及若干写入 syscall 仍可漏过，无法支撑“源码 mutation=0”。见 I4。 |
| I5 R1/R2 来源混标 | ✅ 已关闭 | R1/R2 只保留用户给定路径/命令；caller expansion、cwd、OUT_DIR 和禁编译已拆到 `[计划]` 条目。 |
| I6 terminal/control/rollback gate 不可执行 | ⚠️ 部分关闭 | pre-merge gate、terminal→PLAN review 与 ledger SHA post-merge gate已分开；但 public real-source gate仍缺，rollback 的“direct fixture”没有固定身份和 exact direct output。见 B1、I6、M1。 |
| I7 人审预算无门禁 | ✅ 基本关闭 | R24 和 checklist 已把 800/160 设成 stop-and-replan gate；仅 actual diff 的检查时点文案仍自相矛盾，见 M2。 |
| M1 ref exact values 分散 | ✅ 已关闭 | ref 被固定为 RFC 8785 三字段加 LF，kind 值域和 digest resolution 也在同节给出。 |
| M2 “三段 fsync”含糊 | ✅ 已关闭 | 发布阶段已明确命名为 `OBJECT_TEMP` 至 `REF_DIR_FSYNC` 六阶段。 |

汇总：完全/基本关闭 5 项，部分关闭 7 项；部分关闭项中仍有 2 个阻断和 6 个重要缺口，不能 PASS。

## 阻断（2）

### B1. public AOSP17 的 owner 虽已命名，但实际 producer→consumer 路径与 gate 仍断裂

- PLAN v4 整体验收仍运行 `preflight --descriptor common/tests/fixtures/aosp17-services/seed.json`，随后 `extract` 和 `verify-proof` 又消费同一个 `seed.json`。
- 当前 requirements 明确 preflight 只能读取 `kind=seed_request`，并把 `common/tests/fixtures/aosp17-services/seed.json` 定义为只有从 `real_source` 输出复制/固化后才可存在的 `kind=seed`。因此该路径在 preflight 前不能同时是合法 request，在 preflight 后也没有已定义的 artifact/ref→fixture 发布步骤把它变成 seed。
- R7 把 00 写成 schema、producer 和 fixture 的唯一 owner，但本片主验收只要求 local LK7K real invocation，加一个 public `fixture_only` golden；R155 又允许 real public seed 尚不存在。于是 00 可以 `GATE CONTINUE` 并进入 01，而 PLAN 把 public environment 可用性放在最早 preflight 排除的目标没有实现。
- `seed/v1` 只发布到 state-dir object/ref；没有命令、ref 名或 owner 把 matching real public object交付到 PLAN 后序固定的 descriptor path。仅规定 02“只接受 real public”只能让断链晚一点失败，不能完成交接。
- 必须统一一个可执行链：例如 PLAN 的 preflight 输入改为 `seed-request.json`，固定 public out-ref，02/verify-proof 直接消费并重验该 ref/object；或明确由 00 的哪个 gate byte-for-byte 固化 `seed.json`，并在 real public exit 0 前禁止进入 01。PLAN、DECISIONS、requirements 和整体命令必须使用同一签名。

### B2. 标为 closed 的 evidence ABI 含不可表示字段和未定义 digest，无法产生唯一合法 bytes

- Stable data ABI 先规定“integer 均为 `0..2^64-1`”，但 `trace/v1.records[].result` 要记录全部 syscall 的 result，并以 `result >= 0` 区分成功。失败 syscall 的 `-1`/负 errno 返回值无法进入该 schema；丢弃失败记录又违反“全部 descendant process/file/network syscall”。这是直接的不可实现矛盾。
- `seed/v1.manifest.projects[]` 要求每个 project 含 `source_state_digest`，但 `source-state/v1` 只定义 workspace 顶层 digest，没有定义 per-project payload/domain separator，也没有规定该字段等于顶层 digest。两个实现可生成不同、均看似合规的 seed bytes。
- `trace/v1.argv_b64` 没有定义是 exec argv、原始 syscall argument bytes 还是某种 canonical serialization；`path_b64` 只有一个，而 rename/link/symlink 等承重 syscall含两个路径。它们不仅影响可读性，还决定 `source_mutation` 分类和 seed digest，不能留给 fixture/实现选择。
- 因此 round 2 B3 尚不能关闭。至少需允许 signed syscall result或拆为 `{success,errno/result}`，定义 per-project source-state digest，并固定 syscall argument/path 的 canonical 表示后，golden 才只是规范例子。

## 重要（6）

### I1. publish commit-point 已可实现，但 publish error/ref recovery ABI 仍不是封闭状态机

- `DIGEST_COLLISION` 被列在“先于所有 environment checks”的 validation priority，并声称因先于 publication 不产生 object；但 output object digest 依赖 lunch、trace、source-state 或 terminal observations，必须在环境运行后才能得知。当前优先级在时间上不可执行，也没有说明 collision 应覆盖原始 exit 0 还是 exit 20。
- matrix 提到 replay 读到其他 bytes 时为 `REF_CORRUPT`，但该 code 不在 validation enum、publish matrix或 stdout/stderr/exit 映射中。
- R21 只固定 validation exit 30 的 `CONTRACT CODE`；R22 的三个 publish exit 30 没有固定 stdout/stderr。验收清单要求 exact bytes，却没有标准可依。
- ref 是 atomic replace 而非 compare-and-swap；若允许两个 producer并发写同一 out-ref，“其他 bytes”可能是另一份完整、可解析、指向有效 object 的 ref，不应自动等同 corruption。需固定单 writer/锁/CAS 之一，或定义并发 loser 的稳定结果。

### I2. direct ABI 大体闭合，但 out-ref 的 stable namespace 与路径约束仍靠测试猜测

- PLAN v4 固定 stable ref namespace 为 `$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/`，当前 requirements 只要求 out-ref 不在 Git worktree，未明确它必须是该 state-dir/namespace 的后代，也未固定 public/local seed 的 ref 名。
- checklist 写“out-ref symlink/escape”，但没有写 escape 相对于 state-dir 还是 project ref namespace、对应哪个 `ERROR_CODE`。验收 case 不能代替接口规则。
- R5 的 `exec commands.d/SUBCOMMAND` 也没有声明 `commands.d` 是从 dispatcher 自身路径解析还是当前 cwd；虽所有主命令从 demo root运行，两个实现仍可能解析到不同文件。
- 这会使 producer/consumer 约定不同 ref 路径，也给调用者把 ref 发布到 state-dir 外留下解释空间。

### I3. resource fields 与 pass/fail 算法仍未一一对应

- `seed-request/v1.resource_minimums` 含 memory 与 CPU，但 R14 没有明确以 `effective_memory_bytes` 比较，R15直接写“effective rational 不小于 8”，没有说明使用 request 的 `effective_cpus`。一个实现可忽略输入字段，另一个可按输入比较。
- defaults 声明 32 GiB/8 CPU，只有 disk/inode 明确要求 descriptor threshold 不低于默认；memory/CPU descriptor 为 0 或 1 时既不属于 R27 invalid，也没有确定应拒绝、提升为默认还是接受。
- `estimated_disk_upper_bound_bytes` 被记录但不参与 disk gate；若 estimate 为 1 TiB而 available 为 300 GiB，当前文字允许因超过 200 GiB 而 PASS，违背 preflight 的资源可用性目的。
- cpuset 不可读时 schema 允许 null，但 R15 的 intersection 没有 fallback；cgroup v1/v2 同时可读时也没有选择优先级。应固定 provider selection、nullable fallback，以及每个 `passed` boolean 的唯一公式。

### I4. ignored input 与 syscall guard 仍存在能让 source mutation 假 PASS 的路径

- 一个 `path_b64` 无法表达 rename/link 等两个路径，也没有定义 dirfd、cwd、symlink 和 `/proc/self/fd` 的解析规则，独立 oracle无法从 trace record重算“resolved target under source root”。
- source mutation enum覆盖普通 write/open/rename 等，但未覆盖 writable shared `mmap`、`fallocate`、`copy_file_range`/`sendfile`、xattr、mknod 等可改变源码树内容/metadata 的成功路径；ignored 文件又不在常规 status digest 中，这些遗漏可绕过 before/after oracle。
- observed ignored symlink 只记录 symlink target string digest；若 probe 通过该 symlink 读取 target file，target 内容不是 seed identity 的必然组成部分。相同 symlink bytes、不同 target bytes可得到相同 seed content digest。
- round 1 的“只信自报日志”已解决，但当前 closed schema 本身仍不足以证明 R17/R18 和不变量中的零 mutation。

### I5. real-source seed digest包含调度相关 trace顺序，复现性没有验收

- trace records 按“observed syscall order”保留，process ordinal 又取 first-seen PID。多进程 envsetup/lunch 在相同源码与输入下的调度顺序可以不同；`strace -ff` 的跨文件合并也没有唯一 total-order算法。
- trace digest进入 seed guard，seed artifact digest因此可能随调度改变。当前只要求 deterministic fixture 的 dispatcher/direct digest相同，没有要求两次真实相同输入得到同一 seed content/artifact digest，也没有规定哪些运行证据应排除出稳定 seed identity。
- 这不一定要求删 trace，但必须区分“运行审计 artifact”与“可复现 seed identity”，或定义与调度无关的 canonical trace投影并增加重复运行验收。

### I6. rollback 的阶段已分开，但 recovery fixture 的身份与预期仍不足以独立判断

- R25 说 revert 后“后序 command fixture”经 dispatcher 不可达、direct fixture仍可审计；acceptance 只说“direct fixture remains executable”，未固定该 fixture 的路径、argv、exit/stdout/stderr，无法判断测试审计的是 later-spec direct ABI，还是被 revert 的 00 preflight module。
- 若审计对象是 00 的 preflight direct module，revert 00 后它理应随独占产出一起消失；若是模拟 01+ command，则需固定 fixture owner和安装时点。
- 三个旧 harness verifier 已给精确命令/末行，值得保留；只需把 recovery fixture 同样写成精确命令与结果，并说明 isolated worktree中谁提供它。

## 次要（2）

### M1. pre-merge expected output把 wrapper exit 与真实 CLI exit混写

- 同一句先规定主脚本 exit 0，随后写 real local branch “or exits 20”。从上下文可推断是内层 preflight exit 20、外层验收脚本仍 exit 0并输出 `GATE PLAN_REVIEW`，但事实陈述应显式区分两层 exit，避免 verifier把 terminal知识增量当脚本失败。

### M2. 800/160 gate 的时点和名词仍有低风险歧义

- R24 要求 actual diff超限时“在 tasks/implementation gate 前”停止，但 actual diff只能在实现后得知；checklist 又正确写成 tasks estimate与 final review actual。建议改为“estimate 在 tasks 门，actual 在 implementation acceptance 前”。
- `generated test/descriptor review summary` 容易被读成 tests/descriptor 是 generated diff；PLAN 实际约束是 non-generated diff ≤800、供人审的 test/descriptor summary ≤160。统一措辞即可。

## 规格符合性与文档质量

### 矛盾、YAGNI、空验证与错误路径

- 矛盾：PLAN 的同一路径 `seed.json` 仍同时承担 preflight input 与后序 output/consumer；trace signed result 与全局 unsigned JSON integer直接冲突。
- YAGNI：未发现无来源的 closure/build 功能扩张。dispatcher、publisher、namespace、trace、resource provider均能追溯到 PLAN/DECISIONS或前轮 finding。
- 空验证：anti-fake mutation、外层 namespace/trace、independent digest recomputation 方向有效；但 public real-source 没有本片 gate、real seed重复运行无稳定性 case，且 trace schema遗漏可让“零 mutation”假绿。
- 错误路径：object orphan/ref uncertain/no dangling已覆盖；collision 时序、`REF_CORRUPT`、并发 ref writer和 publish stdout/stderr仍缺确定规则。
- 来源与问题预算：R1/R2 来源已修正；0/15、0/2 在 autopilot 下可接受，剩余 finding都是可从既有计划和 ABI/POSIX语义裁定的技术问题，无需新增用户问题。

### P1–P5

| 判据 | 结论 | 说明 |
|---|---|---|
| P1 独立验收 | ❌ | local path可独立测，但 B1/B2 使“00完成”仍不能由唯一、可执行的 public交接与 evidence bytes判定。 |
| P2 独立回滚 | ⚠️ | exact merge SHA和 post-merge gate已分开；recovery fixture身份/精确结果仍未固定。 |
| P3 独立产出 | ❌ | local seed与 public golden是产出，但批准链所需 real public seed没有闭合的 fixture/ref交付与推进 gate。 |
| P4 值得问用户的问题 ≤15 | ✅ | 0/15、0/2已记录；无需继续提问。 |
| P5 人审全部产出 <1h | ⚠️ | 800/160 stop gate已加入，方向成立；需要修正 estimate/actual gate时点，且 tasks必须在实现前证明不超限或回 PLAN拆分。 |

## 最小修复集合

1. 统一 public request、published seed ref/object 与 PLAN 后序 consumer 的路径/命令，并把 real public exit 0或 terminal→PLAN review变成 00 的明确 gate。
2. 修正 trace signed result，定义 per-project source-state digest以及 syscall argv/双路径 canonical bytes。
3. 把 collision/`REF_CORRUPT`/publish channel/concurrent ref writer纳入一个时间上可执行的封闭状态机。
4. 固定 out-ref namespace、resource pass公式/fallback，并补 ignored symlink与全部承重 mutation路径。
5. 将稳定 seed identity与调度相关 trace证据解耦或 canonicalize；补 real重复运行和精确 rollback recovery fixture验收。

VERDICT: FAIL
