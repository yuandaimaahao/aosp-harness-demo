---
id: 2026-09-04-05-verifier-contract
依赖: [2026-09-01-02-offline-quality-gate, 2026-09-04-04a-runtime-resource-lease-assurance]
消费: "02 的根级离线门禁 bash ./scripts/check.sh --offline 及 tests/test-*.sh 默认发现约定；resource-lease-assurance-v1：provider 保持原 public API/状态格式且其 dependency-present active、exact2/400、full/depth-1/rollback 与全 PASS manifest 顺序门证据已入库（无运行时 API）"
产出: "verifier-contract-v1：docs/verifier-contract.md；canonical physical provider common/.harness/bin/verify-sidebar.sh [--demo] [--since <epoch[.nsec]>] [--allow-skip]；五项断言、受控末行与退出码 0|1|2；tests/test-verifier-contract.sh 默认发现入口"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户明确要求后续所有流程统一走 autopilot 且不再询问；PLAN v6.0 经 requirements round1/2 findings 收窄为05新增独立canonical provider/doc/test、09独占三个旧入口与fallback，04a验收行已记录本片启动门证据
---

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并明确“后续所有流程走 autopilot 流程，不要再问我了”。PLAN v6.0 将本片定义为 04a 后、09 verifier adapters 前的独立 canonical verifier 行为契约。

## 目标

交付 `verifier-contract-v1`：新增不被后序 adapter 改写的 `common/.harness/bin/verify-sidebar.sh` canonical physical provider，统一定义 boot、system_server、crash baseline、service、package 五项断言，以及查询失败、业务缺失、解析失败和 `PASS/FAIL/SKIP` 的聚合语义；新增 `docs/verifier-contract.md` 与 `tests/test-verifier-contract.sh`，使 09 可按 provider present/absent 薄化三个旧入口并安全回退。

## 需求

R1. [计划] 系统必须新增并维持canonical provider路径`common/.harness/bin/verify-sidebar.sh`，接受且只接受`verify-sidebar.sh [--demo] [--since <epoch[.nsec]>] [--allow-skip]`与单独的`--help`；解析阶段必须拒绝三个flag各自重复、`--since`缺值/多值/非法值、help组合、未知参数和位置参数，再拒绝真实模式`--allow-skip`，最后按`^[A-Za-z0-9][A-Za-z0-9._:-]*$`校验ANDROID_SERIAL，任一失败均须在零ADB调用下返回2；所有真实ADB命令必须使用同一`adb -s "$ANDROID_SERIAL"`。单独help须退出0、stderr空、零ADB且stdout参数集合与文档一致。

R2. [计划] 当canonical verifier执行时，系统必须各结算一次boot completed、system_server、crash baseline/window、sidebar service与`com.android.sidebar` package五项逻辑断言，并输出恰五行以`PASS  `、`FAIL  `或`SKIP  `开头的明细；外部查询非零必须按对应query-failed明细记FAIL，值语法不合法必须按parse-failed明细记FAIL，语法合法但boot/PID/service目标不满足必须按业务缺失明细记FAIL，只有package语法合法且目标完整行缺失时才记SKIP。本片只保存查询rc用于分类并继续抑制子命令stderr，stderr诊断保留由06负责。

R3. [计划] 当未显式传`--since`时，系统必须从同一目标的`/proc/stat`解析恰一条完整匹配`btime <nonnegative-integer>`的行，零条、多条或只有畸形btime行均使crash项FAIL且不得调用logcat；当显式传入epoch时，系统必须接受非负十进制秒与一至九位小数并右补为九位后传给`logcat -b crash -d -v epoch,nsec -T`。查询成功后必须忽略空行和不以数字开头的header，数字开头的行首token必须是合法epoch；不存在`timestamp >= baseline`时PASS，即纯空或只有早期记录均PASS，等于或晚于baseline时FAIL，畸形数字token或logcat非零时FAIL。

R4. [计划] 当五项查询成功时，系统必须按以下判定表逐项分类；CR须先移除，表中“空行忽略”后无记录即为空，N/A格不得被测试伪造成另一类别。

