# 05 verifier contract requirements review — round 1

结论：**NEEDS_CHANGES**

计数：阻断 **1** / 重要 **6** / 次要 **1**

审查范围：完整阅读 `requirements.md`；核对 `PLAN.md` 的 05、直接依赖、回滚、预算与 09 边界，`DECISIONS.md`，`research/report.md`，三套现有 verifier，`tests/test-device-safety.sh` 与 `scripts/check.sh`。按委托不重跑 controller 已跑的 checker，也不做开放式全仓审查。

## 阻断

### B1 — 05 的文件所有权与 400 行边界同时背离 PLAN，当前交付边界没有成立证据

定位：`requirements.md:15,19,29,31,35,37,66`；`PLAN.md:68-92,148-150,164-166,227,300-305`。

影响：PLAN 的独占文件表把 05 固定为“verifier contract 文档、common verifier 断言、contract test”，并把“三个薄 verifier 入口”明确归给 09；05 的独立回滚也只写“contract 文档/共用断言”。requirements 却要求直接把 common、Claude、Codex 三个生产 verifier 全部改齐，并把 exact 边界改成五文件。这不是对 PLAN 的细化，而是 owner 和回滚面的变更，会提前占用 09 的三个入口边界。

预算也没有可实施证明。现有三个脚本分别为 120、156、331 行；common 缺 crash/package/`--since`/summary，Claude 仍有查询失败与业务缺失混淆、严格 SKIP rc=1、无 `--help`，Codex 仍有严格 SKIP rc=1、首个 btime 即接受和 stderr 丢弃。与此同时还要新增契约文档和覆盖三入口完整矩阵的测试。requirements 直接宣称五文件总 churn `<=400`，但没有类似 04/04a 的 fixed-shfmt runnable sizing 证据；在显著扩大 PLAN 文件面的同时，这个硬门极易迫使实现压缩或删除承重 oracle。

建议：进入 design 前回流 PLAN，二选一并统一所有表述：

1. 保持 PLAN 原 owner：05 只交付 common canonical contract/doc/test，把真实三入口 parity 明确移到 09；相应改写 05 的目标、矩阵与回滚。
2. PLAN 正式授权 05 修改三入口，并重新划清 09 只做 dispatcher/薄化；先用 fixed ShellCheck/shfmt 的 runnable prototype 证明“三 verifier + 文档 + 完整测试”按 `git diff --numstat` 的 additions+deletions 总和不超过 400，否则拆片。

在 owner 与预算同时闭合前，本 requirements 不能进入实现。

## 重要

### I1 — R2 的 stderr 要求与本片“诊断保留属于 06”直接冲突

定位：`requirements.md:21,31,65`；`PLAN.md:38,150,152-154`。

影响：R2 禁止“stderr 丢弃”，R7 又要求 fake adb 注入 stderr；但超出范围明确说本片不实现诊断保留，诊断属于 06。实现者无法判断 05 是否必须透传、缓存或格式化 adb stderr。三种选择都会形成不同 stdout/stderr contract；若在 05 保留诊断则越过 06，若仅以 rc 分类后丢弃则字面违反 R2。

建议：把 05 的职责钉死为“独立保存 command rc，非零一律归类 query failure，不得用 `|| true` 或空 stdout 抹平 rc”；明确本片是否以及如何处理子命令 stderr。若诊断确归 06，则删去“stderr 丢弃”禁令，R7 只需用带 stderr 的非零 fake 证明分类不受空 stdout/有 stderr 影响，不要求诊断透传。

### I2 — crash PASS 条件自相矛盾，非时间戳行也没有确定语义

定位：`requirements.md:23,31,48`。

影响：R3 一方面规定早于 baseline 的记录必须忽略，另一方面又写“空 crash 结果才可 PASS”。一个只含早期记录的非空输出因此既应 PASS 又不得 PASS。对真实 logcat 可能出现的非数字 header/分隔行，规则只定义了“数字开头但畸形”必须 FAIL，没有定义其他非空非数字行是忽略还是解析失败。三入口可以各自作出不同且都貌似合规的实现。

