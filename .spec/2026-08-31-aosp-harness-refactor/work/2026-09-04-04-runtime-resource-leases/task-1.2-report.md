# Task 1.2 report

Status: DONE

BASE: `569bb221aca20451706b0a6399683a71255bd7d1`
HEAD/commit: `c226a238189fda96e7130cf5cedc9e1bdbe6f8fa` (`docs(harness): document resource lease protocol`)
唯一变更文件: `docs/resource-leases.md`

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.2-red.txt

RED 命令 `cmp -s docs/resource-leases.md "$SPEC/specs/2026-09-04-04-runtime-resource-leases/prototypes/docs/resource-leases.md"`（目标缺席，rc=2）；证据已保存。
GREEN 命令为 prototype `cmp`（rc=0）、`test "$(wc -l <docs/resource-leases.md)" = 7`（rc=0）及逐项 `rg -F` 协议检查（rc=0），完整日志见 `evidence/task-1.2-doc-check.log`。

协议检查覆盖两函数签名、四合法 domain/mode 对、android-instance-id 与 serial/CVD 排除、状态根/EUID 0700、owner/PID reuse/command-substitution 语义、规范 bytes/SHA-256、键级完全独占与重入、bundle 原子可见性、monotonic/stale、tombstone，以及固定 0/2/3 协议。

提交 numstat: `7 0 docs/resource-leases.md`；工作树 clean。文档与 approved prototype `cmp` 一致且恰 7 行。

Concerns: none.
