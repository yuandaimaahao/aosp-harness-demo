# Design review：04-runtime-resource-leases v5.8 round 3

- 规格符合性：**NEEDS_CHANGES**
- 设计质量：**NEEDS_CHANGES**
- Verdict：**NEEDS_CHANGES**
- Findings：Blocking **1** / Important **1** / Minor **0**
- 门③：**不可通过**

本轮由独立 reviewer `design_04_v58_review` 只读复查 round 2 修复稿；以下是本轮后续修复前快照的结论。

## Findings

### [B1] facade 未覆盖 `mktemp` 伪成功与 capture 路径消失

上一轮外部 `wc`、普通 `mktemp` 失败、fake `rm` runtime 回滚及 closed stdout 已闭合，但仍有两个反例：

```text
fake-mktemp-success rc=0 out=33 err=0 victim-exists=no active=1
capture-disappear rc=2 out=0 err-lines=2 fixed=no active=0
```

前者源于只检查“目录且非软链”后即递归删除 helper 返回路径，fake `mktemp` 可返回含 sentinel 的既有目录并使 facade 删除它。后者源于通过版本探针的 fake Python 删除 stdout capture pathname 后，首次 shell 输入重定向的诊断未静默。必须验证 capture 的模板/owner/0700/fresh-empty 条件、避免递归删除任意返回路径，并使 capture 消失也只产生固定 rc2。

### [I1] assurance fake `rm` 是假覆盖

同一 `helper-bin` 依次创建 fake `mktemp` 与 fake `rm`，到 `rm` case 时前者仍在 PATH 首位，导致调用在创建 capture 前退出，fake `rm` 从未执行。独立 fake-rm-only 探针证明 runtime 当时能返回固定 rc2 且 active=0，但 assurance 必须隔离 helper fixture，并加入 fake-mktemp-success 与 capture-disappear oracle。

## 旧 findings 闭合状态

- stored workspace lexical canonicality 已闭合：自洽 `.../ws/../ws` 记录现返回固定 rc2，只保留原 active。
- facade helper/capture 收敛部分闭合，剩余问题见 B1。
- assurance 已加入 stored noncanonical，但 fake-rm 假覆盖且缺新增两条边界，见 I1。

## 已核对通过

- frontmatter、R1–R10 映射、八节/文件清单、04/04a 所有权、NEXT 门、唯一生产 no-op seam 均无漂移。
- 固定 shfmt 3.14.0、ShellCheck 0.11.0、`bash -n` 全绿；core `336+7+57=400/400`、assurance `398/400` 真实。
- 基础 default/all、extra 拒绝及 assurance default 通过，但不足以覆盖上述反例。

结论：补齐 B1/I1 后按三轮熔断规则做只读融合验证；若 fixed-shfmt 超门则回流 PLAN。
