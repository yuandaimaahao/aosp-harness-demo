# 03e「claude session lifecycle」design round 1 审查 verdict

**NEEDS_CHANGES**

存在 1 条 major finding（SessionEnd reason 值集缺官方文档值 `resume`，且其引用的 DECISIONS 出处并未钉死值集）。另有 2 条 minor，均不阻塞。

---

## 一、机械复核（逐项）

**1. frontmatter / 契约逐字 diff —— PASS（附注）**
- design.md 本身无 frontmatter 块，与 03d design.md（同样无 frontmatter，首行 `# ... 设计`）一致，属本片仓库惯例；标题行 `design.md:1` 与切片 id `2026-09-03-03e-claude-session-lifecycle` 一致。
- frontmatter 派生契约逐字 diff 实际执行：`requirements.md:5`（产出）vs `design.md:56` → `diff` 输出 `产出 CONTRACT IDENTICAL`；`requirements.md:4`（消费）vs `design.md:60` → `消费 CONTRACT IDENTICAL`。上游依赖 `依赖: [2026-09-03-03d-session-remove-prune]` 在 design 消费契约与「分层与边界」（design.md:50）中落实。

**2. R1–R10 映射 —— PASS**
- design.md:15-25 共 10 行映射，R1,R2 / R3 / R4 / R5 / R6 / R7 / R8 / R9 / R10 全覆盖，无遗漏、无编造 R 条目；各组件归属与 requirements R 条文语义对应（抽查 R5→session-end+settings、R7→run-demo、R10→04 顺序门均正确）。

**3. sizing 算术 —— PASS**
- 总分项：52+42+52+6+62+176 = **390** ≤ 400，余量 10 ≥ 10 ✓（实际计算验证）。
- 子分解复核：test 分解 12+24+12+26+14+20+20+14+12+8+10+4 = **176** ✓；run-demo 42 增+16 删 = 58 ≤ 62 ✓；settings.json 1 改+5 增 ≈ 6 顶格 ✓；load-feature 46 增+5 删 = 51 ≤ 52 ✓；check-branch-drift 35 增+少量删 ≤ 42 ✓。
- 现状行数实测比对：load-feature.sh 27、check-branch-drift.sh **18**（design 写 18 正确；审查任务书写 19 系任务书误差）、run-demo.sh 63、settings.json 11 —— 与 design.md:220 引用值全符。

**4. 六文件清单逐字 —— PASS**
- design.md:226-231 六路径与 requirements.md:15 目标段逐字一致：改 `claude-code/features/.harness/hooks/load-feature.sh`、`hooks/check-branch-drift.sh`、`settings.json`、`claude-code/run-demo.sh`；增 `hooks/session-end.sh`、`tests/test-claude-session-lifecycle.sh`。创建/修改属性亦一致。

**5. mermaid —— PASS（结构核对，无本地解析器）**
- 实际计数：`graph TB` ×1（design.md:30-47）、`sequenceDiagram` ×2（design.md:135-156、162-178）✓。
- 块 1：alt=2 / else=2 / end=2 平衡（嵌套 alt 合法）；块 2：alt=1 / else=2 / end=1（mermaid 允许单 alt 多 else）✓。graph TB 节点标签内 `+`/`:`/`<br/>` 与 `-.文本.->` 虚线带文边均为合法语法。
- 声明：环境无 `mmdc`/mermaid 库（已验证 `no-mermaid-lib`），未能机器解析，以上为人工结构核对。

**6. `04-runtime-resource-leases` 出现与 NEXT 顺序门 —— PASS**
- 出现于 design.md:113、114、233，均属 design 文档（禁令仅针对 ledger/dispatch/execution-base 三类记录，design.md:114 明确正确复述了该边界）。
- 顺序门目标未写错：五类资产（spec 目录/分支/worktree/ledger BASE/dispatch）与 R10 逐字对应，机械查缺席手段（`ls -d`/`git show-ref`/`git worktree list --porcelain`/`rg`）与 R10 一致。

## 二、重点挑战项（逐项结论）

