# Task 1.1 独立 diff review（R1）

## 结论

**FAIL**

审查范围为 `c959efaf9887808621852aff28073cf1f8789ca7..67db369556ab8754da67d28159ba45bd44bf1853`。精确 diff 为 2 个新增文件、65 行新增；`git diff --check` 通过，且未改动 AOSP 源码。新增测试单次运行输出 `PASS canonical-core`，但不能据此接受本变更，原因如下。

## Blocker

### B1. 唯一获准的 review 包缺少 requirements/design/task/context，无法完成规格、范围及行预算验收

指定输入 `review-c959efaf-67db3695.md` 共 97 行，只包含 commit 列表、diff stat 和 diff；没有 requirements、design、task、context，也没有行预算或允许/禁止范围。因审查指令明确限定该文件为唯一审查输入，当前无法证明实现满足规格、65 行是否在预算内、或新增 API/行为是否完整且无 scope creep。

可执行修复：重新生成不可变 review 包，纳入本任务完整 requirements/design/task/context、明确行预算和 scope/no-AOSP 约束，并保留同一精确 `BASE..HEAD` diff；随后重新执行独立 review。不要仅以可变工作区中的外部 spec 代替 review 包内容。

## Important

### I1. `canonical_bytes` 接受非 JSON 值，导致不同输入得到相同字节/摘要，并可能泄漏原生异常

位置：`common/.harness/closure/v1/lib/seed_contract_runtime.py:17-27`。

`_guard` 明确接受 `tuple`，并递归校验但不限制 `dict` 的 key 必须是字符串。随后 `json.dumps` 会把整数 key 转成字符串、把 tuple 转成数组。因此：

- `{1: "v"}` 与 `{"1": "v"}` 都产生 `b'{"1":"v"}'`，`domain_digest` 也相同；
- `(1, 2)` 与 `[1, 2]` 都产生 `b'[1,2]'`，摘要也相同；
- `{1: "a", "1": "b"}` 在 `sort_keys=True` 下直接泄漏 `TypeError`，没有转换成 `ContractError("DESCRIPTOR_SCHEMA_INVALID")`。

这与模块声明的 “Canonical JSON primitives” 不符，并破坏公共 canonical/digest API 对已接受值的确定、无歧义错误契约。

可执行修复：只接受 JSON 数据模型（数组只允许 `list`；对象 key 必须为无 surrogate 的 `str`），在调用 `json.dumps` 前拒绝 tuple 和所有非字符串 key，并为上述三个用例补充回归测试，统一断言 `DESCRIPTOR_SCHEMA_INVALID`。

### I2. 新测试使用固定的源码树临时文件，测试不隔离且可并发失败

位置：`common/tests/test_seed_contract_runtime.py:18-21`。

测试把中间数据固定写到 `common/tests/test_seed_contract_runtime.json`，两轮覆写后再删除。20 个相同测试以 8 路并发在隔离副本运行时，出现了真实失败：有进程读到其他进程的 payload，得到错误的 `DUPLICATE_JSON_KEY`，也有进程因文件被其他进程删除而得到 `DESCRIPTOR_NOT_FOUND`。该测试还会在中途断言失败时把生成物留在源码树。

可执行修复：使用 `tempfile.TemporaryDirectory()` 或每次调用唯一命名的临时文件，并以 context manager / `finally` 保证清理；增加至少一次并发或隔离性验证，确保测试可被并行 runner 安全执行。

## Minor

无。

## 验证记录

- SHA 解析和 commit 列表与 review 包一致；`git diff --numstat` 为 `41 + 24 = 65` 行新增。
- `git diff --check c959efaf..67db3695`：通过。
- `PYTHONDONTWRITEBYTECODE=1 python3 common/tests/test_seed_contract_runtime.py canonical-core`：单次通过。
- 在 `/tmp` 隔离副本中并发运行同一测试：可复现多次 `AssertionError`，根因分别为共享文件被覆写或删除。
- 工作树在检查前后保持 clean；未运行任何 AOSP `envsetup`、`lunch`、build、sync 或 download 命令。
