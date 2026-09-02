# tasks review: 2026-09-02-03b1-session-snapshot-assurance round 1

审查人：独立文档审查 agent（全新上下文，与起草者/控制器无关）
日期：2026-09-02
对象：`.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-02-03b1-session-snapshot-assurance/tasks.md`
对照：同目录 requirements.md（R1–R10、验收标准）、design.md（八节、E1–E6、fail-closed 七类、sizing）、03b tasks.md（结构模板）、PLAN.md v5.7 03b1 节与全局约束、DECISIONS.md（2026-09-02 上游六文件裁定）、prototype `cbdbdde:.../prototype/snapshot-assurance-r1.sh`（308 行）与 `snapshot-core-r2.sh`（208 行）、check-tasks.py 源码。

## 结论

**NEEDS_CHANGES** —— 阻断 2 / 重要 0 / 次要 2

① 规格符合性：需求并集恰为 R1–R10（1.1: R1–R8；2.1–2.3: R9；2.4–2.5: R10；2.6: R9,R10），无漏无多；验收标准 11 条逐项可落到具体任务步骤（CLI 四态、fail-closed 七类 fixture、exact1/400、offline 发现恰一次、depth-1 commit-count=1/shallow、rollback 发现 0 次、manifest 机械验证、03c 顺序门）。但任务 1.1 内部有两处无法按文通过的验证命令（E6(a) 锚文本不存在、步骤 5 `checks=0` 探针不可达），不修则 R2/R3 的机械验证在执行期必然卡住。

② 文档质量：整体忠实 03b 模板（红六行+assertion、green 六节、evidence TSV 三列、manifest 六列、独立 review、ACCEPTED_HEAD、零 delta 验证任务、终任务 awk 全量核验），编号两级无重复，消费签名逐字闭合（matrix→accepted-head→full→depth1→rollback→order-gate→终交付），每任务有具体验证命令且红步骤含失败语义，粒度与顺序合理（任务 1.1 单文件交付 + 六个串行零 delta controller 任务，可证伪步骤在前）。除两处阻断外，E1–E5 与 E6(b)(c)(d) 的锚文本均在 prototype/provider 原文精确一次（逐条 grep 核实）。

## 裁定回应

- 裁定 2（241 = 240 + 1）：**同意**，且非仅凭转述——我在当前 HEAD 的干净克隆中实跑了 cbdbdde 固定 prototype：rc0、stdout 逐字 `RESULT PASS  session snapshot assurance`、stderr 空；按步骤 4 的 rindex 法注入计数探针后复跑得 `checks=240`。E6(d) 新增的 `check_eq` 仅在 publish-success 迭代执行一次，故 241 成立。该数字在任务 1.1 步骤 4 有实跑机械核验，可证伪。
- 裁定 5（任务 2.6 产出写字段路径而非锚点名）：**同意**。读 check-tasks.py 源码证实：孤儿产出检查只取 requirements 正文「验收标准」节（frontmatter 被剥掉），且 `_anchor` 只取首个空白/（/— 前 token。`session-snapshot-assurance-v1` 在验收标准节正文不出现（仅 frontmatter 产出栏），而 `tests/test-session-snapshot-assurance.sh` 在「主验证命令」行逐字出现；写锚点名会误报孤儿产出，写路径则通过。tasks 在路径后以括号保留锚点名不影响检查（首 token 仍是路径）。

## Findings

### 阻断

- **B1. E6(a) 锚文本与 prototype 原文不符，机械替换必然失败。** tasks.md:107 要求把 ``cleanup_log=$tmp/cleanup_log``（下划线）替换为自身加一行；但 cbdbdde prototype 第 268 行原文是 `cleanup_log=$tmp/cleanup-log`（连字符），该 find 串在 308 行全文中出现 0 次（`grep -cF` 实测）。按裁定 4（diff 除 E1–E6 外必须为零）与步骤 2 的逐 hunk 核对，subagent 找不到锚点即卡死或自行改写原文（更糟）。修正：锚文本改为 `cleanup_log=$tmp/cleanup-log`（替换后文本同理保留连字符，新增行 `unlink_log=$tmp/unlink-log` 不受影响；E6(b)(c)(d) 锚文本已逐字核实无误）。
- **B2. 任务 1.1 步骤 5 的 `checks=0` 核验按文不可能通过。** 步骤 5 要求对 provider-absent 克隆「做步骤 4 同款计数注入」后核 `test "$(<err)" = "checks=0"`；步骤 4 定义同款 = 在最后一处（rindex，第 3 处）`printf 'RESULT PASS  session snapshot assurance\n'` 前插探针。但 provider-absent 时流程在 E3 第一处 inert printf 即 `exit 0`，rindex 探针（prototype 末行 printf 前）永不执行，err 为空串而非 `checks=0`，规定命令必然失败。且不能简单把探针挪到 inert printf 前：`set -u` 下 `checks=0` 在 prototype 第 97 行才初始化，位于 E3 之后，提前引用即 unbound 崩溃。可行修法（任选并写死）：探针用 `${checks:-0}`；或把 `checks=0`/`failures=0` 初始化并入 E1/E3 之前；或步骤 5 改核 err 为空并删除 `checks=0` 断言。

