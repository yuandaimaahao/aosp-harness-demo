---
id: 2026-09-04-05-verifier-contract
依赖: [2026-09-01-02-offline-quality-gate, 2026-09-04-04a-runtime-resource-lease-assurance]
消费: "02 的根级离线门禁 bash ./scripts/check.sh --offline 及 tests/test-*.sh 默认发现约定；resource-lease-assurance-v1：provider 保持原 public API/状态格式且其 dependency-present active、exact2/400、full/depth-1/rollback 与全 PASS manifest 顺序门证据已入库（无运行时 API）"
产出: "verifier-contract-v1：docs/verifier-contract.md；canonical physical provider common/.harness/bin/verify-sidebar.sh [--demo] [--since <epoch[.nsec]>] [--allow-skip]；private HARNESS_VERIFIER_QUERY_RUNNER=<absolute-euid-owned-regular-executable> 接收 <query-key> -- adb -s <serial> <argv...> 并传回 stdout/stderr/rc；五项断言、受控末行与退出码 0|1|2；tests/test-verifier-contract.sh 默认发现基础入口"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户明确要求后续所有流程统一走 autopilot 且不再询问；PLAN v6.1 经 design round1 findings 增加private query-runner seam并拆出05a独立assurance，05仍独占canonical provider/doc/base test、09独占三个旧入口与fallback，04a验收行已记录本片启动门证据
---

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并明确“后续所有流程走 autopilot 流程，不要再问我了”。PLAN v6.1 将本片定义为 04a 后、05a assurance 前的独立 canonical verifier core。

## 目标

交付 `verifier-contract-v1`：新增不被后序 adapter 改写的 `common/.harness/bin/verify-sidebar.sh` canonical physical provider，统一定义 boot、system_server、crash baseline、service、package 五项断言，以及查询失败、业务缺失、解析失败和 `PASS/FAIL/SKIP` 的聚合语义；新增完整 `docs/verifier-contract.md` 与代表性 `tests/test-verifier-contract.sh`，并提供私有逐查询 `HARNESS_VERIFIER_QUERY_RUNNER` transport seam，使 09 能在不改 provider 的前提下组合 06 runtime。穷举 oracle 由后序 05a 独占，在其 dependency-present 证据通过前不得开始 06/09。

## 需求

R1. [计划] 系统必须新增并维持canonical provider路径`common/.harness/bin/verify-sidebar.sh`，接受且只接受`verify-sidebar.sh [--demo] [--since <epoch[.nsec]>] [--allow-skip]`与单独的`--help`；解析阶段必须拒绝三个flag各自重复、`--since`缺值/多值/非法值、help组合、未知参数和位置参数，再拒绝真实模式`--allow-skip`，最后按`^[A-Za-z0-9][A-Za-z0-9._:-]*$`校验ANDROID_SERIAL，任一失败均须在零ADB调用下返回2；所有真实ADB命令必须使用同一`adb -s "$ANDROID_SERIAL"`。单独help须退出0、stderr空、零ADB且stdout参数集合与文档一致。

R2. [计划] 当canonical verifier执行时，系统必须各结算一次boot completed、system_server、crash baseline/window、sidebar service与`com.android.sidebar` package五项逻辑断言，并输出恰五行以`PASS  `、`FAIL  `或`SKIP  `开头的明细；外部查询非零必须按对应query-failed明细记FAIL，值语法不合法必须按parse-failed明细记FAIL，语法合法但boot/PID/service目标不满足必须按业务缺失明细记FAIL，只有package语法合法且目标完整行缺失时才记SKIP。默认transport执行分离argv并抑制子命令stderr；私有`HARNESS_VERIFIER_QUERY_RUNNER`若设置，必须在任何查询前验证为绝对路径、EUID自有、可执行的普通非symlink文件，再以`<query-key> -- adb -s <serial> <argv...>`调用，捕获其stdout、继承其stderr并维持非负rc（信号规范化为`128+signal`）；未设置时保持直接ADB。runner非法须零查询rc2，exec失败须固定诊断并使对应项query FAIL。该seam不是设备真实性边界，09只可绑定到其可信06 adapter；provider缺席仍由09 legacy fallback处理。

R3. [计划] 当未显式传`--since`时，系统必须从同一目标的`/proc/stat`解析恰一条完整匹配`btime <nonnegative-integer>`的行，零条、多条或只有畸形btime行均使crash项FAIL且不得调用logcat；当显式传入epoch时，系统必须接受非负十进制秒与一至九位小数并右补为九位后传给`logcat -b crash -d -v epoch,nsec -T`。所有查询输出按bytes只以LF分行、逐行移除至多一个尾CR；查询成功后必须忽略空行和原始首字节不是ASCII`0`–`9`的header，数字开头行的首ASCII空白分隔token必须是合法epoch；不存在`timestamp >= baseline`时PASS，即纯空或只有早期记录均PASS，等于或晚于baseline时FAIL，畸形数字token或logcat非零时FAIL；前导空白、Unicode digit与非法UTF-8均不得被误当合法数字行。

