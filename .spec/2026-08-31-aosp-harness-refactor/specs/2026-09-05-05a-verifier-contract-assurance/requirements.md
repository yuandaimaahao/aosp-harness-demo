---
id: 2026-09-05-05a-verifier-contract-assurance
依赖: [2026-09-04-05-verifier-contract]
消费: "verifier-contract-v1：docs/verifier-contract.md；canonical physical provider common/.harness/bin/verify-sidebar.sh [--demo] [--since <epoch[.nsec]>] [--allow-skip]；private HARNESS_VERIFIER_QUERY_RUNNER=<absolute-euid-owned-regular-executable> 接收 <query-key> -- adb -s <serial> <argv...> 并传回 stdout/stderr/rc；五项断言、受控末行与退出码 0|1|2；tests/test-verifier-contract.sh 默认发现基础入口"
产出: "verifier-contract-assurance-v1：只新增 tests/test-verifier-contract-assurance.sh；dependency-present完整矩阵成功唯一输出 RESULT PASS  verifier contract assurance；不新增运行时API"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户要求所有剩余spec连续quick autopilot；05验收与post-merge offline已入库；PLAN v6.1把完整verifier grammar、CLI、argv、failure manifest和mutant oracle独占拆入本片
---

> 用户要求重构完善aosp harness，并要求所有剩余spec走quick autopilot连续自动执行。PLAN v6.1规定05a在06/09前穷举05 canonical verifier。

## 目标

只新增默认发现的`tests/test-verifier-contract-assurance.sh`，以唯一case manifest、runner/direct长度保真argv、`boot`、`system_server`、`boot_time`、`crash`、`service`、`package`矩阵和`SUMMARY`/terminal oracle证明05契约；覆盖`list`到`listx`、grammar、case删除与`cleanup_success_before_summary`四mutant。完整缺席inert PASS，partial/damaged fail closed；active证据入库前禁止06/09。

## 需求

R1. [计划] 系统必须只新增`tests/test-verifier-contract-assurance.sh`，BASE..HEAD exact1且added+removed≤400；05 exact3、三个旧verifier、session/resource-lease和06–10源码零变化；固定shfmt v3.14.0、ShellCheck 0.11.0与bash-n全绿。

R2. [计划] 当default或`all`运行时，系统必须从顶层tests解析repo root并在active前验证05 provider/doc/base test均为repo内普通非symlink文件、provider可执行、语法和固定接口anchor唯一；三者全缺席时default/all/`--dependency-absent`零active inert PASS，partial/type/symlink/syntax/source/anchor损坏必须fail closed；present下`--dependency-absent`必须rc1且只报`FAIL dependency-present`。

R3. [计划] 当active矩阵运行时，系统必须以独立expected/executed文本闭合稳定唯一case ID，无缺失、重复或额外；每case核五detail顺序、summary算术、terminal/rc、双流、调用数、serial和完整ADB argv。private runner与direct fake adb分别用argc及每个argv的字节长度+hex记录；`--`只在runner模式，direct query stderr必须被抑制，前置失败零query。

R4. [计划] 当CLI/preflight矩阵运行时，系统必须覆盖三个flag重复、since缺/多/非法/1–9位小数/Unicode/非法UTF-8、unknown/positional/help组合、真实allow-skip、serial缺失/非法/两个合法边界，以及runner absent/relative/missing/type/symlink/owner/exec/spawn/diagnostic/rc/signal；单独help须rc0、双流和query数正确，并与doc/parser参数集合一致。

R5. [计划] 当任一query失败或baseline变化时，系统必须逐一覆盖六query非零、default六调用、explicit-since五调用与九位规范化；boot_time失败或btime零/多/畸形时零logcat。runner-present继承stderr且传回status；direct抑制stderr但非零status仍产生对应FAIL。

R6. [计划] 当grammar矩阵运行时，系统必须覆盖05判定表全部适用格：boot空/0/1/畸形，system_server空/单多PID/0/前导零/非法分隔，btime零一多/ASCII空白/畸形，crash空/早于/等于/晚于/纳秒/header/前导空白/畸形，service空/目标/非目标/80组ASCII分隔尾白/Unicode/control/bracket/CR，package空/目标/非目标/多行/畸形；bytes只按LF切分并最多去一个尾CR，覆盖LF/CRLF/双CR与非法UTF-8。

R7. [计划] 当聚合矩阵运行时，系统必须证明完整执行恰五detail且顺序固定、summary和为5；FAIL优先为`RESULT FAIL`/1，strict SKIP为`RESULT INCOMPLETE`/2，五PASS为`RESULT PASS`/0，仅demo allow-skip可探索PASS；十二demo fixture须与doc/production集合相同、默认demo零query且fixture不执行shell。

