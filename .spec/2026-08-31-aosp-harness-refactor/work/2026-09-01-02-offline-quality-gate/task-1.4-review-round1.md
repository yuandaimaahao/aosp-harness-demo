# Task 1.4 review — round 1

结论：**NEEDS_CHANGES**

计数：阻断 0，重要 3，次要 1，⚠️ 1。

## 规格符合性

- baseline：review diff 中确有 30 行 `path<TAB>40-lowercase-hex-blob`；gate 与 contract 都固定了要求的 SHA-256 `62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f`。gate 的 `awk` 检查 30 行、字段格式、C locale 严格递增、path/blob 唯一。实际文件摘要仅依据 report 的已执行结果确认，本轮按约束未复跑。
- 锚点边界：运行期代码只读取 canonical baseline 并对当前文件执行 `git hash-object`，没有读取 `b143821925e279401334d09a788ba9a969df5c7c` 或任何历史对象，符合要求。
- 豁免/必检：仅 `${approved[$path]-}` 与当前 blob exact pair 相等时豁免；新增和变化入口进入 ShellCheck/shfmt。生产逻辑符合，contract 对普通路径覆盖成立，但特殊路径和非锚点变异覆盖不完整，见重要项 I1、I3。
- baseline 拒绝：固定摘要保证 append-current、摘要变化、重复、乱序、畸形、非 canonical 内容均为 rc 2；测试列出了六个标签，但 `non-anchor` 与 `append-current` 构造完全相同，未形成独立证据，见 I3。
- argv：生产代码精确调用 `shellcheck -x --severity=warning "$path"` 与 `shfmt -d -i 2 -ci -bn "$path"`；普通候选的 NUL 日志断言匹配固定 argv。
- 退出码/短路：baseline 协议错误通过 `quality_protocol_error` 返回 2，静态 finding 通过 `return 1` 返回 1。baseline 错误测试断言三工具零调用；静态失败只断言 rc 1，未断言秘密工具与后续候选零调用，见 I2。
- NUL/预算：生产端以 `read -d ''` 数组承接受管路径，引用传给 hash/static 工具，设计上保留 LF；静态 contract 未用 LF 候选验证这一边界，见 I1。diff 为 gate 13、baseline 30、test 33 行 churn，分别未超过 15/30/35；report 给出的累计 55/30/97 也未超过 85/30/145。

## Findings

### 阻断

无。

### 重要

1. **I1 — 静态阶段没有覆盖 NUL/LF 路径与关联数组查找边界。** `tests/test-quality-gate.sh` 的新增 static fixture 只创建普通的 `new.sh`、`scripts/check.sh` 和普通 approved path（review package L145），两处 argv oracle 的 expected 也只有普通字节串（L152、L161）。此前 LF 路径只到达 core 的 `bash -n` oracle（L125-L130），不能证明新加的 `${approved[$path]-}` lookup、`git hash-object`、ShellCheck/shfmt 仍保持单个路径参数。任务明确要求“以 NUL 数组”传递候选；这一回归可在实现被换成换行分隔时假绿。**建议：**在 static fixture 增加一个实际含 LF 的受管文件（最好同时含空格），把其原始 bytes 纳入两个工具的 record 断言，并确认它不会因 associative-array lookup 被误豁免或拆成多次调用；在 35 行任务预算内优先改写现有 fixture/expected 行而非新增大段 helper。

2. **I2 — 静态失败测试只验 rc，不能证明 fail-fast 与秘密零调用。** review package L164 的循环仅检查 `static_rc == 1`。若 gate 在 ShellCheck/shfmt 失败后继续调用后续候选、另一静态工具或 Gitleaks，最后仍返回 1，这个测试仍会通过；这正是错误处理契约要求禁止的行为。L148 的 Gitleaks 零调用只覆盖成功 case，L166 的三工具零调用只覆盖 baseline rc 2。**建议：**分别为 ShellCheck 与 shfmt failure 断言精确日志前缀、失败点后的 candidate/工具记录不存在、`gitleaks` 日志为空且总 PASS 不出现。

3. **I3 — `non-anchor` case 与 `append-current` case 是同一个 fixture，独立要求未被测试。** review package L165-L166 将 `append-current|non-anchor` 都实现为向 baseline 追加同一条 `new.sh + current blob`；只有标签不同。这没有覆盖“保持 30 行但以非锚点/current blob 替换 canonical pair”的非锚点条目形态，属于重复测试而非第六类变异。**建议：**保留 `append-current` 为第 31 行追加；把 `non-anchor` 改为在原排序位置替换一个 canonical blob/path pair（仍为 30 行、格式与顺序合法），断言固定摘要使其 rc 2 且三工具零调用。

### 次要

1. **M1 — 新增 contract 将多个独立判据压在单行，失败定位偏弱。** review package L136-L166 中 canonical、argv、failure 和六类 mutation 多处以长复合表达式/单行 loop 合并；尤其 L164 只能报告工具名与 rc，无法指出短路、argv 或秘密调用哪个判据失败。这与 brief L283“不得把多个独立判据压成不可定位的一行”的测试组织要求有偏差。**建议：**不扩大 helper 体系，至少把静态 failure 的 rc、调用日志、PASS 禁止拆为带标签的独立断言；可通过重排现有长行保持 churn 预算。

## 质量四项

- 正确性/健壮性：生产 diff 未发现会直接破坏 canonical exact-pair 或固定 argv 的缺陷；协议错误和 finding 的返回路径正确。特殊文件名缺少新阶段回归证据。
- 测试有效性：不通过。I2、I3 都允许合同的一部分在回归时假绿，I1 缺少本任务明确要求的 NUL 边界证据。
- 可读性/可维护性：基本可维护，但长单行复合断言降低首错定位，见 M1。
- 范围/预算：通过。仅触及任务允许的三个文件，增量与累计预算均在 brief 上限内；未夹带 Gitleaks 实现、workflow 或 coverage。

## ⚠️

- 指定输入 `07-review.md` 在仓库中按精确文件名无法定位，因此本轮无法核对其中可能存在的额外 review 规范；Standards 轴仅依据 task brief 内的明确规则与 diff smell baseline。其余三份指定材料已审阅，本轮未修改实现、未复跑报告验证。
