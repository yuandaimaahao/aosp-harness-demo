# 00-environment-seed-preflight requirements review — round 1

## 审查结论

- 最终结论：`NEEDS_CHANGES`。
- Findings：4 个阻断、7 个重要、3 个次要。
- 规格符合性：R1–R11 的 EARS 外形均合规，用户给出的源码路径、`envsetup` 命令和 lunch 目标逐字准确，00 也明确禁止模块/整机编译；但 descriptor ABI、00 独占 dispatcher/recovery ABI、exit/ref 状态机及核心安全不变量的可证性尚未闭合。
- 文档质量：没有明显的编译范围膨胀，也没有把 LK7K/vendor 宣称为公开 AOSP 通用底座；但存在输入/产出同名、错误分支重叠、关键 PLAN v4 产出遗漏，以及可由自写日志或固定输出假绿的验收。
- 机械检查：只运行了规格静态检查，`check-req.py`、`check-criteria.py`、`check-analyze.py` 均 exit 0。未运行真实 lunch、`m`/`mm`/`mmm`、编译、下载或任何 AOSP 修改命令。
- 版本依据：仓库当前只有 `PLAN.md` v4，`PLAN-history.md` 也止于 v4；没有可审的 PLAN v5。本报告以 PLAN v4 加其后 `DECISIONS.md` 的 LK7K/autopilot 口径为唯一依据，不把未落盘的“v5 口径”当事实。

## ① 规格符合性：R1–R11

| 需求 | 结论 | 来源与 EARS | 验收与边界 |
|---|---|---|---|
| R1 | ⚠️ | “当…时，系统必须…”合规；`~/Project/lk7k-a17/system` 与解析后的 `/home/zzh0838/Project/lk7k-a17/system` 对得上用户原话和 DECISIONS。整条标 `[原话]` 不准确：`.repo/`、envsetup、Repo client 可读性是计划/实现前置，不是用户原话。 | 主命令只传已展开的 `$HOME/...`，没有证明 descriptor 内或 CLI 参数中的字面量 `~` 会按规定展开；Repo client 的“可读取/可执行/版本来源”也未定义。 |
| R2 | ⚠️ | EARS 合规；`source build/envsetup.sh` 与 `lunch sys_mssi_64_64only_cn_armv82-fooding-userdebug` 逐字准确，且明确不运行 `m`/`mm`/`mmm`/打包，符合 00 只做 preflight。整条 `[原话]` 仍混入了 PLAN 的外置 `OUT_DIR`、记录字段和禁编译边界。 | 没有规定先 `cd` 到 source root、`OUT_DIR` 的创建/清理/realpath 规则，以及“关键 build variables”的封闭字段集；命令日志也不足以证明没有直接调用 `soong_ui`/`ninja` 等编译入口。 |
| R3 | ❌ | EARS 合规，主方向来自 PLAN；LK7K product/vendor 角色边界来自 DECISIONS 而非 PLAN，来源混标。 | 遗漏 PLAN v4 明列的 Repo commit、container digest、source/mirror URL、预估磁盘上限、断网探针与 seed content digest；也没有机器可读的 `local_lk7k_product` 与 `public_aosp_baseline` 区分。见 B1、I1。 |
| R4 | ⚠️ | “凡具备…，系统必须…”合规，绝对且已存在、位于所有 worktree 外与 PLAN 一致。 | 未规定 realpath/symlink 口径、如何枚举 harness 主仓及 AOSP 多 project 的所有 worktree，也未约束 artifact store 和 `--out-ref` 必须留在该 state-dir 内。见 B3、I3。 |
| R5 | ⚠️ | EARS 合规；214748364800、1000000、34359738368、8 分别准确对应 200 GiB、1,000,000 inode、32 GiB、8 CPU。来源诚实标为 `[默认]`。 | descriptor schema 尚未定义；“可用内存/CPU/容量/inode”没有 host/cgroup 和计量口径，等于阈值与差 1 边界也未验。见 I4。 |
| R6 | ⚠️ | EARS 合规，且诚实标为 `[默认]`；dirty 不在 00 阻断的方向与 Autopilot 段一致。 | status digest 的 canonical 输入、受影响 project 计数、未跟踪文件内容/删除/重命名处理未定义；仅哈希 `repo status` 文本不能证明 dirty 源状态或前后不变。见 I5。 |
| R7 | ❌ | EARS 合规；不 sync/fetch/clone/编译/下载符合 PLAN 与 00 范围。 | “拦截”机制及可观察 oracle 未定义。自写命令记录为空和 manifest/status digest 不变，均不能证明子进程没联网、没往 mirror/cache 写、没调用其他编译入口。见 B4。 |
| R8 | ❌ | EARS 合规，exit 0、`ENV PASS lk7k-a17`、create-if-absent、`env_pass` 方向正确。 | `--descriptor FILE` 同时像输入又像本条发布的输出；没有 seed/env artifact schema、canonical bytes、digest domain/文件名、exact ref bytes，也未继承 PLAN 的 fsync+rename 规则。见 B1、B3。 |
| R9 | ❌ | EARS 合规，exit 20/terminal_report 的知识性终止方向正确。 | state-dir 非绝对/落入 worktree 既可落 R9，又可被 R10 的参数/验证错误覆盖；terminal_report ref 没有对应 artifact 发布契约，可能产生 dangling ref。见 B3。 |
| R10 | ⚠️ | EARS 合规，exit 30 且失败不发布新对象的方向正确。 | descriptor/参数与 R9 的边界不互斥；“不写任何新 artifact/ref”没有明确禁止修改已有 ref/artifact，也没有已有 sentinel 保持原字节的验收。见 B3、I6。 |
| R11 | ⚠️ | EARS 合规；exit 30、`DIGEST_COLLISION`、不覆盖 object 精确继承 PLAN v4。 | 未规定以“目标 digest 路径已有不同 bytes”的可构造 fixture 触发，也未验 collision 时现有 object/ref 字节均保持不变；文案有 `exit 30并` 的空格疏漏。 |

