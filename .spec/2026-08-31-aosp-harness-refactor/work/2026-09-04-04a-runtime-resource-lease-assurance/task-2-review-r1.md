# Task 2 independent diff review r1

Verdict: **PASS**  
Findings: **B/I/M = 0/0/0**

## Scope and independent checks

- Read the complete task brief, implementer report, `3ab44a54..3f17cf66` diff package, evidence package manifest, and every manifest-listed evidence file.
- Worktree HEAD is `3f17cf66c1a13296d77ed1f900109fc1feb633c6`, clean. Task commit diff is exactly one added executable file, `tests/test-resource-leases-assurance.sh`, numstat `396/0`; execution-base diff is exactly provider `2/2` plus assurance `396/0` (total `400/400`). The provider hunk is the required adjacent deadline split/continue only.
- Candidate assurance exactly equals the required absolute prototype: SHA-256 `0bf21e8f9d29e5a87cdcc8e962ede20143ccbf49fcb742756923f519b327690b`, 24,945 bytes, 396 lines, and `cmp -s` succeeds.
- Every `task-2-package.tsv` byte count and SHA-256 matches the on-disk artifact. Static evidence and direct fixed-tool recheck agree: shfmt `v3.14.0` diff-free; ShellCheck `0.11.0 -S warning` clean; `bash -n` clean. ShellCheck info-only SC2015/SC2016/SC1091 notices are permitted by the brief/design's warning threshold and do not violate its fixed static gate.
- Diff semantics substantiate rather than merely report the R3--R8 matrix: six CLI shapes; physical absent/default/all/flag surfaces and seven damaged-provider cases; request/root/self-owner/state-record/PID cases; same/different mode holder, bounded waiter, two-line barrier and adapter isolation; helper/capture/closed-output/root-lock/I/O fault cases; deadline final-flock assertion; unpublish/tombstone recovery; and all three production plus fake-adapter mutant oracles with exclusive failure labels and PASS suppression.
- Evidence captures two complete active runs (default/all): rc 0, 38-byte exact summary SHA `0efda5495dd5fa42489228b3267f9adf88a97d038370adad9f9e17b386d30855`, empty stderr. It also records unchanged tracked provider/docs/base-test hashes and an external, owned, 0700 empty temporary directory followed by physical absence.
- Lifecycle evidence is closed: fake `mktemp` and fake `rm` both have rc 1, empty stdout, the required distinct 28-byte stderr, and no PASS. The named lifecycle root's current physical absence is expected: controller verified its exact prefix and moved it to system trash/recovery, so this review does not treat that absence as missing evidence.

## Conclusion

No correctness, invariant, or maintainability finding was identified within the supplied source-diff and evidence scope. The assurance addition is exact, bounded to the required file, and its static plus recorded runtime evidence closes the specified task contract without a third source file or residual worktree change.
