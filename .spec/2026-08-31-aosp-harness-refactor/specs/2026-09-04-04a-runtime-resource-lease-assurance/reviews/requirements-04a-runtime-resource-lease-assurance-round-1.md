# 04a requirements review — round 1

结论：**FAIL**

计数：Blocking **2** / Important **2** / Minor **0**

审查基线：`PLAN.md` v5.9、`DECISIONS.md` 的 04 验收与 v5.9 裁定、04a ledger、`requirements-prototype-boundary.md`、04 已验收 requirements/decision、当前 336 行生产 provider，以及 04 转交的 fixed-shfmt 398 行 assurance prototype。

## Blocking

### B1 — `2/2 + 398/0` 不满足项目仍在生效的 400 行 churn 硬门

`PLAN.md:70` 把上限定义为“400 行新增+删除”，并指定以 `git diff --numstat` 机械统计；但 `requirements.md:19,35,46` 与 `requirements-prototype-boundary.md:55` 改按 additions-only 计算 `2+398=400`。对当前已实证的相邻修复，numstat 是 provider `2/2` 加 assurance `398/0`，按 PLAN 的新增+删除口径实际为 `2+2+398=402`，不是 400。requirements 不能在单片内用“本项目 additions 预算口径”覆盖仍明确写在 PLAN 的全局门，因此 R1/R9、验收清单和 P5 结论相互矛盾，当前 exact2 边界不可验收。

必须在继续 design 前二选一并形成一致的机械公式：把 fixed-shfmt assurance 收敛到至多 396 个新增行，使总 churn `2+2+396<=400`；或回到 PLAN 门，经正式增量 review 把全项目的预算定义改成 additions-only。不能只改报告中的分母。

### B2 — 398 行转交原型并未执行 requirements 声称的完整矩阵，因而不能作为 exact-size 可实施证据

当前 prototype 虽覆盖主体 request/root/concurrency/record/I/O 路径，但逐行核对后至少缺少以下承重 oracle：

- R3/验收清单要求 damaged provider 覆盖非普通文件、语法与独立 source failure、两个 public API 不齐、seam 非精确一次；prototype 只覆盖语法损坏、缺 seam 和 symlink，没有目录/其他非普通文件、语法合法但 source 失败、缺单个 API、重复 seam。
- R3 要求 provider 物理缺席时默认、`all`、`--dependency-absent` 三入口都跑同一 inert oracle；prototype 的物理缺席 surface 只跑默认入口，`--dependency-absent` 则在检查 provider 之前无条件 PASS，`all` 的物理缺席路径也未执行。`--dependency-absent=value` 亦未单列反证。
- R4 要求同 owner 的同键异 mode 立即 rc2；prototype 的 `a-mode.tsv` 只用于“不同 owner 异 mode”竞争，没有同 owner 异 mode调用。
- R8 和第三个不变量要求 tracked provider 前后 SHA-256、docs/base-test/外部状态不变且所有资产位于 repo root 外；prototype 没有任何前后 hash/fingerprint，首个 `mktemp -d` 还继承调用方 `TMPDIR`，没有证明其绝对路径位于 repo root 外。
- R8 要求每个 mutant 非零、stderr 含 `FAIL ` 且双流无 PASS；prototype 只检查非零和 stderr 中存在 `FAIL `，没有检查 stdout/stderr 均不含 PASS。

这些不是后续实现细节：requirements 的确认依据、R9 sizing 门和 PLAN v5.9 都把“398 行 runnable 完整矩阵”作为边界成立的事实。应先修订 prototype，使上述 oracle 真实执行，并以 fixed tools 重跑 active/all/真实 absent 后重新给出行数；结合 B1，现有 398/400 证明不能进入 design。

## Important

### I1 — assurance 自身失败路径的可观察双流未钉死

`requirements.md:23` 对 invalid CLI 和 damaged provider 只规定 rc1 与“无 PASS”，`requirements.md:48` 又要求“核对 rc 和双流”，但没有给出应当为空还是固定 `FAIL ...\n`。R8 的 mutant 同样只说 stderr“含 `FAIL `”和“无 PASS”，没有说明 stdout 是否必须为空、PASS 禁令作用于哪条流、是否允许额外诊断。当前 prototype 实际对 invalid CLI 要求双流空，而 damaged provider/mutant 使用 stderr `FAIL ...`，两者是不同契约。

应在 R3/R8 分别钉死：invalid CLI 的 stdout/stderr；damaged dependency 的 stdout 与 stderr 形状；mutant 的 rc、stdout、stderr 及 PASS 禁令范围。否则 full/depth/rollback 的逐字节结果和独立 reviewer 无法作同一判断。

### I2 — “adapter-alias production mutant”与本片无 adapter 实现的边界冲突

R8 把四类都称为 production mutant，但 `requirements.md:66-67` 明确本片不新增或修改 adapter；当前 prototype 的 adapter 分支也只是原样复制 provider，再通过 `HARNESS_ASSURANCE_MUTANT_CHILD=adapter` 改写测试 request 的 instance ID，并没有变异任何 production adapter。这个自反证可以有价值，但不能声称杀死了 production adapter mutant。

应把它准确命名并固定为“fake-adapter key-selection/test-fixture mutant”，说明被变异的可执行适配层 fixture 与预期失败点；若坚持 production mutant，则必须先有实际 production adapter 作为 mutation target，这会越出本片边界。

## 已确认无冲突的部分

- Deadline 修复本身可实现：当前 provider 在扫描后分支前已经释放本轮 flock；到期 `continue` 会立即进入下一轮无 sleep 锁尝试。若第二次取得锁，既有锁后 deadline 检查位于 `recover_trash`/`active_records`/publish 之前，可同时保证 rc3、零 record 读取、零 stale 回收和零发布；`wait=0` 仍走首次尝试后的直接退出分支。
- R1-R10 已覆盖 candidate、full-history、真实 file-URL depth-1、rollback、NEXT 五类门，review manifest 连续性和 fixed-tool 门也已写入；R10 正确要求 dependency-present active 证据，未把 inert PASS 当作 05/06/08 的解锁证据。
- 四个不变量覆盖 public contract 零漂移、deadline 后零状态读取/发布、攻击零外部修改，以及 04/03e/offline 零回归；问题在于 B2 所述的 prototype 尚未提供其中第三项的可执行证据。

## 最终裁定

**FAIL — B=2, I=2, M=0。** 先闭合预算口径和 runnable prototype 证据，再进入下一轮 requirements review；deadline 控制流方案本身无需回退。
