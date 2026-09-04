# Review: task 1.1 (b73676ba..b2fab190) round 3 — fix round 2 增量复查

verdict: PASS
阻断: 0 / 重要: 0 / 次要: 0

范围：只审 fix round 2 提交 `b2fab1905278fd523134a8ac656fa152a0824669`（`b73676ba..b2fab190`，session-end.sh 2+/2-）。
round 2 的 S5/S6 两条次要全部真实闭合。

## S5 闭合判定

闭合。`if [[ $prc == 3 ]]` 改为 `if [[ $prc != 0 ]]`，确保所有非零 prc（含 rc127 python3 缺席、rc1/2 语法错误、rc3 校验失败）统一走 `compat_legacy + exit 0`（零删除）。被删除的 `[[ $prc == 0 ]] || use_v1=0` 是 fail-open 源头——任何非 3 的非零 rc 会令 use_v1=0 落 legacy 删除，现在该路径已不可达。

控制流验证（b2fab19 完整文件）：
- prc=0（校验通过）→ 落到 `if [[ $use_v1 == 1 ]]` → 正确
- prc=3（校验失败）→ prc!=0 → compat_legacy + exit 0 → 零删除 ✓
- prc=127（python3 缺席）→ prc!=0 → compat_legacy + exit 0 → 零删除 ✓
- prc=1/2/other → prc!=0 → compat_legacy + exit 0 → 零删除 ✓

## S6 闭合判定

闭合。`cat >/dev/null 2>&1 || true` 位于 `if [[ $prc != 0 ]]` 块内、`compat_legacy` 之前，在 compat marker 输出到 stdout 之前排干未消费的 stdin。`|| true` 防止空 stdin 时 cat 的非零退出码触发 set -e。模式与 load-feature.sh 和 check-branch-drift.sh 的 S1 修复一致。

## 回退检查

无回退。prc==0 路径未受影响——python3 校验成功时执行仍落到 `if [[ $use_v1 == 1 ]]` / `else` 分支。被删除的 `[[ $prc == 0 ]] || use_v1=0` 只影响 prc 非零且非 3 的情况，该情况现被更宽的 `prc != 0` 守卫捕获并在到达 use_v1 之前退出。

numstat：session-end.sh 47 行（预算 ≤52），2+/2- 净增 0，仍在预算内。任务 1.1 四文件合计仍为 140/152。
