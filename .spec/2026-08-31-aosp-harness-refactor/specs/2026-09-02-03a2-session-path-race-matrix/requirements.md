---
id: 2026-09-02-03a2-session-path-race-matrix
依赖: [2026-09-01-03a-session-path-safety, 2026-09-01-03a1-session-path-race-assurance]
消费: "session-path-delivery-v1的private path core与三个唯一anchor；session-path-race-driver-v1的protocol/self-test/run-matrix私有CLI"
产出: "session-path-race-matrix-v1 —— tests/test-session-path-races.sh提供默认发现的37-row入口、依赖缺席inert与固定RESULT PASS  session path race assurance摘要；无运行时API"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户已授权后续按autopilot执行；PLAN v5.6及round7可执行拆分原型已证明shell entrypoint 109/400、dependency-present 37/37、损坏态、inert、full/depth-1与offline可交付
---

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并确认后续按 autopilot 执行。PLAN v5.6固定03a2在03a1 accepted HEAD与全PASS manifest入ledger之后启动，并在任何path consumer 03b之前交付默认37-case门。

## 目标

只新增一个由root offline gate默认发现的shell入口，把37-row四列matrix及九类计数的所有权从private driver外置出来；入口明确校验driver `protocol`，所有分支持续保持`HARNESS_SESSION_STATE_PROVIDER_VERSION`缺席。依赖齐全时必须真实调用已验收driver执行37/37，依赖缺席时保持零case inert，依赖存在但损坏时fail closed，从而在03b开始前形成可回滚、可浅克隆复现的三层path race门禁。

## 需求

R1. [计划] 当03a provider与03a1 driver已合入时，系统必须只新增`tests/test-session-path-races.sh`，不得修改foundation、provider、driver或既有测试，不得定义状态public API或设置`HARNESS_SESSION_STATE_PROVIDER_VERSION`；脚本必须从自身physical路径解析repo root，只消费tracked foundation/provider/driver，不读取固定历史SHA、网络、设备或AOSP build。

R2. [计划] 当入口生成matrix时，系统必须在读取provider/driver、判断inert或执行任何race case之前，按唯一顺序生成exact 37行四列TSV：swap 9、wrong-euid 3、eexist 9、mkdir-replace 3、mkdir-failure 3、post-mkdir-disappear 3、open-disappear 3、final-stat-disappear 3、real-eio 1。系统必须独立核对37行、37个唯一canonical ID与九类连续计数`9/3/9/3/3/3/3/3/1`；matrix损坏必须rc1、stdout无成功摘要，即使provider/driver/foundation同时缺席也不得被inert掩盖。

R3. [计划] 当调用入口时，系统必须只接受无参数、显式`all`或唯一`--dependency-absent`；无参数与`all`行为逐字相同。unknown、额外参数或`--dependency-absent`带值必须rc1且不得打印成功摘要。所有成功分支必须rc0、stderr空、stdout逐字节唯一为`RESULT PASS  session path race assurance\n`。

R4. [计划] 当tracked provider物理缺席时，default与`--dependency-absent`必须执行同一零case inert oracle并成功；当provider存在时，系统必须在foundation/core/flag判断之前先要求三个生产anchor文本各精确一次，任一缺失或重复都fail closed rc1，不能因foundation缺席或flag转为inert。inert oracle必须在隔离shell中证明private core、四个状态public API和provider marker全部缺席，不得source出partial capability。

R5. [计划] 当provider结构完整时，系统必须按以下优先级处理driver：物理缺席则default与`--dependency-absent`零case inert；路径是symlink或存在但非普通文件则fail closed；普通文件必须以`python3 DRIVER protocol`得到rc0、stderr空和逐字`session-path-race-driver-v1\n`，语法/执行/protocol损坏均fail closed。只有provider与driver均通过上述自损坏门后，`--dependency-absent`、foundation物理缺席或source后`_harness_session_path_core`不可用才允许走同一零case inert oracle。

R6. [计划] 当provider、driver、foundation与core齐全且使用default/all时，系统必须在一次入口运行中只调用driver一次`protocol`和一次`run-matrix FOUNDATION PROVIDER ABSENT_WORKSPACE CASE_TSV CASE_LOG`，绝不调用`self-test`；入口必须创建physical absent workspace、四列TSV与case-log路径。driver非零、stderr非空或stdout不逐字等于`RESULT PASS  session path race driver\n`必须fail closed。成功后入口必须逐字比较CASE_LOG与TSV第一列，重新核对37行/37唯一ID与九类计数，任何缺失、重复、额外、乱序或未执行都不得打印总PASS；fake-driver argv log必须能机械证明调用序列精确为`protocol,run-matrix`而不是74 case或重复调用。

R7. [计划] 当验证独立回滚与损坏态时，系统必须至少覆盖：provider absent；三个anchor各自missing/duplicate并与foundation missing/core unavailable/flag组合；driver absent、symlink、directory、protocol mismatch、syntax/rc failure；foundation absent；core unavailable；显式dependency-absent；matrix duplicate。provider/driver真正损坏必须优先fail closed，只有物理缺席或结构完整但运行依赖不可用的规定状态可inert；所有inert分支case-log必须为0 case且surface oracle通过。系统还必须在隔离candidate checkout只删除本片唯一entrypoint，随后独立运行driver self-test与offline gate：driver仍精确38-byte PASS、offline仍PASS且root gate发现race entrypoint次数为0，不要求任何03b文件存在。

