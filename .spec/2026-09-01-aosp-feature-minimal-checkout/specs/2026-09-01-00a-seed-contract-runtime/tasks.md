# 2026-09-01-00a-seed-contract-runtime 实现计划

十个任务均为必需、严格串行；每个 task commit 只含本任务源码变化。High estimate 为 70/75/100/55/65/80/80/75/80/45 non-generated lines，总计 725；任一调整使 high >730 时，在实现开始前返回 PLAN。

## Schema 与稳定 identity

### 任务 1.1: 建立 canonical parser 与 domain digest

文件: 创建 `common/.harness/closure/v1/lib/seed_contract_runtime.py` / 创建 `common/tests/test_seed_contract_runtime.py`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-1.1-red.txt`
消费: 无
产出: canonical-core/v1 capability
需求: R3, R4, R12, R17, R18
必需: 是
状态: 完成

接口明细：`ContractError(code: str)`；`RUNTIME_ABI == "seed-contract-runtime/v1"`；`load_artifact(*, path: str, expected_kind: str) -> dict`；`canonical_bytes(*, value: object) -> bytes`；`domain_digest(*, domain_ascii: str, value: object) -> str`。

- [ ] 步骤 1: 写 `canonical-core` case，覆盖 duplicate key、safe integer 四边界、escaped/raw lone surrogate、合法 Unicode 与 object-key reorder。
- [ ] 步骤 2: 跑 `python3 common/tests/test_seed_contract_runtime.py canonical-core`，确认失败且原因为 runtime/API missing。
- [ ] 步骤 3: 将步骤 2 的完整 command/exit/stdout/stderr 写入 task-1.1-red.txt。
- [ ] 步骤 4: 最小实现 parser、recursive scalar guard、RFC 8785 safe subset、error carrier 与 digest primitive。
- [ ] 步骤 5: 跑 `python3 common/tests/test_seed_contract_runtime.py canonical-core`，确认 exit 0、stdout exact `PASS canonical-core`、stderr empty。
- [ ] 步骤 6: 跑 `git diff --check`，确认 exit 0、stdout/stderr empty。
- [ ] 步骤 7: 只提交本任务两个源码文件，实际增量必须 ≤70。

### 任务 1.2: 闭合 request 与三类 evidence schema

文件: 修改 `common/.harness/closure/v1/lib/seed_contract_runtime.py` / 修改 `common/tests/test_seed_contract_runtime.py`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-1.2-red.txt`
消费: canonical-core/v1 capability
产出: evidence-validation/v1 capability
需求: R3, R4, R12, R17, R18
必需: 是
状态: 完成

接口明细：`seed_request|source_state|trace|command_journal` exact-key/type/nullability/order validators 与 request/project/workspace/trace/journal domain dispatch。

- [ ] 步骤 1: 写 `evidence-schema` case，逐字段覆盖四 kinds、sorted/semantic arrays、base64、enum、signed/unsigned safe bounds 与 domain digest。
- [ ] 步骤 2: 跑 `python3 common/tests/test_seed_contract_runtime.py evidence-schema`，确认失败且原因为 evidence validators missing。
- [ ] 步骤 3: 将步骤 2 的完整 command/exit/stdout/stderr 写入 task-1.2-red.txt。
- [ ] 步骤 4: 最小实现四类 closed validator 与对应 domain dispatch。
- [ ] 步骤 5: 跑 `python3 common/tests/test_seed_contract_runtime.py canonical-core evidence-schema`，确认 exit 0、stderr empty、stdout exact 两行 `PASS canonical-core`、`PASS evidence-schema`。
- [ ] 步骤 6: 只提交本任务两个文件变化，实际增量必须 ≤75。

### 任务 1.3: 实现 seed reconstruction、identity 与 public predicate

