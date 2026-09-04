# 05 verifier contract requirements review — round 2

总裁定：**NEEDS_CHANGES**

合计：阻断 **2** / 重要 **2** / 次要 **1**

- PLAN v6.0 增量：**NEEDS_CHANGES** — 阻断 1 / 重要 0 / 次要 0
- 当前 requirements：**NEEDS_CHANGES** — 阻断 1 / 重要 2 / 次要 1

审查方式：只对 round 1 的 B1、I1–I6、M1 做范围受限增量复审；核对 PLAN v6.0 的 history、05/09 owner、05 详情、`05 -> 09`、回滚与资源边界，以及当前 `requirements.md`。按委托不重跑 controller 已通过的 check-req/check-criteria/check-analyze/check-plan/diff-check。

## PLAN v6.0 增量

### P-B1 — 05 虽已收窄到 common，但 05/09 对同一 common 入口的重叠修改与独立回滚仍未闭合

定位：`PLAN.md:12,88,92,151,167,204,228,306`；`DECISIONS.md:56`。

影响：v6.0 已正确把 Claude/Codex 的 05 修改与 parity 移到 09，但 05 仍直接修改 `common/.harness/features/dev-sidebar/verify-sidebar.sh`，09 的 owner 仍是“common verifier dispatcher、三个薄 verifier 入口”，详情也要求“三入口收敛到 dispatcher”。因此 common 入口仍会在 05 和 09 跨片重复修改；PLAN history/decision 所称“避免同一入口跨片反复改写”并未真实成立。

这还使 `05 -> 09` 的 rollback/fallback 无法机械解释：05 rollback 不是“provider 物理缺席”，而是把始终存在的 common 路径恢复为 pre-05 弱 verifier；05 没有 capability/version marker，09 无法仅凭该路径存在判断 canonical contract 是否仍在。若 09 已把 common 入口改成薄 adapter，exact 回滚 05 又可能覆盖同文件里的 09 consumer 改动。`PLAN.md:228` 只说 09 legacy fixture 保持旧入口可运行，没有说明怎样在不回退 09 自身改动的前提下识别并处理这个状态。

建议：在 PLAN 门先固定一个不会被 consumer 重写的 05 provider 边界，再同步 owner、详情、直接边和回滚。可选方案包括：

1. 05 交付独立、带版本/协议探针的 canonical verifier core/command，09 的 dispatcher/三个入口只消费它；05 rollback 时该 provider 物理缺席，09 可无歧义走 legacy。
2. 明确 09 永不修改 05 的 common canonical 文件，并说明 common 如何仍消费 06 runtime/07 registry、如何参与三入口 parity，以及 05 rollback 时 09 如何探测 legacy 内容。

无论选哪种，都必须证明 05 rollback 不覆盖 09-owned hunks，且 09 在 05 present/rollback 两态均有可执行 fixture。当前 `05 -> 09` 边、05/09 文件 owner 与 rollback 行尚不能同时成立。

### PLAN 已闭合项

- v6.0 history、spec 表、05 详情和 decision 已一致把 05 从“三入口实现/矩阵”收窄为 common canonical verifier/doc/test，并把 Claude/Codex parity 与薄化归 09。
- 05 直接依赖仍只有 02 和 04a；09 仍只消费既有 01/05/06/07，没有新增依赖边或改变实施顺序。
- 04a 只提供已验收顺序门、02 只提供默认发现；v6.0 没有把两者误写成 05 的运行时 API。
- 09 自带 01 等价 preflight、stdout/rc 透传和 legacy fixture 的总体方向仍正确；问题只在 P-B1 的 common 同文件身份与 rollback 探测未定义。

PLAN 增量结论：**NEEDS_CHANGES — 阻断 1 / 重要 0 / 次要 0。**

## 当前 requirements

### R-B1 — exact3/churn≤400 仍只是末端验收门，没有被规定为 design 前的 runnable sizing gate

定位：`requirements.md:8,33,35,50`；round 1 B1；`PLAN.md:12,70,151`。

影响：R8/R9 现在正确要求 exact 三文件和 additions+deletions `<=400`，但没有要求 design 阶段先产出并运行 fixed-format prototype。当前交付仍包含：把 120 行 common verifier补为完整 canonical 实现、新增公共契约文档、以及覆盖六查询、五项分类、CLI、时间边界、fake-adb argv 和 coverage counter 的完整测试。仅把五文件收窄为三文件不能证明这些承重内容能在 400 churn 内同时成立；若直到 execution/acceptance 才发现超限，仍会重复此前靠压缩实现或删 oracle 的风险。

建议：在 R8 或独立需求中加入 design 硬门：进入 tasks/implementation 前，必须在隔离临时工作树完成 fixed ShellCheck/shfmt 的 runnable exact3 prototype；prototype 必须真实执行 R7 全矩阵、产生固定摘要，并以 `git diff --numstat` 证明三个非生成文件的 additions+deletions 总和 `<=400`。若不成立必须回 PLAN 拆片，不能以预估行数、未执行 skeleton 或减少 R7 oracle 放行。

### R-I1 — requirements 声称“五项判定表”，但 boot/service/package 的完整语法与逐格状态仍未实际定义

定位：`requirements.md:21,25,31,33,45,49`。

影响：I5 已部分闭合：package 仅“查询成功且每个非空行合法、目标缺失”才 SKIP，PID 明确 `>0` 且拒绝前导零，service token 前后边界也已钉死。但 requirements 中并没有真正的五项判定表，且仍缺少几项使 matrix 无法唯一落地的语法：

