# AOSP Codex Harness Demo Design

## Goal

Reorganize the repository so the existing Claude Code demo lives under
`claude-code/`, then build an independent Codex demo under `codex/`. The Codex
demo must include a runnable teaching harness and a full Chinese article based
on the existing AOSP harness exploration, while relying only on documented
Codex behavior.

## Deliverables

- Preserve the current Claude Code demo under `claude-code/`.
- Add `codex/README.md` as the runnable demo guide.
- Add `codex/AOSP整机源码Codex-Harness工程探索.md` as the long-form article.
- Add a self-contained Codex demo that runs without a real AOSP checkout,
  Android device, or authenticated Codex session.
- Add regression tests that exercise the harness through its public scripts.
- Add a short repository-root `README.md` that routes readers to both demos.

## Chosen Approach

Use a native Codex three-layer harness:

1. Context: `AGENTS.md`, selected before Codex starts.
2. Process: repository skills under `.agents/skills/`.
3. Verification: deterministic feature verification scripts.

This keeps the useful structure of the reference implementation without
translating Claude Code-specific contracts. In particular, the Codex design
does not claim that a skill `paths` frontmatter field exists or that reading a
matching source path automatically activates a skill. Codex discovers skill
metadata and selects a skill explicitly or implicitly from its description;
the feature `AGENTS.md` therefore contains explicit skill-routing rules.

Alternatives rejected:

- Starting Codex inside each feature directory makes the AOSP working directory
  and root-level source discovery awkward.
- Packaging the first version as a plugin adds installation and distribution
  concerns without solving per-tree feature selection.

## Repository Layout

```text
aosp-harness-demo/
├── README.md
├── claude-code/
│   └── <the current demo, moved without changing its behavior>
└── codex/
    ├── README.md
    ├── AOSP整机源码Codex-Harness工程探索.md
    ├── AGENTS.md -> features/dev-sidebar/AGENTS.md
    ├── CURRENT_FEATURE
    ├── run-demo.sh
    ├── .codex/
    │   ├── hooks.json
    │   ├── bin/
    │   │   ├── codex-feature
    │   │   └── check-process-layer
    │   └── hooks/
    │       ├── feature-common.sh
    │       ├── session-start.sh
    │       └── check-branch-drift.sh
    ├── .agents/skills/
    │   ├── build-services-jar/SKILL.md
    │   └── build-sepolicy/SKILL.md
    ├── features/dev-sidebar/
    │   ├── AGENTS.md
    │   ├── repos.tsv
    │   ├── check-branch.sh
    │   └── verify-sidebar.sh
    ├── frameworks/base/PLACEHOLDER.java
    ├── frameworks/native/PLACEHOLDER.cpp
    └── tests/test-harness.sh
```

The demo runs from `codex/`. In a real repo-based AOSP checkout, that directory
represents `<AOSP_ROOT>`, which is not itself a Git repository. The wrapper
always starts Codex with that directory as its working directory so instruction,
configuration, hook, and skill discovery do not depend on an arbitrary nested
shell location.

## Context Layer

`features/<feature>/AGENTS.md` is the single source of feature context. It
contains:

- tree-wide build rules and safety constraints;
- navigation guidance for a large AOSP tree;
- subagent task-card rules;
- feature goal and allowed repository list;
- repository-specific facts;
- explicit mappings from source areas to repository skills;
- the deterministic verification entry point.

The root `AGENTS.md` is a relative symlink to the active feature file. The
`.codex/bin/codex-feature` wrapper performs these steps before launching Codex:

1. Detect the feature from an anchor repository branch, falling back to
   `CURRENT_FEATURE` in the teaching demo.
2. Resolve `features/<feature>/AGENTS.md`.
3. In a real repo tree, run the feature's `check-branch.sh` and fail closed on
   a missing repository or branch mismatch.
4. Update the root symlink only after all checks pass.
5. Change to the AOSP root and execute `codex` with the caller's arguments.

`--dry-run` performs all selection and validation work but does not execute
Codex. If the root `AGENTS.md` is a regular file, the wrapper fails instead of
overwriting or backing it up silently.

Codex discovers `AGENTS.md` once per run, so the wrapper is the correctness
boundary. A `SessionStart` hook cannot retroactively replace instructions
already loaded for the same session.

## Branch Drift Hooks

`.codex/hooks.json` registers two command hooks:

- `SessionStart` on `startup` records the detected feature in a temporary file
  keyed by the hook input's `session_id`.
- `UserPromptSubmit` compares the current feature with that snapshot.

Hooks parse stdin as JSON through the Python standard library. Snapshot names
are sanitized, and the state directory is private to the current user under
`${TMPDIR:-/tmp}`. Parallel sessions therefore cannot overwrite one global
snapshot.

