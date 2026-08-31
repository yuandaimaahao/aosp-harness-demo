# tasks review：2026-09-01-02-offline-quality-gate（round 3）

## 结论

**NEEDS_CHANGES**

统计：**阻断 0 / 重要 3 / 次要 1**。

机械检查 `python3 /home/zzh0838/.agents/skills/spec/scripts/check-tasks.py <tasks.md>` 退出 `0`；六个任务的需求并集也精确为 `R1-R9`。Round 2 的四路文件范围门、`.spec/` 排除、备用 index 第七文件负测和正常 gate→contract child 防递归均已补齐。但目前仍有一个可以直接复现的错误 argv 断言、gate 未被任务明确锚定到自身仓库根，以及 workflow/COVERAGE 的代码块没有实现步骤文字承诺的 oracle；因此代码任务还不能按“实现者只读单任务”直接派发。

## Findings

### 阻断

无。

### 重要

#### I1. 代码块还不是内部一致、可直接落地的任务简报，且 candidate argv 断言必然失败

- 位置：`tasks.md:34-43`、`tasks.md:158-164`。
- 约束来源：`references/05-tasks.md`“描述做什么但不给怎么做的步骤（代码步骤必须给代码块）”及“执行者可能乱序只读任务”的自包含要求；R6/R9。
- 问题一：任务 1.1 的 parser 代码校验了 `$1`，却没有保存 `mode=$1`；任务 1.3 的实现块随后直接读取 `$mode`。若实现者按块落地并使用常规 `set -u`，CI 分支会因未定义变量失败；若自行补齐，则说明任务块仍要求实现者发明跨任务粘合代码。
- 问题二：任务 1.4 把 NUL argv 日志执行 `tr '\0' '\n'` 后，与 `${expected_shellcheck[*]}` 的空格连接字符串比较。三参数示例的真实值分别是 `$'-x\n--severity=warning\ndemo.sh'` 和 `'-x --severity=warning demo.sh'`，二者不可能相等；shfmt 断言同理。该红绿 oracle 按现稿无法进入绿色。
- 影响：任务 1.3/1.4 不能按给定代码块完成，R6 的固定参数验证会产生确定的假红；“每个代码步骤自包含到可派发”不成立。
- 可执行修复：在 1.1 block 中完成 `mode=$1` 赋值并给出后续分支可直接消费的状态；argv oracle 改为 `mapfile -d ''`/逐索引数组比较，或用 Python 对原始 NUL 字节序列与期望 argv 做精确比较。修订后逐任务检查块内使用的变量均在本任务定义或在 `消费` 签名中给出。

#### I2. managed-file 实现块以调用方 cwd 的 `.` 为根，未兑现设计规定的“从仓库绝对根发现”

- 位置：`tasks.md:32-43`、`tasks.md:69-91`。
- 约束来源：`design.md:42`（发现从仓库绝对根执行）、`design.md:48-51`；R1/R3/R9。
- 问题：任务 1.1 虽计算 `repo_root`，任务 1.2 的 `quality_list_shell_files` 却直接 `find .`，根测试也直接执行相对的 `tests/...`；块中没有 `cd -- "$repo_root"`，也没有把发现和执行显式置于该根。测试调用示例 `"$host_bash" "$fixture/scripts/check.sh" --offline` 同样没有给出 fixture cwd。按代码块实现时，从仓库外或另一个目录调用 gate 会扫描调用方目录；fixture helper 若通过临时 `cd` 绕过，还会让真实接口缺陷假绿。
- 影响：受管 Shell 集合、`.git/.spec` 排除、根测试集合和 baseline candidate 都可能来自错误目录，破坏 R1/R3，且可能在调用方目录执行非预期脚本。
- 可执行修复：在完成 `repo_root` 解析后、任何 discovery 前显式 `cd -- "$repo_root"`，或所有发现/执行都以该绝对根为边界并保持输出为仓库相对路径；contract 增加“从无关 cwd 调用 fixture gate”用例，断言只发现 fixture 内路径，调用方 poison 脚本零次。