## Findings

### 阻断（4）

#### B1. `descriptor` 同时是输入、被修改对象和发布产物，00 的稳定数据 ABI 无法据此实现

- frontmatter 把接口写成 `preflight --descriptor FILE ...`；R5 又说阈值来自 descriptor，说明 FILE 是输入。
- 目标、R6、R8 和验收清单却把 descriptor 写成 preflight 生成、追加 dirty/host/lunch 字段并发布的产物。PLAN v4 后续 `extract`/`verify-proof` 又把 `seed.json` 当稳定输入消费。
- 主验收通过 `AOSP_SOURCE_ROOT`、`AOSP_LUNCH_TARGET` 环境变量注入路径与 lunch，但这两个环境变量不在 frontmatter 签名，也没有定义它们与 FILE 中同名字段的优先级、冲突错误码或是否进入 digest。
- canonical descriptor 只写“SHA-256”，没有 schema version、输入/观测字段边界、RFC 8785 或其他 canonical bytes 算法、digest domain separator、64 位文件名与只读 mode。两个实现可以产生互不兼容的 env artifact，却都满足当前文字。
- 必须拆名并固定角色，例如 immutable `seed-request/v1` 输入与 `env-preflight/v1` 输出；列出每个字段的唯一权威来源、env override 规则、canonical bytes/digest 和后续 consumer 签名。否则 01/02 无法稳定消费。

#### B2. requirements 产出签名漏掉 PLAN v4 指定由 00 独占的 dispatcher、direct recovery ABI 与独立回滚判据

- PLAN v4 明确 00 独占 `./common/.harness/bin/feature-closure` dispatcher、state-dir preflight 和 `preflight` command；dispatcher 只能从 `common/.harness/closure/v1/commands.d/COMMAND` 加载，command module 本身还必须可直接执行作为 recovery ABI。
- PLAN 的 00 回滚契约还要求撤回 00 后后续 modules 不可达、旧 resolver/wrapper 与现有 harness 回归仍 PASS。
- 当前 frontmatter 和 R1–R11 只承诺一个聚合 CLI 调用，没有 dispatcher load/unknown-or-missing command 行为、direct command 签名、旧 harness 回归或 revert/缺席验收。
- 这不仅是设计细节：01 明确不得修改 dispatcher，后续每片依赖该 ABI；遗漏会使后续 spec 无 owner 可补，并使 P2“独立回滚”无法由本 spec 验收。

#### B3. exit 20/30 与 artifact/ref 状态机不互斥，失败时可产生越界或悬空状态

