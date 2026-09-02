# 门⑤验收 — 2026-09-01-00a-seed-contract-runtime

日期：2026-09-02

## ① 判据执行结果

最终 accepted delivery merge：`f9ead254b70c39532a276e8aa63a537d4cac7af6`；parent1=`c959efaf9887808621852aff28073cf1f8789ca7`，parent2=`8d27769692481fc76919ce0f5ea6d7f8c5840479`。主干 merge：`431286513b940c0b6645724cf879f93815e7e0f4`。

在 accepted candidate 和真实 `main` 上本轮重新执行的原始输出：

```text
PASS ledger-candidate accepted f9ead254b70c39532a276e8aa63a537d4cac7af6
SEED ABI PASS
RESULT PASS seed-contract-runtime
RESULT PASS seed-contract-runtime  # digest-immutability
RESULT PASS seed-contract-runtime  # path-confinement
RESULT PASS seed-contract-runtime  # failure-ref-rules
RESULT PASS seed-contract-runtime  # public-real-gate
RESULT PASS seed-contract-runtime  # accepted-state descendant rollback
RESULT PASS  shared Harness regression suite
PARITY PASS  Claude/Codex 共享同一公共契约
PASS  sidebar service registered
PASS  sys.boot_completed = 1
PASS  system_server pid = 1423
RESULT PASS
CHECK_CONVERGE PASS
```

所有命令 exit 0，逐项输出与任务要求一致；测试入口未产生 stderr。`git diff --numstat` 为 631 additions / 0 deletions（631 ≤ 730）；最终 R3 review 57 行（57 ≤ 140）。`git diff --check`、`check-tasks.py`、`sync-ledger.py` 和 `check-converge.py` 均 exit 0。

Git 收口原始事实：主干分支为 `main`；`MERGE_HEAD`、`REBASE_HEAD`、`rebase-merge`、`rebase-apply`、`CHERRY_PICK_HEAD` 均不存在；开发 7 路径与主干本地 `.spec/` 路径交集为空；普通 merge 成功，`git merge-base --is-ancestor spec/aosp-minimal-00a-delivery-r2 main` 通过。已合入的 implementation/delivery worktree 与 branch 已删除；superseded 且未合入的旧 delivery branch `spec/aosp-minimal-00a-delivery` 保留审计。

## ② 逐条对照 requirements 与不变量

- R1–R2：dispatcher 唯一 ABI、ASCII command grammar、self-relative direct exec 和两个互斥 verify productions 由 task 3.1 CLI matrix 与真实 `SEED ABI PASS` 覆盖。
- R3–R4：八类 closed artifact/digest payload、duplicate/unknown/type/safe-integer/surrogate/array-order 与 RFC 8785/domain digest 由 tasks 1.1–1.4 的 canonical/evidence/seed/terminal matrix 覆盖。
- R5–R6：normalized absolute state/store/ref、no-follow/openat/mkdirat、forbidden-root containment 与稳定目录拓扑边界由 task 2.1 和 `path-confinement` 覆盖。
- R7：0444 immutable content-addressed object、hard-link no-replace、fsync、idempotence/collision 由 task 2.2 与 `digest-immutability` 覆盖。
- R8–R9：0600 adjacent lock、lock-before-observation、resolver/ref canonical bytes、atomic replace、durability-uncertain/orphan 由 tasks 2.3–2.4 与 `failure-ref-rules` 覆盖。
- R10–R11：fixture 全量重算、ref evidence closure、public-real pure predicate 与负例由 tasks 1.3、2.3、3.1 和 `public-real-gate` 覆盖；00a 未创建伪 real-source production ref。
- R12–R15：exact error priority、stdout/stderr/exit carrier、direct pre-import availability、四 publish fault point 与 temp cleanup 由 runtime/CLI/fault matrix 覆盖。
- R16：从 exact two-parent merge 创建 descendant recovery wrapper，再 `revert -m 1`；wrapper retained、00a runtime 消失、exact `RUNTIME_UNAVAILABLE` 和旧三回归在 active 与 accepted candidate 上均通过。
- R17：实际 non-generated common diff 631/730；最终 schema/test review 57/140。
- R18：实现、审查、验收均未运行 envsetup/lunch/build/package/flash/repo sync/fetch/clone，也未读取 `/home/zzh0838/Project/lk7k-a17/system`。
- 不变量 1：validation/collision 对 existing object/ref/sentinel 的 byte changes=0，`digest-immutability` PASS。
- 不变量 2：稳定目录拓扑下 path/symlink/containment 在 state-dir 外新增 entry=0，`path-confinement` PASS；同 UID 主动拓扑 mutation 保持已记录排除边界。
- 不变量 3：所有 publish fault 的 visible dangling ref=0，`failure-ref-rules` PASS。
- 不变量 4：failed success/evidence closure 被 public-real 接受数=0，`public-real-gate` PASS。
- 不变量 5：rollback 后 retained-wrapper/旧 harness regression failures=0，accepted-state `rollback` 与三项旧 harness oracle PASS。

## ③ 执行期裁定

ledger 没有字面 `裁定:` 行；以下搬运全部 `adjudication`、`fuse-adjudication` 或显式 `decision=` 记录。承重安全项列前，readability 挂账列后。

