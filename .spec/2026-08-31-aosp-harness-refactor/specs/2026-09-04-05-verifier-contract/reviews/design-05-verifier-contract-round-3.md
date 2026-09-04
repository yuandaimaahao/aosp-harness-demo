# 05 verifier contract design review — round 3

## 结论

- 规格符合性：**NEEDS_CHANGES**
- 设计质量：**NEEDS_CHANGES**
- Findings：**B=0 / I=1 / M=0**

本轮按 `reuse_reviewer=true` 只读复核最新 `design.md` 与三个 prototype，范围限于 round 1 的 B1–B4/I1–I2 闭合及回归。v6.1 新增 05a 的范围拆分已由独立 boundary reviewer 审查，本轮不重新裁定该扩展。

## Finding

### [重要 I1] 单独 help case 仍未按 R7 证明零 query

- 定位：`requirements.md:19,39`；`prototypes/tests/test-verifier-contract.sh:40-50,96-97`
- 现状：`capture()` 会清空 `$LOG`，但单独 `--help` 调用没有设置 `ANDROID_SERIAL`、`HARNESS_VERIFIER_QUERY_RUNNER="$SELF"` 和 `FAKE_LOG="$LOG"`，随后也没有断言 `! -s "$LOG"`。因此该 case 只证明 rc/stdout/stderr，不能证明 R7 明文要求的“单独 help … 零 query”。若 help 路径发生“先执行一个静默 direct query、再打印正确 usage”的回归，当前 oracle 可能仍绿。
- 影响：round 1 B2 的大部分缺口已经闭合，但这一条仍使 05 base prototype 没有完整兑现本片不可后移的基础 oracle，固定 PASS 还不能作为完整 R7 证据。
- 建议：像其它 preflight case 一样，以合法 serial、self runner 和 `$LOG` 执行单独 help，并联合断言 rc0、精确 stdout、stderr 空、log 空。该修复无需复制 05a 的穷举矩阵。

## Round 1 findings 闭合复核

| Round 1 finding | 状态 | 复核结果 |
|---|---|---|
| B1：05 direct ADB 无法组合 06/09 | **已闭合** | private `HARNESS_VERIFIER_QUERY_RUNNER` 在首 query 前校验绝对路径/EUID/普通非 symlink/X_OK；以 `key -- adb -s serial argv...` 分离调用，stdout bytes捕获、stderr继承、rc/信号规范化，unset保持direct。design明确09绑定可信06 adapter且不改provider。 |
| B2：测试缺完整case/argv证明 | **部分闭合** | demo、default六query、explicit-since五query、长度分隔argv、runner stderr/rc及代表CLI/serial/runner已补；完整矩阵按已审v6.1边界归05a。仅剩本轮 I1 的单独help零query oracle。 |
| B3：repo外temp与cleanup后摘要 | **已闭合** | 固定 `/tmp` 创建后立即装trap，`realpath`核repo外、普通非symlink、EUID 0700、初始为空；成功先解除trap、显式删除并核物理缺席，最后才打印PASS。 |
| B4：contract doc不完整 | **已闭合** | CLI优先级、六精确argv、runner协议/信任边界、bytes/LF/尾CR、R4全表、明细顺序/前缀、summary/terminal/rc、十二fixture及探索限制均已写全。 |
| I1：crash parser先strip改变行首 | **已闭合** | bytes只按LF分行、至多移除一个尾CR；原始首字节先按ASCII数字判断，前导空白/Unicode digit不再被改写为合法数字行。 |
| I2：service whitespace不等价 | **已闭合** | v6.1契约已明确固定bytes grammar的space/tab，provider regex、文档与requirements一致。 |

## 实际机械复核

- Base：`bash prototypes/tests/test-verifier-contract.sh` → rc `0`，输出 `RESULT PASS  verifier contract`，无额外诊断。
- shfmt：固定 `/tmp/aosp-harness-tools-04/shfmt` 为 `v3.14.0`；`-d -i 2 -ci -bn` 对 provider/test rc `0`、无 diff。
- ShellCheck：固定版本字段 `0.11.0`；`-x --severity=warning` 对 provider/test rc `0`、无诊断。
- `bash -n`：provider/test rc `0`。
- `wc -l`：provider `202`、doc `67`、test `102`，合计 `371/400`。
- SHA-256：provider `56f696401ccf53db4c81aa47bcce1d61081639eace5cdba983aecf8af396500d`；doc `d22c977c4d361a7ad7a949db33e6d93e73a7564752d9374cd9fa7be4bb3c2634`；test `a6f4cd4d48f5de27c20b60ea2f14df1aef8785410752a9ac199130ce9cb7069e`。三者与最新 `design.md:154` 一致。

三个 prototype 仍是完整 runnable core 而非 skeleton，physical provider、05/09 owner、provider-absent fallback和exact3 rollback边界未回归。修复唯一 I1 并更新 test 行数/hash证据后可再次复审。