R4. [计划] 当五项查询成功时，系统必须按以下判定表逐项分类；按R3逐LF记录移除至多一个尾CR，表中“空行忽略”后无记录即为空，N/A格不得被测试伪造成另一类别。

| 项 | 合法输出 grammar | 空 | 合法但目标未满足 | 语法畸形 | 满足 |
|---|---|---|---|---|---|
| boot | 去首尾ASCII空白后仅`0`或`1` | parse FAIL | `0`为business FAIL | 其他非空为parse FAIL | `1`为PASS |
| system_server | 去首尾ASCII空格/tab/LF后为一个或多个空格/tab分隔的`[1-9][0-9]*` | business FAIL | N/A | `0`、前导零或其他字符为parse FAIL | 合法PID列表为PASS |
| crash | R3的baseline与记录grammar | 空buffer为PASS | 任一合法记录时间`>=baseline`为business FAIL | btime/数字token畸形为parse FAIL | 只有header或早期记录为PASS |
| service | 每个非空LF记录均为bytes grammar `^[0-9]+[ \t]+[^ \t]+:[ \t]+\[[^][\r\n]+\][ \t]*$` | business FAIL | 合法行中无服务名精确为`sidebar`者为business FAIL | 任一非空行不匹配为parse FAIL | 存在精确`sidebar:`行即PASS |
| package | 每个非空行均为`^package:[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$` | SKIP | 合法行中无精确`package:com.android.sidebar`者为SKIP | 任一非空行不匹配为parse FAIL | 存在目标完整行即PASS |

R5. [计划] 当五项断言结束时，系统必须输出`SUMMARY PASS=<n> FAIL=<n> SKIP=<n>`且三计数之和精确为5；FAIL大于零时末行逐字为`RESULT FAIL`并退出1；FAIL为零但SKIP大于零且未选探索时末行逐字为`RESULT INCOMPLETE`并退出2；无FAIL/SKIP时末行逐字为`RESULT PASS`并退出0；只有`--demo --allow-skip`可把纯SKIP改为`RESULT PASS (SKIP allowed)`与退出0，该探索结果不得作为严格交付证据。

R6. [计划] 凡具备`--demo`，系统必须零调用真实ADB，并由DEMO_BOOT_QUERY_FAIL、DEMO_BOOT_COMPLETED、DEMO_SYSTEM_SERVER_QUERY_FAIL、DEMO_SYSTEM_SERVER、DEMO_BOOT_TIME_QUERY_FAIL、DEMO_BOOT_TIME、DEMO_CRASH_QUERY_FAIL、DEMO_CRASH_LOG、DEMO_SERVICE_QUERY_FAIL、DEMO_SERVICE_LIST、DEMO_PACKAGE_QUERY_FAIL与DEMO_PACKAGE_LIST夹具驱动与真实模式同一解析器；所有变量缺省必须生成`5/0/0`严格PASS，每个query-fail开关只改变对应逻辑项，夹具值不得作为shell代码执行。

R7. [计划] 当运行`tests/test-verifier-contract.sh`时，系统必须从自身解析repo root，在repo外EUID自有0700空普通目录运行代表性基础合同：默认demo逐字五PASS且零query；真实default baseline逐字五PASS并逐参数核六条seam调用及统一serial；真实显式since核五调用、九位补齐、query非零对应detail、runner stderr传透和rc；至少各一项duplicate/missing/multivalue/help-combination/positional CLI、非法serial、非法runner及单独help均核rc/双流/零query。测试必须显式删除临时目录、核物理缺席后才打印固定成功摘要，失败trap只尽力清理且任何失败不得提前打印PASS。R3/R4全部格、六query-failure与全部边界的穷举、自反证、case manifest和长度保真argv编码由05a独占，05基础测试不得复制该矩阵。

R8. [计划] 系统必须新增`docs/verifier-contract.md`作为CLI优先级、六条精确分离argv、private runner协议/信任边界、R4完整判定表、bytes/LF/CR规则、十二个demo fixture、五明细固定顺序/前缀、summary、terminal/rc映射和探索限制的单一契约。进入tasks/implementation前，门③必须在隔离临时工作树完成fixed ShellCheck/shfmt的runnable exact3 core prototype：完整provider/doc/base-test、真实执行R7并输出固定摘要，以`git diff --numstat`证明added+removed总量不超过400；05a穷举assurance另须在其自身门③证明exact1≤400。不得用未执行skeleton、预估行数或把R7基础oracle推迟放行。05不得修改三个旧verifier入口、创建05a源码或引入06/07/09实现。

