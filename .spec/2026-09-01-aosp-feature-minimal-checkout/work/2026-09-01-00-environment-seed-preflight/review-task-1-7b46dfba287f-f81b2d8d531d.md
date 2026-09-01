# Task 1 独立 diff review

## 结论

**FAIL**

- blocker: 1
- important: 0
- minor: 0
- 审查范围：`7b46dfba287f2e3e3fb9ca00c3186b69c4720dc7..f81b2d8d531d3989509610c6af01b2a25ce9aad3`
- Standards：PASS（未发现独立的仓库规范违例或需单列的代码气味）
- Spec：FAIL（closed schema 接受非法数字类型）

## Findings

### blocker — `schema_version` / `plan_version` 接受 JSON float

位置：`.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/supersession_lib.py:153`

合同要求 manifest 为 closed schema，并明确“所有 JSON 拒绝 float”。当前代码只用数值不等比较版本值：`1.0 == 1`、`6.0 == 6` 在 Python 中都成立，且仅对 `schema_version` 排除了 `bool`，未要求两个版本字段为 `int`。实测把 canonical manifest 分别改成 `"schema_version": 1.0` 和 `"plan_version": 6.0`，两例均被 `load_and_validate_manifest()` 接受，而预期均为 `MANIFEST_SCHEMA_INVALID`。

这使 `supersession/v1` 不再是声明的封闭类型契约，也说明报告中的 type mutation 没覆盖承重的 JSON 数值等值边界。应让两个字段先经过 `_uint`（或等价的 exact-int/non-bool 检查），再比较固定值，并补两例回归。该修复必须 amend 后由 fresh reviewer 重审；当前不能按 task protocol 开始任务 2。

## 合同核对

- canonical manifest：base SHA、ordered replacements/DAG、R1–R27 owners、exact budgets、六个 bytewise-sorted delivery paths均与合同一致。
- 其余 closed-schema matrix：独立复现 duplicate key、missing/unknown top-level key、错误容器类型、replacement order/missing、owner order/missing、budget 801、unsafe path、invalid base，共 11 例均得到预期 exact code。
- PLAN/DECISIONS/sizing：canonical core 命令 exit 0、stdout 精确 `RESULT PASS supersession-core`、stderr 空；分别漂移承重 fragment 时得到 `PLAN_INVALID`、`DECISIONS_INVALID`、`SIZING_INVALID`。
- dispatcher：`self-test`、合法参数的 `pre-commit`、合法参数的 `accept` 在对应 module 缺席时均 exit 1、stdout 空、stderr 精确 `RESULT FAIL supersession CAPABILITY_UNAVAILABLE`；空 argv 与额外 argv 均精确返回 `ARGUMENT_ERROR`。只允许三个 mode，且动态加载路径固定在 dispatcher realpath 下的 `work/modes/{self_test,pre_commit,accept}.py`。
- scope：commit parent 精确为 base；diff 只有三个 task-1 owned paths，均为新增文件；`git diff --check` 通过；无 `common/` 变更。
- 红阶段真实性：`task-1-red.txt` 记录脚本缺席时 exit 2、stdout 空、Python cannot-open-file stderr、无 PASS，与任务要求相符。报告所列 canonical core、11 mutation 与 dispatcher 5-case 结果均可独立复现；但如 finding 所述，类型矩阵不完整。

## 预算裁定

实际 task-1 diff 为 358 行，超过 slice 的 estimate high 320 共 38 行；这不是合同中的独立 hard limit。R24/Controller 的 hard gates 是 cumulative non-generated diff `<=800` 与每份 review summary `<=160`。按剩余任务 stated highs 计算为 `358 + 85 + 140 + 210 = 793 <= 800`，因此**预算本身允许在修复并重审通过后继续**，但只余 7 行预测余量；amend 后必须按新实际值重算。当前停止继续的原因是上述 schema blocker，不是 320 estimate drift。

## 执行的验证

- `git rev-parse` 固定两端 SHA；`git log`、`git diff --stat`、`git diff --name-status`、commit parent 检查。
- 在 `f81b2d8d531d...` detached 临时 worktree 运行 task-1 exact core oracle。
- 运行 13-case manifest mutation matrix：11 个合同/报告基线 case PASS，2 个 float-version case FAIL。
- 运行 3-case PLAN/DECISIONS/sizing fragment mutation matrix，均返回预期 code。
- 运行 5-case dispatcher matrix，逐字比较 rc/stdout/stderr。
- `git diff --check`；`git diff --numstat` 合计 358；报告 39 行（`<=100`）。

未运行 AOSP、`envsetup`、`lunch`、build、sync、download 或网络操作。
