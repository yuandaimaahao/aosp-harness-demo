# Shared Harness public facts

This file belongs to the .harness public layer. Claude Code and Codex adapters
read the same facts from here; client-specific startup, hook, and skill rules
stay in their own directories.

## Active feature

- feature: dev-sidebar
- repository manifest: .harness/features/dev-sidebar/repos.tsv
- verification entry point: .harness/features/dev-sidebar/verify-sidebar.sh
- delivery evidence: only RESULT PASS

## Manifest schema

repos.tsv uses four tab-separated columns:

    path<TAB>convention<TAB>tags<TAB>description

It is the single source of truth for both clients. Do not copy it under
.claude/ or .codex/. Adapters may render a runtime summary, but they do not
own another copy.

## Synchronization rules

1. Change public facts in .harness first.
2. Run both .claude/bin/claude-feature --dry-run --contract and
   .codex/bin/codex-feature --dry-run --contract.
3. Run .harness/bin/check-parity.sh and require PARITY PASS.
4. Only one client may write the same feature at a time. End the current
   session and save or commit changes before starting the other client.
5. A wrapper chooses context before a new run. A hook may block drift, but it
   cannot hot-reload another instruction chain in the current run.
6. Finish with the shared verifier. RESULT INCOMPLETE and RESULT FAIL are not
   delivery evidence.
