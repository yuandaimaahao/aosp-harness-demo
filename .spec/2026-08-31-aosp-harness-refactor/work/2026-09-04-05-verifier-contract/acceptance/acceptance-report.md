# 2026-09-04-05-verifier-contract 验收报告

验收对象：execution BASE `65d67b52e5b34d0d9d2add587083ebf2fadcd3ea` 到 accepted HEAD `9e5edb45a3048e4c208e2d7fe135639768cc87db`。

## 收口证据回放

本轮执行 `closeout-evidence.py` 的原始输出如下：

```text
# 收口证据回放

## 调研范围
legacy：无此记录

## 调研深度
legacy：无此记录

## 分类依据
legacy：无此记录

## report review
legacy：无此记录

## 自动通过的门及其依据
- 2026-09-01-03-session-state-safety: 门② — 依据：PLAN v5.1 收窄 requirements 已完成三轮全新上下文独立审查并在熔断后逐项裁定；R1-R9、五 API/信号返回、攻击与规模 oracle 闭合，check-plan/check-req/check-criteria/check-analyze/git diff --check 全部通过
- 2026-09-01-03-session-state-safety: 门③ — 依据：PLAN v5.1 收窄 design 经三轮全新上下文独立审查最终 PASS；R1-R9、八节<absolute-path> marker、3文件359行 sizing 全闭合，全部机械检查通过
- 2026-09-01-03-session-state-safety: 门④ — 依据：三轮全新上下文 tasks review 达熔断上限并融合全部承重 finding；16 个串行任务覆盖 R1-R9、六 marker、BASE 证据和 3文件<absolute-path> diff --check 全通过
- 2026-09-04-04-runtime-resource-leases: 门② — 依据：用户已授权后续按 autopilot 执行；requirements 经同一独立 reviewer 三轮审查从 2/5/2 收敛至 0/0/0，owner/独占矩阵<absolute-path> 原子性<absolute-path> hash/状态根<absolute-path> 回流责任全闭合，三项 checker 全绿
- 2026-09-04-04-runtime-resource-leases: 门② — 依据：PLAN v5.8 回流 requirements 经三轮审查与熔断裁定后由同 reviewer 验证最终 PASS（0/0/0）；R1-R8 生产正确性不变，R9 基础合同与04a穷举边界、R10 exact3=400及04a NEXT 五类缺席门闭合，三 checker、固定工具和四类基础 mutant 全绿
- 2026-09-04-04-runtime-resource-leases: 门③ — 依据：PLAN v5.8回流design三轮审查达熔断后由同reviewer只读融合验证最终PASS（0/0/0）；stored lexical canonical、capture安全生命周期、helper固定协议与publish后rollback、assurance反证全部闭合，core exact3=400/400、04a exact1=398/400，固定工具<absolute-path>
- 2026-09-04-04-runtime-resource-leases: 门④ — 依据：tasks三轮独立审查最终PASS（0/0/0）；7任务<absolute-path>
- 2026-09-04-04a-runtime-resource-lease-assurance: 门① — 依据：autopilot：PLAN v5.9 round2 agent复审0/0/0，check-plan与2+2+396=400机械边界通过
- 2026-09-04-04a-runtime-resource-lease-assurance: 门② — 依据：autopilot：requirements三轮熔断后同reviewer只读融合验证PASS 0/0/0；fixed396、churn400、active/all/absent、lifecycle faults与机械门全绿
- 2026-09-04-04a-runtime-resource-lease-assurance: 门③ — 依据：autopilot：design首轮独立review PASS 0/0/0；R1-R10、逐字接口、真实时序、runnable exact2/400原型与固定门通过
- 2026-09-04-04a-runtime-resource-lease-assurance: 门④ — 依据：autopilot：tasks round2 PASS 0/0/0；四任务、R1-R10、exact2/400、四文件red fixture、depth1替代判据和顺序门通过
- 2026-09-04-05-verifier-contract: 门② — 依据：autopilot：requirements三轮原reviewer增量审查最终PASS B0/I0/M0；PLAN v6.0 physical provider边界、五项grammar/六查询、CLI、runnable exact3/400设计硬门与四路验收闭合，全部机械检查及agent+human policy通过
- 2026-09-04-05-verifier-contract: 门③ — 依据：autopilot：PLAN v6.1与requirements范围扩展fresh reviewer PASS；design fresh scope+原reviewer增量最终PASS B0/I0/M0；runnable fixed-format exact3 prototype 371/400，base/shfmt/ShellCheck/bash-n与机械检查全PASS
- 2026-09-04-05-verifier-contract: 门④ — 依据：autopilot：tasks round1 B2/I1已拆为六任务闭合，原reviewer round2 PASS B0/I0/M0；check-tasks/diff-check与R1-R10并集全绿
- 2026-09-04-05-verifier-contract: 门⑤ — 依据：autopilot：controller本轮重跑candidate/full/depth-1/rollback/NEXT/current-21-assets-converge与固定机械门全PASS；R1-R10和四不变量逐条闭合，独立acceptance review B0/I0/M0，无SKIPPED或挂账finding

## 跳过门禁
无

## 挂账 findings
无
```

