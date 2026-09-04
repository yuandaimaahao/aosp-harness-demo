# PLAN v5.8 independent review — round 3

结论：规格符合性 **PASS**；设计质量 **PASS**；Blocking **0** / Important **0** / Minor **0**。**可以批准 PLAN v5.8**。

## 上一轮 findings 闭合状态

### Blocking：04a 完整 assurance

已闭合。provider marker 恰一处，assurance 断言并只替换唯一 seam；realpath target 覆盖 TAB/LF/CR/0x1f，另有 NUL TSV；holder 以同一 instance ID 记录 `serial-A/cvd-A`，contender 以 `serial-B/cvd-B` 返回 3 且命令日志仍仅一条 A；unpublish replace fault 返回固定 rc2 并保留 active，健康 provider 随后可释放；overlap/unpublish/bundle/adapter 四类 mutant 均被对应 oracle 杀死。其余 self-overlap、barrier、PID reuse、monotonic final attempt、全 record 字段、missing/extra/filename/nonregular/duplicate/global-overlap、flock/open/write/fsync/publish+unpublish replace/unlink、closed stdout、fake Python、tombstone 与完整 inventory 均保留。assurance exact1=398/400，core exact3=336+7+57=400/400。

独立实跑 core 与 assurance default/all、assurance `--dependency-absent` 均固定 PASS；extra rc1 无摘要；`bash -n` 与本机 ShellCheck 0.9 warning 级通过。固定工具由 controller 复跑。

### Important：04→04a→05/06/08 门禁一致性

已闭合。spec 表、直接边、文本图的 31 条直接边集合一致；`04→04a`、`04a→05/06/08` 与 `04→06/08` 完整，顺序拓扑合法；04a 详情写明 05 五类资产缺席门；rollback 明确不得重新验收或新启动 05/06/08；ledger 明确 PLAN 通过后回流当前 04 requirements/design。

## 最终评价

v5.8 的拆分理由、稳定 public API、文件所有权、P5 sizing、assurance 主动反证、消费者依赖、回滚方向和 NEXT 门形成一致可执行闭环。

