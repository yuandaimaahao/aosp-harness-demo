# Task 1 独立 Diff Review — verifier base contract test

## 结论

**PASS — B/I/M: 0/0/0**

本审查只覆盖 task 1 的提交 `65d67b52..354d8101` 和其唯一源码文件
`tests/test-verifier-contract.sh`。该提交只新增该 100755 测试文件（102 行）；没有
provider、旧 verifier、session/resource-lease 或其他源码改动，符合本任务的严格范围。

没有重跑实现报告已经给出结果的 red、cmp、格式、静态检查或 provider-absent 验证。
当前 worktree 仍停在 task 1 的 commit，canonical provider 尚未引入；因此本文将
provider-present 的端到端成功判定为后续 task 的依赖，而非 task 1 缺陷。

## 规格符合性（R → E）

| Requirement | Evidence in task-1 diff | 结论 |
|---|---|---|
| R7：测试从自身解析 repo root，并在 repo 外 EUID-owned 0700 空普通目录运行。 | `ROOT` 由本脚本目录的父级以 `pwd -P` 计算（20 行）；`mktemp -d /tmp/verifier-contract.XXXXXX` 建立临时目录（23 行），随后检查非 symlink、真实路径不在 repo 下、`$EUID:700` 和空目录（31–34 行）。 | ✅ |
| R7：demo 基线逐字五个 PASS、零 query。 | 测试建立七行的精确 expected 文件（51–54 行），以 `--demo` 调用，并由 `exact 0` 比对完整 stdout / 空 stderr（55–56 行）；日志必须为空（57 行）。 | ✅ |
| R7：real default baseline 逐字成功，六条 seam 调用逐 argv 核验并使用同一 serial。 | 默认 real 调用使用 `ANDROID_SERIAL=A._:-9` 与 self-hosted runner（59–60 行）；six expected records 明确编码 `key -- adb -s A._:-9 ...`，包含默认 `-T 100.000000000`（61–68 行），`cmp` 比对完整调用日志（69 行）。 | ✅ |
| R7：explicit `--since` 核五调用、九位补齐、query 非零的 detail / runner stderr / rc。 | `--since 1.2` 与 `FAKE_FAIL=boot` 场景断言 rc=1、末行 `RESULT FAIL`、`FAIL  boot query failed` 和精确 runner diagnostic（71–74 行）；五条期望 argv 包含 `-T 1.200000000` 且没有 `boot_time` query（75–81 行）。 | ✅ |
| R7：代表性 duplicate、missing、multivalue/extra positional、help-combination、独立 positional、非法 serial / runner 与单独 help 均核验 rc、双流、零 query。 | CLI 循环覆盖 `--demo --demo`、`--since`、`--since 1 extra`、`--help --demo`、`position`，统一断言 rc=2、stdout/log 为空且 stderr 非空（83–87 行）；serial、relative runner 和 standalone help 各有独立断言（88–93 行）。 | ✅ |
| R7：只在物理删除临时目录后打印固定成功摘要；失败不提前输出 PASS。 | 所有 `fail` 路径在成功摘要之前（28–30 行）；成功路径先移除 trap、显式 `rm -rf`、再证明路径不存在，最后才打印唯一摘要（95–98 行）。 | ✅ |
| R10：任何断言或前置失败非零、无交付 PASS，并尽力清理。 | `fail` 写 stderr 后 `exit 1`（28–30 行）；捕获的各场景均会走断言或 `fail`；EXIT trap 为失败路径尽力清理（24–25 行）。成功路径的清理失败会 `exit 1`（96 行），因此不能到达 PASS（98 行）。 | ✅ |
| R10：不以扩大矩阵、放宽 grammar 或忽略工具失败推进；R3/R4 穷举留给 05a。 | diff 仅是 102 行代表性基础测试；它对关键成功输出、argv、错误 rc/stderr 做严格比较，未添加完整 R3/R4 manifest 或后序资产。此边界与 brief 明示的 task-1 职责一致。 | ✅ |

## 质量检查

- **越界：通过。** diff package 显示仅新增 `tests/test-verifier-contract.sh`；实现报告中的 `BASE..HEAD` exact-one-file 结论也与该 diff 一致。
- **断言有效性：通过。** 成功结果不只是匹配末行：`diff -u` 比对整个 stdout，且默认 real 的六个、explicit failure 的五个分离 argv record 用 `cmp -s` 字节比对。preflight 情形同时要求零 query log、空 stdout、非空 stderr 与 rc 2。runner failure 同时核 rc、业务 detail 和 stderr，未吞掉 transport 失败。
- **逐字重复：通过。** 各 argv 显式列出是此测试的核心 oracle；未见无意义复制或重复测试矩阵。测试主体与 runner mode 共置单文件，符合 task brief 的 exact prototype / 不额外创建源码文件限制。
- **错误路径与清理：通过。** `set -u -o pipefail` 避免未定义变量和 pipeline 错误被静默忽略；每次 capture 在临时树中清空 output/log；失败 trap 尽力删除临时目录，成功路径在删除并确认物理缺席后才输出 PASS。该“失败 trap best effort、成功时严格确认”的处理正符合 brief。

## Findings

- 阻断（B）：0
- 重要（I）：0
- 次要（M）：0

## 审查边界 / 后续验证

该 task 的红阶段和 provider-absent fail-closed 状态在实现报告中有明确证据；按照审查约束未重复运行。完整 `bash ./tests/test-verifier-contract.sh` 的成功输出、provider CLI/grammar 与完整 05a exhaustive oracle 不能由仅含测试文件的本提交建立，分别应在 provider task 集成后和 05a assurance 中验收，不构成本 task 的 finding。