R8. [计划] 系统必须在repo外创建EUID自有0700普通空temp，所有fixture、capture、manifest与copy均在其中，失败cleanup失败升级rc1，成功必须物理清理后才调用guarded summary。05三文件前后hash不变；四mutant须先核唯一anchor/单一替换/语法，再分别由`FAIL mutant-case-manifest`、`FAIL mutant-argv-service`、`FAIL mutant-service-grammar`、`FAIL mutant-cleanup-before-pass`首标签杀死且无PASS。内部self-copy必须以`VC_ASSURANCE_CHILD=1`继续case/manifest/surface但禁止再生成mutant。

R9. [计划] 当验收运行时，系统必须在candidate、完整历史checkout和真实depth-1 clone分别执行assurance、05 base与offline；固定摘要、stderr空、depth-1单commit/shallow marker、exact1≤400、六列review manifest、diff-check、隔离converge及clean全部PASS。

R10. [计划] 如果发生case、manifest、mutant、hash、cleanup、工具、checkout、rollback或NEXT门失败，系统必须非零且不得打印固定PASS；rollback须精确删除唯一源码并使tree与BASE零diff，05/01/04/04a/03e/offline及三个旧demo全绿且assurance发现0。只有active完整证据入ledger才可创建06/09的spec/ref/worktree/BASE/dispatch，inert PASS不得解除门禁。

## 固定 anchor 与原型证据

唯一production anchor为USAGE、runner `command = [runner, key.lower(), "--"] + command`、service argv `["shell", "service", "list"]`和SERVICE regex；doc固定six-query与两个six-fixture集合；base固定成功摘要。assurance独立固定`expect_case grammar_service_ascii_tabs`、`run_case grammar_service_ascii_tabs`和`cleanup_success_before_summary`。变异仅在repo外copy。

门②runnable prototype为`prototypes/tests/test-verifier-contract-assurance.sh`：fixed-format 331行、SHA-256 `88f3abcd3f99e252c10e1134b98ea63212584ebd37bc6dfac2f9dd77dedc92ba`；264个唯一active ID、41项surface、80组service组合和四mutant。显式child-mode修复后，controller在repo外重跑active default于79.62秒内rc0、stdout 41 bytes固定摘要、stderr空；complete-absent default/all/`--dependency-absent`三路同样PASS，验证树物理清理。若不在400行内完成R2–R8，必须回流PLAN，不得删case。

## 验收标准

主验证命令: bash ./tests/test-verifier-contract-assurance.sh
期望输出: dependency-present时退出0、stderr空、stdout逐字为`RESULT PASS  verifier contract assurance\n`，完整manifest和四mutant全部执行

验收清单:

- [ ] runnable prototype与最终源码逐字相同，BASE..HEAD exact1≤400且固定工具全绿，受保护文件零变化。
- [ ] active/inert/partial/damaged/present-absent路由和own CLI机械闭合。
- [ ] 264个唯一ID及独立expected/executed manifest无缺失、重复、额外。
- [ ] runner/direct长度+hex argv、双流、query数、serial、分离argv与零query前置闭合。
- [ ] CLI/serial/runner、六query/default/explicit baseline和help/doc/parser集合全部覆盖。
- [ ] 五项grammar全部适用格、80组service ASCII组合、LF/CRLF/非法bytes覆盖。
- [ ] 五detail、summary、terminal/rc、strict/exploratory与十二fixture闭合。
- [ ] repo外0700 temp、hash、cleanup-before-summary guard及四mutant专属首标签闭合。
- [ ] candidate/full/depth-1、05 base、offline、manifest/converge/diff/clean全部PASS。
- [ ] rollback零diff与回归全绿，06/09执行资产在active证据前缺席。

不变量（不许劣化，2-4项）:

- 05 exact3及三个旧verifier变化数≤0，验证: BASE..HEAD保护路径diff。
- active case detail数=5、summary和=5、manifest缺失/重复/额外数≤0，验证: expected/executed集合。
- preflight及invalid-btime越界query数≤0，验证: runner/direct日志。
- FAIL/INCOMPLETE/mutant/cleanup失败误报strict PASS次数≤0，验证: terminal+rc和guarded summary。

## 超出范围

- 不修改05运行时，不实现06–10，不调用真实ADB/设备/build/CVD/网络。
- 不新增运行时API、第二个源码文件或外部测试框架。
- 不push、不触碰原用户脏工作区或其他spec/worktree。
