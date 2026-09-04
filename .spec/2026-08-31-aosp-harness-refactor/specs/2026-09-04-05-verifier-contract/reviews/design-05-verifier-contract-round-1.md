# 05 verifier contract design review — round 1

## 结论

- 规格符合性：**NEEDS_CHANGES**
- 设计质量：**NEEDS_CHANGES**
- Findings：**B=4 / I=2 / M=0**

设计文档具备概述、需求映射、架构、组件/接口、数据模型、数据流、错误处理、测试策略和文件清单，R1–R10 也都有名义映射。05 新增 physical provider、09 永不修改它、provider 物理缺席时由 09 自有 fallback 接管的 owner/rollback 边界，在 requirements、PLAN v6.0、DECISIONS 和 design 之间一致。三个原型均为完整可运行文件而非 skeleton；三文件全为新增时，`187 + 138 + 43 = 368` 同时就是 additions+deletions churn，满足 `368 <= 400`。但以下问题使该 runnable prototype 还不能作为门③的完整 R7/R8/R10 证明。

## Findings

### [阻断 B1] 05 的内部 ADB transport 无法在既定 owner 边界下与 06/09 组合

- 定位：`design.md:40,46-50,66-67`；`requirements.md:21,73-74`；`PLAN.md:149-167,204-205`；`prototypes/common/.harness/bin/verify-sidebar.sh:74-78`
- 影响：provider 在 Python 内直接执行 `subprocess.run(["adb", "-s", serial] + args, ..., stderr=DEVNULL)`，公开面只有最终 CLI，没有 separated-argv query-runner seam。PLAN 又要求 09 同时消费 05 和 `harness_command_run`，且 09 永不修改 05 provider；因此 09 最多只能用 06 包住整个 verifier 进程，不能让 06 对六条 ADB query 分别实施 timeout/retry/诊断。尤其 ADB stderr 已在 provider 内丢弃，外层 runtime 无法恢复 requirements 所称“stderr 诊断保留由 06 负责”。用 PATH 中的 `adb` shim 也无法恢复 stderr，因为 shim/runtime 的 stderr 仍被 `DEVNULL` 吞掉。这使 `05 -> 09` 与 `06 -> 09` 两条消费签名无法按计划同时兑现。
- 建议：在不让 09 改写 provider 的前提下，先在 PLAN/requirements/design 中固定一个安全、分离 argv、可由 09 绑定到 06 的 transport seam（并规定 rc/stdout/stderr 协议、真实模式信任边界及 absent fallback），或者明确调整文件 owner。随后把该 seam 纳入原型与预算实测。不要把整进程包装或未定义的 PATH 劫持当作逐 query runtime 集成。

### [阻断 B2] contract test 没有证明 R7 要求的逐 case 完整 oracle 与真实 argv

- 定位：`prototypes/tests/test-verifier-contract.sh:16-37,39-137`
- 影响：
  - `result()` 只核一个可选 detail、detail 行总数和宽松 summary 正则，不核五项固定顺序/各状态，也不核 `PASS+FAIL+SKIP=5` 或 summary 与五行一致。
  - 六个 query-failure case 没传期望 detail；调用错误 query、错误分类或错误顺序仍可能被其它非零路径掩盖。
  - fake adb 用 `$*` 记录和分派，丢失 argv 边界；成功 real case只核总调用数、统一 serial 和一条 logcat 文本，不逐字核六条 separated argv 的顺序。各 failure case 的应有调用数/顺序未核。
  - demo case 在 fake adb 安装前运行，且不核调用日志，因而没有证明 `--demo` 零 ADB；btime 失败也没有用真实调用日志证明零 logcat。
  - 没有 real `--since` case证明九位补齐后的 `-T` argv；CLI 表缺 `--since 1 extra` 多值和普通位置参数的独立 case；help 只做子串检查，未证明参数集合与文档精确一致。
  - `CASES >= 38` 不是 case manifest。当前约 41 个 result case 中即便漏跑数个仍可打印固定 PASS，直接违反“任一 case 未执行不得打印固定摘要”。
- 建议：为每个 case 声明唯一 ID 和完整 oracle（rc、完整五 detail、精确 summary、terminal、stderr、精确 argv 序列/次数）；以 NUL/长度编码或逐参数 quoted 记录保留 argv 边界。使用 exact case manifest/count，分别对 demo 零调用、btime 失败零 logcat、六 query failure、default/explicit baseline 和每个 real case断言调用轨迹。补齐 multi-value、位置参数及 help↔doc 精确集合检查，所有 oracle 完成后才能进入最终摘要。

### [阻断 B3] 临时目录与最终摘要顺序允许 R10 所禁止的假 PASS

- 定位：`prototypes/tests/test-verifier-contract.sh:5-14,137-138`
- 影响：`! "$TMP" -ef "$ROOT"` 只证明两个路径不是同一 inode，不能证明临时目录位于 repo 外；调用者令 `TMPDIR` 指向 repo 子目录时仍会通过。更关键的是固定 `RESULT PASS  verifier contract` 在 EXIT cleanup 之前打印；若 `rm -rf` 失败，脚本虽可能最终非零，stdout 已含被 R10 明令禁止的成功摘要，且 cleanup 后没有物理缺席复核。
- 建议：规范化并验证 temp 是 repo 外、EUID 自有 0700 的普通空目录；把 cleanup 变为显式成功门，删除后核物理缺席，最后才打印 PASS。失败 trap 负责尽力清理并保持非零，但任何 cleanup/readiness 失败路径都不能先打印 PASS。

