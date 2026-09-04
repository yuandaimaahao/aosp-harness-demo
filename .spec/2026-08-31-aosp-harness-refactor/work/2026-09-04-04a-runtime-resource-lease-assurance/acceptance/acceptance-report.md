# 04a closeout — resource lease assurance v1

Accepted implementation is `3f17cf66c1a13296d77ed1f900109fc1feb633c6`; BASE is `ffb05899c33d04b4c3d1c6605b3d39b1e6a05204`. Task 4 independent review passed in round 2, the controller added and validated manifest row 4, and the final mechanical rerun below completed before this acceptance decision.

## 1. 判据执行结果

- Candidate, full-history clone, and real `file://` depth-1 clone each recorded default assurance rc 0 and offline rc 0; each offline run discovers the assurance summary exactly once. The shallow clone has commit count 1 and a nonempty shallow marker; because BASE is absent there, it is bound by candidate/prototype file hashes and blobs rather than querying BASE.
- The isolated rollback recorded the inverse provider `2/2` and assurance `0/396`, source diff empty against BASE, base resource-leases rc 0, 03e lifecycle rc 0, offline rc 0, zero assurance discoveries, and clean checkout.
- Task 2 records active default and `all` exact `RESULT PASS  resource lease assurance\n` stdout (38 bytes), empty stderr, and rc 0. Its internal CLI/physical-absent/damaged-provider matrix covers default/all/absent and six CLI forms; absent/inert PASS is explicitly not active evidence.
- Fixed tools are shfmt `v3.14.0`, ShellCheck `0.11.0` warning threshold, and `bash -n`, all rc 0 for the two delivery files. Lifecycle fake-mktemp/fake-rm faults close as rc 1 with empty stdout, dedicated stderr, and no PASS.
- The active assurance covers the deterministic final-flock route, request/root/self-overlap and stored-record fail-closed families, live holder/wait/barrier/adapter cases, helper/capture/closed-output/I/O faults, tombstone recovery, and four self-proving mutants. Task-2 review independently found B/I/M = 0/0/0.
- BASE..accepted HEAD is exactly two files: `common/.harness/lib/resource-leases.sh` `2/2` and `tests/test-resource-leases-assurance.sh` `396/0`: 398 added, 2 deleted, total churn 400. Docs and base lease test have no diff; `git diff --check` and recorded statuses are clean.

Controller final-rerun output from this closeout turn:

```text
check-tasks=PASS
check-req=PASS
check-criteria=PASS
check-analyze=PASS
check-design=PASS
check-converge=PASS
converge-temp-cleanup=PASS
manifest=PASS rows=4 continuity=PASS
candidate-identity-clean=PASS
RESULT PASS  resource lease assurance
default-assurance=PASS
RESULT PASS  resource leases
base-resource-leases=PASS
RESULT PASS  claude session lifecycle
claude-session-lifecycle=PASS
RESULT PASS  aosp-harness offline quality gate
offline=PASS assurance-discovery=1
fixed-static=PASS shfmt=3.14.0 shellcheck=0.11.0 bash-n=PASS
exact2=PASS churn=400 provider=2/2 assurance=396/0
next-gates=PASS spec=0 branch=0 worktree-rg=1 ledger-rg=1 execution-rg=1 dispatch-targets=0 dispatch-rg=1 nullglob=disabled
final-controller-verification=PASS
```

The first controller shfmt probe omitted the approved per-file formatting flags and therefore printed a read-only formatting diff; no file changed. It was an invalid invocation, not an accepted gate result. The exact reviewed commands (`-i 2 -ci -bn` for the provider and `-i 2 -ci` for assurance) were then rerun and returned 0 before the final result above.

After the unified ordinary publish fast-forwarded main, the merged tree was exercised again:

```text
RESULT PASS  resource lease assurance
post-merge-default=PASS
RESULT PASS  resource lease assurance
RESULT PASS  resource leases
RESULT PASS  session path race assurance
RESULT PASS  session path safety
RESULT PASS  session write interrupts
RESULT PASS  session snapshot assurance
RESULT PASS  session snapshot safety
RESULT PASS  session state foundation
RESULT PASS  session state
RESULT PASS  aosp-harness offline quality gate
post-merge-offline=PASS
post-merge-source-clean=PASS
```

## 2. R1–R10 与不变量逐条对照