- R9 把 `state-dir` 不可用归为 exit 20；R10 把参数契约错误归为 exit 30。非绝对 state-dir、symlink 解析失败、落入 worktree、`--out-ref` 越界都同时符合两类。验收只指定“worktree 内=20”，没有给其他交界 case。
- PLAN v4 自身也有需在本 spec 裁定的张力：spec 列表把非绝对/落入 worktree 写成 `ENV NOT-AVAILABLE`，结果码表却把 worktree mismatch 放在 exit 30。requirements 不能靠实现者猜。
- R9 要写 `kind=terminal_report` ref，却没有要求先把 terminal report artifact 原子发布到 store；按 PLAN 的 `{schema_version,kind,digest}` ref 语义，这可形成 dangling ref。
- `--out-ref` 没有限定为 `$STATE_DIR/refs/aosp-feature-minimal-checkout/` 的后代，ref/store 路径也没要求 realpath 后仍位于 state-dir；R10 只禁“新”写入，未禁止改写已有 sentinel。
- 必须给每类输入/环境错误唯一 exit 和 stdout/stderr，固定 artifact/ref 写入矩阵、exact ref schema、out-ref/store confinement，并验失败时已有 object/ref 原字节不变。

#### B4. “不改源树、不联网、不编译”的承重不变量目前可用空日志或恒真实现假绿

- R7/清单只要求“命令记录中没有”禁令字符串。被测实现自己控制记录内容，完全可以不记子进程或直接编译器调用；测试脚本也可以只打印两条期望 PASS 文本。
- manifest/status digest 的 canonical 输入未定义；普通 `repo status` 文本不覆盖未跟踪文件 bytes、被忽略的新输出、mirror/cache 写入，也不能证明 lunch 子进程没有网络访问。
- 只 poison `repo sync`、`git fetch/clone`、`m/mm/mmm` 名称，仍可能通过 `curl/wget/ssh`、Git 其他 transport、`soong_ui`、`ninja` 或 shell function 内部子进程越过。
- 应使用独立 oracle：受控 fake/poison PATH 记录所有网络/编译执行器，验证有效的网络隔离能力而非仅扫描日志，前后以定义好的 manifest/status/content 集合做外部重算，并证明真实 dispatcher/command 被测试调用。核心安全边界没有这种证据前不能 PASS。

### 重要（7）

#### I1. PLAN v4 的 seed 字段与 LK7K/vendor 角色没有闭合

- R3/验收遗漏 Repo commit、container digest、source/mirror URL、预估磁盘上限、断网 probe、seed content digest；`关键 build variables` 也不是封闭字段集。
- PLAN 总目标仍是公开 AOSP 17 Cuttlefish `services` 证明；DECISIONS 只允许 LK7K/vendor 用作本地产品闭包验证，并禁止外推。当前仅写“标记 product/vendor role”，没有字段值、schema 或 consumer 拒绝规则，`env_pass` 仍可能被后序误当公开 AOSP baseline。
- 应明确该 artifact 是替代还是补充公开 Cuttlefish seed，并至少机器标记 `scope/role/product/vendor/public-baseline`；后序 public proof 不得仅凭 `ENV PASS lk7k-a17` 消除公开 seed 前置。

#### I2. R1、R2、R3 的来源标签覆盖了并非该来源确认的承重子句

- R1 的用户原话只确认本地路径可用于验证；`.repo`/envsetup/Repo client 检查不是原话。
- R2 的原话只给 envsetup 与 lunch；外置 OUT_DIR、记录字段、禁止编译来自 PLAN/边界。
- R3 的大部分字段来自 PLAN，但 LK7K/vendor role 来自 DECISIONS。
- 应拆成独立 EARS 需求或标注混合来源的明确逐项依据。当前标签会使门②误以为整条都不需裁定。

#### I3. worktree 隔离规则没有可执行的路径解析算法

- AOSP Repo workspace 含多个 Git project；“`git worktree list --porcelain` 列出的任一 harness/AOSP worktree”没有说明在哪些 repository 中运行、是否包含 linked worktree、submodule/project、主 worktree和 `.repo/manifests`。
- 没有规定 state-dir、store、OUT_DIR、out-ref 都先拒绝 symlink 再 realpath，或允许 symlink 但按 realpath 判 containment；父目录重命名/TOCTOU 也未给最小防护语义。
- 至少应固定枚举输入和 realpath containment 规则，并为 harness 内、AOSP 顶层内、某 project worktree 内、symlink 指回 worktree四类负例提供 oracle。

