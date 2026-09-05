# 05a verifier contract assurance design quick independent review

## 结论

- 规格符合性：**PASS**
- 设计质量：**PASS**
- Findings：**B=0 / I=0 / M=0**

本轮仅做 quick 静态/机械复核，未重跑已入 ledger 的 79.62 秒 dependency-present active 矩阵。审查以当前磁盘上的 `design.md`、`requirements.md`、331 行 runnable prototype、05 provider/doc/base test、PLAN v6.1 和 DECISIONS 为准。

## 八节与 R1–R10 映射

概述之后的八个标准设计节均在：需求映射、架构、组件与接口、数据模型、数据流、错误处理、测试策略和文件清单。需求映射表的七个组件合并覆盖 R1–R10，机械提取结果为 `1..10`，无缺号。

- R1/R9/R10 由 Bash lifecycle 与 controller checkout/rollback gates 承接；exact1、保护路径、fixed tools、full/depth-1/offline/rollback 和 NEXT 门都有明确验收责任。
- R2/R4 由 readiness/surface router 承接；complete-absent、partial、type/symlink/syntax/source/anchor damaged、present+absence flag 与 own CLI 均有 fail-closed 路由。
- R3–R7 由 transport oracle、grammar/aggregate case engine 和 independent manifest 承接；五 detail 顺序、summary 算术、terminal/rc、双流、query 数与完整 argv 均不是只做计数代替。
- R8/R10 由 repo 外 temp、dependency hash、guarded summary 和 four-mutant engine 承接，失败时无固定 PASS。

## 消费/产出与 owner 边界

`requirements.md` frontmatter 中的 `消费` 和 `产出` 字符串在 design 的 verifier assurance entry 中各逐字出现一次，没有改写协议。设计仍只消费 05 canonical provider/doc/base test，产出仍是单一 `tests/test-verifier-contract-assurance.sh`，不新增运行时 API，与 PLAN 的 `05 -> 05a`、`05a -> 06/09` 及 05a 独立回滚边界一致。

## child mode 时序

`VC_ASSURANCE_CHILD=1` 只包围 mutant 生成块，不包围 `main()`、readiness、case engine、manifest、surface、hash 或 cleanup。self-copy child 在变异后先以新 `SELF/TMP/ROOT` 进入相同 `main()`，完整执行 case/manifest/surface，到 mutant 块时才因 marker 停止再生成；因此既不递归，也没有借 child mode 跳过承重 oracle。design 中两张 sequence diagram、child marker 数据约束和错误处理表与该时序一致。

## active/inert/damaged、manifest 与 mutant

- active：default/all 在 dependency-present 时进入同一 `main()` 分支，无参数别名的行为差异。
- inert：exact3 全缺席时 default/all/`--dependency-absent` 均在零 active case 后 cleanup→guarded summary；任一存在则不能走 inert。
- damaged：41 个 surface ID 覆盖完整缺席三路、partial/type/symlink/FIFO/dangling link、provider/doc/base syntax/source/anchor/protocol 损坏、present+absence flag 和非法 own CLI；damaged 均要求 rc1 且 stdout 不含固定 PASS。
- manifest：静态重建得到 264 个 ID、264 个唯一值；`EXPECTED_TEXT` 与 table/loop 独立，executed 另行写入，最终同时核集合、二列 PASS 格式和 expected 文本。
- mutant：`expect_case grammar_service_ascii_tabs`、`run_case grammar_service_ascii_tabs` 和 `cleanup_success_before_summary` 均恰一；provider argv/SERVICE anchor 在05 source 也恰一。四类变异都先核唯一 anchor、单次替换和语法，再由各自专属 label 杀死；cleanup mutant 在 summary 写入前即失败。

## runnable 与 exact1/400 机械核

- prototype：`331` 行，SHA-256 `88f3abcd3f99e252c10e1134b98ea63212584ebd37bc6dfac2f9dd77dedc92ba`，与 requirements/design/ledger 一致。
- 固定工具：shfmt `v3.14.0` 以 `-d -i 2 -ci -bn`、ShellCheck `0.11.0` 以 `-x --severity=warning`、`bash -n` 静态复核全 PASS。
- 实施边界：design 明确要求最终源码与 prototype 逐字相同，文件清单恰为一个新增文件；因为该文件为新增，331 行同时是 added+removed churn，满足 `331 <= 400`。prototype/reviews 是验收资产，不计入 execution BASE 源码 diff。

## 最终裁定

**PASS — B0 / I0 / M0。** design 已把 requirements 中的单文件 owner、active/inert/damaged 路由、264-case independent manifest、runner/direct 字节长度+hex transport、child-mode 时序、四 mutant 自反证与 cleanup-before-summary 门落到可直接实施的设计。未发现会阻止 tasks/implementation 的 blocking 或 important finding。