建议：改为唯一判据，例如“在查询成功、所有承重时间戳均可解析、且不存在 `timestamp >= baseline` 的记录时 PASS；早期记录可使非空输出仍 PASS”。同时明确非数字 header 的允许集合或一律处理方式，并在矩阵中分别覆盖：纯空、纯早期、早期+等于、非数字 header、数字开头畸形。

### I3 — `btime` 的“唯一合法行”没有对应负向 oracle，现有实现的 first-match 假绿不会被明确拦截

定位：`requirements.md:23,25,29,31,48`；现有 `codex/features/dev-sidebar/verify-sidebar.sh:199-230`。

影响：R3 要求 `/proc/stat` 中唯一合法的 `btime <integer>`，但 R7/验收清单只概括“显式/默认 baseline”，未要求 0 条、2 条、合法行夹杂畸形 `btime` 的独立 case。当前 Codex verifier 遇到第一条合法行便 `break`，两个合法 btime 也会通过；contract test 即使覆盖普通 default baseline 仍会假绿。

建议：明确“恰一条匹配整行语法的 btime；0 条或多于 1 条均为 crash 这一项的解析 FAIL”，并至少加入 absent、duplicate-valid、malformed-only 三个 DEMO_BOOT_TIME/real fake-adb oracle；核对失败时不调用 logcat，但仍完成另外四项并保持 summary 总和为 5。

### I4 — query failure 数量写错：R6 定义 6 条失败路径，R7 只要求 5 类

定位：`requirements.md:29,31,47-50`。

影响：五项逻辑断言不等于五条外部查询。crash 项包含 `/proc/stat` baseline 查询和 logcat 查询，所以 R6 实际列出 `BOOT`、`SYSTEM_SERVER`、`BOOT_TIME`、`CRASH`、`SERVICE`、`PACKAGE` 六个 `*_QUERY_FAIL`。R7 的“五类 query failure”允许测试漏掉 boot-time 或 logcat 任一条；前者尤其会留下 baseline failure 被空输出/默认值掩盖的假绿。

建议：把矩阵明确改成 6 条 query-failure case，并列名逐一计数；若显式 `--since` 跳过 btime 查询，也要分别断言默认 baseline 的 btime failure 与显式 baseline 的 logcat failure。每个开关只改变一个逻辑断言，但调用次数应按是否还能安全发起 logcat 给出精确期望。

### I5 — business/parse/status 映射与 token 语法未钉死，package 尤其存在 FAIL/SKIP 冲突

定位：`requirements.md:21,25,27,31,47`。

影响：R2 总则把“查询成功但值缺失或不合法”定为 FAIL，又把 package 目标缺失定为 SKIP；R4 要矩阵分别反证空值、畸形值和业务缺失，却没有说明 package 的空输出是 SKIP 还是 FAIL、含畸形行但不含目标包是什么、含目标完整行同时夹杂畸形行是否 PASS。类似地，“正十进制 PID”没有明确拒绝 `0`/`00`，而“独立的 `sidebar:` token”没有给出尾边界，`sidebar:evil` 可能被子串 regex 误判。R7 只写“五类业务缺失/畸形”，不能机械证明每项的 parse failure 与合法但业务未满足均被区分。

建议：在 requirements（随后同步到文档）加入五项判定表，逐项列出 query rc 非零、空输出、语法畸形、语法合法但目标缺失的 detail 类别与 PASS/FAIL/SKIP。至少钉死：PID 必须数值 `>0`；service 的 `sidebar:` 前后均为 token 边界；package 只有“查询成功且输出语法可接受但目标完整行缺失”才 SKIP，查询输出畸形必须 FAIL。R7 按表的每一行点名 case 和期望计数，不能只给总数。

### I6 — 01 已验收的 CLI 拒绝优先级没有落成可执行契约