## ① 判据执行结果

- candidate 主验证原始 stdout：`RESULT PASS  verifier contract`；rc 0，stderr 空。
- candidate offline 原始末行：`RESULT PASS  aosp-harness offline quality gate`；rc 0，stderr 空。其完整 stdout 同轮依次包含 claude lifecycle、shared regression、device safety、resource leases、session 系列和 verifier contract 的 PASS 行。
- 固定工具：shfmt `v3.14.0`、ShellCheck `0.11.0` warning、两个 shell 文件 `bash -n` 全部 rc 0。
- prototype parity：provider、doc、base test 三份 `cmp -s` 均 rc 0。
- BASE..HEAD 原始文件集和 numstat：

```text
common/.harness/bin/verify-sidebar.sh
docs/verifier-contract.md
tests/test-verifier-contract.sh
202  0  common/.harness/bin/verify-sidebar.sh
67   0  docs/verifier-contract.md
102  0  tests/test-verifier-contract.sh
```

总 churn `371/400`；三个旧 verifier、`common/.harness/lib`、session/resource-lease 测试的差异为空。

- 六行六列 manifest：序号1–6、task名、前后HEAD连续、reviewer非空、全部PASS；首BASE为`65d67b52...`，末HEAD为`9e5edb45...`。
- `check-plan`、`check-tasks`、`check-req`、`check-criteria`、`check-analyze`、`check-design`、`sync-ledger`、`git diff --check` 全部 rc 0。
- 当前21个声明验收资产的隔离 converge 原始摘要：`ISOLATED_CONVERGE_CURRENT PASS assets=21 cleanup=absent`。输入/命令绑定：在`mktemp -d /tmp/vc-accept-converge21.XXXXXX`下以`git clone --no-local`复制candidate并detach到accepted HEAD；只把controller当前`tasks.md`复制到fixture并在该临时副本展开`$WORK`，复制task1–6各brief/report/red、task6 green、manifest和acceptance report，共21个普通文件；随后实际执行`check-converge.py "$FIXTURE" "$BASE" "$HEAD" --repo "$TMP_ROOT/repo"`，rc 0、双流空，最后`find "$TMP_ROOT" -depth -delete`并核物理缺席。生产tasks、controller资产和implementation worktree均未在该命令中修改。
- strict INCOMPLETE只读验收probe原始结果：设置`DEMO_PACKAGE_LIST=''`运行canonical provider `--demo`，rc 2、stderr 0 bytes、交付PASS正则无匹配rc1，stdout为：

```text
PASS  boot completed
PASS  system_server alive
PASS  crash-free since baseline
PASS  sidebar service registered
SKIP  sidebar package missing
SUMMARY PASS=4 FAIL=0 SKIP=1
RESULT INCOMPLETE
```

临时目录在输出后物理缺席。首次probe脚本误写了SKIP明细期望而rc1，诊断显示实现输出符合文档固定前缀；更正验收oracle后完整重跑得到上述rc0证据，未修改源码或放宽产品判据。
- full checkout 原始摘要：

```text
RESULT PASS  verifier contract
RESULT PASS  aosp-harness offline quality gate
FULL_METADATA head=9e5edb45a3048e4c208e2d7fe135639768cc87db exact3=identical clean=true
FULL_CLEANUP absent
```

- depth-1 checkout 原始摘要：

```text
RESULT PASS  verifier contract
RESULT PASS  aosp-harness offline quality gate
DEPTH1_METADATA head=9e5edb45a3048e4c208e2d7fe135639768cc87db count=1 shallow=true exact3=identical clean=true
DEPTH1_CLEANUP absent
```