R8. [计划] 当03a2进入验收时，系统必须由controller把`python3 DRIVER protocol`与`python3 DRIVER self-test FOUNDATION PROVIDER`作为入口之外的独立命令运行，再在dependency-present状态运行默认入口，三者均rc0且精确摘要；入口自身仍只调用R6的protocol/run-matrix。`bash ./scripts/check.sh --offline`必须自动发现并运行本入口。完整历史与真实file-URL `--depth 1` checkout都必须通过默认入口和offline，depth-1不得查询固定SHA。controller必须先逐字验证`shfmt --version`为`v3.14.0`、ShellCheck的version字段为`0.11.0`，再只对`tests/test-session-path-races.sh`运行`shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`与`bash -n`，要求rc0且无差异/诊断。每个checkout必须从当前tracked provider/driver采集调用前SHA-256并在全部测试后逐字比较不变；accepted dependency身份由BASE..HEAD零diff与ledger绑定，运行时不查询固定历史SHA。03/03a/03a1回归、`git diff --check`与worktree clean必须通过。

R9. [计划] 当03a2提交验收时，系统必须证明execution BASE到accepted HEAD exact只新增`tests/test-session-path-races.sh`且numstat总和`<=400`，六列review manifest与tasks一一对应、首尾/相邻连续、reviewer非空且全PASS。controller必须先把03a2 accepted HEAD、dependency-present 37/37、九类计数与全PASS manifest写入ledger，才允许创建03b worktree、固定03b execution BASE或dispatch任务；任何inert PASS不能解除03b门。

R10. [默认] 如果发生37行、37唯一ID、九类计数、400行预算、full/depth-1、review manifest或dependency-present证据任一门不满足，系统必须拒绝03a2验收并保持03b worktree、execution BASE与dispatch缺席。

## 验收标准

终交付物：`session-path-race-matrix-v1 —— tests/test-session-path-races.sh提供默认发现的37-row入口、依赖缺席inert与固定RESULT PASS  session path race assurance摘要；无运行时API`。

主验证命令: bash ./tests/test-session-path-races.sh
期望输出: 退出码为`0`、stderr空，stdout逐字节精确为`RESULT PASS  session path race assurance\n`

验收清单:

- [ ] 无参数与`all`在dependency-present状态真实执行37/37，九类计数逐字为`9/3/9/3/3/3/3/3/1`，CASE_LOG与TSV ID有序逐字一致；fake-driver argv log证明入口精确调用`protocol,run-matrix`且不调用self-test，controller另行取得driver protocol/self-test精确摘要。
- [ ] matrix duplicate自损坏在provider/foundation/driver缺席时仍rc1、stdout 0B且无总PASS，证明matrix门先于任何inert分支。
- [ ] provider absent与driver absent分别零case inert；provider存在时三个anchor missing/duplicate始终fail closed；driver symlink/nonregular/protocol/语法/执行损坏始终fail closed。
- [ ] `--dependency-absent`、foundation absent与core unavailable只在provider/driver结构及protocol通过后inert；每个inert fixture均证明core、四public API和marker缺席且输出同一总摘要。
- [ ] unknown/extra参数rc1无PASS；driver非零、stderr非空、摘要错、case-log缺失/重复/额外/乱序均rc1无PASS。
- [ ] 在隔离candidate checkout只删除entrypoint后，driver self-test仍38-byte PASS、offline PASS、root gate发现race入口0次，且不需要03b文件。
- [ ] accepted driver protocol/self-test、默认入口、03/foundation、03a path与offline在主worktree、full checkout和真实depth-1中全部PASS；root offline gate真实发现本入口。
- [ ] `shfmt --version`精确`v3.14.0`、ShellCheck version字段精确`0.11.0`；仅entrypoint的`shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`、`bash -n`无差异/诊断。每个checkout的当前tracked provider/driver测试前后SHA不变；diff-check与clean通过，BASE..HEAD exact1且只含entrypoint、numstat`<=400`，manifest连续全PASS。
- [ ] 03a2 accepted HEAD、dependency-present 37-case/九类计数和manifest写入ledger前，不存在03b worktree/base/dispatch；inert PASS不计作解除证据。

不变量（不许劣化，2-4项）:

- dependency-present默认入口case数或唯一ID数不等于`37`的次数 ≤ `0`，验证: CASE_TSV/CASE_LOG双向逐字比较。
- provider/driver损坏被inert掩盖的组合数 ≤ `0`，验证: R7优先级矩阵。
- 03/foundation、03a provider/test、03a1 driver的BASE..HEAD变更文件数 ≤ `0`，验证: 限定路径`git diff --name-only "$BASE" "$HEAD"`。
- full与depth-1默认入口/offline失败数 ≤ `0`，验证: 两种checkout分别运行主命令与offline gate。

## 超出范围

- 不修改private Python driver、不复制其family executor/signature/inventory/delta/14项自反证；shell只拥有matrix数据、依赖优先级、调用和case-log复核。
- 不新增生产模块、public API、capability marker、snapshot write/read、signals、remove/prune、consumer或coverage fragment；这些属于03b之后。
- 不声称inert PASS提供race覆盖；03b门只接受dependency-present 37/37证据。
- 不调用真实设备、网络、AOSP build或Claude/Codex客户端，不push、不清理既有spec branch/worktree。