| Item | Result / evidence |
|---|---|
| R1 | PASS evidence: task-1 source review and task-3 exact diff. Only the prescribed adjacent provider deadline branch split is present; API/state/docs/base test are unchanged. |
| R2 | PASS evidence: task-1 r3 and active monotonic oracle. Reached deadline continues to loop-head flock without sleep; acquired final lock reaches the existing deadline guard before recover/read/publish and returns rc 3. |
| R3 | PASS evidence: task-2 r1/report. CLI six forms, repo-contained ordinary provider route, three absent routes, and seven damaged-provider fail-closed surfaces are recorded. |
| R4 | PASS evidence: task-2 r1/report. Request/root/self-overlap matrix checks canonical keys, tokens, `0|2|3`, fixed streams, and final inventory. |
| R5 | PASS evidence: task-2 r1/report. Same/different mode live holders, bounded wait, reverse bundle barrier, and adapter aliases are exercised; no partial visible bundle or competing adapter command. |
| R6 | PASS evidence: task-2 r1/report. Duplicate/noncanonical/global-overlap/nonregular and record-field matrices fail closed; PID reuse reclaim yields a new releasable token. |
| R7 | PASS evidence: task-2 r1/report. Fake helper, capture/closed-output, root/lock identity and I/O fault cases close as rc 2; unpublish retains active and unlink/tombstone recovery clears state. |
| R8 | PASS evidence: task-2 static/lifecycle evidence and r1. External owned 0700 fixture checks, cleanup behavior, readiness handling, tracked hashes, three production mutants, and fake-adapter mutant self-prove. |
| R9 | PASS evidence: task-3 candidate/full/depth1 logs and r1 plus controller final rerun. Default/offline, fixed tools, exact2/400, shallow proof, diff-check, clean states, and the four-row continuous PASS manifest all pass. |
| R10 | PASS evidence: task-3 rollback log/r1 plus corrected task-4 next-gates log and controller rerun. Rollback regressions pass and assurance discovery is zero; 05 is physically absent. The zero dispatch-target count is separately recorded, then actual deterministic `rg` on non-symlink zero-byte `/dev/null` observed rc 1 under explicit temporary errexit capture; no inert result releases 05/06/08. |
| Invariant: public surface | PASS. Provider public API/state format, docs and base lease test have zero change; provider hunk and one seam are bound by task-1/task-3 evidence. |
| Invariant: deadline side effects | PASS. Final-flock monotonic case records two flock calls; deadline returns rc 3 before record read/stale recovery/publish, with empty final inventory. |
| Invariant: assurance isolation | PASS. Task-2 records external mktemp fixture checks and before/after hashes of tracked provider/docs/base test; mutant/fault work is on copies. |
| Invariant: prior gates | PASS. Candidate records base lease/03e/offline context; rollback explicitly reruns base lease, 03e lifecycle, and offline all rc 0. |

## 3. Ledger 裁定原文与错误代价

The following is every authoritative-ledger line beginning `裁定:` reproduced in full. The ledger itself states the decision basis and the cost of a wrong decision; no wording has been normalized.

