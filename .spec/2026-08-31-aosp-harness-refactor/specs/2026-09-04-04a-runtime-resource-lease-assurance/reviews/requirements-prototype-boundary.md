# 04a requirements prototype boundary

日期：2026-09-04

基线：`main@ffb05899c33d04b4c3d1c6605b3d39b1e6a05204`，04 accepted provider `f7cfcb202d1fd2934d07cc90e333a4205b563243` 已合入且与 04 approved prototype 逐字一致。

## 原边界反证

对 04 转交的 fixed-shfmt 398 行 assurance prototype 运行静态门后执行默认 active 矩阵：

```text
PROTOTYPE_LINES=398
SHFMT=v3.14.0 PASS
SHELLCHECK=0.11.0 PASS
BASH_N=PASS
PROTOTYPE_ACTIVE_BEGIN
FAIL monotonic attempt count
error: resource lease operation failed
rc=1
```

隔离诊断把失败断言前的 `flock` seam 次数原样输出，结果为：

```text
DEBUG_FLOCK_COUNT=1
FAIL monotonic attempt count
rc=1
```

provider 在资源扫描后首次观测 deadline 到达时直接 `die(BUSY, 3)`，没有进入 assurance 所要求的最后一次无 sleep 锁尝试。04 执行期新增的锁后 deadline 检查仍能保证最后一轮拿锁后、读取 record 或发布前返回 3。

## 最小边界与实跑

隔离 provider 副本只替换以下相邻分支，不修改 public API、状态格式、文档或基础测试：

```diff
-            if not occupied or wait_value == 0 or test_seam("monotonic", time.monotonic()) >= deadline:
-                die(BUSY, 3)
+            if not occupied or wait_value == 0: die(BUSY, 3)
+            if test_seam("monotonic", time.monotonic()) >= deadline: continue
```

round2发现上一版脚本从顶层`tests/`错误使用`../../common`，使default/all实际走inert；显式provider又会泄漏到内部absent surface。修正版从`repo=$here/..`派生repo内provider，在父进程逐字核普通非symlink默认路径，内部absent surface显式清除override。所有承重fixture补构造/改写/清理失败收口；production mutant先核唯一anchor、预期替换和source健康，unpublish mutant改为真实破坏`os.replace(path, trash)`状态转换，并逐字匹配四个专属失败标签。

同一真实顶层布局随后执行完整三路：

```text
PATCHED ACTIVE BEGIN
RESULT PASS  resource lease assurance
PATCHED ALL BEGIN
RESULT PASS  resource lease assurance
PATCHED ABSENT BEGIN
RESULT PASS  resource lease assurance
PATCHED_MATRIX=PASS provider_lines=336 assurance_lines=396 churn=2+2+396=400
```

requirements round1指出原报告漏计provider的两行删除，并指出转交原型缺少damaged provider source/API/double-seam等负向执行、三种真实absent入口、同owner异mode、tracked hash/repo外fixture和mutant双流断言；round2再杀死默认路径inert、override泄漏、fixture构造和非生产unpublish mutant四类假绿。修订原型在fixed-shfmt后仍为396行，补齐上述oracle；execution BASE到候选的预期exact diff因而是两个文件：provider `2`增`2`删，assurance `396`增`0`删，按项目全局churn口径为`2+2+396=400/400`。04a保持P1（完整矩阵独立验收）、P2（两文件一起回滚到已验收04基线）、P3（闭合deadline缺口并新增保证）、P4（无新用户问题）、P5（exact2/400）。

修订原型还逐字验证：default/all解析到repo内普通provider并真实运行约30秒active矩阵；invalid CLI 双流空；清除override后的三种absent入口同摘要；七类 damaged provider 均 rc1/空 stdout/固定 `FAIL provider validation\n`；overlap/unpublish/bundle production mutant与adapter fixture mutant依次只得到专属`FAIL stored overlap rc=0`、`FAIL disjoint release rc=2`、`FAIL same owner subset rc=0`、`FAIL adapter command count`，stdout均空；tracked provider/docs/base-test 前后 SHA-256 不变。达到三轮熔断后采纳最后两项承重finding：顶层临时树创建后核repo外/EUID自有0700/普通空目录，失败trap核删除且能把cleanup失败变rc1，成功路径先删除并核物理缺席再打印PASS；holder/waiter/clock marker子进程写失败立即非零并由父级专属startup失败收口，adapter fixture改写也立即专属失败。fixed-shfmt仍396行，固定shfmt 3.14.0、ShellCheck 0.11.0、bash-n通过；须由同reviewer只读熔断融合验证后方可放门②。