```text
- 06:33 adjudication task=2.1 class=tasks-wrong decision=exclude-same-uid-active-directory-topology-mutation scope=stable-topology-static-symlink+nonregular+containment+locked-publishers retained=detected-change-fail-closed+best-effort-cleanup if-wrong=same-uid-hostile-rename-can-move-runtime-created-directory-outside-declared-state-and-leave-unknown-name-residual
- 05:28 fuse-adjudication task=1.3 finding=credential-query-deny-coverage class=bearing decision=accept fix=case-insensitive-sensitive-key-policy+common-provider-probes if-wrong=credentials-may-be-persisted-in-canonical-seed-content-and-identity-artifacts
- 05:28 fuse-adjudication task=1.3 finding=credential-semantic-matrix class=bearing decision=accept fix=independent-private-oauth-client-secret-aws-negative-cases if-wrong=credential-regression-can-pass-seed-schema-gate
- 05:36 fuse-adjudication task=1.3 finding=credential-case-normalization class=bearing decision=accept fix=normalize-case-before-sensitive-token-match+uppercase-probes if-wrong=uppercase-or-separator-free-credential-keys-bypass-canonical-artifact-protection
- 09:21 fuse-adjudication task=2.4 finding=stale-fd-double-close-reuse-race class=bearing decision=accept fix=single-owner-fd-removal+reuse-probe if-wrong=finalizer-can-close-unrelated-fd-reused-by-concurrent-thread
- 03:50 fuse-adjudication task=1.1 finding=domain-digest-argument-type+public-signature-annotations class=bearing decision=accept fix=exact-str-validation+ARGUMENT_ERROR+declared-annotations+regression if-wrong=non-string-domain-may-forge-domain-separation-or-leak-runtime-error-and-downstream-ABI-introspection-may-diverge
- 04:38 fuse-adjudication task=1.2 finding=entry-kind-unhashable-carrier class=bearing decision=accept fix=type-before-enum-dispatch+independent-container-probes if-wrong=ordinary-invalid-descriptor-leaks-TypeError-and-wrapper-misreports-RUNTIME_INTERNAL
- 04:38 fuse-adjudication task=1.2 finding=shared-validator-envelope class=bearing decision=accept fix=exact-schema-envelope-in-shared-dispatch+direct-negative-probes if-wrong=in-memory-publisher-path-can-accept-schema-2-or-bool-and-publish-nonconforming-evidence
- 04:38 fuse-adjudication task=1.2 finding=per-field-matrix class=bearing decision=accept fix=independent-boundary-order-base64-enum-digest-rows if-wrong=uncovered-load-bearing-field-regressions-can-pass-task-gate
- 06:41 fuse-adjudication task=2.1 finding=missing-static-zero-outside-test class=bearing decision=accept fix=explicit-before-after-snapshot+sentinel-for-static-symlink-and-containment if-wrong=runtime-static-escape-regression-could-pass-state-paths-suite
- 07:28 fuse-adjudication task=2.2 finding=eexist-race-error-translation class=bearing decision=accept fix=translate-recheck-read-file-dir-fsync-errors+preserve-collision if-wrong=expected-race-durability-error-leaks-OSError-and-CLI-misreports-RUNTIME_INTERNAL
- 07:28 fuse-adjudication task=2.2 finding=exact-commit-matrix class=bearing decision=accept fix=mode-at-fsync+link-flags+collision-bytes+eexist-error-regressions if-wrong=commit-order-or-error-carrier-regression-can-pass-suite
- 08:26 fuse-adjudication task=2.3 finding=ref-schema-bool-as-int class=bearing decision=accept fix=exact-int-version-check+bool-regression if-wrong=malformed-ref-envelope-is-trusted-as-version-1
- 04:00 fix artifact=requirements reopen-round=1 action=accept-all decision=explicit-I-JSON-safe-supersession downstream=00b-05-fail-closed acceptance=numeric-surrogate+four-carrier-matrix
- 03:16 fuse-adjudication artifact=requirements action=accept-all public=success-invariants+four-object-closure errors=missing-ref+ref-leaf+lock-leaf-exact publisher=complete-envelope+prewrite-validation+domain-dispatch schema=remaining-leaves+relations temp=ref-locked-only+object-no-auto-clean confirmation=auto-true
- 05:38 fuse-adjudication artifact=tasks action=accept-all tasks=10 estimates=70+75+100+55+65+80+80+75+80+45=725 split=canonical/evidence/seed/terminal/path/object/resolver/publisher/cli/delivery actions=single-command-or-control red-ledger=absolute candidate=active/superseded/accepted
- 04:38 fuse-adjudication task=1.2 finding=compressed-names class=nonbearing decision=defer reason=hard-75-line-budget if-wrong=validator-priority-remains-harder-to-audit-but-mechanical-contract-tests-still-decide-correctness
```

执行期另有一次门⑤纠偏：旧 merge `6bd8fdda...` 在 candidate 转 accepted 后 rollback 不可重跑，因此被改为 superseded，task 3.2 重开并经 fresh R3 修复；没有把该失败候选当作最终交付。

## ④ 跳过的门禁

`STATE.md` 的 SKIPPED 表为空。未跳过独立 task diff review、candidate gate、accepted-state rollback、check-converge 或主干合入检查。真实 AOSP 验证属于 00b 范围，不是本片跳过项。

## ⑤ 挂账 findings

- task 1.2：runtime/test 的 compact names 与高密度单行控制流降低可读性；受 75 行硬预算约束，机械 contract tests 仍决定 correctness。
- task 3.1：direct loader/test 中 `take`、`r/c/o/e`、`d/m/u/x/p/f` 等短名降低局部可读性；非阻断 judgement call，未违反仓库标准。
- superseded audit branch `spec/aosp-minimal-00a-delivery` 保留，指向 `6bd8fddac2cc00d8b2a68d501750dec8eb4d7c1a`；它未合入 main。

## ⑥ 结论

建议验收通过。00a 的 shared runtime、CLI、schema/digest、path/store/ref、fault recovery 与 direct rollback ABI 已在 accepted candidate 和合入后的真实 `main` 上重复通过；预算、review summary、Git 拓扑、主干脏路径隔离和 no-AOSP 边界均满足。下一步进入 large-spec retro，再选择 00b。
