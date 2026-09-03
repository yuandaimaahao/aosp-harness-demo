# Review: 03e requirements round 1
verdict: NEEDS_CHANGES
阻断: 3 / 重要: 1 / 次要: 4

## findings
- [阻断B1] R8 CLI 与 PLAN.md:223-234 固定回滚验收命令冲突：PLAN 六处逐字要求 `./tests/test-claude-session-lifecycle.sh --session-provider-fixture missing-foundation|missing-path|missing-snapshot|missing-signals|missing-remove|absent`，R8 却写死「只接受无参数/all/唯一 --dependency-absent」且 flag 带值 rc1。「PLAN 未给 CLI 字面量」依据不成立。修法：R8 增加六值 fixture flag，验收清单同步。
- [阻断B2] R3/R5 静默推翻 DECISIONS 2026-09-01「03 requirements review round 1-3」「round 2」已确认口径：project-id 应为权威物理根完整 SHA-256（非常量 claude-code）；SessionStart 应按 source 分级（startup/fork/clear/resume 缺失可建、compact 缺失报错、五 source 永不覆盖）；SessionEnd 缺事件名/session ID/reason 校验；最低 Claude Code 版本 2.1.234 与「SessionEnd 后 resume 建新基线」未承接。修法：按 DECISIONS 改写或显式注明 supersession。
- [阻断B3] R2「provider 任一调用返回非零→legacy」与 R3/R4 设计内非零码（read 缺失 3、write 同值 0、remove 缺失 0）自相矛盾，首个会话 read-rc3 同时被要求继续 v1 write 与转 legacy。修法：R2 收窄为「设计外错误码」并显式豁免设计内码。
- [重要I1] R9 fragment 排除口径依据不实：03b/03c 从未交付 coverage fragment，「既定口径」不存在。修法：改真实理由（fragment 为文档性资产、由 exact 六文件 diff 门覆盖防改）。
- [次要S1] R8 引 PLAN.md:221 脱「还」字；R9 引 DECISIONS 03b1 裁定脱括号。修法：补全或 paraphrase。
- [次要S2] R8 absent surface 未说死应执行全部 legacy 行为 case（非零 case inert）。
- [次要S3] frontmatter 确认依据「03d requirements R10/R11」应为仅 R11。
- [次要S4] R2 引 PLAN.md:154（08 的 contract_version=legacy）易误导，建议删除或改注。

## 核对无误
R2 compat marker 字面量对齐 PLAN:188 成立且注明准确；R1/目标/R10 引 PLAN:187/134/212 逐字正确；NEXT=04 与 PLAN 顺序一致；六文件边界无遗漏（feature-common.sh 不需要改）；上游十二文件累加正确；主验证命令与 PLAN:54 逐字一致（双空格）；验收清单 10 条对应 R1–R10；机械检查全 rc0。