- rollback 删除exact3并提交后相对BASE name-only与numstat均为空；七项回归原始末行：

```text
device rc=0 last=RESULT PASS  device safety
offline rc=0 last=RESULT PASS  aosp-harness offline quality gate
lease-base rc=0 last=RESULT PASS  resource leases
lease-assurance rc=0 last=RESULT PASS  resource lease assurance
legacy-common rc=0 last=RESULT PASS
legacy-claude rc=0 last=RESULT PASS
legacy-codex rc=0 last=RESULT PASS
ROLLBACK_METADATA exact3_deleted=true diff_vs_base=0 clean=true
ROLLBACK_CLEANUP absent
```

- controller主树中05a源码缺席；05a、06、07、08、09、10的spec/branch/worktree/execution BASE/dispatch均缺席。实际检查16个execution目标、0个dispatch目标；空dispatch集合以`rg /dev/null`真实观测rc1，临时树物理清理。
- implementation worktree保持accepted HEAD且clean。

## ② 逐条对照

- R1：CLI参数集合、重复/缺值/组合/位置参数优先级、real `--allow-skip`拒绝、serial正则、统一`adb -s`和help零查询由provider与base test建立；PASS。
- R2：五项逻辑断言、分离query runner、query/parse/business分类和runner前检/双流/rc由provider、文档和base test建立；PASS。
- R3：btime唯一性、显式纳秒补齐、crash bytes/LF/CR与ASCII数字首字节规则已实现；本片代表链路通过，穷举矩阵按约束留给05a；PASS。
- R4：boot/system_server/crash/service/package五项grammar与完整分类表在provider和单一契约文档一致；基础测试未越界复制05a矩阵；PASS。
- R5：五明细、summary和FAIL/INCOMPLETE/PASS/探索PASS终态及rc映射已实现；基础严格PASS路径逐字通过；PASS。
- R6：十二demo fixture、缺省5/0/0、零真实ADB和query-fail单项映射已实现且代表测试通过；PASS。
- R7：repo外EUID自有0700空目录、demo/real default/explicit runner与代表preflight、成功前显式清理全部由102行base test执行；PASS。
- R8：单一文档包含CLI优先级、六argv、runner信任边界、R4表、bytes规则、fixtures、summary/terminal与探索限制；review修复后明确real mode拒绝`--allow-skip`；exact3 runnable 371/400；PASS。
- R9：candidate、full、真实depth-1、rollback四路均本轮运行；固定工具、manifest、converge、clean和NEXT门全部通过；PASS。
- R10：所有任务有真实red，失败路径不提前输出交付PASS；临时树均核物理缺席，首次并行checkout失败结果被废弃并串行重跑，无放宽grammar、删case或忽略工具失败；PASS。

不变量：

- 参数、serial、runner前置错误的query调用数为0：base test日志断言通过。
- 每次完整执行逻辑断言数恰5、缺失0：逐字五明细与summary计数通过。
- strict INCOMPLETE/FAIL误作交付成功次数为0：FAIL由base contract的runner query-failure联合断言，INCOMPLETE由本轮只读demo probe的rc2/末行/无交付PASS联合断言，offline门同时通过。
- 三旧verifier及session/resource-lease public文件变化数为0：BASE..HEAD保护路径diff为空，rollback七回归通过。

## ③ 执行期裁定

以下逐字回放ledger全部`裁定:`行；按潜在代价由接口/证据正确性到仅耗时排序。20资产converge裁定已被后续green声明裁定和最终21资产实跑取代，但仍原样保留：