定位：`requirements.md:19,31,46`；`DECISIONS.md:14,16`；`tests/test-device-safety.sh:106-120`。

影响：01 已固定“真实 `--allow-skip` 错误先于 serial 校验”，现有 device-safety 也机械断言 stderr 含 flag 错且不含 ANDROID_SERIAL。R1 只说两者都在 ADB 前 rc2，验收清单却要求“前置拒绝顺序一致”而没有定义顺序。`--help` 是否必须单独出现、`--help --bad` 的结果、以及“重复”是否覆盖 `--demo`/`--allow-skip`/`--since` 各自也未明确。实现可保留零 ADB 与 rc2，却仍破坏 01 的错误优先级或让三入口顺序漂移。

建议：写出确定优先级：完整解析/重复检测 → 真实 `--allow-skip` 拒绝 → serial 校验 → 首次 ADB；明确 `--help` 只能单独使用（或明确定义与其他参数组合的行为），并在三入口矩阵中点名三个 flag 的重复、help+非法参数、allow-skip+缺失/非法 serial，核 stderr 类别和零 ADB。

## 次要

### M1 — R10 的条件句削弱了后文声称的 mandatory full/depth-1/rollback 门

定位：`requirements.md:35,37,52-53`。

影响：R9 和验收清单把 full、真实 depth-1、rollback 写成验收硬门；R10 却以“如果发生……验证”开头，字面允许不发生便真空满足。另外 contract test 与 offline gate 的固定摘要本来不同，“得到同一固定摘要”也可能被误读为两条命令输出相同。

建议：改成“验收必须执行 full-history、真实 file-URL depth-1 和 exact rollback 三路”；分别写明 contract test 与 offline gate 各自的固定末行，并明确 full/depth-1 的同一性是同一命令跨 checkout 一致，而不是两条不同命令输出相同。

## 已确认成立的部分

- 直接依赖写对：02 提供默认发现门，04a 只提供顺序门证据且没有被虚构成运行时 API；requirements 也没有要求 05 source lease provider。
- 五项逻辑断言、FAIL 优先于 SKIP、strict INCOMPLETE=`rc2`、strict PASS=`rc0`、demo-only exploration PASS 的总体方向忠实覆盖 PLAN，且正确阻止 `RESULT PASS (SKIP allowed)` 成为交付证据。
- `--since` 接受 0–9 位小数、右补九位并使用 `logcat -v epoch,nsec -T`，以及 `>= baseline` 为失败的方向明确；问题集中在 I2/I3 的边界集合。
- 02 默认发现的文件命名、固定主测试摘要、repo-root 自解析、repo 外私有 fake adb、全程不碰真机/网络，以及不提前引入 06/07/08/09 运行时能力，均是正确且可验的约束。
- rollback 要恢复 01/02/04/04a 和旧 demo 回归的意图正确；需先解决 B1 的 exact 文件集合并把 M1 改成强制门。

## 两个独立结论

### 规格符合性

**NEEDS_CHANGES。** 高层目标、直接依赖和结果码方向符合 PLAN，但 B1 直接改变了 PLAN 的 05/09 文件 owner、回滚面与预算前提；在 PLAN 回流或 05 收窄前，不能标记为规格符合。

### 需求质量

**NEEDS_CHANGES。** R2 与“超出范围”段的 stderr 边界冲突、crash PASS 条件矛盾、六查询写成五类、query/business/SKIP 映射不唯一，以及 CLI 拒绝顺序缺失，都会允许三入口产生不同实现或测试假绿。修订上述 oracle 后才具备自洽、可实现、可机械验收的质量。

## 最终裁定

**NEEDS_CHANGES — 阻断 1 / 重要 6 / 次要 1。** 先回流并闭合 05/09 owner 与 400 行 sizing，再修正六查询矩阵、时间/业务语义和 01 CLI 优先级；本轮不建议进入 design/implementation。
