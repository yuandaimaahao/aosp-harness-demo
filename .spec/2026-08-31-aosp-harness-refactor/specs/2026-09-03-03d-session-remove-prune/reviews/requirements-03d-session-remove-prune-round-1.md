# Review: requirements 03d-session-remove-prune round 1
verdict: NEEDS_CHANGES
阻断: 0 / 重要: 1 / 次要: 2

## findings

- [I1] 验收清单第 4 条（requirements.md:51）谓词归并不成立。「五模块各自缺席**与aggregator缺席**的隔离shell fixture 中，aggregator 返回1、双流空，marker 未设置且完整五API predicate 为false」把三个谓词同时施加于六类 fixture；但 aggregator 缺席时根本不存在可「返回1」的 aggregator——bash `source` 一个缺失文件虽返回 1，却会向 stderr 打印 `no such file` 类错误，「双流空」对该子情形不可能成立。R 层文字本身是对的：R6（:29）正确地把「静默返回1」限定在 aggregator 存在而模块缺席/source非零/export缺失的情形，R8（:33）对 aggregator 缺席只断言 marker/predicate；唯独清单第 4 条把 R6 的谓词错误地扩展到了 aggregator-absent fixture。依据：PLAN.md:130 只要求「每个模块缺席、source非零或预期export缺失的隔离shell」验证；bash source 缺失文件的既定行为。建议修法：把该条拆为两组谓词——五模块各自缺席 fixture：aggregator 返回1、双流空、marker unset、五API predicate false；aggregator 缺席 fixture：source 尝试非零（或按设计裁决的模拟方式）、marker unset、五API predicate false，不断言双流空。
- [M1] R8/验收清单第 4 条/不变量 3 把 aggregator-absent fixture 纳入本片自测，超出所引 PLAN 依据。PLAN.md:130 对本片测试只要求模块缺席/source非零/export缺失三类隔离 shell；PLAN.md:221 明确 aggregator 缺席 fixture 是 `03e/08` 的覆盖义务。本片自测多覆盖一类属加严、不矛盾，但 [计划] 标签下的依据括号未覆盖此项。建议：保留该覆盖但在依据中补一句说明（或在 design 门作显式裁决），避免被后续 review 误读为 PLAN 原文要求。
- [M2] R8（:33）要求 `tests/test-session-state.sh` 接受唯一 `--dependency-absent`，但 PLAN.md:223-234 的回滚验收命令对该入口只使用 `--session-provider-fixture <missing-*>`，无任何 `--dependency-absent` 调用（对比：`test-session-signals.sh` 在 :227/:228/:231 行确有 `--dependency-absent` 命令，故 03c R6 的同名 flag 有 PLAN 直接依据，本片没有）。PLAN.md:223 只直接支持「默认无参数运行在真实依赖缺席时执行相同 inert 断言」这半句。与 03c 同构属合理外推且无害，建议保留但在依据中注明是同构外推，或留待 design 门裁决。

## 核对记录

实际读取的文件（全部逐字比对，非仅信 requirements 的「依据」注释）：

- `specs/2026-09-03-03d-session-remove-prune/requirements.md` 全文（70 行）。
- `PLAN.md`：:53（03d 行，判据 `RESULT PASS  session state`）、:80（文件边界表 03d 行）、:130（03d 详情）、:186（03c->03d 边）、:187（03d->03e 边）、:211/:234（回滚矩阵 03d 行）、:223（test-only 参数总约）、:227-233（missing-foundation/path/snapshot/signals 命令）、:67（400 行/六列 manifest）、:203（02 回滚行「03d coverage位于独占fragment」）、:221（03e/08 fixture 义务）、:268（依赖图 03d-->03e）。
- `DECISIONS.md`：:23（round 1 五 API）、:25（round 2 错误表）、:26（round 3 prune/并发非空）、:28（收窄 round 3 I1-I3）、:29（design B1 rmdir 收窄）、:31（PLAN v5.3 P5/P2 回流）、:42（03b1 上游集合裁定）、:44（03c 验收行）。
- `specs/2026-09-01-03-session-state-safety/requirements.md` 全文（原始契约：R2 错误文案、R3 四 public API 名缺席断言）。
- `specs/2026-09-03-03c-session-write-interrupts/requirements.md` 全文（同构参照 R1-R8、frontmatter）。
- 代码现状 grep：`session-state-foundation.sh`（:5 `_harness_component_is_safe`、:10 `harness_validate_feature_name`、:17 `_harness_session_state_run`、:120 `_harness_session_state_foundation_path`）、`session-state-path.sh`（:2-4 三函数 guard、:5 `_harness_session_path_core`）、`session-state-snapshot.sh`（:4 `_harness_session_snapshot_worker`、:206 `_harness_session_snapshot_write_core`、:207 `_harness_session_snapshot_read_core`）、`session-state-signals.sh` 全文（:16-20 三 export guard、:22 `_harness_session_write_with_signals`，签名 `$1=project_id $2=session_id $3=feature`，恰 129/130/143）。Glob 确认 `tests/` 下九个上游文件全部存在、`tests/coverage.d/` 尚不存在。
- ledger 版本标签 grep：`session-foundation-v1`（03b 消费引用）、`session-path-delivery-v1`（03a 产出）、`session-snapshot-core-v2`（03b 产出）、`session-signals-facade-v1`（03c 产出）均真实存在。

