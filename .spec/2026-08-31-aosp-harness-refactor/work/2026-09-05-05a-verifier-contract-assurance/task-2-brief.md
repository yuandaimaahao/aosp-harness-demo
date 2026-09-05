# 任务 2: 验证 candidate、full 与 depth-1

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
R8. [计划] 系统必须在repo外创建EUID自有0700普通空temp，所有fixture、capture、manifest与copy均在其中，失败cleanup失败升级rc1，成功必须物理清理后才调用guarded summary。05三文件前后hash不变；四mutant须先核唯一anchor/单一替换/语法，再分别由`FAIL mutant-case-manifest`、`FAIL mutant-argv-service`、`FAIL mutant-service-grammar`、`FAIL mutant-cleanup-before-pass`首标签杀死且无PASS。内部self-copy必须以`VC_ASSURANCE_CHILD=1`继续case/manifest/surface但禁止再生成mutant。
R9. [计划] 当验收运行时，系统必须在candidate、完整历史checkout和真实depth-1 clone分别执行assurance、05 base与offline；固定摘要、stderr空、depth-1单commit/shallow marker、exact1≤400、六列review manifest、diff-check、隔离converge及clean全部PASS。

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

## 文件清单

| 文件 | 创建/修改 | 职责（一句话） |
|---|---|---|
| `tests/test-verifier-contract-assurance.sh` | 创建 | 默认发现的完整verifier契约assurance、surface与mutant自反证 |

验收资产：`prototypes/tests/test-verifier-contract-assurance.sh`与`reviews/`报告；不计入execution BASE源码diff。

### 上游任务契约

#### 任务 1: 机械交付完整 assurance

文件: 创建 `tests/test-verifier-contract-assurance.sh`
产出: `tests/test-verifier-contract-assurance.sh`

---

## 你的任务

文件: 无
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/task-2-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/evidence/task-2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/evidence/task-2-green.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/task-2-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/review-manifest.tsv`
消费: `tests/test-verifier-contract-assurance.sh`
产出: `verifier-contract-assurance-checkouts-v1`
需求: R1, R2, R3, R8, R9
必需: 是
状态: 待开始

- [ ] 步骤 1: 生成brief；运行`test -s "$WORK/evidence/task-2-green.txt"`，确认红阶段失败且原因是green证据缺席；固定任务1 HEAD为`ACCEPTED_HEAD`候选且clean。
- [ ] 步骤 2: candidate核TARGET与PROTO逐字、exact1=331/0、fixed tools、05保护hash、diff-check与clean；串行运行assurance、05 base和offline，捕获rc/双流/末行到green。
- [ ] 步骤 3: 在repo外`git clone --no-local`完整历史checkout，核HEAD=`ACCEPTED_HEAD`、BASE..HEAD exact1；串行运行assurance、05 base和offline并核clean，追加green。
- [ ] 步骤 4: 在repo外真实`git clone --depth 1 file://...`，核HEAD、commit-count=1、shallow marker、TARGET/PROTO blob hash；串行运行assurance、05 base和offline并核clean，追加green；物理清理两个clone。
- [ ] 步骤 5: 写零源码delta report并交独立diff review，PASS后manifest第2行base=head=`ACCEPTED_HEAD`，mark/ledger/sync。

## 报告契约

完整报告写进控制器指定的 `task-N-report.md`（路径由控制器给出）。

返回控制器的只有：
- **Status**：`DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`
- **Commits**：本任务产生的 commit 列表
- **一行测试摘要**：例如 `Ran 12 tests, OK`
- **顾虑**：如有
