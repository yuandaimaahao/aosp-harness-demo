# Task 1.1 independent diff review — round 1

## Verdict

**FAIL**

- Blocking: 1
- Important: 0
- Minor: 0

审查范围为 `692d52d00b56df9609760aa33a6f9aa3c38095a3..23cb18918583a9e3c2f19e97e4f89382c86ef7d7`。已完整阅读 task brief、implementer report、完整 diff package 与 `07-review.md`。task brief 未提供单独的 `## R→E 映射` 或 E-ID，因此以下不虚构 E-ID，按 brief 中当前任务的 R1–R7 与逐项验收契约审查。

## Findings

### Blocking

1. **[R7] 协调锁的阻塞式获取绕过 monotonic deadline，`wait-seconds=0` 会等待并可在窗口外成功，锁不释放时则可无限挂住。**

   文件：`common/.harness/lib/resource-leases.sh:204`（同一无界 primitive 也见 release 的 `:259`）。

   `deadline` 虽在首次状态扫描前于第 200 行计算，但第 204 行调用 `fcntl.flock(lock_fd, fcntl.LOCK_EX)`，未使用 `LOCK_NB`，也没有任何受 deadline 约束的锁获取机制。deadline 只在锁已取得、扫描发现资源被占用并解锁后才于第 249 行检查。因此：

   - 协调锁被暂停的存活进程持有时，调用会在首次 bundle 尝试之前无限阻塞；
   - 即使锁最终在 deadline 之后释放，只要 bundle key 当时空闲，代码仍会走第 224–246 行发布并成功，而不会先检查 deadline；
   - 这直接违反 R7 的有界等待、`wait-seconds=0` 只立即尝试一次、窗口耗尽停止，以及设计测试策略所写“只保证 wait 有界且不卡死”。

   最小只读复现使用独立的 `/tmp` 0700 状态根和合法 android request：先由另一 Python 进程对该根的 `.lock` 持有 `LOCK_EX` 1.2 秒，再调用 `harness_lease_acquire review-session 0 request.tsv`。实测 acquire+release `rc=0`，耗时 `1235ms`，stdout 为 33-byte token+LF，stderr 为 0B；也就是 wait=0 在窗口外成功。把锁持续持有并对调用施加 1 秒外层 timeout，实测 `rc=124`、耗时 `1003ms`、双流空，证明调用自身没有界限。

   修复需使协调锁获取本身进入 monotonic 有界状态机（例如 `LOCK_NB` + deadline-aware 重试），并保证 deadline 到达时的最后一次无 sleep 尝试覆盖锁获取与 bundle 检查，而不是只覆盖拿到锁之后的资源冲突循环。还需明确/保持无法安全读取状态时的 fail-closed 协议。由于交付物要求与 prototype 逐字一致且 336 行预算固定，修复还必须同步回流获批 prototype/预算，而不能只让 task 文件偏离 prototype。

### Important

无。

### Minor

无。

## ① 规格符合性

| Requirement | 结论 | 审查依据 |
|---|---|---|
| R1 | ✅ | source 仅产生两个 `harness_*` public API；未定义四个 session API，未设置 session provider marker，未 source 03 模块。 |
| R2 | ✅ | request 以普通文件读取；三列、domain/mode、workspace strict realpath/control-byte、android safe component 均在 publish 前校验。 |
| R3 | ✅ | request 按 byte key 排序、拒绝重复 key、SHA-256；单个 JSON bundle 以 `.tmp-* -> active-*` rename 发布，无逐键部分可见状态。 |
| R4 | ✅ | owner/session/hash/request 的完整重入返回原 token；同 owner 非完整重叠 fail closed；异 owner 重叠标记 occupied；facade 收敛成功输出。 |
| R5 | ✅ | 参数、request、owner、root/lock/record、worker rc/输出形状等错误均被捕获并收敛为固定 rc2 协议；未发布临时记录不作为 active 解析。 |
| R6 | ✅ | release 在全记录严格解码、自洽检查、token 唯一匹配及 owner 匹配后，以 `active-* -> .trash-*` 单次 rename 先 unpublish，再 unlink。 |
| R7 | ❌ | 第 204 行阻塞式 flock 不受第 200 行 deadline 约束；已复现 wait=0 延迟成功和无自限阻塞。见 Blocking finding 1。 |

因此规格结论为 **FAIL**。

## ② 质量审查

- **YAGNI / scope**：通过。BASE..HEAD 仅新增 `common/.harness/lib/resource-leases.sh`，未修改 02/03/CI/check.sh，未新增 04a assurance 文件或后续资产。
- **验证真实性**：RED 与提交事实相符：BASE 中目标路径缺席、prototype 存在，`cmp` 因目标缺席为 rc2；GREEN 证据中的 prototype hash、336 行、固定工具版本与结果均可复核。不存在空断言或恒真断言迹象。现有 task 1.1 静态门没有覆盖协调锁被占用的 deadline 行为，因而未捕获 Blocking finding 1。
- **逐字复制**：目标文件与批准 prototype SHA-256 均为 `d7c0015fde97e55accbad5e31634b295749ae2c0e25b343c402337dbeb7af1fa`，`cmp` 为 0；没有额外复制范围。唯一 seam anchor 计数为 1。
- **错误路径**：参数、规范化、状态解码、publish/unpublish、capture 校验与 rollback 路径整体有显式收敛；协调锁等待缺少有界错误/超时路径，是本轮唯一发现的承重缺陷。

因此质量结论为 **FAIL**。

## Mechanical verification

- HEAD：`23cb18918583a9e3c2f19e97e4f89382c86ef7d7`；其唯一 parent 为指定 BASE。
- commit count：1；subject：`feat(harness): add resource lease runtime`。
- name-only：仅 `common/.harness/lib/resource-leases.sh`。
- numstat：`336  0  common/.harness/lib/resource-leases.sh`；文件为 336 行，符合 core 总预算中本文件的 `336/400` 配额。
- prototype：逐字相同，双方 SHA-256 如上。
- 固定工具：shfmt `v3.14.0` diff 空、ShellCheck version field `0.11.0` warning 级通过、`bash -n` 通过、`git diff --check` 通过。
- source surface：排序后仅 `harness_lease_acquire`、`harness_lease_release`；session marker absent；source 静默；seam 恰一处。
- RED：BASE 对象中目标文件不存在；证据记录 rc2 且空 stdout/stderr hash 与事实一致。
- implementation worktree：`git status --porcelain=v1` 为 0B，clean。

