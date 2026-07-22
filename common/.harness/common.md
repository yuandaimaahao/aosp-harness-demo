# Shared Harness public facts

This file belongs to the .harness public layer. Claude Code and Codex adapters
read the same facts from here; client-specific startup, hook, and skill rules
stay in their own directories.

## Active feature

- active feature: read CURRENT_FEATURE at startup
- target branch: the active feature name for every repository in this demo
- repository manifest: .harness/features/<feature>/repos.tsv
- build/deploy facts: .harness/features/<feature>/workflow.md
- verification entry point: the single executable verify-*.sh in the feature directory
- delivery evidence: only RESULT PASS

## Manifest schema

repos.tsv uses four tab-separated columns:

    path<TAB>convention<TAB>tags<TAB>description

It is the single source of truth for both clients. Do not copy it under
.claude/ or .codex/. Adapters may render a runtime summary, but they do not
own another copy.

## Synchronization rules

1. Change public facts in .harness first.
2. Keep shared build/deploy facts in the feature workflow.md. In this demo,
   target_branch equals CURRENT_FEATURE for every listed repository.
3. Run both .claude/bin/claude-feature --dry-run --contract and
   .codex/bin/codex-feature --dry-run --contract.
4. Run .harness/bin/check-parity.sh and require PARITY PASS. In a real repo
   tree, wrappers also require .harness/bin/check-branches.sh to pass.
5. Only one client may write the same feature at a time. End the current
   session and save or commit changes before starting the other client.
6. A wrapper chooses context before a new run. The demo SessionStart hook only
   checks startup parity; real projects should retain client-specific prompt
   hooks that compare the session snapshot with contract_sha256.
7. Finish with the shared verifier. RESULT INCOMPLETE, RESULT FAIL, and
   RESULT EXPLORATION are not delivery evidence.
