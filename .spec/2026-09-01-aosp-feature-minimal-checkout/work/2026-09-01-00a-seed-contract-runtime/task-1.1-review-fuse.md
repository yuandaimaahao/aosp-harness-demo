# Task 1.1 熔断定点修复独立验证

## 结论

**PASS**

审查范围严格固定为 `b7ed7abbd1f40b7c8048e6da03cac597b16678b2..b9d61b7ae681b56a8b2c1caea833ebf165988d16`。R3 I1 已完整关闭；本轮 diff 未对已经通过的 canonical parser/digest、错误 carrier 或 Python call-shape 行为引入直接相关的正确性回归。

Finding count：Blocker 0，Important 0，Minor 0。

## Standards

PASS。diff 只修改任务指定的 runtime 与测试文件；未发现违反 `common/AGENTS.md`、`common/.harness/common.md` 或适用 smell baseline 的本轮 finding。

## Spec

### Blocker

无。

### Important

无。

### Minor

无。

## R3 I1 关闭证据

- `common/.harness/closure/v1/lib/seed_contract_runtime.py:23-25` 在调用 `.encode()` 前以 exact `str` 与 ASCII predicate 校验 `domain_ascii`；非法成功绑定值统一抛 `ContractError("ARGUMENT_ERROR")`。因此具备 `encode()` 的 faux object 不再被接受，`encode()` 会抛 `RuntimeError` 的 exploding object 也不再泄漏异常。
- `common/tests/test_seed_contract_runtime.py:27` 新增 faux/exploding 两个回归用例，均逐字断言 `ARGUMENT_ERROR`。
- `ContractError.__init__(code: str) -> None`、`canonical_bytes(*, value: object) -> bytes`、`domain_digest(*, domain_ascii: str, value: object) -> str`、`load_artifact(*, path: str, expected_kind: str) -> dict` 均具备 brief 固定的参数与返回注解；测试在第 28 行逐项锁定 annotations。
- 独立 exact-head 探针结果为 `faux ARGUMENT_ERROR`、`exploding ARGUMENT_ERROR`、`unicode ARGUMENT_ERROR`、`PASS r3-exact-probe`。同一探针确认 positional、missing 与 unknown-keyword call-shape 仍分别由解释器抛原生 `TypeError`。

## 回归核验

- exact target `b9d61b7…` 的 `canonical-core`：exit 0，stdout exact `PASS canonical-core\n`，stderr empty。
- exact target 的 `concurrent-core`：exit 0，stdout exact `PASS concurrent-core\n`，stderr empty；内部覆盖 20 个隔离子进程。
- base/target 差分语料覆盖 canonical values、合法 ASCII domain（含 NUL/control ASCII）及既有非法 domain（`None`、integer、bytes、non-ASCII string），结果为 `PASS unchanged-valid-and-existing-invalid-domain-corpus`；只有 R3 指定的 faux/exploding 行为发生预期变化。
- 合法 digest 保持精确值：`domain_digest(domain_ascii="test/v1\0", value={"a":1}) == 2d21cc60dc9e027fc3f9fe7ff983098acde637fff210e3d92a58ac956b47dd07`。
- `git diff --check BASE..HEAD`：exit 0，stdout/stderr empty。

## 范围与安全

- `git merge-base BASE HEAD` 精确为 `b7ed7abbd1f40b7c8048e6da03cac597b16678b2`；区间仅 1 个 commit：`b9d61b7 fix(harness): enforce domain digest contract`。
- immutable diff 仅含两个指定文件，共 9 insertions / 9 deletions；没有范围外实现变化。
- 已完整读取 task brief、R3 finding、immutable exact fix diff、task report，以及适用仓库规则。
- 所有动态验证均从 exact target commit 的 `git archive` 隔离副本执行；未读取真实 AOSP，未运行 `envsetup`、`lunch`、build、sync、download、fetch 或 clone。
