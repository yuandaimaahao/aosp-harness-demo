# Task 1.2 熔断定点修复独立验证

## 结论

**PASS**

审查范围严格固定为 `28e8f1b6c1c2690497185e103a44064a28378346..5338e29d0acfc09eb12e6181bf72f9095a179044`。R3 的 3 个 Important 已完整关闭；本轮 diff 未引入直接相关的 correctness regression。

Finding count：Blocker 0，Important 0，Minor 1（R3 已裁定的 readability judgement-call 挂账，非本轮新增，不阻断 PASS）。本轮新增 finding 为 B0/I0/M0。

## Standards

PASS with carried Minor。diff 仅修改任务指定的 runtime 与测试文件，满足 `common/AGENTS.md` / `common/.harness/common.md` 的适用约束；`git diff --check` 无输出。R3 已记录的 compact names / dense control flow readability Minor 保持挂账，本轮未扩大该问题。

## Spec

### Blocker

无。

### Important

无。

### Minor

1. 已挂账 readability judgement call：`seed_contract_runtime.py` 与 `test_seed_contract_runtime.py` 仍使用 compact names 和高密度单行控制流。该项来自 R3，非本轮 correctness regression，按已给裁定不导致 FAIL。

## R3 Important 关闭证据

1. **`entry_kind` expected-failure carrier 已关闭**
   - Exact head `seed_contract_runtime.py:42` 在 dict dispatch 前先调用 `_text(v["entry_kind"])`，因此 list/dict/int/bool/null 不会进入不可 hash 的 `.get()`，而是统一抛 `ContractError("DESCRIPTOR_SCHEMA_INVALID")`。
   - Exact head `test_seed_contract_runtime.py:45` 以独立 row 覆盖 `entry_kind` bogus string/list/dict/integer，没有借其他 invalid field 遮蔽。
   - 独立 probe 额外覆盖 list/dict/int/bool/null/bogus string，六例均精确得到 `DESCRIPTOR_SCHEMA_INVALID`，无 raw `TypeError`。

2. **shared validator schema exactness 已关闭**
   - Exact head `seed_contract_runtime.py:72-73` 的 `_validate_artifact` 现在先执行 scalar guard，再强制 exact dict、`type(schema_version) is int`、`schema_version == 1`、exact string kind 与四类 handler membership，之后才 dispatch。
   - Exact head `test_seed_contract_runtime.py:46` 直接调用 shared validator 断言 schema `2` 和 `True` 均为 `DESCRIPTOR_SCHEMA_INVALID`。独立 probe 对 `2/True/0/-1/None` 全部得到同一 expected carrier/code。
   - File loader 的 error priority 未回归：`seed_contract_runtime.py:81-85` 仍在 shared guard/validator 之前对非 1 schema 返回 `UNSUPPORTED_SCHEMA_VERSION`；独立 mixed probe 中 schema=2 + kind mismatch 与 schema=2 + float field 均精确命中该高优先级 code。

3. **独立 per-field/boundary/order/base64/enum/digest matrix 已关闭**
   - `test_seed_contract_runtime.py:43-45` 对四类 artifact 的顶层/嵌套 field 递归独立执行 missing/unknown/wrong-type/null mutation，并以独立 `simple` rows 覆盖所有 evidence base64 carrier 与 enum 类别；没有上轮“一个早失败字段遮蔽后续字段”的组合 mutation。
   - `test_seed_contract_runtime.py:47-48` 按 applicable numeric field 分行生成 unsigned `-1 / 2^53 / True` reject 和 `0 / 2^53-1` accept，并独立覆盖 signed `result`/`dirfd` 的 `-(2^53-1)` / `2^53-1` accept、越界和 bool reject。
   - `test_seed_contract_runtime.py:37-42` 使用 `a,b,a` 而非相同值验证 exec argv、path operands 与 journal argv 的语义顺序保留/合法重复；并验证 object-key reorder 的 canonical stability、project domain literal oracle 和 project mutation digest inequality。
   - `test_seed_contract_runtime.py:46` 独立覆盖 projects/entries/trace records/journal stages 的 duplicate/out-of-order；`test_seed_contract_runtime.py:49` 以独立 valid mutation rows 覆盖 request/source-state/trace/journal 的承重 field/category，每行同时断言 schema accept 和对应 artifact domain digest 变化。

## 回归与范围核验

- Exact-head isolated `git archive` 内：`canonical-core evidence-schema` exit 0，stdout exact 两行 `PASS canonical-core` / `PASS evidence-schema`，stderr empty。
- `concurrent-core` exit 0，stdout exact `PASS concurrent-core`，stderr empty。
- 旧回归均 exit 0：shared harness 末行 exact `RESULT PASS  shared Harness regression suite`；parity 完整 stdout exact `PARITY PASS  Claude/Codex 共享同一公共契约`；dev-sidebar demo 末行 exact `RESULT PASS`。
- Exact fix range 只有 commit `5338e29 fix(harness): close evidence validator contract`，parent 精确为 `28e8f1b6c1c2690497185e103a44064a28378346`；仅两个任务文件变化，17 insertions / 18 deletions。
- Cumulative task diff `b9d61b7a..5338e29d` 为 74 additions / 5 deletions（runtime 53/2，test 21/3），满足 task 1.2 的 additions ≤75 约束。
- 已完整读取 task brief、task-1.2-review-r3.md、task report、exact fix package 与适用仓库规则。所有动态验证均在 exact head 隔离副本中进行；未读取真实 AOSP，未运行 `envsetup` / `lunch` / build / sync / download / fetch / clone。
