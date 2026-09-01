# Task 1.5 diff review — round 1

结论：**NEEDS_CHANGES**

计数：阻断 0，重要 3，次要 0，⚠️ 1。

审查边界：仅阅读 task brief、实现报告、`9be78e07..5f31ceb2` review package 与 review 规则；未修改实现，未重跑报告中的验证，也未检查 package 之外的仓库文件。

## Findings

### 重要 1：环境变量断言没有先制造污染，删除 gate 的 `unset` 仍会全绿

位置：review package 第 120、135–136 行。

`assert_gitleaks` 要求两条记录都是 `GITLEAKS_CONFIG=unset` / `GITLEAKS_CONFIG_TOML=unset`，但 `run_static` 启动 gate 时没有给这两个变量设置非空 poison 值。调用者环境本来就是 unset 时，即使从 `scripts/check.sh` 删除第 48 行的 `unset GITLEAKS_CONFIG GITLEAKS_CONFIG_TOML`，fake 仍记录 `unset`，所以 R9 要求的“fake 证明两个配置环境变量已清除”是假阳性。

建议 diff：在第 120 行启动 gate 的环境赋值中显式加入两个不同的非空值，例如 `GITLEAKS_CONFIG="$static_fixture/poison-a.toml" GITLEAKS_CONFIG_TOML="$static_fixture/poison-b.toml"`；保留第 135 行对两者均为 `unset` 的精确断言。这样该用例会在任意一个 `unset` 被删掉时真实失败。

### 重要 2：`set -e` 在当前函数调用位置被抑制，canary 写入/清理失败会被静默忽略

位置：review package 第 53–56、74 行。

`quality_run_secrets` 位于 `quality_run_secrets || exit 1` 的 OR-list 左侧；按 Bash 的 `errexit` 语义，函数体内的 `set -e` 在该调用上下文被忽略。这确实使第 54 行能够捕获 Gitleaks 的 rc，当前 canary rc `1` 不会提前退出；但也使第 53 行 `printf` 和第 56 行 `rm -rf` 的失败不被处理。尤其是显式删除失败后仍执行 `trap - EXIT`，随后扫描工作树，并把含完整 canary 的临时目录留在磁盘，违背“trap 保底、扫描前已清理”的错误路径语义。

建议 diff：

- 第 53 行给写入失败增加显式协议错误处理。
- 第 54 行改用 `if gitleaks ...; then canary_rc=0; else canary_rc=$?; fi`（或局部 `set +e` / 恢复），不再依赖调用点抑制 `errexit` 的隐式耦合。
- 第 56 行改为 `rm -rf -- "$canary_dir" || quality_protocol_error 'cannot remove gitleaks canary'`，只有删除成功后才能 `trap - EXIT`。repo 内目录拒绝路径第 51 行也应检查删除结果或先注册清理 trap。

### 重要 3：新增的 Gitleaks 失败 cases 没有断言“无总 PASS”

位置：review package 第 159–162 行。

config mutation、canary rc `0/2`、仓库内 `TMPDIR`、工作树 rc `7` 分别检查了 rc/调用数，但都没有检查 stdout 不含 `RESULT PASS  aosp-harness offline quality gate`。当前 gate 的控制流不会打印 PASS，但 R6/R9 与本任务产出签名明确要求所有失败路径无总 PASS；这些回归无法阻止以后在错误路径误打印成功签名。

建议 diff：给 `run_static` 增加可复用的 `assert_no_total_pass`，并在第 159–162 行每个失败 case 的复合断言后调用；至少覆盖 config 协议错、canary 协议错、仓库内 TMPDIR 与工作树 finding 四类。

## ① 规格符合性

| 要求 | 结论 | 证据 / 判断 |
|---|---|---|
| config 精确 bytes 与 SHA-256 | ✅ | 新文件恰为两行并带末尾换行；gate 与 contract 均固定正确摘要，mutation 在 Gitleaks 前返回 `2`。固定摘要已经约束 exact bytes。 |
| 清除 `GITLEAKS_CONFIG` / `GITLEAKS_CONFIG_TOML` | ❌ | gate 实现有两个 `unset`，但 R9 contract 未先污染环境，不能证明清除行为；见重要 1。 |
| canary 必须在 repo 外，仓库内 `TMPDIR` 拒绝且 Gitleaks 零调用 | ✅ | `pwd -P` 后按 repo 绝对前缀拒绝；fixture 把 `TMPDIR` 指到 repo 内并断言 rc `2`、空日志。 |
| canary 使用两片运行时拼接，完整 token 未跟踪 | ⚠️ | diff 可见 `'AKIA'` 与 `'ABCDEFGHIJKLMNOP'` 分片，且本 review package/report 中无完整 token；但“整个 tracked tree 均无完整 token”无法只从增量 diff 独立判定。实现报告声称已检索通过，本轮按禁令未重跑。 |
| 两次 Gitleaks 调用同 options/config，仅 target 不同 | ✅ | 共用 `gitleaks_args`；Python oracle 要求恰好两条记录、精确 prefix 相同，第一 target 非 repo、第二 target 精确 repo。fake 还按 state 强制调用顺序。 |
| canary rc 精确 `1`；`0/2` 为协议错 | ✅ | gate 精确比较 `-eq 1`；两例均断言最终 rc `2` 且仅一次调用。当前 rc 捕获有效，但依赖 OR-list 的 `set -e` 抑制，质量风险见重要 2。 |
| canary 在工作树扫描前清理并解除 trap | ✅（正常路径） | fake 第二次调用要求首次 target 已不存在，故顺序不是恒真；但删除失败路径不安全，见重要 2。 |
| 工作树任意非零归一为 rc `1` | ✅ | 最终调用 `|| return 1`，fake rc `7` 的 case 断言 gate rc `1`，且两次 argv oracle 仍通过。 |
| 任一失败无总 PASS | ❌（contract） | gate 当前控制流满足；新增四类失败回归未断言该签名缺席，未完整满足 R9，见重要 3。 |
| 预算与最终签名 | ✅ | package numstat 为 test `19+5=24`、gate `19+1=20`、config `2`，精确卡在任务上限；报告给出的累计 `113/73/2` 低于 `169/105/2`。成功 case 精确检查 gate 总 PASS；报告记录 contract/offline 均 rc `0` 且末行精确。 |

## ② 质量

- YAGNI：✅ 只改任务允许的三个文件；没有 workflow、coverage 或其他行为扩张。
- 验证是否真的在验：❌ argv、绝对 config、两次调用、target 顺序、canary 内容、正常清理、rc 协议与工作树失败均有可失败 oracle，cases 不是恒真；但环境清除是假阳性，失败签名也漏验，见重要 1、3。
- 逐字复制：✅ 未发现新增逻辑块的逐字复制；固定 argv 通过同一数组复用。
- 错误路径：❌ config/canary/worktree rc 分类正确，但 canary 写入/删除失败未处理，且 trap 可能在删除失败后被解除，见重要 2。

## 结论

**NEEDS_CHANGES**。三个重要 finding 都会削弱 R9 的可失败 contract 或 canary 清理保证，需修复后由全新 reviewer 做范围受限 re-review。⚠️ 项不单独阻塞，但控制器需用跨任务证据解决“完整 token 未出现在 tracked tree”这一点。
