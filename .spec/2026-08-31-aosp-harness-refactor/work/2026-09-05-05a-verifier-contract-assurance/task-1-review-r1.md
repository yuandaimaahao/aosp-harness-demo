# Task 1 independent diff review — r1

## 结论

**FAIL — B/I/M = 0/1/0。**

源码 diff 与任务要求的机械交付物一致：review 包仅含一个 `100755` 新文件，新增/删除为 `331/0`；从 diff 包还原的 331 行内容 SHA-256 为 `88f3abcd3f99e252c10e1134b98ea63212584ebd37bc6dfac2f9dd77dedc92ba`，与简报固定值及实现报告一致。实现报告还给出了 prototype `cmp -s` rc 0、固定工具版本/结果、active 默认入口、complete-absent 三路以及 present 下 absent flag 的逐字流证据。

FAIL 的原因不是发现源码偏离 prototype，而是两组明确列入验收清单的验证/回滚证据没有出现在限定审阅材料中，无法把完整验收闭合为 PASS。

## 规格符合性：Requirements

| 条目 | 结论 | 核对结果 |
|---|---:|---|
| R1 | ✅ | diff 包只有 `tests/test-verifier-contract-assurance.sh`，mode `100755`、`331/0`、exact one file、总变更 331≤400；因此所有保护路径在 BASE..HEAD 均零变化。报告声明 bash-n、shfmt v3.14.0、ShellCheck 0.11.0 全绿，且 prototype cmp rc 0。 |
| R2 | ✅ | 顶层 tests 解析 root；active 前对 provider/doc/base 做 repo 内普通非 symlink、provider executable、语法、唯一 anchor、doc/parser/query/fixture surface 检查。三文件全缺席的 default/all/flag 均走 inert PASS；partial/type/symlink/syntax/source/anchor damage 均以 rc1 且无 assurance PASS fail closed。报告对 absent 三路和 present `--dependency-absent` 的 `rc1/stdout空/stderr=FAIL dependency-present` 给出逐字证据。 |
| R3 | ✅ | 独立 `EXPECTED_TEXT` 与执行记录双文件闭合；显式 ID 105 个，加 `cli23 + since9 + query6 + service_ascii80 + surface41 = 159`，总计 264，且检查 expected/executed 的重复、缺失和额外。`run_case` 逐 case 比较五 detail、summary、terminal/rc、双流、调用序列、serial 与 argv；runner/direct 均记录 argc 及逐 argv 的 byte length+hex，runner 独有 `--`。 |
| R4 | ✅ | 23 个 CLI case 覆盖三 flag 重复、since 缺失/多余/非法/Unicode/非法 UTF-8、unknown/positional/help 组合及 allow-skip；serial 缺失/非法和两个合法边界；runner direct/relative/missing/type/symlink/owner/exec/spawn/diagnostic/rc/signal 均有覆盖。help rc0、零 query、双流以及 doc/parser 集合被核对。 |
| R5 | ✅ | 六 query 非零逐项覆盖；默认路径期望六调用，explicit since 期望五调用并验证 1–9 位规范化；boot_time parse/query failure 从 wanted query 中排除 crash，从而验证零 logcat。runner stderr/status 和 direct stderr 抑制均有 oracle。 |
| R6 | ✅ | boot/system_server/btime/crash/service/package 的适用语法格均在 table/补充 case 中；service ASCII 组合为 `4×4×5=80`；CRLF、双 CR、Unicode/control、非法 UTF-8 与 LF 切分边界均有覆盖。 |
| R7 | ✅ | 每个 active case 构造并逐字比较固定五 detail、summary 算术与 terminal/rc；FAIL、strict SKIP/INCOMPLETE、全 PASS、demo allow-skip 均覆盖。十二 fixture 名称同时从 doc 与 production query AST 提取核对；demo 零 query，注入字符串不执行 shell。 |
| R8 | ✅ | temp 由 `/tmp/verifier-assurance.XXXXXX` 创建并检查 EUID ownership、0700、普通空目录且 repo 外；所有生成 fixture/capture/manifest/copy 位于其中。成功先物理 cleanup 再 guarded summary，EXIT trap 保留/升级失败 rc；05 三文件前后 hash 被比较。四 mutant 均检查唯一 anchor、单次替换、语法，并以各自精确 Failure/child stderr label 杀死；child 继续运行 case/manifest/surface 且用 `VC_ASSURANCE_CHILD=1` 禁止递归 mutant。 |

