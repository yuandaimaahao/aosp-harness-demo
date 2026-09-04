# Design review：04-runtime-resource-leases v5.8 round 2

- 规格符合性：**NEEDS_CHANGES**
- 设计质量：**NEEDS_CHANGES**
- Verdict：**NEEDS_CHANGES**
- Findings：Blocking **2** / Important **1** / Minor **0**
- 门③：**不可通过**

本轮由独立 reviewer `design_04_v58_review` 只读检查初版 v5.8 `design.md` 与 runnable prototypes；以下是修复前快照的审查结论。

## Findings

### [B1] stored workspace canonicality 可被自洽记录绕过

`stored=True` 只检查绝对路径和控制字节，`raw == canonical` 不能证明 workspace identity 是 initial `Path.resolve(strict=True)` 可生成的规范值。定点探针把合法 active record 改成同一目录的 `.../ws/../ws`，同步重算 request/hash/token/filename 后，再 acquire 原 realpath 得到：

```text
stored-noncanonical-workspace rc=0 out-bytes=33 err-bytes=0 active-count=2
```

同一真实 workspace 因而出现两个 active bundle，违反 R2/R3/R5。修复必须在不要求已消失 workspace 仍存在的前提下拒绝 lexical noncanonical stored identity，并由 assurance 自洽 mutation 反证。

### [B2] facade 自身 helper 未全部纳入稳定协议

修复前 `mktemp` stderr、外部 `wc` 与 `rm` 双流/rc 位于 worker capture 外。定点探针为：

```text
mktemp-failure rc=2 out-bytes=0 err-lines=2 fixed-only=no
wc-failure rc=2 out-bytes=0 err-lines=2 fixed-only=no nonlock-assets=1
rm-replaced rc=0 out-lines=2 err-bytes=0 capture-dirs=1 nonlock-assets=1
```

其中 `wc` 在 worker publish 后失败会留下 active，伪 `rm` 还可泄漏输出并错误返回 0。所有 facade helper 诊断/rc 必须收敛，且 worker 已 publish 后的 facade 失败必须撤销 active。closed-stdout 原路径已正确返回固定 rc2 且无 active。

### [I1] assurance 与 sizing 尚未覆盖 B1/B2

修复前基础/assurance 没有自洽 noncanonical workspace、`mktemp`/`wc`/`rm` 故障族。虽然物理行数为 core `336+7+57=400/400`、assurance `398/400`，但不能证明完整合同可实施；补齐机制/oracle 后必须重跑 fixed-shfmt 计数，超门则回流 PLAN。

## 已核对通过

- requirements 的消费/产出签名与 design 逐字一致，R1–R10 映射、八节与文件边界完整。
- Python 3.8 API、owner/token 绑定、strict JSON 七键、全局 overlap、bundle publish/unpublish、monotonic 最终尝试、tombstone recovery 主状态机已闭合。
- 生产 seam 唯一且默认 no-op；04/04a 文件所有权、消费者依赖和 NEXT 五类资产缺席符合 PLAN v5.8。

结论：先修复 B1/B2、补齐 I1 并重新给出 exact3/exact1 可运行证据，再复审门③。
