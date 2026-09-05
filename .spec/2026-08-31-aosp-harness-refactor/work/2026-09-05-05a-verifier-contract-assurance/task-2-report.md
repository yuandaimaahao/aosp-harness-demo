# Task 2 report

Status: DONE

红阶段证据: .spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/evidence/task-2-red.txt

## Scope

- Task 2 source delta: `BASE=HEAD=5f867fa8e5d1c5b79001d0ec201045139fa29a40`; no source file was modified or committed.
- Execution BASE: `1e3d297a7bc636d8ea2e7f4b7aa0dfbe4731fdf5`.
- ACCEPTED_HEAD: `5f867fa8e5d1c5b79001d0ec201045139fa29a40`.
- Fixed tools were taken only from `/home/zzh0838/.cache/aosp-harness-tools-04/bin`: shfmt `v3.14.0`, ShellCheck `0.11.0`.
- Full raw command, rc, and key stdout/stderr evidence is in `evidence/task-2-green.txt`.
- The independent diff review object is task 2's zero source delta plus its checkout evidence. Task 1 owns the accepted artifact's source diff and prior source review; task 2 verifies that artifact across candidate/full/depth-1.

## Candidate

- HEAD `5f867fa8e5d1c5b79001d0ec201045139fa29a40`; history count `239`; non-shallow.
- TARGET equals PROTO byte-for-byte; each SHA-256 is `88f3abcd3f99e252c10e1134b98ea63212584ebd37bc6dfac2f9dd77dedc92ba`; line count `331`.
- Execution BASE..HEAD diff is exact one added path, `tests/test-verifier-contract-assurance.sh`, with `331/0`; `git diff --check` rc0.
- `bash -n`, shfmt diff, and ShellCheck warning checks all rc0 with empty output.
- Assurance rc0, stdout exactly `RESULT PASS  verifier contract assurance\n`, stderr empty.
- 05 base rc0, stdout exactly `RESULT PASS  verifier contract\n`, stderr empty.
- Offline rc0, stdout last line `RESULT PASS  aosp-harness offline quality gate`, stderr empty.
- The three protected 05 files had identical before/after SHA-256 values; final candidate status count is 0 (clean).

## Full-history checkout

- Created outside the repository with `git clone --no-local --branch spec/2026-09-05-05a-verifier-contract-assurance --single-branch`; clone rc0.
- HEAD `5f867fa8e5d1c5b79001d0ec201045139fa29a40`; history count `239`; `--is-shallow-repository=false`.
- BASE..HEAD diff is exact one added TARGET with `331/0`.
- TARGET and PROTO SHA-256 are both `88f3abcd3f99e252c10e1134b98ea63212584ebd37bc6dfac2f9dd77dedc92ba`.
- Assurance, 05 base, and offline ran serially: all rc0, fixed summary/last line correct, all stderr empty.
- Final full checkout status count is 0 (clean).

## True depth-1 checkout

- Created outside the repository with `git clone --depth 1 ... file://...`; clone rc0.
- HEAD `5f867fa8e5d1c5b79001d0ec201045139fa29a40`; commit count `1`; `--is-shallow-repository=true`; `.git/shallow` is a one-line nonempty marker containing HEAD.
- TARGET and PROTO SHA-256 are both `88f3abcd3f99e252c10e1134b98ea63212584ebd37bc6dfac2f9dd77dedc92ba`; both Git blob IDs are `3688cfe9ea2e17d85c3b726ff4d9e7c15ec0f1f2`.
- An additional, non-gating diagnostic probe attempted a direct BASE..HEAD diff and returned rc128 with `Invalid revision range`, because a true depth-1 clone physically lacks BASE. This raw rc/stderr remains in green evidence. It is not a task step 4 gate and is not used as a “depth-1 exact diff gate”: the task-defined depth-1 identity proof is HEAD, count, shallow marker, TARGET/PROTO SHA-256 and blob equality, plus clean; candidate/full provide the authoritative BASE..HEAD exact1 proof.
- Assurance, 05 base, and offline ran serially: all rc0, fixed summary/last line correct, all stderr empty.
- Final depth-1 checkout status count is 0 (clean).

## Cleanup and handoff

- The exact `/tmp/05a-task2-clones.3G27Vz/{full,depth-1}` clones and their root were physically removed using prefix-validated `find -depth -delete`; all three paths were proven absent afterward. No `rm -rf` was used.
- Candidate capture temp was also physically absent after cleanup.
- The first candidate orchestration attempt was discarded before producing evidence because zsh's special `path` variable overwrote `PATH` in the driver and caused rc127. It made no repository change; the entire candidate sequence was rerun under explicit Bash and passed. A final temp audit found its exact empty/capture path `/tmp/05a-task2-candidate.pEpI39`; prefix validation plus `find -depth -delete` physically removed it, and the matching prefix count is now 0. This is not a product failure.
- The independent r2 review returned PASS with B/I/M=`0/0/0`. Only afterward, as post-review controller bookkeeping, six-column `review-manifest.tsv` row 2 was appended with base=head=`5f867fa8e5d1c5b79001d0ec201045139fa29a40`, reviewer `review_05a_task2_diff`, result `PASS`.

## Reproducible assurance anchors

- A read-only AST/literal audit of the exact TARGET/PROTO computes `expected_base=105`, generated `cli:23 since:9 query:6 service_ascii:80 surface:41`, total `264`, unique `264`; the literal TABLE has 73 rows. Independent expected construction and exact executed-set comparisons are at source lines 87–98, 181–187 and 299–302.
- Runner/direct recording and its independently constructed oracle both encode `argc` and every argv byte length+hex (lines 29–42 and 209–214), then line 228 jointly asserts argv, rc, stdout, and stderr.
- The source has one `range(41)` surface loop and one service Cartesian product with dimensions `4*4*5=80` (lines 231 and 267–298).
- The four exact mutant labels are `mutant-case-manifest`, `mutant-argv-service`, `mutant-service-grammar`, and `mutant-cleanup-before-pass`. Lines 303–320 enforce single replacement, syntax/compile, exact label, rc/stream for child mutants, and no survivors.
- Lines 321–330 enforce dependency hashes, cleanup before guarded summary, and rc1/FAIL conversion for every exception. The assurance intentionally exposes no per-case success stream. No internal stream is reconstructed or invented: the audited fail-closed control flow plus three exact 41-byte rc0/empty-stderr assurance runs proves the matrix reached its sole success terminal in candidate/full/depth-1.

## Result

Candidate, full-history, and true depth-1 validations all PASS. “Nine serial gates” means exactly three checkouts × the three test commands assurance/base/offline; all nine returned rc0 and empty stderr. Mechanical Git probes are outside that set, including the retained non-gating depth-1 BASE-missing rc128 diagnostic. Worktrees were clean and temporary clones were physically removed.