文件: 修改 `common/.harness/closure/v1/lib/seed_contract_runtime.py` / 修改 `common/tests/test_seed_contract_runtime.py`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-1.3-red.txt`
消费: evidence-validation/v1 capability
产出: seed-validation/v1 capability
需求: R3, R4, R10, R11, R12, R17, R18
必需: 是
状态: 完成

接口明细：seed request/content/identity reconstruction、success invariants、project relations 与 `_validate_public_real(payload, evidence)` pure seam。

- [ ] 步骤 1: 写 `seed-schema` case，逐字段 mutation seed/nested payload，覆盖 repeated-field relation、identity exclusions、success invariant、public fixture/local/vendor 与 evidence summary。
- [ ] 步骤 2: 跑 `python3 common/tests/test_seed_contract_runtime.py seed-schema`，确认失败且原因为 seed validator missing。
- [ ] 步骤 3: 将步骤 2 的完整 command/exit/stdout/stderr 写入 task-1.3-red.txt。
- [ ] 步骤 4: 最小实现 seed closed validator、三个 nested reconstruction/domain 与 pure public predicate。
- [ ] 步骤 5: 跑 `python3 common/tests/test_seed_contract_runtime.py evidence-schema seed-schema`，确认 exit 0、stderr empty、stdout exact 两行 `PASS evidence-schema`、`PASS seed-schema`。
- [ ] 步骤 6: 只提交本任务两个文件变化，实际增量必须 ≤100。

### 任务 1.4: 闭合 terminal report 与 fixture golden

文件: 修改 `common/.harness/closure/v1/lib/seed_contract_runtime.py` / 修改 `common/tests/test_seed_contract_runtime.py` / 创建 `common/tests/fixtures/aosp17-services/seed.golden.json`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-1.4-red.txt`
消费: canonical-core/v1 capability；seed-validation/v1 capability
产出: artifact-validation/v1 capability；schema-valid `fixture_only` positional golden
需求: R3, R4, R10, R11, R12, R17, R18
必需: 是
状态: 完成

接口明细：六 artifact/two internal-payload kind dispatch、terminal reason/order/completed-digest validator 与 canonical object bytes。

- [ ] 步骤 1: 写 `terminal-golden` case，覆盖 terminal exact schema/reason priority、golden digest、run-evidence mutation只改 artifact digest 与六-kind dispatch。
- [ ] 步骤 2: 跑 `python3 common/tests/test_seed_contract_runtime.py terminal-golden`，确认失败且原因为 terminal validator/golden missing。
- [ ] 步骤 3: 将步骤 2 的完整 command/exit/stdout/stderr 写入 task-1.4-red.txt。
- [ ] 步骤 4: 最小实现 terminal validator、all-kind dispatch 与 one-line golden。
- [ ] 步骤 5: 跑 `python3 common/tests/test_seed_contract_runtime.py seed-schema terminal-golden`，确认 exit 0、stderr empty、stdout exact 两行 `PASS seed-schema`、`PASS terminal-golden`。
- [ ] 步骤 6: 只提交本任务三文件变化，实际增量必须 ≤55。

## 安全 state 与 publication

### 任务 2.1: 实现 no-follow state path confinement

文件: 修改 `common/.harness/closure/v1/lib/seed_contract_runtime.py` / 修改 `common/tests/test_seed_contract_runtime.py`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-2.1-red.txt`
消费: artifact-validation/v1 capability
产出: state-paths/v1 capability
需求: R5, R6, R12, R17, R18
必需: 是
状态: 完成

接口明细：`validate_state_paths(*, state_dir: str, out_ref: str | None, artifact_store: str, forbidden_roots: tuple[str, ...]) -> StatePaths`，返回 runtime read-only MappingProxy。

- [ ] 步骤 1: 写 `state-paths` case，覆盖 tilde/relative/missing/unwritable/symlink/containment、missing leaf、exact store/out-ref derivation 与 immutable exact keys；稳定目录拓扑下 failure 验零越界 entry，同 UID hostile rename 排除项只验 fail closed 与 best-effort cleanup。
- [ ] 步骤 2: 跑 `python3 common/tests/test_seed_contract_runtime.py state-paths`，确认失败且原因为 StatePaths API missing。
- [ ] 步骤 3: 将步骤 2 的完整 command/exit/stdout/stderr 写入 task-2.1-red.txt。
- [ ] 步骤 4: 最小实现逐分量 directory-fd openat/mkdirat/O_NOFOLLOW、forbidden-root component containment 与可见拓扑变化的 fail-closed/best-effort cleanup；不宣称消除 DECISIONS 已排除的 post-mkdir hostile rename gap。
- [ ] 步骤 5: 跑 `python3 common/tests/test_seed_contract_runtime.py state-paths`，确认 exit 0、stdout exact `PASS state-paths`、stderr empty。
- [ ] 步骤 6: 只提交本任务两个文件变化，实际增量必须 ≤65。

### 任务 2.2: 实现 immutable object publisher

文件: 修改 `common/.harness/closure/v1/lib/seed_contract_runtime.py` / 修改 `common/tests/test_seed_contract_runtime.py`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-2.2-red.txt`
消费: state-paths/v1 capability；artifact-validation/v1 capability
产出: object-store/v1 capability
需求: R5, R6, R7, R9, R12, R15, R17, R18
必需: 是
状态: 完成