## 规格符合性：验收证据（E）

| 条目 | 结论 | 核对结果 |
|---|---:|---|
| E1 机械交付 | ✅ | prototype cmp rc0 由报告给出；diff 包独立确认 exact one、331 行、331/0、mode 与固定 SHA。 |
| E2 路由/own CLI | ✅ | active/inert/partial/damaged/present-absent 路由可由源码静态闭合，关键 absent/present 路径有报告逐字证据。 |
| E3 manifest | ✅ | 静态计数为 264，expected/executed 独立集合检查具备缺失、重复、额外 oracle。 |
| E4 transport | ✅ | runner/direct 的 length+hex argv、流、query 数、serial、分离 argv、preflight 零 query 均有逐 case oracle。 |
| E5 CLI/query baseline | ✅ | CLI/serial/runner、六 query/default/explicit baseline、help/doc/parser 均覆盖。 |
| E6 grammar | ✅ | 五项 grammar、80 service ASCII、LF/CRLF/非法 bytes 均覆盖。 |
| E7 aggregate/demo | ✅ | 五 detail、summary/terminal、strict/exploratory、十二 fixture 闭合。 |
| E8 temp/hash/mutant | ✅ | 0700 repo 外 temp、hash、cleanup guard 与四 mutant 均有实现；报告声明 green run 执行并清除了 temp。 |
| E9 全套 gates | ⚠️ | 报告仅列 default green、bash-n、固定格式/静态工具和若干 fixture；没有给出验收清单所要求的 candidate/full/depth-1、05 base、offline、manifest/converge/diff/clean 全部 PASS 结果。限定材料无法补证。 |
| E10 rollback/regression/06–09 absence | ⚠️ | exact-one diff 足以证明本提交未改保护路径，但报告没有给出 rollback 零 diff、回归全绿，以及“06/09 执行资产在 active 证据前缺席”的时序/基线证据。 |

## Findings

### 重要

1. **验收清单 E9/E10 缺少报告证据。** `task-1-report.md` 未记录 candidate/full/depth-1、offline、manifest/converge/diff/clean、rollback/regression 以及 active 前 06/09 资产缺席结果。它们是简报的显式验收项；在本次只允许读取三份材料且禁止补跑长验证的条件下，无法判定为已通过。需要补充这些既有运行结果（命令、rc、关键输出/时序）或由控制器明确声明这些是外层 gate、并提供对应证据引用后再复审。

## 质量结论

- **YAGNI：✅** 单文件 Bash wrapper + quoted Python heredoc，未引入第二个源码文件、运行时 API 或外部框架；与固定 prototype/hash 一致。
- **验证有效性：⚠️** 264 manifest、argv codec、grammar、surface 与 mutant oracle 的结构有效；但总体有效性仍受 E9/E10 缺证限制。
- **重复逻辑：✅** expected manifest 与 execution table/loops 有意独立；其余重复主要是紧凑矩阵数据，不构成无收益复制。
- **错误路径：✅** Python 异常统一变为 `FAIL <label>`/rc1，cleanup 失败保留失败态；partial/damaged、query failure、spawn/signal、strict skip 与 present/absent 拒绝路径均 fail closed。

## 复审条件

仅需补齐 finding 1 的现有验证证据或明确的外层 gate 归属；无需因本轮审查修改源码。
