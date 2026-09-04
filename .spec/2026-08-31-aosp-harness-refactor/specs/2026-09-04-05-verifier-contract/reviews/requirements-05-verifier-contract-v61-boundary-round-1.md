# 05 verifier contract v6.1 boundary review — round 1

## 结论

- `PLAN.md` v6.1：**PASS — B0 / I0 / M0**
- `requirements.md`：**PASS — B0 / I0 / M0**
- 合计：**B0 / I0 / M0**

本轮以磁盘最终版本为准，对 v6.1 增量与完整 artifact 做只读融合审查。已完整读取 `PLAN.md`、`requirements.md`、`reviews/design-05-verifier-contract-round-1.md`、`PLAN-history.md` 的 v6.1、`DECISIONS.md` 最后一行及 `prototypes/` 三文件；未发现剩余 blocking、important 或 minor finding。

## 机械复核

实际执行结果：

- `bash ./tests/test-verifier-contract.sh`：rc `0`、stderr `0` bytes、stdout 逐字为 `RESULT PASS  verifier contract\n`。
- shfmt `v3.14.0`：对 exact 两个 shell 文件执行 `shfmt -d -i 2 -ci -bn`，rc `0`、无 diff。
- ShellCheck `0.11.0`：执行 `shellcheck -x --severity=warning`，rc `0`、无诊断。
- `bash -n`：exact 两个 shell 文件 rc `0`。
- 物理/逻辑行数：provider `202`、doc `67`、base test `97`，合计 `366/400`。
- SHA-256：provider `56f696401ccf53db4c81aa47bcce1d61081639eace5cdba983aecf8af396500d`；doc `d22c977c4d361a7ad7a949db33e6d93e73a7564752d9374cd9fa7be4bb3c2634`；test `077ca1b144c8c0fa86e1c1f0766b0a4e153fc451334d2e6c2f3ef9679d5e5c80`。三者与 `design.md`、`PLAN-history.md` v6.1 和 `DECISIONS.md` 最后一行的最终证据一致。

依赖映射脚本复核得到：spec 表 `20` 个节点、`34` 条预期直接边；依赖契约表和文本依赖图均恰为同一 `34` 条边，无缺失或额外边；实施顺序包含全部 `20` 个节点且没有逆拓扑边。

## PLAN v6.1 边界结论

### 05 / 05a owner 与承重 oracle

- 05 exact3 只拥有新增 canonical provider、完整 contract 文档和代表性 base test，不修改三个旧 verifier 入口。
- 05a exact1 只新增 `tests/test-verifier-contract-assurance.sh`，消费 05 provider/doc，明确禁止修改 05 exact3 或后序文件。因此两片没有文件或 hunk 叠改。
- 05 没有把承重的基础 oracle 推给 05a：当前 runnable base 已逐字覆盖 demo/real 主链、default 六查询完整 argv、explicit-since 五查询/纳秒补齐、runner stderr/非零 rc、代表 CLI/serial/runner preflight、单独 help，以及 repo 外普通非 symlink 0700 空目录和 cleanup 后摘要门。
- 05a 独占的是完整逐格 grammar、六 query-failure、全部边界、长度保真 argv、exact case manifest 和四类 mutant 自反证；其 dependency-present active、exact1/400、full/depth-1/offline/rollback 证据入 ledger 前，06/09 均不得启动，inert PASS 不能解除门禁。该切分保留了 P5 边界且没有形成“05 空壳、05a 承重基础”的倒置。

### 05 / 06 / 07 / 09 组合与回滚

- private `HARNESS_VERIFIER_QUERY_RUNNER` 的协议已闭合：真实模式在首查询前核绝对路径、EUID owner、普通非 symlink、可执行；调用形态为 `query-key -- adb -s serial argv...`；stdout 被 provider 捕获为 query bytes，stderr 继承，rc 保留为非负值，signal 规范化为 `128+signal`，exec 失败固定诊断并落对应 query FAIL；未设置时保持 direct ADB 且抑制子命令 stderr。
- 该 seam 足以让 09 在不修改 05 owner 文件的前提下组合 06：09 自有可信 runner adapter 从 dispatcher 已校验的显式 CLI 参数生成并再次校验内部 context，再调用 `harness_command_run query ... -- <adb argv>`，不信任外部环境注入的 session/wait/instance 值。
- v2 readiness 与 fallback 唯一：05 provider、06 runtime、07 resolver 三者物理齐全才走 v2；任一缺席走 09 自有 legacy fallback。09 测试责任同时覆盖 07 present 下的 05×06 四组合、07 absent/present、01 present/absent及环境注入。
- 回滚逐片闭合：回滚 05 只删除 exact3，05a inert 且 09 按 provider 物理缺席 fallback，不覆盖 09 hunks；回滚 05a 不改运行时但撤销重新验收/新启动 06/09 的资格；回滚 06 或 07 时 09 fallback；回滚 09 不影响 08，10 只依赖稳定旧入口。owner、详情、直接边和回滚表使用同一分流条件。

### PLAN 内部一一一致性

spec 表、文件边界、05/05a/06/09 详情、直接边、依赖图、固定实施顺序、资源冲突和独立回滚矩阵一致。05 的直接依赖仍仅为 02/04a；05a 依赖 05；06 依赖 04/04a/05a；09 依赖 01/05/05a/06/07。没有把 04a/05a 的验收证据误写为运行时 API，也没有提前占用 06/07/09 文件。

## Requirements 完整性结论

- R1–R6 对 CLI 优先级、serial allowlist、六条外部查询/五项逻辑断言、bytes/LF/单尾 CR、crash epoch、R4 分类表、summary/terminal/rc 与 demo fixture 给出唯一语义；prototype provider/doc 相互一致。
- R7 明确 base 的代表性承重合同和 05a 的穷举边界；最终 base test 在任何 fallible temp 使用前安装 cleanup trap，验证物理 repo 外、普通非 symlink、EUID 0700、初始为空，删除和物理缺席之后才打印固定 PASS。
- R8 的门③要求是实际 runnable fixed-format exact3 和 `git diff --numstat` churn，而非 skeleton/估算；本轮原型以 `366/400` 和实际全绿命令证明 core 边界可实施。05a 仍须在自己的门③独立证明 runnable exact1≤400，这不是本轮已提前声称的证据。
- R9 强制 candidate/full/depth-1/exact rollback、offline、fixed tools、manifest、diff-check、converge和后序资产缺席；R10 对 query、parse、fixture、case count、cleanup、static、budget、checkout、rollback和顺序门统一 fail closed。
- 四项不变量均有可失败验证来源；超范围明确排除真机/build/网络、06 runtime 策略、07 registry、09 dispatcher/parity/fallback 实现及其他前序/后序文件修改，没有与 R1–R10 或 PLAN owner 冲突。

## 最终裁定

`PLAN.md` v6.1 与 `requirements.md` 均可进入后续既定门禁：**PASS — PLAN B0/I0/M0；requirements B0/I0/M0。** 后续必须继续遵守顺序门：先完成 05，随后由 05a 自身的 dependency-present active runnable exact1 证据证明穷举 assurance，才能启动 06/09。
