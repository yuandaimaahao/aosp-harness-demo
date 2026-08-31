# tasks review：2026-09-01-02-offline-quality-gate（round 1）

## 结论

**NEEDS_CHANGES**

统计：**阻断 1 / 重要 2 / 次要 0**。

机械检查 `python3 /home/zzh0838/.agents/skills/spec/scripts/check-tasks.py <tasks.md>` 虽然退出 `0`，但最终预算命令会对本 spec 的新建、未跟踪文件产生假绿，且两处 contract 测试描述没有给出能够观察目标行为的 oracle；因此还不能通过门④。

## Findings

### 阻断

#### B1. 六文件/387 行硬门实际不会统计本 spec 的新文件，且不能阻止第七个实现文件

- 位置：`tasks.md:7`、`tasks.md:49`、`tasks.md:63`、`tasks.md:79`、`tasks.md:89`；同类无效空白检查还出现在 `tasks.md:17`、`tasks.md:31`、`tasks.md:45`、`tasks.md:59`、`tasks.md:73`。
- 约束来源：`requirements.md:73-85`；`design.md:186-197`。
- 问题：六个实现文件当前都不存在，任务明确把它们全部“创建”为未跟踪文件；没有任何步骤执行 `git add -N` 或形成提交。普通 `git diff --numstat -- <paths>` 和 `git diff --check -- <paths>`忽略未跟踪文件。因此 `tasks.md:89` 的总量会在六个文件任意超限时仍可能算出 `0`，各任务的 `git diff --check` 也可能在新文件含空白错误时仍退出 `0`。该命令还只枚举许可的六条路径，无法发现意外创建的第七个非生成实现文件，并且没有机械检查 `scripts/check.sh <= 105`；这不是真实的 6 文件/387 行硬门。
- 已核验证据：对当前未跟踪的本 spec `tasks.md` 执行同形命令时，`git status` 显示 `??`，`git diff --numstat` 输出 0 字节，`git diff --check` 却退出 `0`。
- 可执行修复：把任务 2.1 的最终验证改为对六个新文件逐一用 `wc -l` 检查 `105/30/2/42/8/200` 上限并求和断言 `<= 387`；再用 NUL 安全的 `git status --porcelain=v1 -z --untracked-files=all` 与任务开始时的基线比较，断言 `.spec/` 之外的新增/修改集合恰好是这六条路径。空白检查应对每个未跟踪文件使用可覆盖新文件的方式，例如逐文件运行 `git diff --no-index --check /dev/null <file>`（接受“有内容”的 diff 退出语义、只把 whitespace error 当失败），或使用不污染既有 index 的等价检查。若选择 `git add -N`，必须保存并恢复原 index 状态，不得覆盖用户暂存内容。

### 重要

#### I1. “缺少 bash”用例没有定义如何让 gate 启动，可能只测到宿主启动失败而非 R2 preflight

- 位置：`tasks.md:13-16`。
- 约束来源：`requirements.md:27`；`design.md:162-164`。
- 问题：步骤要求逐个隐藏 `bash ... sha256sum` 并验证 gate 在 syntax/root-test 前以协议错误 `2` 失败，但没有规定缺少 `bash` 这一例用哪个解释器启动 gate。若 helper 仍通过 `bash gate` 或 `#!/usr/bin/env bash` 启动，PATH 中隐藏 bash 会令 gate 本体根本没有执行，通常得到宿主的 `127`；即使断言被放宽，也无法证明 gate 自己执行了 `command -v bash`、输出了协议诊断并返回 `2`。这是红绿验证真实性缺口。
- 可执行修复：在污染 PATH 前捕获并校验绝对宿主解释器（例如 `host_bash=$(command -v bash)`），缺 bash case 必须用 `"$host_bash" "$fixture/scripts/check.sh" --offline` 启动，同时让传入 gate 的 PATH 中确实没有 `bash`；断言 stderr 含 gate 独有的 `missing required command: bash`，rc 精确 `2`，syntax/root-test marker 都为 `0`。把这段机制直接写入任务步骤和预期失败标签。

#### I2. managed-set fixture 只“放入”多个边界路径，没有可观察的逐路径发现断言

