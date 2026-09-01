# 03 foundation requirements review round 1

Status: NEEDS_CHANGES

Findings: blocker 2, important 3, minor 1.

- B1: add the PLAN-required private `_harness_session_state_run path` cross-slice contract beside the private facade.
- B2: replace a multi-name `declare -F` false-positive oracle with a per-function loop and exact marker-unset check.
- I1: define HARNESS/XDG/TMP unset/empty/safe/missing/dangerous truth table.
- I2: freeze all foundation stdout/stderr/LF and `0|1|2` behavior.
- I3: use one executable package/manifest snippet with consistent variables.
- M1: mark sizing/manifest requirements as PLAN-derived.

Mechanical evidence: check-req, check-criteria, check-analyze and git diff checks passed before semantic fixes.
