# 2026-09-01-00a-seed-contract-runtime

结论：成立并已合入 `main`。

交付内容：

- `seed-contract-runtime/v1` marker 与 stable Python API。
- 唯一 `feature-closure` dispatcher、`verify-seed` direct recovery ABI。
- closed seed/evidence/terminal schema、RFC 8785 + domain SHA-256。
- no-follow state confinement、immutable object store、locked atomic ref 与 fault recovery。
- active/accepted ledger candidate 驱动的 descendant wrapper + `revert -m 1` rollback oracle。

Git 证据：accepted delivery merge `f9ead254b70c39532a276e8aa63a537d4cac7af6`；main merge `431286513b940c0b6645724cf879f93815e7e0f4`。

验收证据：[acceptance.md](../work/2026-09-01-00a-seed-contract-runtime/acceptance.md)、[task-3.2-review-r3.md](../work/2026-09-01-00a-seed-contract-runtime/task-3.2-review-r3.md)、[ledger.md](../specs/2026-09-01-00a-seed-contract-runtime/ledger.md)。

适用边界：00a 只证明契约和持久化机制；不读取真实 AOSP、不运行 envsetup/lunch/build/sync/download。真实 local/public source evidence 由 00b 负责。同 UID 在单次 invocation 中主动 rename/move/delete 已验证目录拓扑仍是明确排除项。