#### I4. 资源阈值数值准确，但“可用”口径和边界 case 未定义

- 磁盘应明确取 state-dir 所在 filesystem 对当前用户的 available bytes，inode 取 available inodes；内存应明确 host `MemAvailable` 还是 cgroup effective available；CPU 应明确在线 logical CPU 还是 cpuset/quota 后可用 CPU。
- 容器/CI 中 host 值与 effective limit 可能相反，当前文档允许错误 PASS。
- 验收只写“低于阈值”，未证明等于阈值通过、阈值减 1 失败，或 descriptor 缺失/负数/溢出走 exit 30。

#### I5. dirty tree 继续的默认策略缺少可重算证据与后序约束

- “只包含 digest 的 status 证据”没有定义 status payload；若只哈希路径/status code，不包含 tracked diff 与 untracked bytes，dirty 内容变化可保持同 digest。
- “受影响 project 计数”没有规定 nested project、重复 path、manifest project 删除/新增的计数方法。
- 后序 lock “决定 mutable project 边界”是意图，不是本 spec 可验证的消费契约；应至少保证 env artifact 明确标记不可作为 clean/pinned source proof，并列出后序必须重验的字段。

#### I6. 默认问题处理和确认依据没有留下可审计记录

- 明示 `[默认]` 共 2 条（R5 资源阈值、R6 dirty policy），数量在 `question_budget=15`、`question_rounds_max=2` 内；但 requirements 没有写“必答/带推荐/已定告知”的计数，也没有记录 autopilot 猜错代价。
- frontmatter 已写 `已由用户确认: true`，却没有 `确认依据`；ledger 仍为空，DECISIONS 也没有资源阈值、dirty 策略、descriptor/env precedence 或 exit 交界裁定。
- autopilot 可以自动通过门②，但不能把默认值伪装成用户原话或省略裁定记录。进入 design 前应写清 `0/15` 或实际问题数、自动裁定依据与猜错代价，并把稳定新口径落到 DECISIONS/ledger。

#### I7. 验收矩阵漏掉多个可失败的公开契约，主验证输出也不够精确

- 主命令只约定出现 `RESULT PASS environment-seed-preflight；ENV PASS lk7k-a17`，没有退出码、两行精确文本/顺序/出现次数、stderr 是否为空；脚本恒定 echo 即可满足表面要求。
- 缺 literal `~`、`.repo` 缺失/不可读、Repo client 不可执行、descriptor/env 冲突、resource 等值/差 1、out-ref 越界、terminal artifact digest、existing ref sentinel、direct recovery ABI、unknown command 等 case。
- PLAN 还要求 `ENV NOT-AVAILABLE` 报告不超过 120 行、artifact/ref 用 temp+fsync+rename；requirements 未继承，也没有 crash/interruption 后无 partial object/ref 的 oracle。
- 应把公开 CLI/ABI 的正负矩阵写入验收，并使用独立 fixture/fake，避免负例意外触发真实 lunch。

### 次要（3）

#### M1. 字面量 `~` 的责任边界不清

- 未加引号的 shell 会在调用 CLI 前展开 `~`，JSON/引号内不会。R1 若要求系统自身展开，应有字面量 fixture；若只要求 shell-expanded absolute path，应改写需求，避免实现两套扩展规则。

#### M2. terminal report 的审查上限丢失

- PLAN v4 要求 `ENV NOT-AVAILABLE` 分类报告不超过 120 行；当前只约定状态行和 ref。补上行数上限，才能维持知识性终止报告的人审预算。

#### M3. 文案有一个低风险格式错误

- R11 的 `exit 30并输出` 缺空格；不影响 EARS 解析，但建议改为 `exit 30，并输出`。

## ② 文档质量

### 矛盾与歧义

