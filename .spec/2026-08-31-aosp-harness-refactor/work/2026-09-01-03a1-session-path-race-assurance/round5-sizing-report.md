# 03a1 round5 shared-oracle prototype report

## Verdict

**PASS, credible but extremely tight** — the round5 prototype is pinned-shfmt-clean at **351/400 lines**, leaving **49 lines**. It keeps round4's anchor-first dispatcher and strict only-anchor injection, runs the same 19 unique dynamic cases, and now routes all nine attack families through a shared before/after inventory, complete object-signature, allowed-delta, and ordered-hook oracle. Four active self-disproofs execute on every normal run and are required in exact order.

The remaining 18 matrix rows can credibly fit because they reuse existing family helpers and schemas, but there is little tolerance for duplicated bodies. This evidence is **not BLOCKED**; implementation must return to PLAN if the projected compact data rows do not close the complete 37-case gate within 400.

## Artifacts and boundary

- Runnable: `round5-session-path-races.prototype.sh`
- Raw summary: `round5-evidence.log`
- Source fixed point: 03a implementation HEAD `f91f54d3d9832c803097bf171e9628b8d1adedab`
- Production provider SHA before/after: `07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`, equal.
- Implementation worktree status after all executions: empty.

Only `.spec/.../work/2026-09-01-03a1-session-path-race-assurance/` contains round5 changes. This remains throwaway execution-backed sizing evidence, not production code.

## Shared scoped inventory and complete signature

`signature()` at prototype lines 141–146 records every object's:

```text
lstat type, st_dev, st_ino, exact mode, uid, symlink readlink target, regular-file SHA-256
```

`inventory()` at lines 149–156 walks the case-scoped fixture without following links and maps every relative path to that signature. `exercise()` at lines 226–236 always takes the full inventory immediately before the real provider-copy child and again immediately after it; there is no family-specific bypass.

Therefore at least one actual representative from each requested family executes the complete shared oracle:

| Family | Executed representative | Expected delta shape |
|---|---|---|
| swap | root/project/session × safe-dir/link/file | old and old/victim added, original victim path removed, target changed under type/identity/readlink predicate |
| wrong-euid | project | no path or signature delta; all before signatures protected |
| EEXIST | safe root / unsafe project / disappearing session | exact safe additions / unsafe winner addition / no surviving delta |
| mkdir-replacement | root | replacement and `.old` added under exact mode/type predicates |
| mkdir-failure | project | no delta; all existing signatures protected |
| post-mkdir disappearance | session | no surviving delta; all existing signatures protected |
| open disappearance | root | exact target removal, all other signatures protected |
| final-stat disappearance | session | exact target removal, all other signatures protected |
| EIO | layer-independent | no delta; provider copy signature protected |

The nine swap cases retain explicit original/victim/replacement assertions in addition to the schema. Link replacements still require the exact `readlink()` target `<name>.old`.

## Shared allowed-delta schema

`delta_schema()` and `assert_delta()` at lines 159–175 implement the same five-field schema for every case:

- `paths_added`: exact set equality with `after - before`;
- `paths_removed`: exact set equality with `before - after`;
- `protected`: the complete before signatures for every path not declared removed or changed, all required byte-for-byte unchanged after execution;
- `allowed_changed_paths`: exact set equality with intersecting paths whose complete signatures changed;
- `predicates`: per-added/per-changed path checks such as safe EUID/0700 directory, unsafe 0755 winner, replacement type/distinct inode, or preserved moved-object signature.

This is an allowed-delta model, not a loose allowlist: unexpected additions/removals, a changed protected path, a missing declared change, an undeclared change, or a failed object predicate all reject the case.

## Ordered one-to-many hooks

`assert_hooks()` compares the actual list with the expected list, preserving count and order. Each normal one-hook family still supplies a one-element list. EEXIST supplies two elements and requires exact order:

```text
MANAGED|<layer>|<name>|before_mkdir|0|0
MANAGED|<layer>|<name>|after_eexist|0|1
```

This keeps `after_eexist` as direct evidence that the provider reached the `FileExistsError` catch, without replacing an ordinary catch sentinel.

## Active self-disproofs

Lines 335–345 derive probes from the real `swap-root-safe-dir` before/after/schema and `eexist-root-safe` hook results, then actively require four malformed oracles to throw:

1. mutate one protected complete signature;
2. add an unexpected inventory path;
3. remove the real changed target from `allowed_changed_paths`;
4. delete EEXIST's second hook while retaining the two-hook expectation.

`must_reject()` records each rejection. The dynamic run then requires the exact ordered list:

```text
protected signature, inventory, allowed delta, EEXIST second hook
```

If any shared oracle becomes permissive or any self-disproof stops executing, the prototype fails before its PASS summary.

## Preserved round4 gates

- Full default: rc 0, exact 41-byte stdout, empty stderr, 19 total/unique dynamic cases.
- Full-dependency `--dependency-absent`: rc 0, exact summary, zero cases.
- Real provider absent default/flag: both inert PASS, zero cases.
- Structurally intact provider with foundation physically missing or present-but-core-unavailable, default/flag: all four inert PASS, zero cases.
- Marker missing/duplicate × foundation missing/core unavailable × default/flag: all eight fail closed with rc 1, stdout 0, zero cases, and no success summary.
- Provider anchor validation still precedes flag/core routing; provider copies still use the single marker-bearing-line replacement call only.

## Pinned tools and final size

```text
bash -n: rc=0
shfmt --version: v3.14.0
shfmt -d -i 2 -ci -bn round5-session-path-races.prototype.sh: rc=0, stdout/stderr 0 bytes
ShellCheck version field: 0.11.0
shellcheck -x --severity=warning round5-session-path-races.prototype.sh: rc=0, stdout/stderr 0 bytes
formatted prototype: 351 lines
headroom: 49 lines
```

## Projection from 19 to 37 cases

The 18 missing rows remain the same: two wrong-EUID, six EEXIST, two mkdir-replacement, and two each for mkdir failure, post-mkdir disappearance, open disappearance, and final-stat disappearance.

The current generic functions already accept arbitrary layers for every family except the single inline wrong-EUID setup. A credible production expansion is:

- six missing EEXIST calls: 6 lines;
- ten missing `managed_case` calls: 10 lines;
- factor wrong-EUID into a helper and add root/session: at most 10 lines;
- exact nine-family/37-ID category accounting: about 5 lines.

Projected addition is approximately **31 lines**, producing about **382/400** and retaining roughly 18 lines of buffer. Shared inventory, full signatures, allowed-delta predicates, ordered hooks, anchor-first rollback, and all four active self-disproofs are already paid for in the 351-line measurement. The projection is credible only with data rows and shared helpers; duplicated per-layer oracle bodies are not acceptable.
