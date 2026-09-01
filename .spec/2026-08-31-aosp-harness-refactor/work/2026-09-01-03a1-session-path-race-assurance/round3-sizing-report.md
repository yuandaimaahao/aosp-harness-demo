# 03a1 requirements round 1 — round3 anchor-only prototype report

## Verdict

**PASS** — a strictly three-anchor-only, execution-backed 03a1 driver is credible within the immutable single-file limit. The pinned-shfmt-clean prototype is **270/400 lines**, leaving **130 lines**. It ran 19 unique representative dynamic cases, all requested inert repository shapes, fail-closed anchor damage probes, syntax, pinned shfmt, and pinned ShellCheck without changing the implementation worktree.

This is throwaway sizing evidence, not production code. The prototype skill shaped it as an executable state-model probe, while the requested artifact boundary overrides that skill's usual HTML form: every action is visible through exact subprocess protocol, hook signatures, case IDs, filesystem signatures, and inventories.

## Artifacts and fixed point

- Runnable prototype: `round3-session-path-races.prototype.sh`
- Raw result summary: `round3-evidence.log`
- Provider source: implementation worktree HEAD `f91f54d3d9832c803097bf171e9628b8d1adedab`
- Provider SHA-256 before/after all runs: `07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`, equal.
- Implementation worktree status after all runs: 0 bytes.

No production module or repository test was modified. All new files are confined to `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a1-session-path-race-assurance/`.

## Strict only-anchor replacement model

The prototype reads the provider once, requires each production marker to occur exactly once, finds the unique marker-bearing line, and reconstructs the expected provider copy by replacing only that line. It then requires the actual copy to equal that reconstruction byte for byte and rechecks all three marker counts. There is no ordinary production-source needle replacement and no catch-sentinel replacement.

Each child uses exactly one of these anchors:

| Anchor | Recorded signature | Injection behavior |
|---|---|---|
| `HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN` | `MANAGED|layer|name|phase|made|catch` | Acts only when the plan's target layer/name and fixed phase/made state match. |
| `HARNESS_TEST_MARKER_EXPECTED_EUID` | `EXPECTED_EUID|layer|name|N/A|made|0` | Changes expected EUID only for the target layer/name; phase is explicitly N/A. |
| `HARNESS_TEST_MARKER_OS_ERROR` | `OS_ERROR|N/A|N/A|N/A|N/A|N/A` | Raises real `OSError(errno.EIO)` before the first fd operation and is explicitly layer-independent. |

The MANAGED hook implements the phase table without editing any other provider line:

- existing swaps: `before_open/made=0/catch=0`;
- EEXIST: `before_mkdir/made=0/catch=0`, then `after_eexist/made=0/catch=1`;
- mkdir-success replacement and post-mkdir disappearance: `before_open/made=1/catch=0`;
- mkdir failure: `before_mkdir/made=0/catch=0`, installing a real one-shot `os.mkdir` wrapper that raises `FileNotFoundError(ENOENT)`;
- open and final-stat disappearance: `before_open/made=0/catch=0`; final-stat installs a one-shot `os.stat` wrapper at the anchor and removes the name only when the later name-stat is reached.

`after_eexist` itself is the catch proof: production calls that checkpoint only from the `FileExistsError` catch. The hook log's exact `after_eexist|...|catch=1` line therefore replaces the round2 prototype's forbidden ordinary-source catch-sentinel edit.

Marker-missing and marker-duplicate provider fixtures both failed closed with rc 1, empty stdout, and no success summary. Unknown option, positional extra argument, and `--dependency-absent` with an extra argument also returned nonzero with no success summary.

## Executed 19-case matrix

Default execution returned rc 0, exact 41-byte stdout `RESULT PASS  session path race assurance\n`, empty stderr, 19 case-log rows, and 19 unique IDs.

- 9 swaps: `root/project/session × safe-dir/link/file`.
- 3 distributed EEXIST representatives: safe root winner (`0`), unsafe project winner (`2`), disappearing session winner (`1`).
- One representative each: root mkdir-success replacement, project wrong EUID, project mkdir failure, session post-mkdir disappearance, root open disappearance, session final-stat disappearance, and layer-independent real EIO.

Every swap preserved the original directory and victim type/dev/inode/mode/uid/content signature, proved replacement type and distinct inode, prohibited later traversal, and compared the exact allowed inventory. Link replacements additionally asserted the exact `os.readlink()` target (`<name>.old`), so symlink identity is not reduced to lstat metadata alone.

The remaining representative cases assert exact rc/stdout/stderr and exact anchor signature. The driver also verifies 19 total/unique case IDs and production-provider bytes at the end, so a dead call list cannot satisfy the prototype.

## Inert and absent matrix

All rows returned rc 0, exact 41-byte stdout, empty stderr, and zero dynamic cases:

| Repository shape | Default | `--dependency-absent` |
|---|---:|---:|
| dependencies fully present, explicit inert flag | N/A | PASS |
| provider present, foundation file physically absent | PASS | PASS |
| provider present, foundation file present but core capability unavailable | PASS | PASS |
| real provider file absent, foundation present | PASS | PASS |

The inert oracle unsets foundation/core/public functions and the provider marker, optionally sources only the provider, then requires core, all four public APIs, and the marker to remain absent. Capability detection uses a separate isolated shell; file presence alone cannot send a core-unavailable fixture into the dynamic driver.

## Fixed tools and size

```text
bash -n: rc=0
shfmt --version: v3.14.0
shfmt -d -i 2 -ci -bn round3-session-path-races.prototype.sh: rc=0, stdout/stderr 0 bytes
ShellCheck version field: 0.11.0
shellcheck -x --severity=warning round3-session-path-races.prototype.sh: rc=0, stdout/stderr 0 bytes
formatted prototype: 270 lines
headroom: 130 lines
```

## Projection to the complete 37-case delivery

The 19 executed cases leave 18 matrix rows:

- wrong EUID: root and session (`2`);
- EEXIST safe/unsafe/disappearing: six missing layer/category pairs (`6`);
- mkdir-success replacement: project and session (`2`);
- mkdir failure: root and session (`2`);
- post-mkdir disappearance: root and project (`2`);
- open disappearance: project and session (`2`);
- final-stat disappearance: root and project (`2`).

The remaining rows reuse existing `setup`, `managed_case`, `eexist`, exact protocol, hook-signature, signature, and inventory primitives. Mechanically, the missing calls require about 18 data rows; parameterizing the current single wrong-EUID block and layer-specific replacement assertions is expected to add under 20 lines. That leaves roughly 90 lines for strengthening the shared non-swap inventory/signature oracle, active self-disproofs, exact 37-case category accounting, and the production dispatcher/root calculation.

The projection is therefore credible but deliberately tight: the final implementation must stay data-driven and must not duplicate per-layer bodies. If the full R5 signature/inventory self-disproofs cannot be closed inside the remaining 130 lines, execution must return to PLAN rather than delete an oracle. On present evidence this is **not BLOCKED**.

## Boundary not answered by this prototype

The review's controller-order finding is a workflow-state contract, not a driver sizing question. This prototype does not simulate it. The authoritative requirements must keep the mechanical rule that the ledger records the accepted 03a1 HEAD plus all-PASS manifest before any 03b base/worktree/dispatch record; the controller must enforce that separately.