**1. 不设 mutant 自反证的论证 —— 成立**
- aggregator 临界区证据 `common/.harness/lib/session-state.sh:42-46`：四个状态 API 函数定义在前、marker 赋值在最后，全部是不会失败的 bash 内建语句；`set -e` 无可触发点。唯一能在窗口内中断执行的是异步信号，但信号杀死的是整个 hook 进程，不存在「source 正常返回后观察到 API 在场而 marker 缺席」的执行路径 —— hook 侧该状态物理不可观，论证严密。
- 「validate 在场但 marker 缺席」（foundation source 成功、后续模块失败，`session-state.sh:23` vs `:38-41` return 1）确实可达，但 guard 合取的 marker 子句恰好捕获它 —— design 未遗漏此分支。
- 七类 fixture（完整+absent+五 missing-*）覆盖的是 consumer 可观测二元划分（完整合取 vs 其余）的全部六个产生点；aggregator 内部「source 成功但 export 缺席」分支由 03d 自身测试覆盖（`session-state.sh:28-36` 九个 `declare -F`），consumer 侧不可区分，无需重复。结论：mutant 不新增信息的裁定成立。

**2. 三 hook guard 各自内联 ~6 行 —— 成立**
- exact 六文件约束 + requirements.md:66 超出范围明确「不改 `.harness` 下其他文件」，`feature-common.sh` 无处可放公共 guard，内联是被约束强制的最小改动；design.md:7 的论证与基准一致。6 行×3 已在 load(6)/drift(6)/session-end(6) 各自预算中真实计入 ✓。

**3. SessionEnd 校验先于删除 —— 成立**
- design.md:88 流程 (1)guard→(2)校验→(3)(4)删除，与 R5（requirements.md:27）逐字核对：非法输入「零删除（v1 状态与 legacy 全局快照均不动）只 marker+rc0」= R5「不删除任何状态…不执行 legacy 清理」；provider 缺席时非法输入因校验独立于 use_v1 而不触发 legacy 删除 ✓；provider 设计外错误码只 marker+rc0、不删 legacy 快照，符合 R6 v1/legacy 文件隔离 ✓。design.md:9 对「guard 先于校验短路」备选方案的排除理由与基准吻合。

**4. run-demo.sh v1 fixture 布局 —— 成立**
- 布局满足 R7：hook 以 `CLAUDE_PROJECT_DIR=$tmp/tree/claude-code` 调用 → `ROOT/../common/.harness/lib` 命中私有 lib 副本（design.md:102），`TMPDIR`/`HARNESS_STATE_ROOT` 均重定向进 mktemp；真实 `CURRENT_FEATURE` 零写入（连只读断言都只为验收）。R7 的「trap 恢复暂改状态」因新设计不暂改任何树根状态而空虚满足，单 EXIT trap 只 `rm -rf` 合规。
- 受控失败=UPS exit 2 + demo 断言 rc==2 后继续，可实现（`set -e` 下需 `|| rc=$?` 捕获，属实现细节）。
- 保留的 install-harness 段幂等（`install-harness.sh:18-20` 只在软链缺席时创建），净零变更不变量可守住；design.md:214 工具列含「inventory 比较」，与 requirements 不变量验证方法对应。
- ≤62 预算现实：增 42+删 16=58，余 4 行；偏紧但可行，且 design 声明了超限回 PLAN 拆片的 fallback。

**5. SessionStart read 返回码语义 —— 成立**
- rc3=「状态文件缺席」实证链：`session-state-snapshot.sh:78-82` `read_snapshot` 对缺席 `raise Missing`；`:182` `except Missing: raise SystemExit(3)`；write 侧 `:118`/`:142` 异值→3、同值→0。bash 包装 `_harness_session_snapshot_read_core`（`:207`）直传 worker rc。
- design.md:74 分支表（rc0 只读不 write / rc3 compact 报错不创建+其余四 source write / 其他落 legacy）与 R3 及 provider 实际契约逐字一致 ✓。

