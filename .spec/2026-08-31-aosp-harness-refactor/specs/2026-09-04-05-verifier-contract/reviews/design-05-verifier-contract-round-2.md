# 05 verifier contract design review — round 2

## 结论

- 规格符合性：**PASS**
- 设计质量：**PASS**
- Findings：**B=0 / I=0 / M=0**

本轮以磁盘最终版本为准，完整审查最新 `design.md` 与 `prototypes/` 三文件，并对照 PLAN v6.1、最新 `requirements.md`、`requirements-05-verifier-contract-v61-boundary-round-1.md` 及 round 1 的 B1–B4/I1–I2。05 core、05a owner 和后序 09/06 组合边界现已一致，没有剩余 finding。

## 独立机械复核

实际重跑结果：

- `bash ./tests/test-verifier-contract.sh`：rc `0`，输出固定摘要 `RESULT PASS  verifier contract`。
- shfmt `v3.14.0`：`shfmt -d -i 2 -ci -bn` 对 exact 两个 shell 文件 rc `0`、无 diff。
- ShellCheck `0.11.0`：`shellcheck -x --severity=warning` 对 exact 两个 shell 文件 rc `0`、无诊断。
- `bash -n`：exact 两个 shell 文件 rc `0`。
- 行数：provider `202`、doc `67`、base test `102`，合计 `371/400`。
- SHA-256：provider `56f696401ccf53db4c81aa47bcce1d61081639eace5cdba983aecf8af396500d`；doc `d22c977c4d361a7ad7a949db33e6d93e73a7564752d9374cd9fa7be4bb3c2634`；test `a6f4cd4d48f5de27c20b60ea2f14df1aef8785410752a9ac199130ce9cb7069e`。

上述行数与 hash 和 `design.md:154`、PLAN-history v6.1、DECISIONS 最后一行及 ledger 当前记录一致。由于三个源码文件均为新增，`371` 同时是 runnable prototype 对应的 additions+deletions sizing，满足 `<=400`。

## Round 1 findings 闭合复核

| Round 1 finding | 状态 | 当前闭合证据 |
|---|---|---|
| B1：05 内部 direct ADB 无法组合 06/09 | **已闭合** | provider 增加 private `HARNESS_VERIFIER_QUERY_RUNNER`；真实模式在首查询前核绝对路径、EUID owner、普通非 symlink、X_OK，以 lowercase query key、`--`及完整 `adb -s serial argv...` 分离参数调用。stdout 捕获为 bytes、stderr 继承、rc 保留，signal 转 `128+signal`；unset 保持 direct/抑制 stderr。PLAN 已规定 09 自有可信 adapter 从已校验显式 CLI 生成并复核内部 context 后调用 06，不改 05 provider且不信任外部环境控制值。 |
| B2：测试缺完整 case oracle、argv 边界和 manifest | **已闭合并安全拆分** | 05 base 现在履行 R7 的全部基础 oracle：demo 逐字五 PASS/零 query；real default 逐字五 PASS并精确比较六条 argv/顺序/统一 serial；explicit-since 精确比较 boot/system/crash/service/package 五条 argv/顺序/serial及九位补齐，同时验证 query 非零 detail、runner stderr和rc；另有 duplicate/missing/multivalue/help-combination/positional、非法 serial/runner及单独 help的 rc/双流/零 query。R3/R4逐格、六 query failure、全部边界、长度保真编码、exact manifest及四类 mutant明确归 05a exact1，且 05a 禁止修改05 exact3；其 active 证据前 06/09 不得启动。 |
| B3：repo 外 temp 与 cleanup 后摘要门不足 | **已闭合** | base 在 `mktemp` 成功后的第一时刻安装 EXIT cleanup，再执行 fallible `realpath`；显式核 temp 是 canonical repo 外普通非 symlink目录、EUID `0700`、初始为空。failure trap只尽力清理且从不打印PASS；成功路径先解除trap、显式删除并核 `! -e && ! -L`，最后才打印固定摘要。 |
| B4：contract doc 不是完整单一契约 | **已闭合** | 文档列出 CLI 接受集/拒绝优先级、六条精确 argv、六 query key、runner stdout/stderr/rc/信任边界/signal/exec失败、bytes LF/单尾CR与scalar trim、R4五项完整表、crash规则、五明细顺序/前缀、summary、terminal/rc、十二 fixture及探索证据限制。 |
| I1：crash parser先 strip 导致行首误分类 | **已闭合** | `lines()` 只按 LF 分行并至多移除一个尾 CR；crash 在任何 trim 前先检查原始首字节是否为 ASCII `0`–`9`，空行、前导空白和 Unicode digit header被忽略；数字开头行只按 ASCII space/tab取得首 token，非法 ASCII epoch或非法 UTF-8 token为 parse FAIL。 |
| I2：service `[[:space:]]` 与实现不等价 | **已闭合** | 契约已固定为 bytes grammar中的 ASCII space/tab，而非 locale `[[:space:]]`；provider bytes regex、LF分行、单尾CR、文档判定表完全相同。全部合法 separator/trailing 与 Unicode/control 反例由 05a 穷举。 |

## 设计完整性

### 架构与接口

设计把前置、query adapter、evaluator/aggregator 分开：前置失败保证零 query；query 层只返回 `(nonnegative rc, stdout bytes)`，不把命令失败误作业务缺失；五项 evaluator固定顺序产生 detail，aggregator强制计数和为5并执行 FAIL 优先于 SKIP。默认 direct、demo data和private runner复用同一解析器，没有 shell eval 或字符串命令面。

runner seam 的能力与信任边界足以供 09 组合 06，同时没有把 timeout/retry/lease 策略带入05。provider缺席由09 fallback；05/06/07三运行时输入任一缺席时09走自有legacy，三者齐全才绑定可信runner进入v2。05回滚只删除exact3，不覆盖09-owned hunks。

### R1–R10 与测试责任

需求映射覆盖 R1–R10：CLI/serial、六查询/五断言、crash epoch、bytes grammar、结果聚合、demo fixture、R7 base、R8文档/sizing以及R9/R10 controller门均有明确组件。错误处理表区分 parser/preflight rc2、runner exec/query failure、btime parse、输出parse、合法package SKIP和fixture/static/预算/cleanup失败。

05没有把基础承重 oracle推出本片；同时也没有把完整穷举矩阵压回371行core。05a只拥有独立 assurance 文件，消费而不改 provider/doc/base test，dependency-present active 与 inert 路由、partial/damaged fail-closed、exact1≤400和顺序门均已定义。完整 05a runnable sizing 应在其自身门③证明，当前 design 没有把未来证据伪写成已完成事实。

### 文件与回滚边界

源码清单恰为三个新增文件：canonical provider、contract doc、base test；prototype/review/ledger明确只是spec验收资产，不计入source diff。设计不修改三个旧verifier、session/resource lease provider或后序06/07/09文件。该清单与 PLAN 文件owner、requirements R8/R9、371行证据及独立回滚路径一致。

## 最终裁定

**PASS — 规格符合性 PASS；设计质量 PASS；B0 / I0 / M0。** Round 1 的 B1–B4/I1–I2 均已在05 core中实际闭合，或以不叠改05 exact3且有严格active顺序门的05a owner安全承接；当前 design/prototype 可以进入后续既定 tasks/implementation 门。