| 项 | 合法输出 grammar | 空 | 合法但目标未满足 | 语法畸形 | 满足 |
|---|---|---|---|---|---|
| boot | 去首尾ASCII空白后仅`0`或`1` | parse FAIL | `0`为business FAIL | 其他非空为parse FAIL | `1`为PASS |
| system_server | 去首尾ASCII空白后为一个或多个空白分隔的`[1-9][0-9]*` | business FAIL | N/A | `0`、前导零或其他字符为parse FAIL | 合法PID列表为PASS |
| crash | R3的baseline与记录grammar | 空buffer为PASS | 任一合法记录时间`>=baseline`为business FAIL | btime/数字token畸形为parse FAIL | 只有header或早期记录为PASS |
| service | 每个非空行均为`^[0-9]+[[:space:]]+[^[:space:]]+:[[:space:]]+\[[^][]+\][[:space:]]*$` | business FAIL | 合法行中无服务名精确为`sidebar`者为business FAIL | 任一非空行不匹配为parse FAIL | 存在精确`sidebar:`行即PASS |
| package | 每个非空行均为`^package:[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$` | SKIP | 合法行中无精确`package:com.android.sidebar`者为SKIP | 任一非空行不匹配为parse FAIL | 存在目标完整行即PASS |

R5. [计划] 当五项断言结束时，系统必须输出`SUMMARY PASS=<n> FAIL=<n> SKIP=<n>`且三计数之和精确为5；FAIL大于零时末行逐字为`RESULT FAIL`并退出1；FAIL为零但SKIP大于零且未选探索时末行逐字为`RESULT INCOMPLETE`并退出2；无FAIL/SKIP时末行逐字为`RESULT PASS`并退出0；只有`--demo --allow-skip`可把纯SKIP改为`RESULT PASS (SKIP allowed)`与退出0，该探索结果不得作为严格交付证据。

R6. [计划] 凡具备`--demo`，系统必须零调用真实ADB，并由DEMO_BOOT_QUERY_FAIL、DEMO_BOOT_COMPLETED、DEMO_SYSTEM_SERVER_QUERY_FAIL、DEMO_SYSTEM_SERVER、DEMO_BOOT_TIME_QUERY_FAIL、DEMO_BOOT_TIME、DEMO_CRASH_QUERY_FAIL、DEMO_CRASH_LOG、DEMO_SERVICE_QUERY_FAIL、DEMO_SERVICE_LIST、DEMO_PACKAGE_QUERY_FAIL与DEMO_PACKAGE_LIST夹具驱动与真实模式同一解析器；所有变量缺省必须生成`5/0/0`严格PASS，每个query-fail开关只改变对应逻辑项，夹具值不得作为shell代码执行。

R7. [计划] 当运行`tests/test-verifier-contract.sh`时，系统必须从自身解析repo root，在repo外EUID自有0700临时目录安装记录argv并可按六条查询注入stdout/stderr/rc的fake adb，对canonical provider覆盖默认demo成功，boot/system_server/btime/logcat/service/package六条query failure，R4每个适用格，严格与探索SKIP，显式/default baseline，纯空/纯早期/header/等于/晚于/纳秒/畸形数字边界，CRLF，三个flag重复、单独help/help组合、非法since，以及missing、`-bad`、含路径分隔符、空白、控制字符和两个边界合法serial；每个case必须核rc、末行、summary、五明细与调用次数/顺序/`-s`串号，任一case未执行都不得打印固定成功摘要。

R8. [计划] 系统必须新增`docs/verifier-contract.md`作为CLI优先级、六条外部查询、R4判定表、demo fixture、明细前缀、summary、terminal/rc映射和探索限制的单一契约。进入tasks/implementation前，门③必须在隔离临时工作树完成fixed ShellCheck/shfmt的runnable exact3 prototype：完整三文件、真实执行R7全矩阵并输出固定摘要，以`git diff --numstat`证明added+removed总量不超过400；若不成立必须回PLAN拆片，不得用未执行skeleton、预估行数或删减R7 oracle放行。05不得修改三个旧verifier入口或引入06/07/09实现。

