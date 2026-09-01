# Task 1 fresh independent diff review

## 结论

**PASS**

- blocker: 0
- important: 0
- minor: 0
- 审查范围：`7b46dfba287f2e3e3fb9ca00c3186b69c4720dc7..5ab105e8909e893a055e6e834abceb9192e0b133`
- Standards：PASS
- Spec：PASS

## 上轮 blocker 关闭确认

上一轮指出 `schema_version=1.0` 与 `plan_version=6.0` 会因 Python 数值等值而被接受。目标提交在 `supersession_lib.py:153` 将两个字段都先送入 `_uint()`；该函数明确排除 `bool`、非 `int` 和负数，再比较固定版本值。

独立从目标 commit 导出的临时树重放两例，均得到精确 `MANIFEST_SCHEMA_INVALID`，未再被 loader 接受。`f81b2d8d..5ab105e8` 的唯一实现差异也正是这项 exact-int 修复，因此该 blocker 已实质关闭。

## 完整复审

- canonical manifest 的 process base、ordered replacements/DAG、R1–R27 owners、exact budgets 与六个 bytewise-sorted delivery paths均与合同一致。
- closed loader 对 top-level/object shape、duplicate key、array order/duplicate、字符串容器、bool/negative/float、replacement、owner、budget、base 与 path 做了封闭校验并映射稳定错误码；未发现接受非法 canonical 形态的旁路。
- canonical core oracle exit 0，stdout 精确 `RESULT PASS supersession-core`，stderr 空；PLAN v6 rows、DECISIONS、sizing 与外部 `check-plan.py` 均通过。
- 独立漂移 PLAN、DECISIONS、sizing 三个承重 fragment，分别得到 `PLAN_INVALID`、`DECISIONS_INVALID`、`SIZING_INVALID`。
- dispatcher 仅声明 `self-test`、`pre-commit`、`accept` 三个 mode，按 dispatcher realpath 固定加载 `work/modes/*.py`；非法额外 argv 返回 exit 1 / 空 stdout / 精确 `ARGUMENT_ERROR`，三个 module 缺席路径均返回精确 `CAPABILITY_UNAVAILABLE`。
- 红阶段证据记录目标脚本缺席时 exit 2、空 stdout、cannot-open-file stderr 且无 PASS，符合 task 1 要求。
- Scope：目标 commit 的唯一 parent 精确为 base；diff 仅新增三个 task-1 owned paths，共 358 行；`git diff --check` 通过，无 `common/` 变更或越权实现。
- Standards：未发现适用于该 `.spec` 路径的更具体仓库规范违例，也未发现需要单列的 smell baseline 问题。

## 独立验证证据

- 13-case manifest matrix 全部匹配预期 exact code：两个 version float、schema bool、negative budget、missing/reordered replacement、missing/reordered owner、budget 801、unsafe path、invalid base、unknown key、duplicate key。
- canonical core exact oracle与 3-case PLAN/DECISIONS/sizing mutation matrix全部通过。
- dispatcher invalid-argv 与三个 missing-module 路径逐字比较 rc/stdout/stderr，全部通过。
- `git rev-parse`、commit parent、`git diff --name-status`、`git diff --numstat`、`git diff --check` 均从固定 commit 对象核验。

## 预算裁定

Task 1 实际 358 行，比 slice estimate high 320 多 38 行；320 是估算值，不是独立 hard gate。按剩余任务 stated highs 计算，预测累计为 `358 + 85 + 140 + 210 = 793 <= 800`，仍符合 R24 cumulative hard limit，但只余 7 行预测余量。实现报告 41 行，满足 task-1 `<=100`，亦满足全局 `<=160`。

未运行任何 AOSP envsetup、lunch、build、sync、download 或网络命令。