R9. [计划] 当本片进入验收时，系统必须在candidate、完整历史checkout、真实`git clone --depth 1 file://...`与exact rollback四路执行验证；candidate/full/depth-1的contract test须退出0、stderr空、stdout逐字为`RESULT PASS  verifier contract\n`，offline门禁须退出0且末行为`RESULT PASS  aosp-harness offline quality gate`，depth-1须只有一个commit且存在shallow marker；rollback须移除本片exact3，使01 device-safety、02 offline、04/04a lease与三个旧verifier既有demo回归通过。固定ShellCheck/shfmt、`bash -n`、`git diff --check`、六列review manifest和隔离`check-converge.py`必须全绿；05a的spec/branch/worktree/execution BASE/dispatch五类资产以及06/07/08/09/10执行资产必须物理缺席。只有05 dependency-present证据入ledger后才可创建05a，只有05a完整active证据入ledger后才可启动06/09；05a inert PASS不能解除顺序门。

R10. [计划] 如果发生任一查询、解析、fixture构造、case计数、临时目录清理、静态检查、预算、checkout、回滚或顺序门失败，系统必须非零退出且不得打印`RESULT PASS  verifier contract`；失败路径不得残留repo内状态或repo外测试树，也不得以减少矩阵case、放宽grammar或忽略工具失败继续推进。

## 验收标准

主验证命令: bash ./tests/test-verifier-contract.sh
期望输出: 退出码为`0`、stderr空，stdout逐字节精确为`RESULT PASS  verifier contract\n`，且canonical provider的demo/real、default/explicit baseline、runner与preflight基础合同全部执行

验收清单:

- [ ] canonical provider物理独立于三个旧入口；CLI拒绝优先级、三个flag重复、单独help/help组合、真实allow-skip、serial正则与全部ADB `-s` argv符合R1，所有前置错误零ADB且rc2。
- [ ] provider实现R3/R4完整grammar；基础测试以default/explicit baseline及代表query failure验证主链，05a负责逐格穷举与mutation自反证且在其验收前无consumer启动。
- [ ] private runner前置校验、六query key、`--`后分离ADB argv、stdout/继承stderr/rc协议与默认direct模式闭合；09无需改provider即可接06。
- [ ] FAIL、严格SKIP、严格PASS与demo探索PASS的末行/退出码逐字符合R5，只有严格`RESULT PASS`可作交付证据。
- [ ] base contract test逐字核demo与real主链、runner传输、代表preflight，并在repo外安全temp物理删除后才打印摘要；完整case manifest由05a单文件独占。
- [ ] `docs/verifier-contract.md`列出CLI/优先级、六query argv/runner seam、R4 bytes判定表、fixture、summary、terminal/rc与交付限制；门③runnable exact3 core prototype fixed-format、真实执行且churn≤400。
- [ ] BASE..HEAD exact三文件且churn≤400；固定静态工具、manifest、diff-check、clean、隔离converge与candidate/full/depth-1的contract/offline全部通过。
- [ ] rollback移除exact3后，01/02/04/04a与三个旧入口回归通过；后序09可按provider物理缺席走自有fallback而不覆盖其hunks，后序五片无提前执行资产。

不变量（不许劣化，2-4项）:

- 真实模式在参数、serial或runner校验完成前的query调用数 ≤ 0，验证: contract test的invalid CLI/serial/runner log。
- 每次完整verifier执行的逻辑断言数 = 5且断言缺失数 ≤ 0，验证: base test逐字输出与后序05a完整summary/coverage counters。
- strict INCOMPLETE或FAIL被误判为交付成功的次数 ≤ 0，验证: contract test对terminal+rc联合断言及`bash ./scripts/check.sh --offline`。
- 三个旧verifier及session/resource-lease public文件变化数 ≤ 0，验证: `git diff "$BASE" "$HEAD" -- common/.harness/features/dev-sidebar/verify-sidebar.sh claude-code/features/dev-sidebar/verify-sidebar.sh codex/features/dev-sidebar/verify-sidebar.sh common/.harness/lib tests/test-session-*.sh tests/test-resource-leases*.sh`。

## 超出范围

- 不调用真实设备、AOSP build、CVD、网络或外部客户端；真实模式只在隔离fake adb上验argv、输出和退出码。
- 不实现超时、重试、取消、租约、registry、dispatcher或client/session adapter；private seam只传输runner stderr/rc/stdout，runtime策略属于06，绑定属于09。
- 不改三个旧verifier，不做三入口parity、薄化或legacy fallback；09消费本片physical provider后完成。
- 不修改session/resource-lease provider、01/02既有测试、README/长文或后序spec，不push，不清理其他项目或已有worktree。
