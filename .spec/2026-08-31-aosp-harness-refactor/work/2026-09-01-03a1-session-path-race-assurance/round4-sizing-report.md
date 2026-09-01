# 03a1 anchor-first round4 prototype report

## Verdict

**PASS** — provider structure now has unconditional precedence whenever the provider file exists. Missing or duplicate anchors fail closed before either `--dependency-absent` or core-availability routing. Structurally intact core-unavailable fixtures still take the inert branch. The executable prototype remains **280/400 lines**, leaving **120 lines**, and still runs the round3 19-case anchor-only matrix.

All round4 artifacts are confined to `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a1-session-path-race-assurance/`; no production or repository test file changed.

## Dispatcher order

`round4-session-path-races.prototype.sh:45-59` implements the order mechanically:

1. If the provider file exists, count `HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN`, `HARNESS_TEST_MARKER_EXPECTED_EUID`, and `HARNESS_TEST_MARKER_OS_ERROR`; each must equal one.
2. Any count failure emits `FAIL provider anchors: expected each exactly once`, returns 1, and prints no success summary.
3. Only after structure passes may `--dependency-absent` or a failed isolated `core_available` probe enter the shared inert oracle.
4. A genuinely absent provider has no text to validate and continues to the same inert oracle.

The Python dynamic driver retains its second-line defense at lines 158–171: each copied provider is checked for three unique markers, exactly one selected marker-bearing line is replaced, the resulting copy must equal the reconstructed expected text byte for byte, and marker counts remain one. `source.replace(original, replacement)` is still the only replacement call in the 280-line file; no ordinary provider needle or catch sentinel is replaced.

## Required eight damaged combinations

The missing/duplicate probe modifies the MANAGED marker as a representative. The production validator loops over all three marker strings identically, so EXPECTED_EUID or OS_ERROR damage follows the same branch.

| Marker damage | Dependency shape | Entry | rc | stdout | stderr | cases | Success summary |
|---|---|---|---:|---:|---:|---:|---|
| missing | foundation physically missing | default | 1 | 0 B | 50 B | 0 | no |
| missing | foundation physically missing | flag | 1 | 0 B | 50 B | 0 | no |
| missing | foundation present, core unavailable | default | 1 | 0 B | 50 B | 0 | no |
| missing | foundation present, core unavailable | flag | 1 | 0 B | 50 B | 0 | no |
| duplicate | foundation physically missing | default | 1 | 0 B | 50 B | 0 | no |
| duplicate | foundation physically missing | flag | 1 | 0 B | 50 B | 0 | no |
| duplicate | foundation present, core unavailable | default | 1 | 0 B | 50 B | 0 | no |
| duplicate | foundation present, core unavailable | flag | 1 | 0 B | 50 B | 0 | no |

All eight results prove that neither an explicit rollback flag nor an unavailable core can mask a damaged provider.

## Structurally intact inert controls

The exact corresponding controls all returned rc 0, exact 41-byte stdout `RESULT PASS  session path race assurance\n`, empty stderr, and zero dynamic cases:

| Dependency shape | Default | `--dependency-absent` |
|---|---:|---:|
| provider intact, foundation physically missing | PASS | PASS |
| provider intact, foundation present but core unavailable | PASS | PASS |

The previously established real-provider-absent default/flag controls also remain PASS with the same exact stream and zero cases. With full dependencies, the explicit flag remains inert PASS with zero cases.

## Dynamic and only-anchor regression

Full-dependency default execution remained rc 0, exact 41-byte stdout, empty stderr, with **19 total and 19 unique** dynamic cases. It retains:

- root/project/session × safe-dir/link/file swaps;
- distributed EEXIST safe/unsafe/disappearing cases whose `after_eexist` checkpoint proves catch;
- mkdir replacement, wrong EUID, real `os.mkdir` failure, post-mkdir/open/final-stat disappearance, and layer-independent EIO;
- exact `layer/name/phase/made/catch` hook signatures;
- symlink `readlink` target, original/victim/replacement signatures, scoped inventory, and provider-before/after hash checks.

The implementation provider SHA remained `07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`, and the implementation worktree status stayed empty.

## Pinned tools and sizing

```text
bash -n: rc=0
shfmt --version: v3.14.0
shfmt -d -i 2 -ci -bn round4-session-path-races.prototype.sh: rc=0, stdout/stderr 0 bytes
ShellCheck version field: 0.11.0
shellcheck -x --severity=warning round4-session-path-races.prototype.sh: rc=0, stdout/stderr 0 bytes
formatted prototype: 280 lines
headroom to immutable limit: 120 lines
```

Round4 spends ten lines to close precedence while preserving the same remaining 18 data rows needed for the complete 37-case matrix. The current shared helpers make a projection below 110 added lines credible: about 18 data rows, under 20 lines to parameterize wrong-EUID/replacement assertions, and roughly 70 lines for shared non-swap signature/inventory strengthening, active self-disproofs, category accounting, and final dispatcher/root calculation. With **120 lines** now remaining, the projection is credible but tight; implementation must stay data-driven and return to PLAN rather than remove an oracle if the full file exceeds 400. This is **not BLOCKED** on current execution-backed evidence.
