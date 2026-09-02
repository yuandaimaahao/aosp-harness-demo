# Task 1.1 独立 diff review（R3）

## 结论

**FAIL**

审查范围严格固定为 `c959efaf9887808621852aff28073cf1f8789ca7..b7ed7abbd1f40b7c8048e6da03cac597b16678b2`。不可变 diff 只新增任务指定的两个文件，共 70 行；预算、文件范围和禁止 AOSP 操作约束均满足。前两轮报告的所有具体 findings 已关闭，但本轮发现一项新的 Important API 参数契约问题。

## Standards

未发现违反仓库 `common/AGENTS.md`、`common/.harness/common.md` 或适用 smell baseline 的独立 finding。

## Spec

### Blocker

无。

### Important

#### I1. `domain_digest` 未验证固定的 `domain_ascii: str` 参数类型，可接受非字符串或泄漏非契约异常

位置：`common/.harness/closure/v1/lib/seed_contract_runtime.py:23-26`。

Brief 第 66–75、273–288、685 行把接口固定为 `domain_digest(*, domain_ascii: str, value: object) -> str`，并要求成功绑定后的非法 value/type/combination 统一抛 `ContractError("ARGUMENT_ERROR")`。当前实现直接对任意对象调用 `.encode("ascii")`，只捕获 `AttributeError` 与 `UnicodeEncodeError`，因此：

- 带有 `encode()` 方法的非 `str` 对象会被接受并得到正常 digest；
- 非 `str` 对象的 `encode()` 若抛出其他异常，该异常会直接泄漏，而不是 `ContractError("ARGUMENT_ERROR")`。

隔离副本中的可执行探针结果：

```text
faux-domain-result fc87966a57c4b48b17645b8d9f55f43ae131a3606bede105e834e13d010a9673
exploding-domain-error RuntimeError unexpected
```

同一探针还显示公开签名缺少 brief 固定的类型/返回注解：`domain_digest (*, domain_ascii, value)`，而不是声明的 `(*, domain_ascii: str, value: object) -> str`；其余本任务公开 callable 同样省略了声明注解。

可执行修复：在编码前明确验证 `domain_ascii` 为规格允许的 `str`，非法类型统一抛 `ContractError("ARGUMENT_ERROR")`；补充一个可返回 bytes 的伪 `encode` 对象和一个抛 `RuntimeError` 的伪对象回归用例；同时把本任务所有公开 callable 的类型/返回注解补齐为 brief 的固定签名。保留 positional/unknown/missing call-shape 的原生 `TypeError`。

### Minor

无。

## 前两轮 findings 复核

- R1 B1 **closed**：本轮完整读取了 705 行 task brief、104 行 immutable exact diff package、两轮旧报告及 task report，规格、范围与 70 行预算可复核。
- R1 I1 **closed**：tuple、非字符串 key 和混合 key 均返回 `DESCRIPTOR_SCHEMA_INVALID`。
- R1 I2 **closed**：测试改用 `TemporaryDirectory()`；20 个子进程的 `concurrent-core` 隔离验证通过。
- R2 I1 **closed**：非 ASCII object key 在 canonical/digest 两条路径均返回 `DESCRIPTOR_SCHEMA_INVALID`，实现保持设计限定的 ASCII-key safe subset。
- R2 I2 **closed for the reported cases**：`load_artifact(path=None, ...)`、非字符串 `expected_kind` 均为 `ARGUMENT_ERROR`，`ContractError(7).code` 为 `ARGUMENT_ERROR`；本轮 I1 是此前未枚举的 `domain_digest` 参数缺口。

## 验证记录

- `git rev-parse`：base/head 均精确解析；merge-base 为指定 base；提交链共 3 个 commit，与不可变包一致。
- `git diff --name-status BASE..HEAD`：仅新增 `seed_contract_runtime.py` 与 `test_seed_contract_runtime.py`。
- `git diff --numstat BASE..HEAD -- common`：`36 + 34 = 70` 行新增，满足 task 上限。
- `git diff --check BASE..HEAD`：exit 0，stdout/stderr empty。
- 从 exact head `git archive` 到 `/tmp` 隔离副本运行 `canonical-core`：exit 0，stdout exact `PASS canonical-core\n`，stderr empty。
- 同一隔离副本运行 `concurrent-core`：exit 0，stdout exact `PASS concurrent-core\n`，stderr empty。
- 合法 escaped surrogate pair 被接受；raw lone surrogate bytes 返回 `DESCRIPTOR_INVALID_UTF8`；三项 stable callable 的 positional call-shape 均保留原生 `TypeError`。
- 未读取真实 AOSP 源码，未运行 envsetup、lunch、build、sync、fetch、clone 或 download。

Finding count：Blocker 0，Important 1，Minor 0。
