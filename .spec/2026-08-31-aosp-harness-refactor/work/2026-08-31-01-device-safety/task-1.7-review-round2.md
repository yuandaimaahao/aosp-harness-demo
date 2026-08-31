# Task 1.7 review — round 2

## Verdict

**PASS**

Counts: 阻断 0；重要 0；次要 0。

## ① 规格符合性

| 检查项 | 结论 | 依据 |
|---|---|---|
| 两个 skill、regex/bare 共四个变体 | 符合 | `device_safety_run_skill_mutations` 对 `build-services-jar`、`build-sepolicy` 各运行 regex 与 bare mutation，并均复用 `device_safety_check_skill_file`。 |
| 计数器假绿已闭合 | 符合 | checker 在独立 subshell 中以 `DEVICE_SAFETY_FAILURES=0` 运行；外层不再复位全局计数。checker 错误接受 mutation 或未产生日志标签时，外层 `device_safety_fail` 的失败都会保留。模拟 accepting checker 的 selftest 进一步覆盖此路径。 |
| mutation 只使用唯一目标 block | 符合 | mutator 直接调用 `device_safety_extract_device_blocks`，要求计数精确为 `1`，且仅把 `block-1.bash` 交给 awk 修改。 |
| bare mutation 为第一条真实固定目标 ADB | 符合 | awk 仅在 replacement count 为 0 时匹配行首（可带空白）的 `adb -s "$device_serial" `，因而只删除首个合规 ADB 的固定 target 前缀。 |
| 替换计数与 `cmp` | 符合 | awk 写出 replacement count，必须等于 `1`；重组的 baseline 与 mutation file 用 `cmp -s` 证明不同。 |
| 预期错误标签 | 符合 | regex 期待 `missing safe serial preflight`，bare 期待 `bare adb`；每个变体检查对应 `FAIL  <skill>-<mutation> device block 1: ...`。 |
| 生产隔离 | 符合 | extractor、baseline、变异 block、变异 skill、stderr 均置于 `$DEVICE_SAFETY_TMPDIR/skill-mutations`；源 skill 仅作为读取输入。 |
| mutation-selftest / 生产 skills 语义 | 符合 | 两个最小安全合成 skill 覆盖正常拒绝；accepting checker 自测证明外层可见失败。原生产 skill 的 contract/mutation 仍由 `skills` scope 统一执行。 |

## ② 质量

未发现阻断、重要或次要问题。

- 该修复消除了 round 1 的无条件恢复失败计数问题。
- mutation 解析已与 contract checker 共用 extractor，避免两套 fenced-block 识别规则漂移。
- 改动范围限于测试 oracle，未触碰生产 verifier 或 skill 文件。

## 审查限制

依用户要求，本轮未重跑任何验证命令；结论基于任务简报、round 1 审查、fix 报告及 `f7c94e56..d92af9d1` 的静态 diff / 提交内容。