关键逐字比对结果（全部通过项）：

- **R3/R4 vs 权威**：rc 表（成功/缺失0、OS错1含EIO、协议/安全错2、无 rc3）与 DECISIONS:25「仅 write 异值冲突、read 缺失返回 3，remove 缺失幂等 0」一致；stderr 两文案与 DECISIONS:25 及 03 requirements R2 逐字一致；`PRUNE_BEFORE_IDENTITY`、non-creating verified remove、ENOENT/ENOTEMPTY 幂等与 PLAN:130 逐字一致；prune 空层级/并发非空仍成功与 DECISIONS:26、:28 逐字一致。
- **R5 的预期 export 清单**：实际点名 **9 个**（foundation 3 + path 1 + snapshot 3 + signals 1 + remove 1），非审查任务书所说的 10 个——任务书计数有误，R5 的 9 个枚举本身完整且与真实模块逐字一致（8 个现存 export 全部核实存在，`_harness_session_remove_core` 为本片将交付）。foundation 的 `_harness_component_is_safe` 与 snapshot 的嵌套 helper 不在清单内，R5 只断言在场、未断言互斥，不构成问题。source 顺序（foundation→path→snapshot→signals→remove）非 PLAN:130 字面（原文只写「再逐个source」），但由 signals/remove 的 inert guard 机制强制唯一，属可机械推出的蕴涵，未列为 finding。
- **R6/R7 vs PLAN**：返回1/不设marker/不定义四 public API 与 PLAN:130、:186 逐字一致；thin 转接四目标（path_core/write_with_signals/read_core/remove_core）与真实模块签名一致；marker=1、validate 不代表完整 capability 与 PLAN:130/:187 一致。
- **R8**：五 fixture 值与 PLAN:227-234 逐字一致（含 :234 的 missing-remove）；固定摘要双空格与 PLAN:53 一致；非法 CLI rc1 与 03c R6 同构。
- **R9** vs PLAN:80/:203 一致。
- **R10**：上游九文件清单 = 03c 七文件（03c R7 逐字）+ signals 模块 + signals 测试，九个路径逐个核实存在，且与 DECISIONS:42「后序片累加各自前序交付」一致；不变量 1 的 git diff 命令同样列九文件，三处（R10/不变量1/超出范围）互相一致；exact 四文件、numstat≤400（PLAN:67）、shfmt `v3.14.0`/ShellCheck `0.11.0`（DECISIONS:18）、「四文件中三个 shell 文件」（.md 排除）均无误。
- **R11**：NEXT=`03e-claude-session-lifecycle` 与 PLAN:54/:268 一致；五类资产（spec目录/分支/worktree/BASE/dispatch）与四条机械核对命令覆盖完备，与 03c R8 同构（03c 原文计「四类」，本片把 BASE/dispatch 分列计五类，各自内部自洽）；「spec 文档允许出现 NEXT 全名」澄清与 03c ledger 裁定 6（禁令 scoped 于 ledger/dispatch/execution-base 15 文件）一致；inert 不作证据与 DECISIONS:44 一致。
- **frontmatter**：id/依赖（单一 03c，与 03c requirements 的 id 逐字一致）/验收方式无误；消费引用的 `session-signals-facade-v1` 签名与 03c 产出逐字一致；产出五 public API 名与 03 requirements R3、DECISIONS:23、PLAN:187 一致，错误语义与 DECISIONS:25/:28 一致；确认依据所引 DECISIONS:44 03c 验收行真实存在且内容相符。
- **来源标签抽查**：R1（PLAN:130/:186 ✓）、R3（DECISIONS:25/:26 + PLAN:130 ✓）、R6（PLAN:130/:186 ✓）、R10（PLAN:67 + DECISIONS:42 ✓）均有真实依据；全文无 [推断]/[默认] 标签，除 M1/M2 两处外未发现无依据断言。
- **内部一致性**：R1/R2 双态、R6/R7 互斥完备、验收清单 9 条除 I1 外均为可机械核对的事实陈述、不变量 4 项（在 2-4 上限内）与 R 文无矛盾；「四个状态 public API」（path/write/read/remove，validate 归 foundation）在 R1/R2/R6/R7、PLAN:130 间口径一致。
