# Review: requirements 03d-session-remove-prune round 2
verdict: PASS
阻断: 0 / 重要: 0 / 次要: 0

## findings
无

## round1 findings 闭合核对

- **I1（验收清单谓词误扩到 aggregator-absent fixture）→ 闭合**。round 1 指出的原第 4 条已按建议拆为两条：现第 4 条（requirements.md:51）只覆盖「五模块各自缺席的隔离shell fixture」，谓词为 aggregator 返回1、双流空、marker 未设置、完整五API predicate 为 false——与 R6(:29) 的适用域（aggregator 存在而模块缺席/source非零/export缺失）一致；新增第 5 条（:52）单独覆盖 aggregator 缺席 fixture，谓词降为「source尝试返回非零，marker未设置且完整五API predicate为false，**不断言双流空**」——逐字落实了 round 1 的建议修法（bash `source` 缺失文件返回非零但 stderr 非空，故不断言双流空）。R8(:33) 本身只对该 fixture 断言 marker/predicate，与清单不矛盾；清单比 R 文多断言的「source返回非零」属机械细节加严，非冲突。
- **M1（aggregator-absent 覆盖超出 PLAN 直接依据）→ 闭合**。R8(:33) 依据括号内新增「其中aggregator缺席fixture为本片自愿加严、非PLAN原文要求——PLAN.md:221将aggregator缺席覆盖划给03e/08」；验收清单第 5 条（:52）同步注明同一来源。已亲自核对 PLAN.md:221 原文：「对 session provider，`03e/08` 还必须逐个覆盖 foundation/path/snapshot/signals/remove 缺席以及 aggregator 缺席」——引用准确。不变量 3(:63) 仍含 aggregator-absent 但未重复注明，因 R8 与清单两处已声明自愿加严，不构成残留问题。
- **M2（--dependency-absent 无 PLAN 直接依据）→ 闭合**。R8(:33) 依据括号内新增「`--dependency-absent` flag在PLAN.md:223-234对本入口无直接依据，为本片与03c `tests/test-session-signals.sh`的同构外推」。已亲自核对 PLAN.md:227/:228/:231：`--dependency-absent` 仅用于 test-session-path/test-session-path-races/test-session-snapshot/test-session-snapshot-assurance/test-session-signals；`test-session-state.sh` 在 :227-234 只以 `--session-provider-fixture missing-*` 出现——「无直接依据」的陈述准确，「与 03c 同构外推」也属实（03c R6 同名 flag 有 PLAN 直接命令依据）。

## 核对记录

实际执行（全部逐字比对，未仅信 requirements 的「依据」注释）：

- 重读 `specs/2026-09-03-03d-session-remove-prune/requirements.md` 全文（71 行）与 round 1 报告全文，逐条比对三处修复落点。
- `PLAN.md` 亲读：:53（03d 行判据 `RESULT PASS  session state`）、:80（文件边界：四交付文件、独占 coverage.d fragment、不改 COVERAGE.md）、:130（03d 详情：`_harness_session_remove_core <project-id> <session-id>`、双流空、0/1/2 无 rc3、non-creating verified remove、feature缺失prune、held parent/child identity、`PRUNE_BEFORE_IDENTITY`、ENOENT/ENOTEMPTY 幂等、remove EIO、signals export 缺失时 remove 静默 inert、aggregator 先验证五模块路径再逐个 source、任一 source 非零或私有函数缺失静默返回1不设marker不定义四API、全部成功才发布四 public+marker=1、validate 不代表完整 capability、三类隔离 shell 验证 marker/predicate/consumer 忽略前序函数）、:186（03c->03d 边：signals export absent 时 remove inert、aggregator 返回1）、:187（03d->03e 边：marker 精确1+五API、0|1|2|3、remove缺失0、write 129/130/143）、:221（aggregator 缺席覆盖归 03e/08）、:223-234（回滚命令集，本片入口仅 `--session-provider-fixture` 五值；:234「另以 missing-remove 覆盖保留aggregator但remove模块回退」支持 missing-remove 取值）。
- `DECISIONS.md` 亲读：:23（round1 五API）、:25（round2 错误表：rc1 `error: session state operation failed`、rc2 `error: unsafe session state`、仅 write异值/read缺失 3、remove缺失幂等0）、:26（round3 prune 空层级、并发非空仍成功不删他项）、:28（收窄 I1-I3：feature缺失仍prune、129/130/143）、:29（B1 rmdir 收窄）、:31（PLAN v5.3 P5/P2 回流：03d 仅在五模块及预期私有函数完整时设 marker 发布五API、每片400行门+六列manifest）、:42（03b1 上游集合裁定：六文件基线、后序片累加前序交付）、:44（03c 验收行：exact2/400、03d 启动门由本行满足、inert 不作证据）——与 R3/R4/R5/R10/R11、frontmatter 确认依据的引用全部相符。
- 真实模块 export grep 复核（`common/.harness/lib/`）：foundation `harness_validate_feature_name`(:10)、`_harness_session_state_run`(:17)、`_harness_session_state_foundation_path`(:120)；path `_harness_session_path_core`(:5)；snapshot `_harness_session_snapshot_worker`(:4)、`_harness_session_snapshot_write_core`(:206)、`_harness_session_snapshot_read_core`(:207)；signals `_harness_session_write_with_signals`(:22)。R5 点名 9 个 export（8 现存+本片将交付的 `_harness_session_remove_core`）与真实清单逐字一致，无多无少。
- 原始契约 `specs/2026-09-01-03-session-state-safety/requirements.md` R2：两 stderr 文案含 `\n` 与 R3 逐字一致；R3 四 public API 缺席断言与 R1/R2 一致。
- 同构参照 03c requirements：R6 CLI 形态（无参数/`all`/唯一flag、unknown/extra/带值 rc1）、验收清单「真实dependency-present默认/all与隔离absent默认/flag均得唯一固定摘要…但只有dependency-present active证据计入」句式，与 R8/验收清单第 6 条同构；03c 产出 `session-signals-facade-v1` 签名与 frontmatter 消费逐字一致。

重点复核的潜在新问题（均判定不构成 finding）：

- 修复后验收清单由 9 条变 10 条，R→清单映射仍完备（R1/R2→1、R3/R4→2、R5/R7→3、R6→4、aggregator-absent→5、R8→6、R9→7、R10→8/10、R11→9/10）；不变量 3 的「六类inert fixture」与清单第 4+5 条（5 模块+1 aggregator）计数一致。
- PLAN:130 提到「模块缺席、source非零或预期export缺失」三类隔离 shell，而 R8 只列五 missing-module+aggregator-absent fixture：因 PLAN:223-234 把本入口 test-only 参数集固定为五个 `missing-*` 值（脚本无法再接受 source-error 类取值），且五个 missing fixture 经 inert guard 级联实际同时压到 aggregator 的文件缺席与 export 缺失两条路径，R8 口径是与固定命令集自洽的读法，round 1 未 flag 的判断维持。
- R8 的 `all` 参数同 03c R6 惯例（round 1 已按同构接受，本轮维持）。
- 清单第 5 条「source尝试返回非零」比 R8 多一处断言，属 round 1 建议原文的落实，方向是加严而非放松。

结论：I1/M1/M2 三条全部按建议修法真实闭合，引用来源（PLAN.md:221、:223-234）经亲核准确；全量重读未发现修复引入的新问题，也未发现 round 1 漏掉的阻断/重要/次要问题。