接口明细：`publish_object(*, state_dir: str, artifact_store: str, object_kind: str, payload: dict, forbidden_roots: tuple[str, ...], fault_point: str | None = None) -> ObjectResult`。

- [ ] 步骤 1: 写 `store-object` case，覆盖 same/different digest、0600 temp、file fsync、0444、link-no-replace、dir fsync、prelink/orphan faults 与 stale-temp non-consumption。
- [ ] 步骤 2: 跑 `python3 common/tests/test_seed_contract_runtime.py store-object`，确认失败且原因为 object publisher missing。
- [ ] 步骤 3: 将步骤 2 的完整 command/exit/stdout/stderr 写入 task-2.2-red.txt。
- [ ] 步骤 4: 最小实现 canonical object commit/collision/fault/cleanup state machine。
- [ ] 步骤 5: 跑 `python3 common/tests/test_seed_contract_runtime.py store-object`，确认 exit 0、stdout exact `PASS store-object`、stderr empty；该 PASS 必须内部断言 external sentinel delta=0 和 controlled temp count=0。
- [ ] 步骤 6: 只提交本任务两个文件变化，实际增量必须 ≤80。

### 任务 2.3: 实现 locked resolver 与 evidence closure

文件: 修改 `common/.harness/closure/v1/lib/seed_contract_runtime.py` / 修改 `common/tests/test_seed_contract_runtime.py`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-2.3-red.txt`
消费: state-paths/v1 capability；object-store/v1 capability；artifact-validation/v1 capability
产出: locked-resolver/v1 capability
需求: R5, R6, R8, R11, R12, R17, R18
必需: 是
状态: 完成

接口明细：`resolve_ref(*, state_dir: str, ref: str, artifact_store: str, forbidden_roots: tuple[str, ...], require_public_real: bool = False) -> dict`。

- [ ] 步骤 1: 写 `ref-resolve` case，覆盖 lock owner/mode/nofollow/contention、lock-before-observation、ref/object leaf errors、四-object closure、project/count/sequence/public relations。
- [ ] 步骤 2: 跑 `python3 common/tests/test_seed_contract_runtime.py ref-resolve`，确认失败且原因为 resolver missing。
- [ ] 步骤 3: 将步骤 2 的完整 command/exit/stdout/stderr 写入 task-2.3-red.txt。
- [ ] 步骤 4: 最小实现 lock/finally、持锁 resolver、closure/public gate 与 exact post-lock priority。
- [ ] 步骤 5: 跑 `python3 common/tests/test_seed_contract_runtime.py ref-resolve`，确认 exit 0、stdout exact `PASS ref-resolve`、stderr empty；该 PASS 必须内部断言 failure byte changes=0。
- [ ] 步骤 6: 只提交本任务两个文件变化，实际增量必须 ≤80。

### 任务 2.4: 实现 atomic ref publication

文件: 修改 `common/.harness/closure/v1/lib/seed_contract_runtime.py` / 修改 `common/tests/test_seed_contract_runtime.py`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-2.4-red.txt`
消费: locked-resolver/v1 capability；object-store/v1 capability
产出: stable-runtime/v1 complete API
需求: R5, R6, R7, R8, R9, R12, R15, R17, R18
必需: 是
状态: 完成

接口明细：`publish(*, state_dir: str, out_ref: str, artifact_store: str, object_kind: str, payload: dict, ref_kind: str, semantic_exit: int, forbidden_roots: tuple[str, ...], fault_point: str | None = None) -> PublishResult`。

- [ ] 步骤 1: 写 `ref-publish` case，覆盖 missing/existing ref、object-first/ref-second bytes、prelink/orphan/rename/fsync faults、replay与 dangling-ref invariant。
- [ ] 步骤 2: 跑 `python3 common/tests/test_seed_contract_runtime.py ref-publish`，确认失败且原因为 ref publisher missing。
- [ ] 步骤 3: 将步骤 2 的完整 command/exit/stdout/stderr 写入 task-2.4-red.txt。
- [ ] 步骤 4: 最小实现持锁 publish coordinator、atomic ref replace、durability codes 与 exact result。
- [ ] 步骤 5: 跑 `python3 common/tests/test_seed_contract_runtime.py ref-publish`，确认 exit 0、stdout exact `PASS ref-publish`、stderr empty；该 PASS 必须内部断言 dangling ref=0 和 controlled temp=0。
- [ ] 步骤 6: 只提交本任务两个文件变化，实际增量必须 ≤75。

## CLI、回归与 rollback

