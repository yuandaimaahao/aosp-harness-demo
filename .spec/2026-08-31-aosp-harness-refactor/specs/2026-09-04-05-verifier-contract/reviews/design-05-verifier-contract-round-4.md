# 05 verifier contract design review — round 4

## 结论

- 规格符合性：**PASS**
- 设计质量：**PASS**
- Findings：**B=0 / I=0 / M=0**

本轮按 `reuse_reviewer=true` 只读复核 round 3 唯一 I1 的修复及其局部回归。修复完整，round 1 的 B1–B4/I1–I2 至此全部闭合。

## Round 3 I1 闭合证据

`prototypes/tests/test-verifier-contract.sh:96-97` 的单独 `--help` case 现在显式设置：

- `HARNESS_VERIFIER_QUERY_RUNNER="$SELF"`
- `FAKE_LOG="$LOG"`

并联合断言 rc `0`、stderr 空、runner log 空及 stdout 精确 usage。`capture()` 在调用前清空 log，因此该 oracle 能直接证明单独 help 在本次执行中零 query，符合 R1/R7；没有复制或侵入 05a 的穷举矩阵责任。

## 回归复核

- B1：private runner seam、09/06 组合及 provider 不被后序改写的边界未变化。
- B2：base test 的 demo/default/explicit-since/runner/CLI/serial oracle 保持不变，help 零 query 缺口已补齐。
- B3：repo 外 0700 temp、失败 trap、显式 cleanup、物理缺席后才打印 PASS 的顺序未变化。
- B4：完整 contract 文档未变化。
- I1/I2：bytes/LF/单尾 CR、原始 ASCII 数字行首和 service space/tab grammar 未变化。
- physical provider、exact3 文件 owner、05 rollback 与 09 provider-absent fallback 边界均无回归。

## 实际机械复核

- Base：rc `0`，唯一摘要 `RESULT PASS  verifier contract`。
- 固定 shfmt `v3.14.0`：`-d -i 2 -ci -bn` 对 provider/test rc `0`、无 diff。
- 固定 ShellCheck `0.11.0`：`-x --severity=warning` 对 provider/test rc `0`、无诊断。
- `bash -n`：provider/test rc `0`。
- 行数：provider `202`、doc `67`、test `102`，总计 `371/400`。
- SHA-256：provider `56f696401ccf53db4c81aa47bcce1d61081639eace5cdba983aecf8af396500d`；doc `d22c977c4d361a7ad7a949db33e6d93e73a7564752d9374cd9fa7be4bb3c2634`；test `2c5b3b096cae5c2494b533afe108b3eb6386368d844345c5f03a362df7742160`，与最新 `design.md:154` 一致。

最终裁定：**PASS — B0 / I0 / M0**。