If the current feature differs from the startup snapshot,
`UserPromptSubmit` returns structured JSON with `continue: false`, a
`stopReason`, and a visible `systemMessage`. The current turn is stopped and
the user is directed to restart through `codex-feature`. No output is produced
when there is no drift.

The demo hook commands use paths relative to the session working directory.
This is safe because the wrapper fixes the working directory at the harness
root. The article calls out this dependency explicitly.

## Process Layer

Two repository skills demonstrate progressive disclosure:

- `build-services-jar` covers the `frameworks/base/services` build, output,
  deployment loop, ART-cache hazards, API updates, and final verification.
- `build-sepolicy` covers service contexts, policy types and allow rules,
  policy build, deployment, denial inspection, and final verification.

Each `SKILL.md` uses only documented `name` and `description` frontmatter. Its
description front-loads the relevant source paths and task intent so implicit
selection remains useful even if skill metadata is shortened. The active
feature `AGENTS.md` also states that modifying the corresponding paths requires
explicit use of `$build-services-jar` or `$build-sepolicy`.

`.codex/bin/check-process-layer` validates the skill files and their important
commands without claiming to test model activation behavior.

## Verification Layer

`features/dev-sidebar/verify-sidebar.sh` is the feature test entry point. It
supports real ADB mode and deterministic `--demo` mode. Assertions cover:

1. Android boot completion.
2. `system_server` liveness.
3. Crash-buffer queries within a defined time window.
4. Sidebar service registration.
5. Sidebar application installation.

The default crash baseline is the device boot time read from `/proc/stat`.
`--since <epoch-seconds>` narrows it to an explicit deployment baseline. Query
errors are failures, not empty successful results.

Each assertion produces `PASS`, `FAIL`, or `SKIP`. Final status follows this
strict precedence:

- Any failure: `RESULT FAIL`, nonzero exit.
- No failures but at least one skip: `RESULT INCOMPLETE`, nonzero exit.
- All assertions passed: `RESULT PASS`, zero exit.
- `--allow-skip` is an explicit exploration-only exception and prints
  `RESULT PASS (SKIP allowed)`.

## Demo Flow

`codex/run-demo.sh` demonstrates, in order:

1. Wrapper selection and root `AGENTS.md` synchronization.
2. Session snapshot and branch-drift blocking behavior.
3. `repos.tsv` branch-consistency failure in demo mode.
4. Offline process-skill validation.
5. Strict deterministic feature verification.
6. Full regression tests.

The demo never launches Codex, changes a real Android device, or needs an AOSP
build tree.

## Tests

`codex/tests/test-harness.sh` uses temporary fixtures and public scripts to
test:

- successful feature selection and relative symlink creation;
- missing feature, missing repository, branch mismatch, and regular-file
  collision failures without a partial context switch;
- valid hooks configuration and per-session feature snapshots;
- zero-output no-drift behavior and structured blocking drift output;
- skill metadata plus required build, artifact, and verification content;
- strict skip semantics;
- crash timestamps before and after a deployment baseline;
- crash query failure handling;
- normalization of integer epoch values passed to `adb logcat -T`;
- missing and aligned repositories in `repos.tsv`;
- absence of Claude Code-only terminology from Codex mechanism descriptions.

Tests must clean only the temporary directories they create. Existing untracked
repository output such as `demo-out/` remains untouched.

## Documentation

`codex/README.md` is operational and concise: directory map, quick start,
individual layer commands, expected output, and real-AOSP adaptation notes.

The long-form article is a Codex-specific rewrite rather than a search-and-
replace edit. It covers:

1. Why AOSP-scale trees need harness engineering.
2. Current Codex customization surfaces and their documented contracts.
3. The three-layer architecture and rejected alternatives.
4. Feature context selection with `AGENTS.md`.
5. Process skills without undocumented path-scoped activation claims.
6. Deterministic build, deployment, and verification loops.
7. Full session lifecycle.
8. Failure-driven design lessons.
9. Known boundaries and evolution paths.

Official Codex documentation is cited for `AGENTS.md`, skills, project config,
hooks, subagents, and CLI behavior. The article labels official guarantees,
demo-specific choices, and real-AOSP recommendations separately.

## Acceptance Criteria

- The current tracked demo is reachable under `claude-code/` and still passes
  its existing test suite from that directory.
- `codex/run-demo.sh` exits zero and demonstrates all three Codex layers.
- `codex/tests/test-harness.sh` exits zero.
- Both Codex documents exist, are internally consistent, and contain no claims
  that Claude Code-only mechanisms are Codex contracts.
- The Codex demo contains no `.claude/` directory or `CLAUDE.md` file.
- Untracked user files are not moved, deleted, or rewritten.