### 重要

无。

### 次要

- **S1. sizing 证据文档数字过期未标注。** `cbdbdde:.../round3-assurance-sizing-evidence.md` 正文仍记 293 行/236 断言（修复旧 close 顺序 mutant 前的早期测量），与现行口径 308/240 不一致。design.md sizing 节已裁定以 308/240 为准（我实跑证实 240），但 tasks.md 引用 prototype 时未提示该文档内数字已过期，后续 reviewer 循链接读到旧数字易误判口径漂移。建议在 tasks 头部或裁定 2 依据处加一句「该文档 293/236 为早期测量，现行 308/240」。
- **S2. 步骤 4「全文该字面量恰 3 处，取 rindex」存在隐性耦合。** 当前成立：E3 两处 + prototype 末行一处共 3 处，E1 结构注释只含摘要文字、不含 `printf '...'` 字面量（已核实）。但若日后有人把 E1 注释改写成 printf 形式，计数即静默错位。建议在 E1 注释处或步骤 4 注明「注释不得包含该 printf 字面量」。

## 审查清单逐项结果

- 五字段：七任务均含文件/验收资产/消费/产出/需求/必需，齐。
- 需求并集：= {R1..R10}，无漏无多（check-tasks.py R 全集比对逻辑亦会通过）。
- 孤儿产出：1.1→2.1→…→2.6 消费链逐字闭合；终产出按裁定 5 落验收标准节正文，无孤儿。
- 编号：1.1、2.1–2.6，两级、无重复。
- 验证命令：除 B2 外每任务均有具体命令；红步骤均含失败语义（rc127 文件缺席 / `test -s` 报告缺席）。
- 占位符：无；E1–E5、E6(b)(c)(d) 均给出确切代码/确切转换规则，锚点逐条 grep 核实精确一次（E1 锚 prototype 第 4 行、E2 第 5 行、E4 heredoc 行、E5 键 `"    raise Interrupted"` 条目及其后插入位、E5 替换键在 provider 148–149 行精确一次且 `errno` 已 import、替换后缩进与原 except 体 20 格一致）。
- 粒度：任务 1.1 单文件 + 8 步骤，与 03b 任务 1.2 同量级，一个 subagent 可装下。
- 顺序：红→blob 门→静态工具→active 实跑→absent 实跑→fail-closed→提交→review，可证伪项在前，无复杂度跳跃。
- design 一致性：exact1/400（步骤 2/7 双核）、241=240+1（实跑证实）、fail-closed 七类与步骤 6 (a)–(g) 一一对应、六上游文件与 DECISIONS.md 2026-09-02 裁定同集、03c 顺序门（2.5+2.6 步骤 6）齐。
- 终任务 awk：七行、六列、`$1==NR`、ids 序列 1.1/2.1–2.6、首行 base=BASE_SHA、相邻 `$3==prev($4)`、END `NR==7 且 prev==ACCEPTED_HEAD`，逻辑正确；与任务 2.1–2.6 的 base/head 约定（TASK_HEAD→ACCEPTED_HEAD 链）自洽。
- 头部执行约束与 03b 模板一致（红六行+assertion、green 六节、evidence TSV、manifest 六列、mark/ledger/sync 三步、独立 review 与 re-review 规则）。

## 附：本次实跑证据（可复现）

```bash
git clone --no-local <repo> /tmp/aosp-proto-run
git -C <repo> show cbdbdde:.../snapshot-assurance-r1.sh > /tmp/aosp-proto-run/.proto/snapshot-assurance-r1.sh
git -C <repo> show cbdbdde:.../snapshot-core-r2.sh   > /tmp/aosp-proto-run/.proto/snapshot-core-r2.sh
cd /tmp/aosp-proto-run && bash .proto/snapshot-assurance-r1.sh
# rc=0, stdout 逐字 RESULT PASS  session snapshot assurance, stderr 空
# rindex 注入 printf 'checks=%d\n' "$checks" >&2 后复跑: checks=240
```
（临时目录已清理；对仓库零改动。）
