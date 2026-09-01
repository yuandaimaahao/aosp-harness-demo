# 03 foundation requirements review round 2

Status: NEEDS_CHANGES

Findings: blocker 1, important 1, minor 0.

- B1: require direct `_harness_session_state_run path` calls to validate both path IDs, with exact unsafe bytes and rc 2.
- I1: define source preconditions and assert rc/streams, marker non-creation, and caller sentinel value/export-attribute preservation.

HARNESS/XDG/TMP truth table, per-public-function absence oracle, unified manifest/package snippet, source attribution and 373/400 sizing all passed. Mechanical requirements checks passed.