### [阻断 B4] contract 文档没有交付 R8 指定的单一完整契约

- 定位：`prototypes/docs/verifier-contract.md:3-22,24-43`
- 影响：文档只用摘要文字描述 query 和判定，没有列出六条完整外部 argv，没有复刻 R4 的合法 grammar/空/业务缺失/parse/满足全表，也没有定义 `PASS  `/`FAIL  `/`SKIP  `明细前缀和逐项固定顺序；query-failure fixture 只写泛化的 `DEMO_<KEY>_QUERY_FAIL`，没有枚举六个实际 key。CLI 优先级也没有完整列出缺值/多值/非法 since、help 组合、未知/位置参数的拒绝关系。09 或人类调用者仍须回读 requirements/实现猜测，故它不是 R8 所要求的 single contract。
- 建议：把 CLI 接受集与拒绝优先级、六条精确 separated argv、R4 完整表、十二个 fixture 名、五明细固定顺序/前缀、summary/terminal/rc 和探索证据限制全部写入文档，并由测试机械比对 help/fixture/query 契约，避免三份真相漂移。

### [重要 I1] crash parser 会把“非数字开头”的行改写成数字开头再分类

- 定位：`requirements.md:23`；`prototypes/common/.harness/bin/verify-sidebar.sh:127-135`
- 影响：R3 要求只解析原始行中数字开头的行，非数字开头 header 忽略；实现先 `line = line.strip()`，所以 `" 100.000000000 record"` 被当成等于 baseline 的记录并 FAIL，而按契约它原本以空格开头，应作为 header 忽略。`.isdigit()` 还不是明确的 ASCII `[0-9]` 判定，Unicode digit 会进入后续 parse-failed 路径，增加 bytes/Unicode 语义歧义。
- 建议：CR 移除后保留行首，先按原始首字节/ASCII 字符判断 `[0-9]`，再提取首 token；只对真正空行做空判断。增加 leading-ASCII-space、Unicode digit 和非法 UTF-8（real fake-adb 字节输出）用例，固定是 ignore 还是 parse FAIL。

### [重要 I2] service grammar 实现窄于 R4 的 `[[:space:]]`

- 定位：`requirements.md:32`；`prototypes/common/.harness/bin/verify-sidebar.sh:12,148-155`；`prototypes/tests/test-verifier-contract.sh:58-60,89-91`
- 影响：实现将分隔和尾空白限定为 space/tab，且 `splitlines()` 会把 VT/FF 当作换行边界；这不等价于契约明确写出的 `[[:space:]]`。合法 grammar 在这些字符上会被判 parse FAIL，现有测试只有普通空格/CRLF，未发现偏差。相同的 text/bytes line splitting 规则也未在文档中固定。
- 建议：先固定 `[[:space:]]` 在本契约中的确切字节集合与按 LF 分行规则，再让 Python regex/分行严格等价；为每个允许的 separator/trailing whitespace 和一个 Unicode/非法字节反例加 oracle。

## 规格覆盖结论

| 需求 | 结论 | 摘要 |
|---|---|---|
| R1 | 部分符合 | parser/serial/统一 `adb -s` 实现正确；测试缺多值/位置参数、help 精确集合和逐 argv 边界证明。 |
| R2 | 部分符合 | 五项聚合及 query rc 分类主路径存在；transport 与 06 不可组合，spawn/OSError 也会逃出结构化五项协议。 |
| R3 | 部分符合 | tuple epoch、btime 数量、九位补齐和边界主体正确；原始行首语义错误，零 logcat 未由调用日志直接证明。 |
| R4 | 部分符合 | 每个适用表格类别都有名义 case；service whitespace 实现不等价，且 case oracle 没核完整五项结果。 |
| R5 | 部分符合 | provider terminal/rc 分支正确；测试不证明 summary 算术及与 detail 一致。 |
| R6 | 部分符合 | demo/real 共用 evaluator、fixture 不经 shell eval；测试没有 ADB spy 证明 demo 零调用。 |
| R7 | 不符合 | B2、B3 所述逐 case、argv、计数、隔离和 cleanup 证据不足。 |
| R8 | 不符合 | exact3/churn 成立，但文档不完整且 runnable prototype 没跑出完整 R7 oracle。 |
| R9 | 设计层符合 | candidate/full/depth-1/exact rollback 和旧回归责任已交给 controller，exact3/09 fallback 边界清楚。 |
| R10 | 不符合 | cleanup 前打印 PASS，且 loose coverage threshold 允许漏 case 后成功。 |

## 质量结论

优点是 physical ownership、回滚物理缺席判定、单文件 Python 3.8 兼容实现、整数 tuple epoch、无 shell-eval fixture、ADB stderr 抑制和 368 行预算都清晰可审。当前主要质量风险不是代码骨架不足，而是跨片可组合性和测试证据强度不足：即使现有 prototype 固定输出 PASS，也尚不能排除 transport 无法接入 06、argv 边界漂移、漏 case、cleanup 后失败以及两处 grammar 偏差。修复 B1–B4、I1–I2 并重新给出 runnable exact3/churn 证据后再复审。