- 位置：`tasks.md:27-30`。
- 约束来源：`requirements.md:20`、`requirements.md:25`、`requirements.md:50`；`design.md:42`、`design.md:178`。
- 问题：步骤明确加入 gate 自身、无扩展名 Bash、空格路径、实际 LF 路径及指向仓库外脚本的 symlink，但只明确观察了 fake sort 的 locale、一个非法 `.sh` 对 root test 的短路和根测试顺序/双流。仅把其余良性文件放进 fixture，并不能证明它们真的进入了 `bash -n` 集合；同样也没有证明 symlink、`.git/`、`.spec/` 被排除。`tasks.md:30` 的“managed-set ... 全部通过”没有对应的可失败 oracle，可能让漏发现实现假绿。
- 可执行修复：为 discovery case 使用在污染 PATH 前捕获的绝对 Bash 启动 gate，并让 PATH 中的 fake `bash` 对每次 `-n` 以 NUL 安全形式记录目标后委托真实 Bash；精确断言 gate、自定义无扩展名 Bash、空格路径、LF 路径和非法 `.sh` 各出现一次，symlink、`.git/`、`.spec/` 路径出现零次，而且所有 `-n` 记录发生在第一个 root-test marker 之前。也可以拆为每个边界文件单独可证伪的 fixture，但不能只声明“加入”。

## ① 规格符合性

**结论：NEEDS_CHANGES。**

- R1：❌ 任务覆盖 CLI、syntax-before-tests、C 序执行与统一结果，但 managed Shell 全集缺少逐路径可观察 oracle（I2）。
- R2：❌ 十命令枚举完整，但缺 `bash` case 的可执行启动机制，不能证明是 gate preflight 返回 `2`（I1）。
- R3：✅ 自动发现根测试、失败双流转发、短路与 rc `1` 均有明确 case。
- R4：✅ 私有 poison PATH、`GIT_ALLOW_PROTOCOL=file`、外部调用零次和 `CURRENT_FEATURE` hash 不变均有验证。
- R5：✅ 三工具分别覆盖缺失/错版本，且明确验证早于 core。
- R6：✅ baseline exact-pair、mutation、固定静态 argv、config 摘要、canary、环境清除和失败归类均被任务覆盖。
- R7：✅ 三触发器、runner、官方资产/摘要、安装映射及唯一 CI gate 调用均有静态 oracle。
- R8：✅ 五列表、当前根测试唯一 active 行、空字段/重复/未知与数字覆盖率误称均有 oracle。
- R9：❌ 大部分 contract 矩阵完整，但 R1/R2 的两个验证缺口使“离线 gate contract 回归”尚未形成真实闭环。
- 需求全集：✅ 六个任务的 `需求` 并集精确为 `{R1, R2, R3, R4, R5, R6, R7, R8, R9}`，无范围外 R。
- PLAN/design 边界：❌ 文件职责没有扩张，但 B1 使 6 文件/387 行及单文件预算没有被真实执行。

## ② 质量结论

**结论：NEEDS_CHANGES。**

- 五字段、编号：✅ 共 6 个任务，均具备 `文件/消费/产出/需求/必需`，编号最多两级且无重复。
- 签名链：✅ 1.1→1.2→1.3→1.4→1.5→2.1 的每个消费签名都能在更早产出中逐字找到。
- 无孤儿产出：✅ 中间产出均被下一任务消费；2.1 的 workflow、coverage、contract test 是 requirements/design 中的终交付物。
- 顺序：✅ 先锁 CLI/core，再扩展 discovery、CI preflight、baseline/static、Gitleaks，最后接 workflow/coverage；核心可证伪路径在昂贵交付物之前。
- 四条粒度：⚠️ 各片文件增量上限为 35–80 行，范围可装入一次上下文且可按层反向撤销；但 B1 令“命令可判成败”不成立，I1/I2 令两个核心片的红绿证据不充分。在修复前不能认定全部四条均通过。
- 红绿真实性：⚠️ 1.2–2.1 的预期红点总体与前序实现状态相符，且当前六个目标文件均不存在；但 I1/I2 是会实际产生假红/假绿的验证缺陷。
- YAGNI/占位符：✅ 未发现额外交付物、三级任务、`TBD/TODO/实现后补` 或未定义接口。
- 硬预算：❌ B1；当前命令无法证明单文件上限、总 387 行或恰好六个实现文件。

修复 B1、I1、I2 后应重新派全新上下文 reviewer 做下一轮完整 tasks review。
