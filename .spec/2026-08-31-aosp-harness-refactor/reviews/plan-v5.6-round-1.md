# PLAN v5.6 增量 review round 1

Reviewer: `review_plan_v5_2`

Verdict: **NEEDS_CHANGES** — blocker 0 / important 3 / minor 1

审查范围：只审 v5.5→v5.6 的 03a1/03a2 拆分及受影响位置；对照 `research/report.md`、`PLAN-history.md`、round6/round7 sizing report、round7 evidence 与两份可运行 prototype。未扩查已完成的 01/02/03/03a 实现。

## Findings

### Important 1 — PLAN 的 matrix fail-closed 优先级没有 round7 实证支撑

- 位置：`PLAN.md:111`；round7 entrypoint prototype `tests/test-session-path-races.sh:61-90`。
- PLAN 固定顺序为“先拒绝参数/自有matrix损坏；provider缺席inert”。实际 round7 prototype 在第61–78行已经可因 provider、driver、flag 或 core 状态返回 inert，第81–90行才生成并检查37-row matrix。
- 影响：v5.6把round7写作执行依据，但其原型没有证明“自有matrix损坏不能被依赖缺席掩盖”这一承重语义；后续 requirements/design 无法同时忠实于 PLAN 和 prototype。
- 可执行修复：二选一。若坚持 PLAN 的 fail-closed 语义，把 matrix 生成/37唯一ID/九类计数检查移到 provider absent 分支之前并重跑 round7 缺席/损坏矩阵；若接受 provider 缺席优先，则修改 PLAN 顺序并明确该取舍。前者不改变 owner、依赖或400行边界。

### Important 2 — 03a2 的“独立判据”仍可被 inert PASS 满足，depth-1 也只写成历史证据而非硬门

- 位置：`PLAN.md:47-49,111`。
- spec表给03a2的独立判据只有运行 `./tests/test-session-path-races.sh` 并得到固定摘要；但同一脚本在provider/driver/foundation/core缺席时故意输出完全相同摘要。第111行虽说 controller 要“另证”dependency-present 37 case，却没有给出可执行判据。03a1/03a2两行及详情也没有把各自的真实file-URL depth-1验收写成必须执行的门。
- 影响：只看PLAN规定命令即可把inert路径误验收为03a2完成；实现也可删除浅克隆验收而仍字面满足PLAN，无法机械闭合P1和此前R7的depth-1边界。
- 可执行修复：把03a2独立判据改为精确的dependency-present命令链，例如先要求driver `protocol`/`self-test`成功，再运行默认入口，并由入口内部37/37与九类计数断言闭合；同时分别规定03a1 accepted HEAD的depth-1 `self-test`，以及03a2 accepted HEAD的depth-1 default + `scripts/check.sh --offline`。不得只引用round7报告作为未来验收门。

### Important 3 — 03a2 的回滚命令不能在该片完成时独立执行，也未验证private driver不会被默认发现

- 位置：`PLAN.md:197,219`。
- 回滚矩阵正确说明删除root entrypoint后driver仍留存且不应默认执行；但固定回滚命令只要求未来的 `./tests/test-session-snapshot.sh` 及后序测试保持不变。03a2完成、03b尚未开始时该文件不存在，而且该命令本身不证明root gate没有发现private driver。
- 影响：03a2的P2有语义说明和round7证据，却没有在当前拓扑点可执行的固定回滚验收；执行者只能等待未来consumer或自行猜测命令。
- 可执行修复：03a2行至少加入“删除root test后运行 `bash ./scripts/check.sh --offline` 并要求固定quality-gate摘要”，以直接证明剩余 `tests/lib/*.py` 不被默认发现；未来snapshot/后序回归可保留为追加检查。

### Minor 1 — v5.6依据有明显错字

- 位置：`PLAN.md:8`（`PLAN-history.md:57`同样出现）。
- `新墖03a2` 应为 `新增03a2`。不影响语义或机械检查。

## 已确认闭合

- spec表、owner表、详情、直接边、依赖图和顺序一致：`03a→03a1`、`03a→03a2`、`03a1→03a2`、`03a→03b`、`03a2→03b`；无 `03a1→03b`，图无环。
- 03a1 exact1拥有private Python driver，03a2 exact1拥有唯一root shell entrypoint；round7实测381/400与98/400，满足P5和每片400行门。
- private CLI与原型一致：`protocol` stdout精确`session-path-race-driver-v1\n`/rc0；`self-test` stdout精确38-byte private摘要/rc0；misuse rc2；`run-matrix`成功摘要由shell完整捕获消费。
- 03a1 self-test不读取03a2文件；03a1回滚后03a2对driver物理缺席inert，driver存在但directory/symlink/protocol/语法/执行损坏均fail closed；03a2回滚后driver不在root `tests/test-*.sh`默认glob中。P2架构和默认发现边界本身成立。
- 03b只消费03a runtime core；03a2→03b是controller验收边，无运行时API或循环依赖。PLAN明确禁止以inert摘要解除03b gate。
- round7已实跑37/37、14项self-disproof、full/depth-1 direct/offline；证据本身可信，缺口是PLAN尚未把其中部分写成未来机械门。

## Mechanical evidence

- `check-plan.py PLAN.md`: rc0。
- `git diff --check`（PLAN、history、round7 report/evidence）: rc0。
- 本 reviewer 实跑round7 prototype：protocol rc0且精确token；self-test rc0且精确38B；entrypoint rc0且精确41B；protocol额外参数rc2。

## 最终判定

**NEEDS_CHANGES**。拆分边界、owner、CLI、依赖和400行证据成立；修复三项important后可做范围受限的round2复审。