**6. embedded python3 解析 stdin JSON —— 成立**
- codex 侧先例实证：`codex/.codex/hooks/session-start.sh:12`、`codex/.codex/hooks/check-branch-drift.sh:13` 均用 `python3 -c` 解析 hook stdin JSON；provider 五模块亦全为 embedded python3。python3 已是既有测试与运行时的硬下限，offline 可用性有先例背书，不抬高环境要求 ✓。

**7. compat marker 恰一次 —— 成立**
- 单行 `compat_legacy()` helper（design.md:67）使字面量在 hook 文本中仅一个 printf 位点 → `rg -o` 计数==1 的结构核对有效；各 legacy 入口（guard 失败/stdin 非法/设计外 rc）互斥且每条路径只调一次 → 逐 case stdout 计数==1 的行为核对该捕捉任何双重调用。结构+行为双计数足以机械证明「恰一次」✓。

**8. SessionEnd reason 定死四值 —— 不成立，需改（major finding，见下）**
- DECISIONS 核对：`DECISIONS.md:24`（round 1-3）仅有「最低 Claude Code 版本 2.1.234」，`DECISIONS.md:25`（round 2）只说「经事件名/session ID/reason 校验后删除目标已提交快照」——**两行均未钉死 reason 值集**。按审查规则此为需实查官方文档的 open question。
- 实查官方文档（docs.claude.com Hooks reference，2026-09-03 抓取）：SessionEnd reason 表为 `clear`/`resume`/`logout`/`prompt_input_exit`/`other` 五值，且 `bypass_permissions_disabled` 注明「Removed in v2.1.234」——即在 design 自定的 2.1.234 下限之上，官方值集是**五值含 `resume`**。design.md:88 的四值集缺 `resume`，与其自引的「官方 SessionEnd 事件契约」矛盾。

## 三、findings

- **[major] design.md:88（另涉 :50、:126 及测试策略 SessionEnd 行）—— SessionEnd reason 值集缺官方文档值 `resume`。** 违反基准：DECISIONS.md:24-25 未钉死值集（design 的引用落空），官方 ≥2.1.234 值集为 `clear/resume/logout/prompt_input_exit/other` 五值。后果：交互式 `/resume` 切换会话时 SessionEnd 以 reason=`resume` 触发（正常路径），被判非法 → 零删除 → 被结束会话的 v1 已提交状态永久泄漏；legacy 模式下全局快照同样不被清理。
- **[minor] design.md 无 frontmatter 块**（标题/日期/依赖字段缺失于文档头）。与 03d design 惯例一致，且产出/消费契约行已逐字 diff 通过，不阻塞；若本轮流程要求 design 自带 frontmatter 则补齐。
- **[minor] sizing 余量偏紧的风险记录**（design.md:220）：总余量 10 行，settings.json 6/6 顶格、run-demo 58/62；测试预算 176 行低于同构 03d 测试实测 204 行而覆盖范围相当（七类 fixture+CLI+双 surface）。design 已声明超限即回 PLAN 拆片（run-demo 可独立拆出），不阻塞，tasks 阶段应先行复核该两处预算。

## 四、修复指引（NEEDS_CHANGES）

1. **改 design.md:88 §session-end.sh 精确流程（2)**：reason 值集由四值改为五值 `clear`/`resume`/`logout`/`prompt_input_exit`/`other`，依据改写为「官方 SessionEnd reason 表（≥2.1.234，`bypass_permissions_disabled` 已移除）」；同步修订 design.md:126 数据模型表 stdin JSON 行、design.md:190 错误处理表对应行、design.md:210 测试策略中 SessionEnd 非法 reason 用例（改用值集外字符串如 `bogus`）、以及 design.md:50 架构节「SessionEnd reason 值域…官方事件契约下限」的表述。
2. **建议在 DECISIONS 补一条记录**钉死五值集及出处（官方文档 reason 表），消除「DECISIONS 未明确值集」的引用空洞；若坚持排除 `resume`，必须先回 DECISIONS 裁定并配套论证 `/resume` 路径的状态泄漏处置——但按现有官方契约，直接采五值是更简且合规的方向。
3. minor-2 可在 tasks 阶段对 settings.json/run-demo.sh/测试三处预算做一次纸面复核，确认 400 门限内可装下，无需本轮改 design。
