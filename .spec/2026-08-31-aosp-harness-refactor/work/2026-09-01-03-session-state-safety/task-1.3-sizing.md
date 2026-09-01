# Task 1.3 sizing prototype

Measured at worktree HEAD `6d95aaf376c8985dac9d2fb0bf462603ba1fbbcd` against execution BASE `5038c5455ab0063959971b7020f1ed3de4f95d4d`:

| File | Current | Planned additions | Semantic reuse/reduction | Target |
|---|---:|---:|---:|---:|
| provider | 118 | +8 exact-arity/op/ID guard shared by direct dispatcher | 0; public-to-private rename is line neutral | 126 |
| test | 255 | +24 surface/marker, dispatcher table, two-export OS error, source sentinel | -4 from one `assert_call` helper replacing ten adjacent capture/assert pairs; up to -8 redundant blank separators, without joining statements or deleting comments/oracles | 267 |
| total | 373 | +32 | -12 | 393 |

The seven-line reserve covers source-path/result-line adjustments. `git mv` is line neutral because neither temporary filename exists at BASE. The implementer must run the BASE-to-working-tree numstat before commit. If the actual total exceeds 400, or reaching 400 would require deleting an oracle/comment, joining statements, or changing R1–R6, task 1.3 reports BLOCKED and returns to PLAN.