R9. [计划] 当本片进入验收时，系统必须在candidate、完整历史checkout、真实`git clone --depth 1 file://...`与exact rollback四路执行验证；candidate/full/depth-1的contract test须退出0、stderr空、stdout逐字为`RESULT PASS  verifier contract\n`，offline门禁须退出0且末行为`RESULT PASS  aosp-harness offline quality gate`，depth-1须只有一个commit且存在shallow marker；rollback须移除本片exact3，使01 device-safety、02 offline、04/04a lease与三个旧verifier既有demo回归通过。固定ShellCheck/shfmt、`bash -n`、`git diff --check`、六列review manifest和隔离`check-converge.py`必须全绿，06/07/08/09/10不得出现本片提前创建的branch/worktree/execution BASE/dispatch资产。

R10. [计划] 如果发生任一查询、解析、fixture构造、case计数、临时目录清理、静态检查、预算、checkout、回滚或顺序门失败，系统必须非零退出且不得打印`RESULT PASS  verifier contract`；失败路径不得残留repo内状态或repo外测试树，也不得以减少矩阵case、放宽grammar或忽略工具失败继续推进。

## 验收标准

主验证命令: bash ./tests/test-verifier-contract.sh
期望输出: 退出码为`0`、stderr空，stdout逐字节精确为`RESULT PASS  verifier contract\n`，且canonical provider的完整mock矩阵全部执行

验收清单:

- [ ] canonical provider物理独立于三个旧入口；CLI拒绝优先级、三个flag重复、单独help/help组合、真实allow-skip、serial正则与全部ADB `-s` argv符合R1，所有前置错误零ADB且rc2。
- [ ] R4判定表逐个适用格覆盖query非零、空、语法畸形、合法业务缺失与PASS；package仅合法缺包为SKIP，每次summary计数和恰为5。
- [ ] btime absent/duplicate/malformed、显式0–9位小数、纯空/纯早期/header/等于/晚于/纳秒/畸形数字行与logcat失败均有唯一结论，btime失败零logcat。
- [ ] FAIL、严格SKIP、严格PASS与demo探索PASS的末行/退出码逐字符合R5，只有严格`RESULT PASS`可作交付证据。
- [ ] contract test的每个canonical×matrix case都有执行计数，fake adb核argv/stdout/stderr输入/rc，demo全程零ADB，固定摘要只在全部oracle后打印。
- [ ] `docs/verifier-contract.md`列出CLI/优先级、六查询/R4判定表、fixture、summary、terminal/rc与交付限制；门③runnable exact3 prototype真实跑完整矩阵、fixed-format且churn≤400。
- [ ] BASE..HEAD exact三文件且churn≤400；固定静态工具、manifest、diff-check、clean、隔离converge与candidate/full/depth-1的contract/offline全部通过。
- [ ] rollback移除exact3后，01/02/04/04a与三个旧入口回归通过；后序09可按provider物理缺席走自有fallback而不覆盖其hunks，后序五片无提前执行资产。

不变量（不许劣化，2-4项）:

- 真实模式在参数或serial校验完成前的ADB调用数 ≤ 0，验证: contract test的invalid CLI/serial fake-adb argv log。
- 每次完整verifier执行的逻辑断言数 = 5且未执行matrix case数 ≤ 0，验证: `bash ./tests/test-verifier-contract.sh`的summary/coverage counters。
- strict INCOMPLETE或FAIL被误判为交付成功的次数 ≤ 0，验证: contract test对terminal+rc联合断言及`bash ./scripts/check.sh --offline`。
- 三个旧verifier及session/resource-lease public文件变化数 ≤ 0，验证: `git diff "$BASE" "$HEAD" -- common/.harness/features/dev-sidebar/verify-sidebar.sh claude-code/features/dev-sidebar/verify-sidebar.sh codex/features/dev-sidebar/verify-sidebar.sh common/.harness/lib tests/test-session-*.sh tests/test-resource-leases*.sh`。

## 超出范围

- 不调用真实设备、AOSP build、CVD、网络或外部客户端；真实模式只在隔离fake adb上验argv、输出和退出码。
- 不实现子命令stderr诊断保留、超时、重试、取消、租约、registry、dispatcher或client/session adapter；这些属于06、07、09与08。
- 不改三个旧verifier，不做三入口parity、薄化或legacy fallback；09消费本片physical provider后完成。
- 不修改session/resource-lease provider、01/02既有测试、README/长文或后序spec，不push，不清理其他项目或已有worktree。