1. 裁定: PLAN v6.0先将05收窄为canonical provider/doc/test、09独占三旧入口；round2进一步证明既有common入口仍与09重叠，最终改为新增`common/.harness/bin/verify-sidebar.sh` physical provider，05回滚物理缺席、09自有fallback且永不改provider。若判断错误，代价是三入口漂移延至09闭合；若不改，代价是05/09同文件hunk和独立回滚失效。证据：`reviews/requirements-05-verifier-contract-round-{1,2}.md`。
2. 裁定: accept阶段直接从implementation worktree或controller根运行`check-converge.py`均因tasks中的字面`$WORK`验收资产路径正确fail closed；沿用任务6已独立review通过的隔离fixture，只在repo外clone中把`$WORK`展开为同一repo-relative work路径并复制恰20个声明资产，checker rc0后物理删除fixture。依据：tasks reviewer接受`$WORK`简写但checker不展开变量，生产tasks和源码不应在验收期改写；如果错了代价是什么：可能掩盖真实验收资产断链，因此fixture先核20个精确普通文件且不复制未声明green/review资产，最终由manifest/ledger另行独立核验。
3. 裁定: task6独立review要求补出的`evidence/task-6-green.txt`已被report引用但原tasks资产清单只声明red；在accept阶段把green加入任务6验收资产并重生成同任务brief，交原reviewer范围受限复核，source exact3与accepted HEAD不变。依据：closeout只允许引用tasks精确声明的work/evidence路径；如果错了代价是什么：增加一个9121-byte审计资产与一次brief/review更新，但不会改变产品代码、判据或回滚边界。
4. 裁定: 采纳I1，由原实现者在final doc和approved prototype同一行补明确reject谓词，保持67行/exact3=371并更新design中的prototype hash；任务3单提交amend后由原reviewer只审修复增量。依据：这是既有R1/R8的文档澄清、无接口或范围扩大；如果错了代价是什么：prototype hash和任务3提交会变化，但仅需回退一行文档与一处证据hash，provider行为不受影响。
5. 裁定: full与depth-1首次并行offline时full以`FAIL path TMP missing base: fixture changed`失败而depth-1通过，证明套件共享fixture不支持并行；废弃该轮结果并分别串行重跑full和depth-1，两者均contract/offline/exact3/clean PASS。依据：串行是tasks明示顺序且两次repo外clone独立、失败轮全部临时树已清理；如果错了代价是什么：只增加约两分钟验收时间，不放宽任何判据或接受失败结果。
6. 裁定: `plan-wave.py`因产出说明的括号文本未把任务2消费匹配到任务1而把两者同列wave1，但任务2步骤明确要求任务1 HEAD且二者共用单一实施worktree；按tasks的更具体依赖串行执行1→2，其余3→6继续串行。依据：任务2步骤2与共享worktree隔离事实；如果错了代价是什么：只损失可忽略的并行时间，不会改变源码边界或验收结果。
7. 裁定: 上轮会话中断后任务4原执行者不可恢复，仅留下合法red证据、无报告且worktree HEAD/clean未变；改派全新执行者复核red并继续candidate审计，不重派任务1–3。依据：ledger无`任务 4: 完成`锚点且git无新delta；如果错了代价是什么：任务4只读门可能被重复执行一次，但不会产生或遗漏源码变更。
8. 裁定: 当前统一ordinary producer只从source worktree读取ledger并同时要求source status clean，但执行期ledger按controller独占保存在主工作树；发布前独立核source ledger逐字等于HEAD且该路径无既有`assume-unchanged`，再仅临时镜像规范worktree header与唯一execute行并对这一已知路径设flag，退出/中断trap必须反向apply_patch恢复HEAD字节、清flag并复核全source clean。producer的clean只能覆盖ledger以外路径，ledger由上述独立检查补偿；producer可能已在返回前快进main，若后置恢复失败不得自动回滚main，必须保留feature worktree/branch并报告partial publish状态。依据：不改写accepted commit、不扩大exact3，同时仍用原producer核main锁、分支绑定和BASE；如果错了代价是什么：main可能已快进而source留下ledger/index临时态，需要人工按已记录HEAD字节恢复后才能清理，不能把保留feature误报为未发布。

## ④ 跳过的门禁

无。`closeout-evidence.py`回放为“无”，STATE的SKIPPED表也无当前记录。

## ⑤ 挂账 findings

无。六个任务的最终独立diff review均为B0/I0/M0；任务3文档I1已修复并复审PASS，任务6 green声明增量也经两个reviewer复核PASS。
发布前第8条裁定经增量r3复审PASS（B0/I0/M0），r2提出的clean例外与partial publish风险披露I1已闭合。

## ⑥ 结论

可以验收。accepted HEAD只新增约定exact3、总churn 371/400，R1–R10与四条不变量均有本轮执行证据；candidate/full/depth-1/rollback、offline、NEXT、converge、review manifest和clean全部闭合。未push，发布阶段只允许ordinary fast-forward合入controller main。
