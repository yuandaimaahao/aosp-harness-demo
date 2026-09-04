# task-2.1 report: 审计 candidate 并提出 accepted HEAD

Status: DONE

Commits: 无（本任务为只读 candidate 审计，implementation HEAD 未改变）

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.1-red.txt

## 范围与结论

- implementation worktree: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/worktree`
- EXEC_BASE: `692d52d00b56df9609760aa33a6f9aa3c38095a3`
- 审计前 HEAD: `f7cfcb202d1fd2934d07cc90e333a4205b563243`
- 审计后 HEAD: `f7cfcb202d1fd2934d07cc90e333a4205b563243`
- accepted-head 候选: `f7cfcb202d1fd2934d07cc90e333a4205b563243`
- implementation 源码 delta: `0`；本任务未修改源码、index、HEAD 或 commit。
- implementation clean: 审计前后 `git status --porcelain=v1` 均为 0 行。
- 审计结果: 全部要求通过，无源码 finding。

## RED

`test -s "$WORK/task-2.1-report.md"` 在报告物理缺席时返回 rc `1`；`report_exists=no`。RED 证据 SHA-256 为 `ce02ef89bd6aed7c67f1d578537ff3498908df6b93f429c4eb19c830d19fec3a`（437 B），并同时记录 candidate HEAD 与 clean 状态。

## 固定工具与静态门

- `/tmp/aosp-harness-tools-04/shfmt --version` → rc0，stdout 逐字 `v3.14.0`。
- `/tmp/aosp-harness-tools-04/shellcheck --version` → rc0，version field 逐字 `0.11.0`。
- 只对 `common/.harness/lib/resource-leases.sh` 与 `tests/test-resource-leases.sh` 分别运行：
  - `/tmp/aosp-harness-tools-04/shfmt -d -i 2 -ci -bn <file>` → 两次均 rc0、无 diff。
  - `/tmp/aosp-harness-tools-04/shellcheck -x --severity=warning <file>` → 两次均 rc0、无诊断。
  - `bash -n <file>` → 两次均 rc0。
- provider 的 `HARNESS_RESOURCE_LEASE_TEST_SEAM` 计数为 1，base test 中计数为 0；provider 中 `HARNESS_SESSION_STATE_PROVIDER_VERSION` 计数为 0。
- 最终路径 `tests/test-resource-leases-assurance.sh` 物理缺席。
- 完整静态证据 SHA-256: `6ec4b2bec81da638b8eca956ef44680aada7d10e11daa4fb47b154fc3eef3014`（2590 B）。

## Prototype 与 execution diff

三个 final 文件分别与批准 prototype `cmp -s` rc0，逐字节相同：

| 文件 | 行数 | final/prototype SHA-256 |
|---|---:|---|
| `common/.harness/lib/resource-leases.sh` | 336 | `011d4804129420ff99b37115d8df0ebc605214fb3c1ecfc937cdbefb4ce746af` |
| `docs/resource-leases.md` | 7 | `f16ea8af762fc9dfc65b5d8e96c9c42db9b9253a1c64aae5703a6cc3f5963dea` |
| `tests/test-resource-leases.sh` | 57 | `d2f324a3f9ae0efef805a8cae7297d996bd7804e119b65e8cc922d69fa2a0983` |

总计 `336+7+57=400/400`。`git diff --name-only EXEC_BASE HEAD` exact 3 文件且仅为上述三路径；`git diff --numstat EXEC_BASE HEAD` 为 `336/0`、`7/0`、`57/0`，总和 400。`git diff --check EXEC_BASE HEAD` 与 working-tree `git diff --check` 均 rc0、无输出。

## 运行结果与哈希

- `bash ./tests/test-resource-leases.sh` → rc0；stdout 29 B，逐字 `RESULT PASS  resource leases\n`，SHA-256 `91cc39b0d798a121e52ca21cb7aa42970725c9afa25229a4b99d782cf79a821b`；stderr 0 B，SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
- `bash ./tests/test-resource-leases.sh all` → rc0；stdout/stderr 与 default 逐字相同。
- `bash ./tests/test-resource-leases.sh all extra`、`... unknown`、`... --x value` → 各 rc1；每例 stdout/stderr 均 0 B，双流 SHA-256 均为空流 hash `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`，成功摘要缺席。
- `bash ./scripts/check.sh --offline` → rc0、stderr 0 B；stdout 603 B，SHA-256 `2c58ffd67925744312239804178e80401c2376395528499ea1c7e2c756da7a2a`；`RESULT PASS  resource leases` 恰出现 1 次，末行逐字 `RESULT PASS  aosp-harness offline quality gate`。

default/all 的固定摘要证明 base test 已实际执行 source surface、33-byte token framing、逆序 request 同 token 完整重入、同 owner 换 session rc2、不同 owner 相交 rc3、不相交 bundle、dead-owner stale、空 request rc2、非法 stored request rc2、合法 tombstone 恢复、假 Python 收敛 rc2及最终 inventory allowlist。

## Evidence package

`evidence/task-2.1-package.tsv` 汇总每份证据的 rc/状态、SHA-256、字节数以及 exact3/400、diff-check、HEAD/clean/零 delta 结论；package SHA-256 为 `98e956b5caaee0dae94cbc1bacfb18873c4aaf8d3c8331f3bfd92a9c5d4adf68`（1133 B）。

## 顾虑

无。按本任务边界未执行独立 review，未修改 review manifest/ledger，未创建后续任务资产；accepted-head 候选待 controller 的独立 review PASS 后固定。

测试摘要: candidate default/all/offline、三个非法 argv、六个固定静态检查、prototype/exact3/400/diff-check/clean 全部 PASS。
