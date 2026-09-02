# Task 1.1 独立 diff review（R2）

## 结论

**FAIL**

审查范围为 `c959efaf9887808621852aff28073cf1f8789ca7..214add6b6dd1555afbb977a0a8fcc76cf2d0ba3d`。精确 diff 只新增任务指定的两个源码文件，共 70 行；`git diff --check` 通过，未发现 AOSP 读取或命令调用。R1 的 B1、I1、I2 均已关闭，但仍有两项 Important 正确性问题。

## Blocker

无。R1 B1 已由完整的 `task-1.1-brief.md` 与 immutable exact diff 包关闭，规格、范围、预算及禁止 AOSP 约束均可复核。

## Important

### I1. `canonical_bytes` 接受 Unicode object key，却没有按 RFC 8785 的 UTF-16 code-unit 顺序排序

位置：`common/.harness/closure/v1/lib/seed_contract_runtime.py:19-26`。

`_guard` 接受任意无 surrogate 的字符串 key，而 `json.dumps(sort_keys=True)` 按 Python Unicode code point 排序。RFC 8785 要求 object property name 按 UTF-16 code units 排序；两者对部分 BMP/non-BMP key 的顺序不同。隔离探针使用 key U+10000 与 U+E000 时，规范顺序应为 U+10000、U+E000，当前输出却为 U+E000、U+10000，因此 canonical bytes 与 domain digest 都会错误。

这也越出了 brief 第 244 行声明的安全子集：“closed schema 的 ASCII keys”。当前实现既未将 key 限制为 ASCII，也未实现完整 RFC 8785 排序。

可执行修复：选择与设计一致的最小方案，在 `_guard` 中对非 ASCII object key 返回 `DESCRIPTOR_SCHEMA_INVALID`；或者实现 RFC 8785 UTF-16 排序。为 BMP/non-BMP 交叉顺序补 canonical bytes 与 digest 回归测试。

### I2. `load_artifact` 没有把成功绑定后的非法参数类型映射为 `ARGUMENT_ERROR`

位置：`common/.harness/closure/v1/lib/seed_contract_runtime.py:31-38`。

Brief 第 288 行要求所有 public callable 在 call shape 成功绑定后，非法 value/type/combination 抛 `ContractError("ARGUMENT_ERROR")`。当前行为为：

- `load_artifact(path=None, expected_kind="seed")` 返回 `DESCRIPTOR_NOT_FOUND`，把非法参数误报为文件缺失；
- `load_artifact(..., expected_kind=1)` 甚至会接受 `{"kind":1}`；
- `ContractError(7).code` 为整数，也不满足 brief 第 68 行“构造参数和只读 `.code` 均为 exact error-code string”。

错误优先级因此不符合 R12，且整数 fd/PathLike 等 `open()` 可接受对象会扩大固定 `path: str` ABI。

可执行修复：在任何文件 I/O 前验证 `path` 与 `expected_kind` 的稳定 ABI 类型并以 `ARGUMENT_ERROR` 失败；同时保证 `ContractError.code` 只能承载字符串 error code。补充上述三项回归测试，并保留 unknown/missing/positional call-shape 的原生 `TypeError`。

## R1 findings 复核

- **B1 closed**：brief 提供了完整 requirements/design/tasks/context；diff 包固定 `BASE..newHEAD`。
- **I1 closed**：tuple、非字符串 key、混合 key 均统一返回 `DESCRIPTOR_SCHEMA_INVALID`，不再产生 canonical/digest 别名或泄漏 `TypeError`。
- **I2 closed**：测试改用 `TemporaryDirectory()`，并新增 `concurrent-core` 以 8 workers/20 subprocess 验证；隔离运行通过。

## Minor

无。

## 验证记录

- `git rev-parse c959efaf 214add6b`：两个 SHA 均解析为 diff 包中的 full SHA；提交链为 `c959efaf -> 67db369 -> 214add6b`。
- `git diff --numstat c959efaf..214add6b`：runtime 39 行 + test 31 行 = 70 行，满足 task 上限；只涉及指定两文件。
- `git diff --check c959efaf..214add6b`：exit 0，stdout/stderr empty。
- 从 `214add6b` archive 到 `/tmp` 的隔离副本运行 `canonical-core`：exit 0，stdout exact `PASS canonical-core\n`，stderr empty。
- 同一副本运行 `concurrent-core`：exit 0，stdout exact `PASS concurrent-core\n`，stderr empty。
- 合法 escaped surrogate pair 探针被正确接受；BMP/non-BMP key 排序探针复现 I1。
- 静态检查与测试过程均未读取真实 AOSP，也未运行 envsetup/build/sync/download 等 AOSP 命令。
