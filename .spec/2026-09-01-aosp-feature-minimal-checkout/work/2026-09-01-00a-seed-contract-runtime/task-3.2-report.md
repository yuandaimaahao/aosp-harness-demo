Status: DONE
红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-3.2-red.txt
Commits: 8d27769692481fc76919ce0f5ea6d7f8c5840479 (amended task commit)
Head: 8d27769692481fc76919ce0f5ea6d7f8c5840479
Tests: `PYTHONDONTWRITEBYTECODE=1 python3 common/tests/test_seed_contract_runtime.py canonical-core evidence-schema seed-schema terminal-golden state-paths store-object ref-resolve ref-publish cli` — nine ordered PASS lines, stderr empty. Four named routes (`digest-immutability` includes `ref-resolve`, `path-confinement`, `failure-ref-rules`, `public-real-gate`) and the main acceptance entry — exit 0, exact `RESULT PASS seed-contract-runtime\n`, stderr empty. Anchored temporary-ledger noise/multi-active/superseded fold probes, including `python3 -O`; fake-Python stderr/zero-exit; forced pre-registration worktree-add failure cleanup; type/symlink/newline predicates; and full descendant rollback from both temporary active and accepted candidates — PASS. `bash common/tests/test-harness.sh`, `bash common/.harness/bin/check-parity.sh`, and `bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo` — PASS; `git diff --check` — PASS.
Lines: 44 additions / 6 deletions across the two task files; additions limit 45.
Files: common/tests/test-seed-contract-runtime.sh; common/tests/test_seed_contract_runtime.py.
Concerns: The active and accepted rollback checks used a dangling synthetic merge and temporary ledger; no formal merge or live ledger candidate was created.
