# 任务 1: 机械交付完整 assurance

> 这是你的需求。数值、签名、命令一律照抄，不要自己发挥。
> 你只做这一个任务，不要顺手做别的。不要派 subagent。

---

## 任务相关上下文

下面只包含当前任务关联的需求、设计和上游契约。需要额外信息时返回
`NEEDS_CONTEXT`，不要猜测，也不要扩大任务范围。

### Requirements（当前 R + 验收契约）

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

### Design

# 2026-09-05-05a-verifier-contract-assurance 设计

## 概述

把已实跑的331行prototype机械交付为唯一源码文件：Bash只负责0700 temp与可靠EXIT cleanup，内嵌Python负责readiness、264-case table、长度+hex transport log、surface与mutant oracle。

关键决策：

1. 选择单文件Bash+quoted Python heredoc，复用05的Python bytes语义且满足exact1/400；放弃拆helper文件，避免扩大回滚和consumer边界。
2. 选择独立`EXPECTED_TEXT`和执行table/loops形成manifest，不从执行代码生成expectation；放弃只计case数量，避免删case后同源假绿。
3. 选择repo外layout copy验证absent/damaged/mutant，tracked 05 exact3只读并前后hash；self-mutant以`VC_ASSURANCE_CHILD=1`继续case/surface但停止再生mutant，放弃隐式Python-global child状态和递归审计歧义。

## 需求映射

| 组件 | 实现的需求 |
|---|---|
| Bash lifecycle wrapper | R1、R8、R10 |
| readiness与surface router | R2、R4、R8 |
| runner/direct transport oracle | R3–R5 |
| grammar/aggregate case engine | R3、R5–R7 |
| independent manifest | R3、R6、R10 |
| four-mutant engine | R8、R10 |
| controller checkout/rollback gates | R1、R9、R10 |

## 组件与接口

### Verifier assurance entry

- 职责：执行readiness、active/inert/damaged、transport、grammar、manifest、mutant与cleanup oracle。
- 对外接口：`verifier-contract-assurance-v1：只新增 tests/test-verifier-contract-assurance.sh；dependency-present完整矩阵成功唯一输出 RESULT PASS  verifier contract assurance；不新增运行时API`
- 依赖：`verifier-contract-v1：docs/verifier-contract.md；canonical physical provider common/.harness/bin/verify-sidebar.sh [--demo] [--since <epoch[.nsec]>] [--allow-skip]；private HARNESS_VERIFIER_QUERY_RUNNER=<absolute-euid-owned-regular-executable> 接收 <query-key> -- adb -s <serial> <argv...> 并传回 stdout/stderr/rc；五项断言、受控末行与退出码 0|1|2；tests/test-verifier-contract.sh 默认发现基础入口`

CLI只接受无参数、`all`或`--dependency-absent`。default/all在present布局调用同一`main()` active分支；absence flag只允许exact3全缺席。成功唯一stdout为固定摘要，失败stdout不得含该摘要、stderr首行为`FAIL <label>`、rc1。

### Case engine

- 职责：table和紧凑loop执行264个稳定ID，生成实际manifest并与独立expectation集合比较。
- 对外接口：无运行时接口；只在assurance进程内使用。
- 依赖：05 provider/doc/base test只读copy、Python`ast/re/subprocess/pathlib/hashlib`。

runner脚本按调用创建递增JSON，字段为`key`、`argc`和`argv:[[byte_length,hex],...]`；direct fake adb使用同一codec。case engine从固定query args计算expected argv，逐字比较五detail、summary、terminal和双流。

### Surface与mutant engine

- 职责：构造41种complete-absent/partial/type/symlink/syntax/anchor/CLI布局，以及四个只改repo外copy的mutant。
- 对外接口：无。
- 依赖：readiness固定anchors、独立manifest、guarded success summary。

## 文件清单

| 文件 | 创建/修改 | 职责（一句话） |
|---|---|---|
| `tests/test-verifier-contract-assurance.sh` | 创建 | 默认发现的完整verifier契约assurance、surface与mutant自反证 |

验收资产：`prototypes/tests/test-verifier-contract-assurance.sh`与`reviews/`报告；不计入execution BASE源码diff。

### 上游任务契约

无：当前任务不消费其他任务产出。

---

## 你的任务

文件: 创建 `tests/test-verifier-contract-assurance.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/task-1-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/evidence/task-1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/task-1-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/review-manifest.tsv`
消费: 无
产出: `tests/test-verifier-contract-assurance.sh`
需求: R1, R2, R3, R4, R5, R6, R7, R8
必需: 是
状态: 待开始

- [ ] 步骤 1: 生成brief；运行`cmp -s "$TARGET" "$PROTO"`，确认红阶段失败且原因是目标物理缺席，记录命令、rc和缺席断言为red。
- [ ] 步骤 2: 核worktree HEAD=`BASE_SHA`且clean；用apply_patch把prototype逐字复制到TARGET并设0755，不重新设计、不修改05 exact3。
- [ ] 步骤 3: 核`cmp -s`、`wc -l=331`、SHA=`88f3abcd...c92ba`，固定shfmt/ShellCheck/bash-n全绿；`git diff --name-only "$BASE_SHA"`逐字仅TARGET、numstat`331/0`、05 exact3前后hash相同。
- [ ] 步骤 4: 运行TARGET default，核rc0、stdout 41 bytes固定摘要、stderr空；运行complete-absent fixture的default/all/flag和present flag拒绝，核child marker、264 IDs、41 surface、80 service与四mutant由入口内部全执行，temp物理缺席。
- [ ] 步骤 5: 提交只含TARGET的清晰commit，核commit exact1、331/0、worktree clean；写report并交独立diff review，PASS后写manifest第1行与ledger完成锚点。

## 报告契约

完整报告写进控制器指定的 `task-N-report.md`（路径由控制器给出）。

返回控制器的只有：
- **Status**：`DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`
- **Commits**：本任务产生的 commit 列表
- **一行测试摘要**：例如 `Ran 12 tests, OK`
- **顾虑**：如有
