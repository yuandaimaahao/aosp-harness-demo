# Claude Code + Codex Shared Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a runnable `common/` demo that shares one Harness fact source between Claude Code and Codex adapters while preserving the existing independent demos.

**Architecture:** `.harness/` owns the canonical feature manifest, shared resolver, verifier, and parity checker. `.claude/` and `.codex/` own only client-specific wrappers/configuration; both wrappers expose the same normalized contract in dry-run mode.

**Tech Stack:** Bash, Python 3 standard library, Markdown, Git.

---

## File Map

- Create `common/.harness/common.md`: shared feature facts and synchronization rules.
- Create `common/.harness/features/dev-sidebar/repos.tsv`: canonical four-column manifest.
- Create `common/.harness/features/dev-sidebar/verify-sidebar.sh`: strict offline verifier.
- Create `common/.harness/bin/resolve-feature.sh`: feature and manifest resolver used by both adapters.
- Create `common/.harness/bin/check-parity.sh`: normalized adapter parity checker.
- Create `common/.claude/bin/claude-feature` and `common/.claude/settings.json`: Claude adapter.
- Create `common/.codex/bin/codex-feature` and `common/.codex/hooks.json`: Codex adapter.
- Create `common/CLAUDE.md`, `common/AGENTS.md`, `common/CURRENT_FEATURE`, `common/run-demo.sh`, and `common/tests/test-harness.sh`.
- Modify root `README.md` and add `common/README.md` plus a Chinese article explaining synchronization.

## Task 1: Write shared-layer regression tests

**Files:** Create `common/tests/test-harness.sh`.

- [ ] Add tests for both adapters returning the same feature, manifest, verifier, and hash in `--dry-run --contract` mode.
- [ ] Add tests for missing/invalid feature, missing manifest, and missing verifier failing closed.
- [ ] Add tests for the canonical four-column manifest and parity checker rejecting a changed adapter contract.
- [ ] Add tests for verifier `RESULT PASS`, strict `RESULT INCOMPLETE`, and `--allow-skip` behavior.
- [ ] Run `bash common/tests/test-harness.sh`; expect failure because the shared implementation does not exist yet.

## Task 2: Implement the `.harness` public layer

**Files:** Create `common/.harness/common.md`, `repos.tsv`, `resolve-feature.sh`, `verify-sidebar.sh`, and `check-parity.sh`.

- [ ] Implement feature-name validation and manifest parsing with exactly four non-empty tab-separated fields.
- [ ] Return normalized `key=value` contract fields and a SHA-256 hash over the public fact files.
- [ ] Implement deterministic demo assertions with strict PASS/FAIL/INCOMPLETE semantics.
- [ ] Implement parity comparison that ignores only the client name and validates both adapter references.
- [ ] Re-run the tests and confirm the shared tests turn green.

## Task 3: Implement the Claude and Codex adapters

**Files:** Create `common/.claude/**`, `common/.codex/**`, `common/CLAUDE.md`, `common/AGENTS.md`, and `common/CURRENT_FEATURE`.

- [ ] Make each wrapper call the shared resolver and emit the normalized contract; `--dry-run` must not launch a client.
- [ ] Keep actual launch commands client-specific (`claude` vs `codex`) and document that the demo never invokes them.
- [ ] Add minimal, valid-looking client configuration examples without claiming cross-client hook compatibility.
- [ ] Add public context files that reference `.harness/common.md` and describe their distinct startup boundaries.

## Task 4: Add demo orchestration and documentation

**Files:** Create `common/run-demo.sh`, `common/README.md`, and `common/Claude-Codex共用Harness方案.md`; modify root `README.md`.

- [ ] Demonstrate both dry-run adapters, parity, strict verification, and a deliberate failure that is recovered in a temporary fixture.
- [ ] Explain the synchronization workflow, branch/session ownership rule, migration path to a real AOSP root, and troubleshooting.
- [ ] Link the new demo from the root README without changing the existing demo contracts.

## Task 5: Verify and integrate

- [ ] Run `bash claude-code/tests/test-harness.sh`.
- [ ] Run `bash codex/tests/test-harness.sh`.
- [ ] Run `bash common/tests/test-harness.sh` and `bash common/run-demo.sh`.
- [ ] Run `git diff --check` and inspect the diff; preserve untracked `demo-out/`.
- [ ] Commit the shared demo and push the current branch if the remote is available.