- 阻断：`descriptor` 既是 `--descriptor FILE` 输入，又是 R6/R8 修改并发布的输出。
- 阻断：state-dir 的格式/containment 错误同时可归 exit 20 和 exit 30；PLAN v4 两处文字也有张力，requirements 尚未裁定。
- 重要：PLAN 的公开 AOSP 17/Cuttlefish seed 与本地 LK7K product seed 的关系未定义；当前只有人读标签，没有机器消费边界。
- 重要：`source-status SHA-256`、`关键 build variables`、`断网能力`、`Repo client 可读取` 均不是唯一可实现定义。

### YAGNI / 范围

- ✅ 00 明确不运行 `m`、`mm`、`mmm`、整机编译/打包/刷机，也不做 closure 求解；没有把 02–05 的功能提前实现。
- ✅ LK7K/vendor 标记是必要边界，不属于 YAGNI；问题是它还不够机器可执行，而非不应存在。
- ⚠️ 硬编码 `/home/zzh0838` 只适合本次本机验收；通用 CLI 不应内建该路径。requirements 已对 state-dir 明说不得硬编码，但对 source root 也应采用同样边界。

### 空验证 / 恒真验证

- ❌ “命令记录中没有禁令字符串”可通过不记录而恒真。
- ❌ manifest/status digest 只比较相等，在 digest 输入未定义时可用常量或不覆盖 untracked/ignored bytes 假绿。
- ❌ 主测试只要求两条 PASS 文本，未要求证明它调用真实 dispatcher/preflight、检查生成 artifact/ref 或拒绝 poison 命令。
- ⚠️ `digest-immutability` case 方向正确，但必须先放置“目标 digest 文件名下的不同 bytes”并比较调用前后 object/ref 原字节，不能只检查 CLI 返回码。

### 错误路径

- ❌ exit 20/30 的分类不互斥。
- ❌ terminal_report ref 可能没有对应 artifact。
- ❌ exit 30 只禁止“新”写入，没有保护已有 ref/object。
- ❌ 未覆盖 symlink/out-ref 越界、partial temp、fsync/rename 中断、descriptor/env 冲突、resource schema 错误。
- ✅ 无 envsetup、无效 lunch、低资源、worktree 内 state-dir、digest collision 已列出负例方向。

### P1–P5 与问题预算

| 判据 | 结论 | 说明 |
|---|---|---|
| P1 独立验收 | ⚠️ | 可在环境可用时 exit 0、不可用时 exit 20 并独立终止，切片方向成立；但 B1/B3/B4 使当前判据尚不能唯一判断完成。 |
| P2 独立回滚 | ❌ | PLAN 有 00 dispatcher/缺席/旧 harness 回归口径，requirements 未将它纳入产出和验收，见 B2。 |
| P3 独立产出 | ✅ | env/seed artifact、preflight CLI 或可审计 terminal report 都是独立产品/知识增量。 |
| P4 值得问用户的问题 ≤15 | ⚠️ | 明示默认仅 2 个，数量未超 15；但未记录问题层级/自动裁定，且多项 ABI/错误码歧义被静默留给实现者。技术上能从 PLAN/DECISIONS 裁定的应直接修文档，真正需用户选择的才占预算。 |
| P5 人审全部产出 <1h | ⚠️ | PLAN v4 已给 800 行非生成 diff + 160 行摘要上限，理论上可满足；requirements 未给实现文件/行预算，且 dispatcher、schema、preflight、fixtures/test 同片后接近超限。tasks 门必须在实施前给可执行预算，超限就按 PLAN 拆分。 |

问题预算结论：当前显式候选为 2/15、轮次 0/2，不因数量要求拆片；但在门②自动通过前，必须把默认裁定、确认依据和错误代价写入 requirements/DECISIONS/ledger。

## 通过条件摘要

1. 固定 input seed request 与 output env artifact 的不同 schema、字段权威、canonical digest 及 consumer 签名。
2. 把 00 的 dispatcher/direct recovery/state-dir owner 与独立回滚验收纳入 requirements。
3. 给 exit 0/20/30 建互斥决策表，并闭合 success/terminal/contract 三类 artifact/ref 的发布、confinement 和失败不变性。
4. 用独立 oracle 证明真实 CLI 被调用、源树全约定集合不变、网络/同步/编译入口零调用，消除空日志/常量 digest/恒定 echo 假绿。
5. 补齐 PLAN seed 字段、LK7K/vendor 机器边界、资源与 dirty canonical 口径，以及 autopilot 默认/问题预算记录。

VERDICT: FAIL
