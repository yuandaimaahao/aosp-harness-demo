# 04a design review — round 1

## 结论

**PASS**

计数：Blocking **0** / Important **0** / Minor **0**

审查对象：`design.md`（SHA-256 `c464e39f9eeaae125063ec864a88a6a9ae5b98c1e2bdf0eed9c42c4dfb40d2e3`）。本轮独立只读核对当前 `requirements.md`、PLAN v5.9 的 04a 边界、DECISIONS 最新三项 04a 裁定、ledger、requirements 三轮 FAIL 与熔断融合 PASS、`requirements-prototype-boundary.md`、04 已验收 requirements/design/生产 provider，以及 04a provider/assurance runnable prototypes。

## 机械与可运行证据

- `check-design.py design.md`：rc0、无 `missing:`。
- 八节及外加文件清单齐全，顺序符合 design 门；需求映射逐条覆盖 R1–R10，无未映射需求。
- design 的“消费契约”“产出契约”与 requirements frontmatter 分别逐字相同。
- fixed tools：shfmt 逐字 `v3.14.0`，ShellCheck version field 逐字 `0.11.0`；对 provider/assurance 两个 prototype 运行 `shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`、`bash -n` 均通过。
- provider prototype 相对当前 accepted provider 的真实 numstat 为 `2/2`；assurance fixed-shfmt 行数为 `396`；总 churn 为 `2+2+396=400`。provider diff 只有 requirements 钉死的 deadline 相邻两行。
- 04a prototype 中的 docs/base test 与当前已验收 `docs/resource-leases.md`、`tests/test-resource-leases.sh` 逐字相同。
- 独立实跑 prototype：default rc0、唯一摘要、约 38.45 秒；`all` rc0、唯一摘要、约 37.65 秒；`--dependency-absent` rc0、唯一摘要、约 0.05 秒。default/all 的时长与入口 route guard、脚本控制流共同证明走的是 dependency-present active 矩阵，不是先前错误路径产生的 inert 假绿。

## 设计核查

### Blocking

无。

### Important

无。

### Minor

无。

## 独立判断依据

- deadline 时序与真实 provider 一致：当前生产分支在扫描结束并释放 flock 后直接把 deadline 并入 rc3；设计的两行替换只把 deadline 分支改为 `continue`。下一轮先执行第二次 nonblocking flock，再命中当前已存在于 `recover_trash`、`active_records`、stale cleanup 和 publish 之前的锁后 deadline 检查。因此“恰两次 flock、第二次前无 sleep、锁后零 record/stale/publish”没有虚构额外状态或接口；`wait=0` 仍由独立条件在首次扫描后退出。
- active/inert/damaged 三路边界明确且与 prototype 一致：顶层 active route 固定到 repo 内普通非 symlink provider；内部 absent surface 清除 provider override 并以真实同构布局执行三入口；存在但类型、语法、source、API 或 seam 损坏时固定 fail closed。invalid CLI、damaged provider、成功摘要的 rc/stdout/stderr shape 已全部钉死。
- 临时树生命周期没有把 cleanup 放在 PASS 之后：设计明确成功前删除并验证物理缺席；失败 trap 的 cleanup failure 追加专属错误并收敛 rc1。holder/waiter/clock marker 失败由 child 非零和父级 startup 标签收口，adapter fixture 改写也有独立失败标签；这与最终 prototype 和熔断融合证据一致。
- 三类 production mutant 都变异真实生产语义 anchor：global overlap、`os.replace(path, trash)` unpublish 转换、bundle 完整规范化；构造先要求目标恰一次并只做该替换，再核 provider 可静默 source。fake-adapter 明确只改测试 request，provider 由 candidate 原样复制，没有冒称 production adapter mutant。四个 recursive child 只能以对应专属首个失败行、空 stdout、无 PASS 被接受，provider-validation 或其他错因不能假绿。
- controller 边界完整：源码清单只含 provider 修改和 assurance 新建两个文件；prototypes、review/manifest/checkout/rollback 日志均明确列为“不纳入源码文件清单”的验收资产。candidate/full/depth-1/offline、六列连续 PASS manifest、clean/diff-check、rollback 恢复两行并删除入口，以及 05 五类资产缺席/后续 05/06/08 顺序门均未漂移；inert PASS 明确不能解锁消费者。

## 最终裁定

**PASS — B=0, I=0, M=0。** 当前 design 已把 requirements 熔断融合后的全部承重裁定转化为可执行组件、时序、错误优先级与验收边界，可以进入门③后续流程。
