Status: DONE
红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-3.1-red.txt
Commits: 8c55b7bc83183b69a01ed30bb54151e17b1516ad
Head: 8c55b7bc83183b69a01ed30bb54151e17b1516ad
Tests: `PYTHONDONTWRITEBYTECODE=1 bash common/tests/test-seed-contract-runtime.sh --case cli` — exit 0; stdout exact `RESULT PASS seed-contract-runtime\n`; stderr empty. `PYTHONDONTWRITEBYTECODE=1 python3 common/tests/test_seed_contract_runtime.py canonical-core evidence-schema seed-schema terminal-golden state-paths store-object ref-resolve ref-publish cli` — all nine PASS. `PYTHONDONTWRITEBYTECODE=1 bash common/tests/test-harness.sh` — last line exact `RESULT PASS  shared Harness regression suite`; `PYTHONDONTWRITEBYTECODE=1 bash common/.harness/bin/check-parity.sh` — stdout exact `PARITY PASS  Claude/Codex 共享同一公共契约`; `PYTHONDONTWRITEBYTECODE=1 bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo` — last line exact `RESULT PASS`; `git diff --check 6953c19e73a5edc500fcc2f26a1ef94474b9a1cf..HEAD` — PASS.
Lines: 79 additions / 1 deletion across exactly five files; additions limit 80.
Files: common/.harness/bin/feature-closure; common/.harness/closure/v1/commands.d/verify-seed; common/.harness/closure/v1/runtime/seed-contract-runtime.version; common/tests/test-seed-contract-runtime.sh; common/tests/test_seed_contract_runtime.py.
Modes: 0755/0755/0644/0755 (dispatcher/direct/marker/shell acceptance).
Concerns: none.
