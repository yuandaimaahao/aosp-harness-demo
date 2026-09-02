Status: DONE

Commits:

- 67db369556ab8754da67d28159ba45bd44bf1853 `feat(harness): add canonical seed contract core`
- 214add6b6dd1555afbb977a0a8fcc76cf2d0ba3d `fix(harness): restrict canonical JSON inputs`
- b7ed7abbd1f40b7c8048e6da03cac597b16678b2 `fix(harness): validate canonical runtime arguments`
- b9d61b7ae681b56a8b2c1caea833ebf165988d16 `fix(harness): enforce domain digest contract` (HEAD)

Tests: `PYTHONDONTWRITEBYTECODE=1 python3 common/tests/test_seed_contract_runtime.py canonical-core` and `... concurrent-core` — both exit 0 with exact respective `PASS` stdout and empty stderr. R3 faux/exploding-encode, fixed-signature, and positional-call-shape probe — exit 0, stdout exact `PASS r3-probe`, stderr empty. `git diff --check c959efaf9887808621852aff28073cf1f8789ca7..HEAD` — exit 0, stdout/stderr empty.

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-1.1-red.txt` (runtime/API missing, exit 1).

Actual lines: 70 non-generated additions from task base `c959efaf9887808621852aff28073cf1f8789ca7` (35 runtime, 35 test), within the 70-line task limit.

Concerns: None.
