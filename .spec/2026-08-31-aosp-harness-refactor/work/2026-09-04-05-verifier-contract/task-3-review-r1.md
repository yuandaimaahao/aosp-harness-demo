# Task 3 diff review r1 — verifier contract document

## Verdict

**FAIL** — B=0, I=1, M=0.

Review scope is task 3 only: `75221708e444bdff` adds exactly one 67-line file,
`docs/verifier-contract.md`.  This review inspected the supplied brief, task
report, review package, and the resulting provider/test source for contract
cross-checking.  It did not rerun validations already recorded in the task
report.

## R -> E compliance

| Requirement | Evidence | Result | Finding |
|---|---|---|---|
| R8: a single `docs/verifier-contract.md` contract is added | Review-package diff adds only `docs/verifier-contract.md` (67 insertions); report records byte-for-byte prototype parity and `wc -l = 67`. | ✅ | — |
| R8: CLI priority is defined | The opening states standalone-only `--help`, parser rejection phase, a real-mode `--allow-skip` phase, serial phase, rc 2/zero-query preflight, and the serial regex.  However, its `then real --allow-skip` fragment has no rejection predicate, so it does not unambiguously state the required real-mode rejection and ordering. | ❌ | I1 |
| R8: all six exact separated argv are defined | “Query transport” lists boot, system-server, btime, crash, service, and package argv in order, including `adb -s SERIAL`, and states that btime is omitted with `--since`.  Cross-check agrees with the six/five query arrays in the provider. | ✅ | — |
| R8: private runner protocol and trust boundary are defined | Document specifies absolute/EUID-owned/executable/regular/non-symlink validation; `QUERY_KEY --` followed by argv; stdout/stderr/rc handling; all six keys; direct fallback; and the 06/09 trust boundary. | ✅ | — |
| R8: complete R4 table plus bytes/LF/CR rules are defined | “Five assertions” gives all five grammars and Empty/Absent/Malformed/Satisfied outcomes; adjacent prose fixes byte input, LF splitting, single trailing-CR removal, scalar trimming, and token separators.  Cross-check agrees with `lines()` and evaluator branches. | ✅ | — |
| R8: twelve demo fixtures are defined | “Output and demo” enumerates six `*_QUERY_FAIL` and six value fixtures, gives defaults, and states values are data rather than shell code. | ✅ | — |
| R8: five fixed-order details/prefixes, summary, terminal/rc mapping, and exploration limit are defined | Document fixes order `boot, system_server, crash, service, package`, the three detail prefixes, summary sum=5, all four terminal cases/rcs, demo-only skip allowance, and excludes exploratory PASS from strict delivery evidence. | ✅ | — |
| R8: pre-implementation runnable exact3 core gate, real R7 execution, and churn cap | Task report records the prior red phase, three prototype parity checks, base-contract exact success, BASE..HEAD exact-three scope, and numstat `202 + 67 + 102 = 371 <= 400`; those are report evidence, not re-executed here by review instruction. | ✅ | — |
| R8: no forbidden implementation/scope expansion | Task increment contains only the required documentation file.  No old verifier, 05a source, or 06/07/09 implementation is in its diff. | ✅ | — |

## Document-quality review

### Completeness and source-of-truth role

The document has a clear title plus the three necessary sections: transport,
five assertions, and output/demo.  The opening paragraph carries the CLI
contract; together the sections cover the R8-listed subjects except that the
real-mode `--allow-skip` rejection is ambiguous (I1).  Apart from that gap, the
contract is consistent with the provider inspected at the task head and does
not rely on unstated implementation behavior.

### Three sampled claims, traced to source

| Sampled claim | Document location | Source cross-check | Result |
|---|---|---|---|
| Default real execution makes six separated queries and explicit `--since` omits btime | lines 9–16 | Provider query arrays and `if not baseline_ok` branch | ✅ |
| Runner receives `key -- adb -s serial ...`, captures stdout, inherits stderr, and normalizes signals | lines 20–26 | Provider `query()` command construction and `subprocess.run()` return handling | ✅ |
| A package list with syntactically valid but absent target is SKIP, while malformed records are FAIL | lines 36–39 | Provider package `records` evaluator | ✅ |

### Fact, inference, and normative-language check

The document is a contract, so its normative wording (“requires”, “must”, and
the result table) is appropriate.  Its factual implementation descriptions
were sampled against the provider and matched.  The report separately labels
commands and results; it does not use an expected result as if it were an
observed result.  No unsupported inference was found.

### Scope check

The documentation includes the 06/09 relationship only to state the mandated
private-seam trust boundary.  It introduces no runtime, adapter, legacy
fallback, 05a source, old-entrypoint, or unrelated-file change.  Scope is
therefore compliant.

## Findings

### Important

- **I1 — Real-mode `--allow-skip` rejection is not stated unambiguously.**
  `docs/verifier-contract.md:5` says the parser rejects the initial error
  class “then real `--allow-skip`; then” serial validation.  The middle phrase
  lacks a verb and does not say that real mode *rejects* that flag.  R1 fixes
  this precedence as: parse errors, then rejection of real
  `--allow-skip`, then serial validation; R8 requires that CLI priority to be
  in the single document contract.  The implementation's `if allow and not
  demo` correctly rejects it, but a document consumer cannot obtain that
  requirement from the document alone.  Amend the sentence to state the
  rejection explicitly (and retain rc 2/zero-query behavior).

### Blocking

None.

### Minor

None.
