# task-2.4 report: 04a 顺序门与终交付审计

Status: DONE

Commits: 无（只读审计；implementation 源码、index、HEAD 均未改变）

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.4-red.txt

## RED 与 implementation 基线

- `test -s "$WORK/acceptance/acceptance-report.md"` 在报告物理缺席时返回 rc `1`；RED 证据为 214 B，SHA-256 `47cbcc58740d12d8ec7e3631dcc82cc954794038505146eaa95c3b5186684eca`。
- 审计前后 implementation HEAD 均为 accepted HEAD `f7cfcb202d1fd2934d07cc90e333a4205b563243`；`git status --porcelain=v1` 为 0 B，working tree/index diff 均为空。
- EXEC_BASE 为 `692d52d00b56df9609760aa33a6f9aa3c38095a3`；本任务没有 source delta 或 commit。

## NEXT 五类物理缺席门

在未启用 `nullglob` 的独立 `bash -e` 子 shell 中逐字定义 `NEXT=04a-runtime-resource-lease-assurance` 与三态 helper：`rg` rc0 表示命中并失败，rc1 是唯一允许的未匹配，rc>1 表示工具/I/O 失败并失败；没有使用裸 `! rg`。

| capture | 字节数 | 记录数/判据 | 结果 |
|---|---:|---:|---|
| `evidence/task-2.4-next-specs.txt` | 0 | 顶层 `*-$NEXT` spec 目录 0 | PASS |
| `evidence/task-2.4-next-work.txt` | 0 | 顶层 `*-$NEXT` work 目录 0 | PASS |
| `evidence/task-2.4-next-refs.txt` | 642 | 日期前缀规范 spec ref 的 `rg` rc1 | PASS |
| `evidence/task-2.4-next-worktrees.txt` | 2902 | 日期前缀规范 branch/path 的 `rg` rc1 | PASS |
| `evidence/task-2.4-next-records.txt` | 4655 | 正向非空 27 条；逐文件 `rg -qF` 均 rc1 | PASS |

records 清单只由 `$PROJECT/specs` 下 depth-2 `ledger.md` 与 `$PROJECT/work` 下 `dispatch.tsv` / `execution-base.env` 组成；没有搜索 PLAN、requirements、design、tasks 中合法的 NEXT 规划文字。由此证明 04a 真实 spec/ref/worktree/ledger execution BASE/dispatch record 全部缺席。

## 固定工具、exact3 与 candidate

- 固定 `/tmp/aosp-harness-tools-04/shfmt --version` 逐字为 `v3.14.0`；ShellCheck `version:` field 逐字为 `0.11.0`。
- 只对 provider 与 base test 运行 `shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`、`bash -n`，全部 rc0 且无 diff/诊断。
- `EXEC_BASE..ACCEPTED_HEAD` name-only 恰为 `common/.harness/lib/resource-leases.sh`、`docs/resource-leases.md`、`tests/test-resource-leases.sh`；numstat 为 `336+7+57=400/400`。三文件逐字等于 approved prototype；`git diff --check` 通过；最终 assurance 入口物理缺席。
- 独立重跑 candidate default/all 均 rc0、stdout 29 B 且 SHA-256 为 `91cc39b0d798a121e52ca21cb7aa42970725c9afa25229a4b99d782cf79a821b`、stderr 0 B；逐字摘要为 `RESULT PASS  resource leases\n`。
- `all extra`、`unknown`、`--x value` 均 rc1、双流 0 B、无 PASS；base matrix 随 default/all 实际执行并覆盖 public surface/framing、重入、自重叠、异 owner 占用、不相交、stale、非法 request/stored state、tombstone、恶意 worker 收敛及完整 inventory。
- 独立重跑 `bash ./scripts/check.sh --offline` rc0、stderr 0 B，本入口固定摘要恰出现 1 次，末行为 `RESULT PASS  aosp-harness offline quality gate`。

## checkout、rollback 与 manifest 交叉核验

- candidate 证据：`evidence/task-2.1-{default,all}.{out,err}`、`task-2.1-invalid.log`、`task-2.1-offline.log` 与 `task-2.1-package.tsv` 均通过内容/摘要复核。
- full/depth-1 证据：四份 default 双流与两份 offline log 通过复核；full/depth-1 HEAD 均绑定 accepted HEAD，depth-1 `commits=1` 且 `.git/shallow` 非空，见 `evidence/task-2.2-package.tsv`。
- rollback 证据：隔离 commit `f8d815829c90619926ab08fa90d7a386993de89a` exact 删除三文件，相对 EXEC_BASE zero diff；03e 生命周期摘要恰 1、lease 摘要 0、offline `RESULT FAIL` 0，见 `evidence/task-2.3-*`。
- `review-manifest.tsv` 保持 controller 指定的已审六行：六列、reviewer 非空、全 PASS、从 EXEC_BASE 连续绑定至 accepted HEAD。未追加 task-2.4 第七行，也未运行七行 awk；这两步由 controller 在本独立 review PASS 后执行。

## 终结论

`resource-leases-v1` 在 accepted HEAD 上通过 R10 的 candidate/full/depth-1/rollback、固定工具、exact3/400、default/all/invalid/base matrix 与 04a 顺序门。implementation HEAD/index/worktree 未变且 clean；task 2.4 zero-source-delta。

顾虑: 无。按 controller 边界未 review/ledger/manifest/mark，未创建任何后序 04a 资产；controller 可据本 PASS 完成第七行与 ledger/accept 流程。

测试摘要: candidate default/all/offline、3 个 invalid、6 个固定 shell 静态检查、exact3/400、full/depth-1/rollback 证据复核及 NEXT 五类门全部 PASS。