- 裁定: 04a按PLAN v5.9从exact1纯assurance收窄为exact2相邻修复+assurance：provider只替换扫描后deadline分支两行，使到期立即continue并由下一轮既有锁后检查在读record/发布前rc3；assurance仍为398行，预期numstat `2/2+398/0=400 additions`，不改API/docs/base-test/状态格式 — 依据：隔离副本default/all/dependency-absent三路逐字PASS，原边界稳定FAIL且只有一次flock。若判断错误，代价是04a修改已验收provider；若不修，代价是已知final-attempt契约缺口被带入05/06/08且active assurance无法成立。证据：reviews/requirements-prototype-boundary.md。
- 裁定: round1全部finding按同一边界闭合：保留provider `2增2删`修复，把assurance从398压到fixed-shfmt396行并补七类damaged provider、三种真实absent入口、同owner异mode、tracked三文件hash/repo外fixture及mutant双流；四类自反证重命名为三类production mutant加一类fake-adapter fixture mutant，exact churn机械口径固定为`2+2+396=400` — 依据：修订prototype default/all/dependency-absent、shfmt/ShellCheck/bash-n全PASS。若判断错误，代价是压缩引入`&&`假绿或遗漏失败族；因此所有压缩链以显式`|| fail`收口，review round2必须逐项执行负向fixture与mutant。证据：reviews/requirements-prototype-boundary.md与prototypes/。
- 裁定: round2三项finding闭合且仍保持exact2/400：默认provider改由`repo=$here/..`派生并在父进程核repo内普通非symlink，absent surface清除override；全部承重fixture构造/改写/清理显式收口；三类production mutant核唯一anchor/预期替换/source健康和专属失败标签，unpublish真实破坏`os.replace(path, trash)`，adapter provider逐字不变 — 依据：fixed-shfmt assurance仍396行，default/all各真实运行完整active矩阵约30秒并逐字PASS，dependency-absent PASS，固定静态门全绿。若判断错误，代价是最后复审仍发现假绿并触发回PLAN；不得以摘要替代provider route与专属oracle证据。证据：reviews/requirements-prototype-boundary.md与round2报告。
- 裁定: round3两项均承重并采纳精确修法继续：顶层mktemp失败立即专属退出，创建后核repo外/EUID自有0700/普通空目录；失败trap核删除并可把cleanup失败改rc1，成功路径在摘要前删除且核物理缺席；holder/waiter/clock marker写失败立即让child非零并由父startup标签收口，adapter fixture改写失败立即专属退出。若判断错误，代价是cleanup残留仍可能伴随PASS或并发fixture错误仍被后序oracle掩盖；因此不再开启第4轮改写review，只允许同reviewer对最终artifact做只读熔断融合验证，未PASS不得放门②。证据：round3报告与reviews/requirements-prototype-boundary.md。
- 裁定: tasks round1两项均采纳最小修法：任务1 red/green按真实顶层布局复制provider/assurance/docs/base-test四文件并核repo外临时树前后边界；candidate/full保留BASE diff exact2/400，depth-1改用与prototype及candidate SHA记录逐文件一致性，不获取BASE以保持commit-count=1和shallow marker。若判断错误，代价是red错因或shallow验收临时决策重现；因此round2必须独立执行同构red与真实depth-1替代命令。证据：`reviews/tasks-04a-runtime-resource-lease-assurance-round-1.md`。
- 裁定: 任务1不改源码commit，只由原实现者补green原始stdout/stderr/命令rc并更新报告与package hash，再交原reviewer范围受限复审；若判断错误，代价是执行声明无法由reviewer绑定到原始证据，后续manifest形成假PASS。证据：`work/2026-09-04-04a-runtime-resource-lease-assurance/task-1-review-r1.md`。
- 裁定: 当前04a authoritative prototype实际SHA=`0bf21e8f9d29e5a87cdcc8e962ede20143ccbf49fcb742756923f519b327690b`且与green副本一致；仍由原实现者从绝对04a路径重跑，日志同时写source path/source SHA/copied path/copied SHA和cmp PASS，消除review输入歧义后进入round3。若判断错误，代价是把历史04 prototype或未知脚本当作当前保证；不改源码commit。证据：task-1-review-r2.md与controller `sha256sum`。
- 裁定: 任务4不改源码或候选HEAD，只由原实现者在独立`bash --noprofile --norc`、`set -e`且nullglob关闭环境重跑NEXT：先记录dispatch目标数0，再对`/dev/null`执行真实确定性no-input/no-match rg并显式捕获observed rc1；更新NEXT日志、task4/acceptance受影响措辞与全部hash/bytes，交原reviewer增量复审。若判断错误，代价是把未执行搜索伪装成05 dispatch缺席，提前解除R10顺序门。证据：`work/2026-09-04-04a-runtime-resource-lease-assurance/task-4-review-r1.md`。

## 4. 跳过门

- 无未补门禁。Task 4 本身作为零源码汇总没有重复三套 checkout，但其独立 review 已通过；controller 随后重跑了 candidate 主验证、04/03e 不变量、offline、固定静态、exact2/400、clean、converge、四行 manifest 与完整 NEXT 门。
- Full-history、真实 depth-1 和 rollback 使用本轮 task 3 的原始命令/rc/hash 证据及独立 review；controller 终验收再次核对这些证据与当前候选身份，没有用 inert PASS 替代 active 结果。

## 5. 挂账 findings

- 无挂账 source finding。Tasks 1–4 的最终独立 reviews 均为 PASS，B/I/M=0/0/0。
- Task 4 round 1 的唯一 B1 是 synthetic dispatch rc 证据；完整 NEXT 重跑改为 target count 0 加真实 `/dev/null` `rg` observed rc1，同 reviewer round 2 PASS，controller 终验收再次得到相同结果。
- 顺序门仍按契约关闭到本片正式发布完成：05 spec、同名分支、worktree、execution BASE 与 dispatch 均缺席，且没有创建 05/06/08 资产。

## 6. 结论

可以验收。R1–R10、四条不变量、candidate/full/depth-1/rollback、fixed tools、exact2/400、四行连续 PASS manifest、`check-converge.py`、clean 与 NEXT 五类缺席门均闭合；accepted implementation HEAD 为 `3f17cf66c1a13296d77ed1f900109fc1feb633c6`。本片未 push，也未提前创建 05/06/08 的真实资产。
