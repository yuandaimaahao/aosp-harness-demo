# Task 1.1 Review — Round 1

Review target: `782387ab4688f55495e56fc1430e2cd998f82c2f` (`tests/test-device-safety.sh` only)

Scope: task 1.1 only. This review is based on the supplied brief, implementation report, and diff package. It did not rerun the implementer-reported verification.

## 1. 规格符合性

| 简报要求 | 结论 | 证据 |
|---|---|---|
| 红阶段先确认根级入口不存在 | ✅ | 实现报告记录 `test -e ./tests/test-device-safety.sh` 返回 1，并指向保存的红阶段证据。 |
| 创建 `tests/test-device-safety.sh` | ✅ | 提交新增该可执行 shell 文件。 |
| 提供 `device_safety_register_scope <scope> <function>` | ✅ | 第 14–17 行以平行数组注册名称和函数。 |
| 提供失败汇总和无位置参数 runner | ✅ | 第 9–12 行累计失败；第 123–126 行拒绝任意位置参数并返回 2；第 131–133 行运行 scope 后以失败数收口。 |
| 未知 scope 向 stderr 报错并退出 2 | ✅ | 第 19–29 行输出指定 `DEVICE_SAFETY_TEST_SCOPE` 错误并 `return 2`。 |
| 建立私有 fake adb，记录 argv/命令名，错误 serial 或未知命令非零 | ✅ | 第 35–64 行创建临时 `bin/adb`；以 `%q` 记录完整 argv；独立检查 `$1 == -s` 和 `$2 == EXPECTED_SERIAL`（91），未知命令返回 92；响应表与简报逐项一致。 |
| fixture 自测 PATH 首项、cleanup trap、全部响应、日志、未知 serial/命令 | ✅ | 第 66–118 行实际调用临时 fake adb，检查私有 `command -v adb`、`trap -p EXIT`、六类响应、日志和 91/92 错误路径。 |
| 自测不得调用系统 adb | ✅ | 每一次 fixture 调用均以 `PATH="$DEVICE_SAFETY_FAKE_BIN:$PATH"` 启动，且先断言解析到的 `adb` 正是私有 fake 可执行文件。 |
| `bash -n` 通过 | ✅ | 实现报告记录 `bash -n ./tests/test-device-safety.sh` 退出 0。 |

本任务仅负责 fixture/scope 骨架；后续 verifier、skill、legacy 聚合及最终 `RESULT PASS  device safety` 契约属于 1.2–1.8，未将其缺席计为本任务不符合。

## 2. 质量

| 维度 | 结论 | 说明 |
|---|---|---|
| YAGNI | ✅ | 只增加 scope runner、一个 fixture 和其自测；没有提前实现后续任务的 verifier/skill/legacy scope。 |
| Oracle 是否真实 | ✅ | fixture 通过实际子进程执行生成的 fake `adb`，检查分离的 `-s`/serial argv、模拟响应、退出码和写入日志，而非只检查脚本文本。 |
| 重复 | ✅ | 六个命令调用是响应表覆盖所需的显式矩阵；未形成可维护性问题。 |
| 错误路径 | ✅ | 覆盖未知 scope、位置参数、错误 serial、未知命令、失败累计和 `mktemp` 失败。 |
| 隔离/清理 | ✅ | `mktemp -d` 创建私有目录，fake bin 每次置于 `PATH` 首位，并在 EXIT trap 中清理；scope 自测确认 trap 已注册。 |
| 安全 shell argv | ✅ | 路径与变量均被引用；fake adb 用 `$1`/`$2` 分离校验 serial，并用 `%q` 记录 argv，未通过拼接字符串执行 shell 命令。 |

## Findings

- 阻断：0
- 重要：0
- 次要：0

没有 ⚠️ 项，因此无需控制器追加核实。

## 结论

**PASS** — 任务 1.1 的范围和要求均已满足，质量审查无 findings。
