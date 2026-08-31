# Task 1.7 review — round 1

## Verdict

**NEEDS_CHANGES**

Counts: 阻断 1；重要 1；次要 0；⚠️ 1。

## ① 规格逐项符合性

| 检查项 | 结论 | 依据 |
|---|---|---|
| 两个 skill、每个两种 mutation（共四变体） | 部分符合 | `device_safety_run_skill_mutations` 枚举两个 skill 并调用 regex/bare 两次；但 mutation 失败可被吞掉，不能构成有效证明。 |
| 只改唯一目标 block | 部分符合 | mutator 自行重写 fenced-block 解析，未消费 extractor 的输出，且 opening fence 规则与 extractor 不同。 |
| 替换恰一处并用 `cmp` 证明改变 | 符合 | `replacement_count == 1` 且两处 `cmp -s` 检查。 |
| 预期错误标签 | 部分符合 | 调用的 oracle 会产生要求的标签，但阻断问题使标签缺失也不会令 scope 失败。 |
| 同一 contract oracle | 符合 | 四个变体均调用 `device_safety_check_skill_file`。 |
| 临时副本隔离、无生产文件写入 | 符合 | awk 只读取 source，输出至 `$DEVICE_SAFETY_TMPDIR/skill-mutations/`；未见写生产 skill 路径。 |
| 非恒真 oracle | 不符合 | mutation assertion 的失败计数被无条件恢复，scope 可在 oracle 接受 unsafe 副本时仍成功。 |

## ② 质量

### 阻断

1. `tests/test-device-safety.sh:509-521` 无条件执行 `DEVICE_SAFETY_FAILURES="$failures_before"`，会同时抹掉**预期的 oracle 拒绝**和本函数自己产生的**实际 assertion failure**。例如 `device_safety_check_skill_file` 若错误地返回 0，522 行的 `device_safety_fail ... unsafe skill must be rejected` 与 524 行的缺少错误标签都会递增计数，但随后仍复位到旧值；`mutation-selftest`/`skills` 能退出 0。应只抵消 oracle 预期增加的一个 failure，或在调用 oracle 前后使用局部捕获而保留本函数新增加的断言失败。

### 重要

1. `tests/test-device-safety.sh:438-482` 没有按任务要求在 extractor 返回的唯一目标 block 上 mutation，而是复制了一套解析器；其 opening-fence 规则为 `^```bash[[:space:]]*$`，现有 extractor 只接受精确 ` ```bash`。bare mutation 也对任意包含固定前缀的行改写，包含注释/示例文本时可不改第一条真实 ADB。应先调用 `device_safety_extract_device_blocks`，在其唯一 `block-1.bash` 上精确定位第一条 command，再将该 block 重组回临时副本，或复用同一套 fence/target 判定。

### 次要

无。

### ⚠️

- 未重跑报告中的任何验证命令；结论基于给定 diff、任务简报和实现文本的静态审查。报告所称 `mutation-selftest` 为绿，不能排除上述被复位计数器掩盖的假绿。
