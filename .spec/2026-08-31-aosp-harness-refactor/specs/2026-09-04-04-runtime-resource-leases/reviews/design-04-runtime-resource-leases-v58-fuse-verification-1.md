# Design fuse verification：04-runtime-resource-leases v5.8（第一次）

- 规格符合性：**FAIL**
- 设计质量：**NEEDS_CHANGES**
- Verdict：**FAIL**
- Findings：Blocking **0** / Important **1** / Minor **0**
- 门③：**暂不可放行**

同一 reviewer `design_04_v58_review` 按 `fix_loop_max=3` 只读验证 round 3 指定 findings，不开启新一轮发散审查。

## 已闭合

生产 facade 三个定点与 stored canonicality 均通过：

```text
fake-mktemp-success rc=2 out=0 fixed=yes victim-dir=yes sentinel=yes active=0
capture-disappear rc=2 out=0 fixed=yes active=0
stored-noncanonical rc=2 out=0 fixed=yes active=1
```

capture 预检、点名 cleanup、shell 诊断静默、publish 后 rollback 与 stored lexical canonical 实现/设计一致。assurance 的 stored/capture/rm mutants 均 rc1 无 PASS；helper fixture 已隔离，fake `rm` 确实被命中。固定工具、core `336+7+57=400/400`、assurance `398/400` 和全部 CLI 协议无回归。

## 剩余 I1

fake-mktemp-success oracle 把 sentinel 放在独立文件名。删除生产 capture preflight 后，坏实现虽会创建/删除 `out`/`err`，但最终仍因 sentinel 使 `rmdir` 失败，观察结果与健康实现相同：

```text
mktemp-mutant rc=0 pass=1
```

裁定修法：sentinel 直接占用 `victim/out` 并核对原内容，使缺 preflight 的实现必然在 worker stdout 重定向阶段截断它；健康实现必须写入前拒绝并原样保留。完成后继续同一 fuse verification。
