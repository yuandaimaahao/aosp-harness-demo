# tasks review：2026-09-01-02-offline-quality-gate（round 2）

## 结论

**NEEDS_CHANGES**

统计：**阻断 1 / 重要 2 / 次要 0**。

机械检查 `python3 /home/zzh0838/.agents/skills/spec/scripts/check-tasks.py <tasks.md>` 退出 `0`。Round 1 的“缺少 Bash 如何启动 gate”和 managed-set 逐路径 oracle 已按建议补齐；但最终六文件硬门仍会漏掉 index 中的变更，并会把本规格已知的 `.spec/` 工作文件算成越界文件。另有正常根 gate 调用 contract test 时的防递归协议未被任务实现或回归激活，以及全部代码步骤缺少规则要求的代码块。因此门④仍不能通过。

## Findings

### 阻断

#### B1. 六文件范围硬门仍不是真实 oracle：当前必然误报，且可漏掉 staged 的第七个文件

- 位置：`tasks.md:89`。
- 约束来源：`requirements.md:70,73-85`；`design.md:184,186-197`；round 1 B1 的修复要求。
- 问题：修订稿已经改用 `wc -l` 真实检查六个新文件的 `105/30/2/42/8/200` 与总 `387` 行，也用 `git diff --no-index --check` 覆盖了未跟踪文件，这两部分有效；但“恰好六文件”集合仍不完整。集合把 `base...HEAD`、未暂存 diff 和 untracked 合并，却没有读取 index（`git diff --cached` 或等价状态），所以把意外第七个文件 `git add` 后即可漏检；若六个许可文件进入 index，也会产生反向误报。与此同时集合没有排除 `.spec/`。当前 checkout 已有 `PLAN.md`、`STATE.md`、reviews 和本 spec 五份文档等 `.spec/` 修改/未跟踪项，实际运行同形集合会得到这些路径而不是空集合，最终断言必然失败；写入本报告后还会再多一个 review 路径。
- 已核验证据：当前 `base=$(git merge-base main HEAD)` 为 `b143821925e279401334d09a788ba9a969df5c7c`；三路集合实际列出 15 个 `.spec/2026-08-31-aosp-harness-refactor/...` 路径。`git status --short` 同时证明这些规格文件正是当前门④流程产生的正常工作状态。
- 影响：该命令既可能让合规实现永远过不了任务 2.1，也能让 staged 的越权实现文件假绿，不能承担“6 个非生成文件、总 387 行”的硬门。
- 可执行修复：以任务执行开始时的固定 base/status 为基线，收集 committed、index、working tree、untracked 四类变化，NUL 安全地排除 `.spec/` 后再与六个许可路径比较；或直接使用能同时覆盖 index/working/untracked 的 porcelain-v1 `-z` 基线差分。保留现有逐文件 `wc -l`、求和和 `--no-index --check`，并用一个暂存第七文件的负向自测证明范围门会失败且不改坏用户 index。

### 重要

#### I1. `QUALITY_GATE_NESTED=1` 只有被测分支，没有由正常 gate 激活，自动发现 contract test 会递归

- 位置：`tasks.md:13,27-31`；对应 `design.md:85-89,174-181`。
- 约束来源：R1、R3、R9；design 要求 contract test “在被根 gate 嵌套执行时用 `QUALITY_GATE_NESTED=1` 只返回 child marker，避免自递归”。
- 问题：任务 1.1 只要求在 `tests/test-quality-gate.sh` 创建读取该变量的防递归分支；任务 1.2 的实现步骤却只说逐个执行根测试，没有要求 gate 在启动 child test 时设置该变量。其真实仓库边界 case 又是从外部以 `QUALITY_GATE_NESTED=1 bash ./scripts/check.sh --offline` 启动，因而绕过了正常无变量入口。正常 `bash ./scripts/check.sh --offline` 自动发现 `tests/test-quality-gate.sh` 后，按任务文字实现会再次完整执行 contract test，并再次调用 gate；步骤 5 的无界手工命令不能替代可失败的防递归 oracle。
- 影响：R1/R3 的正常成功路径可能递归/挂起，R9 仍可在外部预设变量的特殊路径下假绿。
- 可执行修复：在任务 1.2 的实现步骤明确 root-test child 的环境协议（例如 gate 对每个 child 设置 `QUALITY_GATE_NESTED=1`，外层直接执行 contract test 时保持未设置）；在 fixture 增加一个 child 精确断言该值的 oracle，并用有界调用验证普通 `bash ./scripts/check.sh --offline` 只执行一次 contract body、只出现一次 child marker且成功结束。

#### I2. 所有测试/实现代码步骤仍是纯 prose，违反 tasks 细则的代码块硬要求

