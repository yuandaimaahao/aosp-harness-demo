# 03e「claude session lifecycle」design round 2 审查 verdict

**PASS**

Round 1 唯一 major finding（SessionEnd reason 五值集）已完整修复，未引入新问题；全篇终审无 critical/major。

## 修复验证（逐项）

1. **design.md:88 §session-end.sh 精确流程 (2)** ✓ —— reason 值集为 `clear`/`resume`/`logout`/`prompt_input_exit`/`other` 五值，依据表述为「官方 SessionEnd reason 表（最低版本 2.1.234 起，`bypass_permissions_disabled` 已移除）与 DECISIONS 已确认行；requirements 为最高约束」，与修复指引逐字口径一致。
2. **design.md:126 数据模型表** ✓ —— hook stdin JSON 行 SessionEnd reason 值集同步为 `clear/resume/logout/prompt_input_exit/other` 五值。
3. **design.md:190 错误处理表 SessionEnd 行** ✓ —— 「reason 非 `clear`/`resume`/`logout`/`prompt_input_exit`/`other` 五值之一」同步，零删除语义保持。
4. **design.md:210 测试策略** ✓ —— 非法用例为「reason 值集外（如 `bogus`）」；新增「reason=resume 合法清理一行（五值集覆盖）」，不再把 `resume` 当非法值。合法/非法两侧覆盖正确。
5. **design.md:50 架构节** ✓ —— 「最低 Claude Code 2.1.234（SessionEnd reason 五值表——2.1.234 起 `bypass_permissions_disabled` 已移除——与 fork source 的官方事件契约下限，承接 DECISIONS 已确认行）」同步。
6. **全文 grep** ✓ —— `bypass_permissions_disabled` 仅出现于 design.md:50 与 :88 的「已移除」表述，无作为合法值的残留；无四值枚举残留（所有 reason 枚举均为五值）；`resume` 其余出现（design.md:5/74/81/123/150/210）均为 SessionStart source 五值之一的合法语义，不受影响。
7. **DECISIONS.md 新增行** ✓ —— 最后一行 `| 2026-09-03 | 03e design review round 1 |` 钉死五值集及出处（官方表、2.1.234 起 `bypass_permissions_disabled` 移除），并明确 2026-09-01「round 1-3」「round 2」两行只确认「经校验后删除」未枚举值集、本行补齐；附漏收 `resume` 会导致已结束会话状态永久泄漏的代价论证。与 design 表述一致。

## 机械复核

- **产出/消费契约逐字 diff** ✓ —— design.md:56 vs requirements.md:5、design.md:60 vs requirements.md:4 经机械 diff 均 `OK`（剥除 frontmatter 引号与行内反引号后零差异）。
- **R1–R10 映射 10/10** ✓ —— design.md:17-25 九行覆盖 R1,R2 / R3 / R4 / R5 / R6 / R7 / R8 / R9 / R10，无缺号。
- **sizing 算术** ✓ —— 52+42+52+6+62+176=390≤400；test 子分解 12+24+12+26+14+20+20+14+12+8+10+4=176，与 176 上限相符；现状文件实测 27/18/63/11 行与分解依据一致（复测确认）。
- **六文件清单** ✓ —— design.md:226-231 与 requirements.md:15 的 exact 六文件（两修改 hook、新增 session-end.sh、修改 settings.json、修改 run-demo.sh、新增测试）逐字一致。
- **mermaid 结构** ✓ —— 1 个 `graph TB`（design.md:30）+ 2 个 `sequenceDiagram`（design.md:135、162），结构合法。
- **04-runtime-resource-leases** ✓ —— 仅作为 NEXT 顺序门目标出现（design.md:47、113-115、214、233），均落在 R10 允许的「requirements/design/tasks 文档允许出现 NEXT 全名」范围，禁令三类记录（ledger/dispatch/execution-base）未写错。

## 重点挑战 1–8

1. **不设 mutant 自反证** —— 维持 round 1「成立」。实证复核：`common/.harness/lib/session-state.sh:42-46` 四个状态 API 转接与 `HARNESS_SESSION_STATE_PROVIDER_VERSION=1` 同处单临界区（42-46 行连续），「API 在场而 marker 缺席」物理不可达成立；七类 fixture 覆盖 marker/API 缺席侧。
2. **三 hook guard 内联 ~6 行** —— 维持「成立」。exact 六文件约束下无公共文件可放，三份重复是预算内最小解（52/42/52 行上限含 guard 6 行分解）。
3. **SessionEnd 校验先于删除** —— 维持「成立」。design.md:88 顺序为 guard→校验→分流删除；非法输入零删除、provider 设计外错误码（含 rc3 保守归入）不删 legacy 快照，与 R5/R6 一致。
4. **run-demo.sh fixture 布局与 ≤62 行预算** —— 维持「成立」。实测 run-demo.sh 63 行，分解保留 ~45 + 新增 ~42 − 删除 ~16 的算术在上限内，受控失败由 demo 内断言 rc==2 自证。
5. **SessionStart read rc 语义** —— 维持「成立」。实证复核 `session-state-snapshot.sh:78-82`（FileNotFoundError → Missing）与 :182（`except Missing: raise SystemExit(3)`），rc3=缺席确认。
6. **embedded python3 解析 stdin** —— 维持「成立」。codex 先例与 provider 五模块同一下限，不引入 jq 新依赖。
7. **compat marker 恰一次** —— 维持「成立」。单行 helper + 结构 `rg -o` 计数 ==1 + 行为逐 case 计数 ==1 双重机械保证。
8. **SessionEnd reason 五值集（本轮修复对象）** —— **裁定修复成立**。五值与官方 ≥2.1.234 契约一致；design 全篇五处表述（:50/:88/:126/:190/:210）互相一致；测试策略合法侧（`reason=resume` 清理）与非法侧（值集外 `bogus` 零删除）覆盖正确；DECISIONS 新行补齐值集出处，与 2026-09-01 两行的衔接关系（只确认「校验后删除」未枚举值集）说明清楚，无基准冲突。

## findings

- **minor** design.md:210 —— 「非法 session_id/source/ malformed JSON 三行」中英混排（`malformed` 应为「格式非法」类中文表述，与全篇语言风格不一致）。纯措辞，不影响语义与任何契约，**不阻塞**。
- **minor** design.md:88 —— 「rc 其他（1/2/3 均视为设计外）」中 rc3 不在 remove 契约（0/1/2）内，归入设计外属保守处理，语义安全但与「设计外」字面略有张力。不影响正确性，**不阻塞**。

## 结论

仅 2 条 minor，均不阻塞。Round 1 major finding 修复完整、无回归、无新增问题，verdict 为 **PASS**，可进入 tasks 阶段。