### 任务 3.1: 接通 dispatcher、direct recovery ABI 与 channels

文件: 创建 `common/.harness/bin/feature-closure` / 创建 `common/.harness/closure/v1/commands.d/verify-seed` / 创建 `common/.harness/closure/v1/runtime/seed-contract-runtime.version` / 创建 `common/tests/test-seed-contract-runtime.sh` / 修改 `common/tests/test_seed_contract_runtime.py`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-3.1-red.txt`
消费: stable-runtime/v1 complete API；schema-valid `fixture_only` positional golden
产出: closure-cli/v1 deliverable；main-acceptance-entry/v1
需求: R1, R2, R10, R11, R12, R13, R14, R17, R18
必需: 是
状态: 完成

接口明细：mode 0755 dispatcher/direct；marker exact `seed-contract-runtime/v1\n`；两组 positional/ref productions。

- [ ] 步骤 1: 写 `cli` case 与 shell route，覆盖 command target、runtime preamble、grammar、fixture/ref parity、mixed faults 与 binding-TypeError seam。
- [ ] 步骤 2: 跑 `bash common/tests/test-seed-contract-runtime.sh --case cli`，确认失败且原因为 dispatcher/direct/marker missing。
- [ ] 步骤 3: 将步骤 2 的完整 command/exit/stdout/stderr 写入 task-3.1-red.txt。
- [ ] 步骤 4: 最小实现 generic dispatcher、direct pre-import loader、CLI adapter、marker 与 shell route，并设置三个 executable mode 0755。
- [ ] 步骤 5: 跑 `bash common/tests/test-seed-contract-runtime.sh --case cli`，确认 exit 0、stdout exact `RESULT PASS seed-contract-runtime`、stderr empty。
- [ ] 步骤 6: 跑 `bash common/tests/test-harness.sh`，确认 exit 0、stderr empty、stdout 末行 exact `RESULT PASS  shared Harness regression suite`。
- [ ] 步骤 7: 只提交本任务五文件变化，实际增量必须 ≤80。

### 任务 3.2: 完成 named invariants、delivery 与 descendant rollback

文件: 修改 `common/tests/test-seed-contract-runtime.sh` / 修改 `common/tests/test_seed_contract_runtime.py`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-3.2-red.txt` / 验证 `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/ledger.md`
消费: closure-cli/v1 deliverable；main-acceptance-entry/v1
产出: `bash common/tests/test-seed-contract-runtime.sh` exact `RESULT PASS seed-contract-runtime`；四个 named invariant case；ledger merge-SHA 驱动的 isolated descendant-wrapper rollback oracle
需求: R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, R13, R14, R15, R16, R17, R18
必需: 是
状态: 完成
控制器失败规则：candidate gate 失败先追加同 SHA `status=superseded`，随后 task fix→new commit→fresh review→new merge；修复窗口 0 active 时 parser fail closed；禁止修补已审 merge。