#### I3. 任务 2.1 的 workflow/COVERAGE 代码 oracle 明显弱于步骤文字，会让 R7/R8 假绿

- 位置：`tasks.md:237-256`，并结合 `tasks.md:225,294-317` 的 test 最终 200 行预算。
- 约束来源：R7、R8、R9；`design.md:65-83,174-184`；tasks 代码步骤自包含规则。
- 问题：workflow block 只 grep 若干 trigger/runner/资产名、`install -m 0755`、`$GITHUB_PATH`，甚至没有把三个固定 SHA-256 放进 `workflow_needles`；它也没有实现文字承诺的 artifact→executable 映射、RUNNER_TEMP 绝对 bin、三次安装全部发生在写 GITHUB_PATH 之前、独立 quality step 等结构/顺序断言。COVERAGE block 只检查表头、每个预期路径有一次 substring 和数字百分比正则，没有实现五列非空、Status 精确 `active`、未知行/重复数据行拒绝。把所有要求只留在 prose，执行者仍需自行设计 parser。
- 影响：把摘要放在注释、漏装/装错二进制、提前写 PATH、coverage 行为空字段或非 active 等错误都可能通过给出的代码，R7/R8/R9 没有真实闭环。任务 1.5 已把 test 累计预算用到 180 行，2.1 只剩 20 行；在没有完整块的情况下也无法确认这些结构 oracle 能在 200 行内以 design 要求的可定位方式实现。
- 可执行修复：给出可直接落地的 Bash/Python 结构 oracle，至少逐项核对三个 URL/tag/asset/SHA/解包源/安装目标的同一映射和步骤顺序，并解析 coverage 数据行得到严格的 `path -> 五字段` 映射后与自动发现集合做集合相等；同时展示它如何落在剩余 20 行内，若做不到就按 requirements 回 PLAN 拆片，而不是压成不可定位的一行。

### 次要

#### M1. `mktemp -d` 没有机械保证 canary 位于仓库外

- 位置：`tasks.md:190,209-223`。
- 约束来源：`design.md:103-107,156` 及任务 1.5 自己的“repo 外 canary”断言。
- 问题：实现块直接调用 `mktemp -d`，它受调用者 `TMPDIR` 影响；当 `TMPDIR` 指向仓库内时，canary 不再满足设计边界。测试文字要求断言“repo 外”，实现块却未给出确保或拒绝仓库内结果的代码。
- 影响：通常环境默认 `/tmp` 时不触发，但 gate 行为随外部环境变化，任务块和设计不完全一致。
- 可执行修复：显式选择并校验仓库外临时根，或创建后用规范化绝对路径拒绝 `repo_root/` 前缀；增加仓库内 `TMPDIR` 负测。

## 已核对通过的重点

- **四路 file-scope oracle：通过。** `scope_check` 合并 `base...HEAD`、`git diff --cached`、tracked working diff、untracked 四路 NUL 集合；使用 Python set 排除 `.spec/` 后与六个许可路径精确比较，能覆盖 index，且不会因 staged 文件漏检。
- **备用 index 第七文件负测：通过。** `GIT_INDEX_FILE="$probe_dir/index" git read-tree HEAD` 后仅在备用 index 暂存 `.quality-range-canary`，`! QUALITY_INDEX=... scope_check` 要求真实失败；没有写用户 index，trap 有界清理明确目标。
- **单文件/总预算：通过。** 六个 cap 精确为 `105/30/2/42/8/200`，逐文件 `wc -l`、总和 `<=387`，并用 `git diff --no-index --check /dev/null` 覆盖新建未跟踪文件。六文件在本 spec 中均为创建文件，因此整文件行数等于本片新增行数。
- **正常 gate→contract child：通过。** contract 在 `QUALITY_GATE_NESTED=1` 时只输出 child marker；gate 对 root child 显式设置该变量；外层真实普通调用不预设变量并由 Python `timeout=30` 有界，断言 child 一次、body/外部 poison 不执行。当前没有递归缺口。
- **canonical baseline 生成：通过。** 只读复算锚点命令得到 30 行，SHA-256 精确为 `62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f`。

