Status: DONE

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/evidence/task-1.3-red.txt

Commits:

- `6afe239296bf244c97087a92f7cbfdc6bbbf89b9` — `feat(harness): validate seed schema relations`
- `8c4bebb50845061a57f70abe8fbf8d402d74d231` — `fix(harness): close seed semantic validation`
- `7f2d97fee8705b658bea613ffda6f2f957042f53` — `fix(harness): harden seed reconstruction schema`
- `bf1b8facb9b4e16a4487f6f6643a0cbdecd71da9` — `fix(harness): reject sensitive remote query keys`
- `ac37b75f9ddda61b647632c72ad2f8fbc72f8a2d` — `fix(harness): normalize credential query keys`

HEAD: `ac37b75f9ddda61b647632c72ad2f8fbc72f8a2d`

Tests:

- `python3 -B common/tests/test_seed_contract_runtime.py evidence-schema seed-schema` — PASS (two exact PASS lines; stderr empty)
- `python3 -B common/tests/test_seed_contract_runtime.py canonical-core evidence-schema seed-schema` — PASS (three exact PASS lines; stderr empty)
- r1 semantic review probe — dirty false/0, dirty true/1, affected count greater than manifest count, host+digest, and credential URL all reject with `DESCRIPTOR_SCHEMA_INVALID`; malformed public `schema_version`/`kind` both return `False`.
- Fuse credential probe — independently exercises `fetch_url`, `review_url`, and `mirror_url`; separator-free uppercase and mixed-case `PRIVATETOKEN`, `OAUTHTOKEN`, `CLIENTSECRET`, `XAMZCREDENTIAL`, and `XAMZSIGNATURE` families all reject with `DESCRIPTOR_SCHEMA_INVALID`; userinfo rejects; legal `@` path, empty string, null, and `ref`/`author` query values accept.
- `bash common/tests/test-harness.sh` — PASS (final line `RESULT PASS  shared Harness regression suite`; stderr empty)
- `bash common/.harness/bin/check-parity.sh` — PASS (`PARITY PASS  Claude/Codex 共享同一公共契约`; stderr empty)
- `git diff --check` — exit 0, stdout/stderr empty

Lines: `5338e29d0acfc09eb12e6181bf72f9095a179044..HEAD` changes are 83 additions and 7 deletions across the two permitted runtime/test files; additions are within the task limit of 100.

Concerns: none.