- [ ] 步骤 1: 写 four named routes、`ledger-candidate` fold case 与 rollback route。
- [ ] 步骤 2: 以 cwd=task worktree root 跑 `bash common/tests/test-seed-contract-runtime.sh --case rollback --ledger /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/ledger.md`，确认现在失败、live ledger 存在、exit 非 0、stdout empty、stderr exact `ROLLBACK ERROR active delivery candidate unavailable`。
- [ ] 步骤 3: 将步骤 2 的完整 command/exit/stdout/stderr 写入 task-3.2-red.txt。
- [ ] 步骤 4: 最小实现 named aggregation、candidate fold、rollback topology 与 stdout suppression。
- [ ] 步骤 5: 跑 `python3 common/tests/test_seed_contract_runtime.py canonical-core evidence-schema seed-schema terminal-golden state-paths store-object ref-resolve ref-publish cli`，确认 exit 0、stderr empty、stdout 依序 exact 九行 `PASS canonical-core`、`PASS evidence-schema`、`PASS seed-schema`、`PASS terminal-golden`、`PASS state-paths`、`PASS store-object`、`PASS ref-resolve`、`PASS ref-publish`、`PASS cli`。
- [ ] 步骤 6: 跑 `bash common/tests/test-seed-contract-runtime.sh --case digest-immutability`，确认 exit 0、stdout exact `RESULT PASS seed-contract-runtime`、stderr empty。
- [ ] 步骤 7: 跑 `bash common/tests/test-seed-contract-runtime.sh --case path-confinement`，确认 exit 0、stdout exact `RESULT PASS seed-contract-runtime`、stderr empty。
- [ ] 步骤 8: 跑 `bash common/tests/test-seed-contract-runtime.sh --case failure-ref-rules`，确认 exit 0、stdout exact `RESULT PASS seed-contract-runtime`、stderr empty。
- [ ] 步骤 9: 跑 `bash common/tests/test-seed-contract-runtime.sh --case public-real-gate`，确认 exit 0、stdout exact `RESULT PASS seed-contract-runtime`、stderr empty。
- [ ] 步骤 10: 只提交本任务两文件变化，实际增量必须 ≤45。
- [ ] 步骤 11: 实现者按 execute 协议报告 `DONE`；不得写任务完成锚点。
- [ ] 步骤 12: 控制器运行 `review-package.sh` 生成 exact parent/task diff package。
- [ ] 步骤 13: 控制器派 fresh independent reviewer 并等待 PASS。
- [ ] 步骤 14: 控制器从 frozen base 与 reviewed task tip 创建 two-parent delivery merge。
- [ ] 步骤 15: 控制器运行 `git rev-list --parents -n 1 MERGE_SHA`，确认 stdout 有且仅有 commit+两个 parent、stderr empty。
- [ ] 步骤 16: 控制器向 live ledger 追加 `delivery-candidate sha=MERGE_SHA status=active`。
- [ ] 步骤 17: 跑 `python3 common/tests/test_seed_contract_runtime.py ledger-candidate --ledger /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/ledger.md`，确认 exit 0、stdout exact `PASS ledger-candidate active MERGE_SHA`、stderr empty。
- [ ] 步骤 18: 以 cwd=isolated delivery worktree root 跑 `bash common/tests/test-seed-contract-runtime.sh`，确认 exit 0、stdout exact `RESULT PASS seed-contract-runtime`、stderr empty。
- [ ] 步骤 19: 在同一 cwd 跑 `bash common/tests/test-seed-contract-runtime.sh --case digest-immutability`，确认 exit 0、stdout exact `RESULT PASS seed-contract-runtime`、stderr empty。
- [ ] 步骤 20: 在同一 cwd 跑 `bash common/tests/test-seed-contract-runtime.sh --case path-confinement`，确认 exit 0、stdout exact `RESULT PASS seed-contract-runtime`、stderr empty。
- [ ] 步骤 21: 在同一 cwd 跑 `bash common/tests/test-seed-contract-runtime.sh --case failure-ref-rules`，确认 exit 0、stdout exact `RESULT PASS seed-contract-runtime`、stderr empty。
- [ ] 步骤 22: 在同一 cwd 跑 `bash common/tests/test-seed-contract-runtime.sh --case public-real-gate`，确认 exit 0、stdout exact `RESULT PASS seed-contract-runtime`、stderr empty。
- [ ] 步骤 23: 在同一 cwd 跑 `bash common/tests/test-seed-contract-runtime.sh --case rollback --ledger /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/ledger.md`，确认 exit 0、stdout exact `RESULT PASS seed-contract-runtime`、stderr empty。
- [ ] 步骤 24: 在同一 cwd 跑 `bash common/tests/test-harness.sh`，确认 exit 0、stderr empty、stdout 末行 exact `RESULT PASS  shared Harness regression suite`。
- [ ] 步骤 25: 在同一 cwd 跑 `bash common/.harness/bin/check-parity.sh`，确认 exit 0、stderr empty、完整 stdout exact `PARITY PASS  Claude/Codex 共享同一公共契约`。
- [ ] 步骤 26: 在同一 cwd 跑 `bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo`，确认 exit 0/empty stderr/末行 exact `RESULT PASS`。
- [ ] 步骤 27: 控制器运行 `git diff --numstat FROZEN_BASE..TASK_TIP -- common`，确认 non-generated additions+deletions ≤730。
- [ ] 步骤 28: 控制器运行 `wc -l REVIEW_SUMMARY`，确认输出行数 ≤140。
- [ ] 步骤 29: 控制器向 live ledger 追加 `delivery-candidate sha=MERGE_SHA status=accepted`。
- [ ] 步骤 30: 重跑步骤 17 的 ledger-candidate 命令，确认 stdout exact `PASS ledger-candidate accepted MERGE_SHA`。
- [ ] 步骤 31: 控制器运行 `python3 /home/zzh0838/.agents/skills/spec/scripts/mark-task-done.py .spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/tasks.md 3.2` 标记任务完成。
- [ ] 步骤 32: 控制器运行 `python3 /home/zzh0838/.agents/skills/spec/scripts/sync-ledger.py .spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/ledger.md`，确认 exit 0。