## ① 规格符合性

**结论：NEEDS_CHANGES。**

- R1：❌ CLI/预检/语法/测试/总结果均有任务，但 managed-file/root-test 实现未锚定 `repo_root`（I2）。
- R2：✅ 十个命令逐个缺失；缺 Bash 用预先保存的绝对解释器启动并断言 gate 自身 rc/诊断/零 core marker。
- R3：❌ 自动发现、C 序、双流、短路和嵌套 child 已覆盖，但从非根 cwd 调用时集合可错误（I2）。
- R4：✅ 私有 poison PATH、`GIT_ALLOW_PROTOCOL=file`、外部工具零调用及三个 `CURRENT_FEATURE` hash 不变均有 oracle。
- R5：✅ 三工具缺失/错版本六 case，且明确早于 core；补齐 I1 的 `mode` 后接口链可落地。
- R6：❌ baseline/config/canary/错误分类覆盖完整，但 ShellCheck/shfmt argv 的给定断言必然假红（I1）；仓库外 canary 还有 M1 的环境边界缺口。
- R7：❌ workflow prose 完整，代码 oracle 未验证固定摘要、映射和步骤结构/顺序（I3）。
- R8：❌ coverage prose 完整，代码 oracle 未验证五列非空、精确 active 和数据集合相等（I3）。
- R9：❌ 正常 child 防递归、scope/baseline 等主要 contract 已闭合，但 I1-I3 令固定 argv、cwd 边界和 workflow/COVERAGE 仍可假红/假绿。
- 需求全集：✅ 六个任务 `需求` 并集精确为 `{R1,R2,R3,R4,R5,R6,R7,R8,R9}`，无遗漏或范围扩张。
- 对外签名：✅ requirements frontmatter 的 gate 产出签名在任务 1.5 逐字出现；线性消费签名均能在更早产出中逐字找到。
- 文件与预算边界：✅ 六个文件职责未扩张，四路 scope、单项 cap 和总 387 行均有可执行机械门。

## ② 质量结论

**结论：NEEDS_CHANGES。**

- 五字段、编号、必需项：✅ 共 6 个任务，均有五字段，全部必需；编号只有两级且无重复。
- 签名链：✅ `1.1→1.2→1.3→1.4→1.5→2.1` 消费/产出逐字闭合。
- 无孤儿产出：✅ 中间产出均被下一任务消费；最终 gate、baseline、config、workflow、coverage、contract test 都是 requirements/design 终交付物。
- 顺序：✅ 先 CLI/core/discovery，再 CI preflight、baseline/static、Gitleaks，最后 workflow/coverage，核心证伪路径靠前且没有明显复杂度断崖。
- 粒度与回滚：⚠️ 每片最多 3 个文件，线性增量可按任务 diff 回退；但 2.1 在 test 仅余 20 行时没有给出完整结构 oracle，尚不能证明“给定内容一次上下文直接派发且 review <10 分钟”（I3）。
- 验证真实性：❌ scope、递归、baseline、preflight 的 oracle 已真实化；但 argv 比较确定假红，workflow/COVERAGE 代码确定存在假绿空间（I1、I3）。
- 自包含/占位符：❌ 没有 `TBD/TODO/实现后补`，且每个写代码步骤表面都有代码块；但跨块变量未定义、错误断言和只覆盖 prose 子集的代码块仍要求实现者自行发明关键实现，不满足可派发自包含性（I1、I3）。
- YAGNI：✅ 未增加六文件之外的产品交付物，未越权修改后续 session/lease/verifier/runtime/registry/adapter 行为。

修复 I1-I3（并顺手收口 M1）后，需要按 `fix_loop_max=3` 的熔断/裁定规则处理本轮结论；当前不能判定门④通过。