- 位置：代表性位置 `tasks.md:13,15,27,29,41,43,55-58,69-71,85-88`；实际覆盖六个任务的代码步骤。
- 约束来源：`references/05-tasks.md` 的“禁止占位符”规则：描述做什么但不给怎么做属于缺陷，且“代码步骤必须给代码块”；执行者可能乱序只读单任务，不能依赖自行还原设计。
- 问题：修订稿的算法与 oracle 描述已经很具体，但没有任何代码块。实现者仍需自行发明 fixture helper、NUL 记录格式、baseline validator、Gitleaks trap/rc 分流、workflow/coverage parser 和最终范围集合的实际代码；这不符合所指定任务格式，也使上述 B1/I1 这类细节容易在实现时滑落。
- 影响：任务不能按细则作为一次上下文内可直接派发的完整实现简报；`check-tasks.py` 退出 `0` 不覆盖这条人工规则。
- 可执行修复：每个任务至少为测试步骤和最小实现步骤给出可直接落地的精简代码块（可以是完整 helper/分支骨架加精确 argv/断言，不必复制整文件），且每个任务自包含，不写“同前一任务”。代码块也必须保持各片预算和 review <10 分钟。

## ① 规格符合性

**结论：NEEDS_CHANGES。**

- R1：❌ CLI、受管语法、C 序执行和统一结果均有任务，但正常 gate 自动执行 contract test 的防递归协议缺口会破坏成功路径（I1）。
- R2：✅ 十个命令逐个缺失，尤其缺 Bash 时用预先保存的绝对解释器启动 gate，并断言 gate 自身 rc/诊断/零 core marker；round 1 I1 已修复。
- R3：❌ 自动发现、双流原样转发、短路与 rc `1` 的普通 fixture 完整，但当前根测试集合包含 contract test，正常自动发现路径未闭合 I1。
- R4：✅ 私有 poison PATH、`GIT_ALLOW_PROTOCOL=file`、外部调用零次及三个 `CURRENT_FEATURE` hash 不变均有 oracle。
- R5：✅ 三工具分别覆盖缺失/错版本，且工具预检明确早于 core。
- R6：✅ canonical 30 行/固定摘要、exact-pair、mutation、固定 ShellCheck/shfmt argv、两行 config、环境清除、仓库外 canary、工作树扫描和错误归类均有任务级验证。
- R7：✅ 三触发器、`ubuntu-24.04`、官方 tag/资产/摘要、安装映射、`GITHUB_PATH` 顺序和唯一 CI gate 调用均有静态 oracle。
- R8：✅ 固定五列表、自动发现根测试、唯一 active 行、未知/重复/空字段和数字覆盖率误称均有 oracle。
- R9：❌ Round 1 的 Bash/discovery 缺口已补齐，但正常无变量 gate→contract-test 路径仍未被 contract 回归证明（I1）。
- 需求全集：✅ 六个任务 `需求` 并集精确为 `{R1,R2,R3,R4,R5,R6,R7,R8,R9}`，无遗漏、无范围外 R。
- 六文件与预算：❌ 六个职责和数值均未扩张，单文件/总行数命令已改善；但文件集合硬门仍有 B1，不能证明恰好六文件。
- 对外签名：✅ requirements frontmatter 的 gate 产出签名在任务 1.5 `产出` 中逐字一致；已消费的 device-safety 接口没有被改写。

## ② 质量结论

**结论：NEEDS_CHANGES。**

- 五字段与编号：✅ 共 6 个必需任务，均有 `文件/消费/产出/需求/必需`；编号最多两级、无重复。
- 签名链：✅ `1.1→1.2→1.3→1.4→1.5→2.1` 的每个消费签名都能在更早任务产出中逐字找到。
- 无孤儿产出：✅ 中间产出均被后续任务消费；workflow、coverage、contract test 与最终 gate/config/baseline 都是 requirements/design 的终交付物。
- 顺序：✅ 先证伪 CLI/core，再做 CI preflight、baseline/static、Gitleaks，最后接 workflow/coverage；没有明显复杂度断崖。
- 粒度与 review 时间：✅ 每片新增上限约 35–80 行，最多修改 3 个文件，单个 subagent 一次上下文可装下，人工逐片 review 预计可控制在 10 分钟内。
- 独立回滚：✅ 六片按线性消费链推进；每片只增量修改本 spec 的新文件，在后续消费者开始前可按该片 diff 反向撤销，不要求改外部 provider。
- 红绿 oracle：❌ Round 1 两处 oracle 已真实化，1.1、1.3–2.1 的预期首红总体与前序状态相符；但正常嵌套防递归没有红阶段 case（I1），最终范围门还存在确定的假红/假绿（B1）。
- 自包含与占位符：❌ 无 `TBD/TODO/实现后补`，但所有代码步骤缺少细则强制的代码块（I2）。
- YAGNI：✅ 未增加六文件之外的产品交付物，也未把后续 session/lease/verifier/runtime/registry/adapter 行为带入本片。

修复 B1、I1、I2 后，应重新派全新上下文 reviewer 完整复审 tasks.md。
