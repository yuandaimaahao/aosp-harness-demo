# Review: 03e requirements round 2
verdict: NEEDS_CHANGES
阻断: 0 / 重要: 2 / 次要: 1

## round 1 闭合核验
B1/B2/B3/I1/S1–S4 全部真实闭合（六值 fixture flag 与 PLAN:223-234 逐字对应；source 五值分级/SHA-256 project-id/UPS rc2/reason 校验/2.1.234 承接且 DECISIONS 引文逐字；R2 收窄设计外错误码；fragment 真实理由；引文「还」字、frontmatter 仅 R11、PLAN:154 引用已处理）。

## findings
- [重要N1] R9 依据累加算术错误：「03b1六文件累加03c两文件与03d三shell共十二文件」漏算 03b1 自身交付的 assurance 测试（6+2+3=11≠12）；显式十二文件清单本身正确。修法：改「03b1七文件（基础六文件+assurance交付）累加03c两文件与03d三shell」。
- [重要N2] SessionEnd 事件名非法时行为未唯一确定：R2 触发集与目标节 partial 清单不含事件名非法，R5 只说「校验失败不删除任何状态」，是否转 legacy/是否删 legacy 快照/退出码无条款裁定。修法：R2 触发集补事件名非法或 R5 显式规定路径。
- [次要N3] SessionEnd 事件名非法负向用例未列入 R8 必覆盖集与验收清单。随 N2 一并处理。

## 边界核对无问题
R2/R3/R5 分工（除 N2）唯一确定；R4 与 R2 边界划清；R6 与现状逐字吻合；codex demo 同构声明属实；字面量六处一致；机械检查全 rc0。
