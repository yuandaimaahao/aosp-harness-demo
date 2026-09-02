# PLAN v5.7 independent review — round 1

结论：**NEEDS_CHANGES**。Blocking 4，Important 1，Minor 1。审查只读，未改文件。

## Blocking

1. Python child 首次收到 HUP/INT/TERM 后未先 ignore 三种信号；group 直达与 facade 再转发可能二次打断 `finally`。03b 必须拥有 child first-signal latch，03c 只拥有 Bash facade 状态机，03b1 必须验证不同第二信号不改变首信号码且 temp 清零。
2. 当时的 393/400 candidate 未主动调用 spawn-only worker 验证 TEMP barrier 后 PID 为 Python、未真实投递信号、未对 exact 两文件运行 ShellCheck，且 write success 未断言 stdout 空。必须补齐后重新固定格式并实跑。
3. 03b1 只有“独享400行”额度，没有覆盖全部 active family 的 shfmt-clean runnable sizing candidate；必须先证明 exact1/400 可实施，超门则继续拆片并同步拓扑。
4. 03c 详情只检查 write/read exports，漏掉新 worker；必须钉死 worker write/read 精确签名，并让 source guard 与测试分别覆盖 worker/write/read 任一缺席时 inert。

## Important

1. ledger 仍混有 v5.6 与已证伪稳定PID证据；必须更新为 v5.7，并只把通过上述门的新 commit 作为 current sizing evidence。

## Minor

1. 整体显式验收命令链未列 `test-session-snapshot-assurance.sh`；应加入或明确该链仅为抽样。

## 已核对通过

- canonical spec/owner/直接依赖表、文本图、实施顺序和18个spec计数已同步。
- `03 -> 03b` validate直接边与validate/path双guard已补齐。
- 03b/03b1/03c独立回滚外形成立；03d前不发布public capability的边界保持闭合。