- boot 只定义去 CR/LF 后 `1` PASS，没有定义 `0` 是“合法但业务未满足”还是 parse failure，也没有定义空值和其他数字的类别。
- service 只定义目标 token 的命中边界，没有定义 service-list 什么输出算语法合法、什么输出算 parse-failed，因而无法分别构造“畸形”与“合法但 sidebar 缺失”。
- package 的 `<safe-name>` 没有正则/字节集合；不同实现可把同一行分别判为合法缺包 SKIP 或畸形 FAIL。
- R45 要求五项“逐格”覆盖 query 非零、空值、畸形、合法业务缺失与 PASS，但 crash 是“发现新记录则业务 FAIL”、package 是“合法缺包 SKIP”，并非每格都有相同含义；未适用格也没有标 N/A。

建议：在 requirements 内直接给出五行判定表，而不是只要求未来文档提供。每项列出输入归一化、合法输出 grammar、query-failed、empty、parse-failed、合法业务未满足、PASS/SKIP 及明细类别；不适用项明确写 N/A。固定 `<safe-name>` 的 ASCII 正则，并明确空行是否忽略。R7/验收清单按表中的适用格点名 case 与计数。

### R-I2 — CLI 顺序已闭合，但 common 的 serial allowlist与单独 `--help` 成功路径仍缺机械 oracle

定位：`requirements.md:19,31,33,44,55`；`DECISIONS.md:14,16`；`tests/test-device-safety.sh:84-123`。

影响：I6 的核心优先级已经修正为“完整解析/重复/help组合 → real allow-skip → serial → ADB”，三个 flag 重复也已点名。但 R1 仍只说“安全的 ANDROID_SERIAL”，没有继承 01 已验收的精确 `^[A-Za-z0-9][A-Za-z0-9._:-]*$`；R7 只写“安全serial”，没有要求 common 对 missing 和代表性 unsafe serial 逐一 rc2/零 ADB。现有 `test-device-safety.sh` 的 invalid-serial matrix只覆盖 Claude，flag matrix只覆盖 Claude/Codex，并不能替 common 补这个 oracle。R7 也只覆盖 help 组合失败，没有要求单独 `--help` 的 rc0、参数集合和零 ADB。

建议：R1 逐字继承 01 serial 正则；R7 至少覆盖 missing、`-bad`、路径/空白/控制字符及两个边界合法 serial，并核同一 `-s` argv。另加入单独 `--help` 的 rc0、stderr空、零 ADB与参数集合 oracle，同时保留 help+其他参数 rc2。

### R-M1 — R9 已把四路验收改为强制，但 R7 仍残留“如果发生”措辞

定位：`requirements.md:31,35,50-51`。

影响：round 1 M1 的实质已由 R9 闭合：candidate/full/depth-1/exact rollback 四路均写成“必须”，且 contract/offline 的不同固定输出已分别说明。R7 的“如果发生 `tests/test-verifier-contract.sh` 验证”仍是多余的条件式，单独阅读时会弱化主测试矩阵；虽然 R9/主验证命令最终兜底，不再构成验收逃逸，但会给任务拆解留下不必要歧义。

建议：恢复为“当运行”或“`tests/test-verifier-contract.sh` 必须……”，与 R9 的 mandatory 语气一致。

### round 1 finding 闭合状态

| round 1 finding | round 2 状态 | 依据 |
|---|---|---|
| B1 owner/预算 | **部分闭合** | 三入口 owner 已收窄；P-B1 的 common/09 overlap 与 R-B1 的 runnable sizing 仍未闭合 |
| I1 stderr/06 | **已闭合** | R2 明确只按 rc 分类并抑制 stderr，`requirements.md:63` 明确诊断保留属于 06 |
| I2 crash PASS/header | **已闭合** | R3 明确空行/header忽略、纯早期 PASS、`>=` FAIL、数字畸形 FAIL |
| I3 btime uniqueness | **已闭合** | R3/R46 明确恰一、absent/duplicate/malformed、失败零 logcat且仍只结算一个 crash 项 |
| I4 六查询 | **已闭合** | R6/R7/R8 明确 boot/system/btime/logcat/service/package 六条 |
| I5 query/business/SKIP | **部分闭合** | package/PID/service target边界已修；R-I1 的完整 grammar/判定表仍缺 |
| I6 CLI priority | **部分闭合** | 顺序、重复与help组合已修；R-I2 的serial正则、invalid matrix与help成功仍缺 |
| M1 四路门 | **实质闭合，余措辞** | R9 已强制四路并分开两种摘要；R7 尚残留条件句 |

Requirements 结论：**NEEDS_CHANGES — 阻断 1 / 重要 2 / 次要 1。**

## 两个独立结论

### 规格符合性

**NEEDS_CHANGES。** requirements 已忠实跟随 v6.0 的 common-only 05 方向，且没有新增 01/02/04a/06/07/09 运行时依赖；但 PLAN 自身的 05/09 common 同文件 owner、capability 探测与独立回滚仍矛盾，故整体尚不能判规格符合。

### 需求质量

**NEEDS_CHANGES。** I1–I4 与 M1 的承重主体已经闭合，结果聚合和时间边界已具备唯一语义；但缺 design-time runnable exact3/400 证明、真正可执行的五项判定表、common serial负向矩阵与 help 成功 oracle，仍可能在 design/implementation 阶段产生超预算或分类假绿。

## 最终裁定

**NEEDS_CHANGES — PLAN：B1/I0/M0；requirements：B1/I2/M1；合计 B2/I2/M1。** 先解决 05/09 对 common 入口的同文件回滚矛盾，并把 runnable exact3/400 prototype 设为 design 前硬门；随后补全判定表和 common CLI 的剩余 oracle，再进入下一阶段。
