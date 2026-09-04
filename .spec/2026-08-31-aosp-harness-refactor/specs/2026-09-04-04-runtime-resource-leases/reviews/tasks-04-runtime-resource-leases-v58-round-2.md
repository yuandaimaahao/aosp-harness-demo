# Tasks review：04-runtime-resource-leases v5.8 round 2

- 规格符合性：**NEEDS_CHANGES**
- 任务质量：**NEEDS_CHANGES**
- Verdict：**NEEDS_CHANGES**
- Findings：Blocking **0** / Important **1** / Minor **0**
- 门④：**不可放行**

## round1闭合

源码/资产边界已闭合：1.1–1.3各自只列一个创建路径，2.1–2.4解析为`文件: 无`；brief/red/具体日志/report/package/manifest/acceptance均改为repo-relative literal；exact3与03e不再重复登记为验收资产。04a spec/work单层日期前缀glob、branch/worktree匹配与限定records清单也已具体化。

## 剩余 I1：否定 `rg` 会吞 rc2

原 records 循环在`set -e`下用 `if rg -qF ...; then exit 1; fi`。Bash对`if`条件禁用errexit，文件消失/不可读导致的rg rc2会被当作“未匹配”放行：

```bash
bash -c 'set -e; if rg -qF needle /definitely/missing; then exit 1; fi; echo FALSE_GREEN'
```

实测rc0并打印`FALSE_GREEN`。必须显式只允许rc1：rc0=命中失败，rc>1=探针失败。

修复：定义`no_match`，在`set +e`区捕获rg rc后恢复`set -e`并`test "$rc" = 1`；branch/worktree和逐records循环统一调用，禁止裸`! rg`或if否定。

机械检查仍全rc0，core/assurance计数400/398不变。
