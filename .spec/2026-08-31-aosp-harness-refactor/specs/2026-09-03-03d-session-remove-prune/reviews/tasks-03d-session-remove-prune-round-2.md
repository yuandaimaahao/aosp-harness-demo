# Review: tasks 03d-session-remove-prune round 2
verdict: NEEDS_CHANGES
阻断: 0 / 重要: 1 / 次要: 0

## findings

- [I1] tasks.md:16 `EXACT4` 定义与 tasks.md:126（任务 1.3 步骤 8）、:140（任务 2.1 步骤 3）、:184（任务 2.4 步骤 2）三处「逐字等于 `$EXACT4`」断言：`EXACT4` 的文件顺序为 `…remove.sh …session-state.sh tests/test-session-state.sh tests/coverage.d/03d-session-state.md`，但 `git diff --name-only` / `git diff --name-status` 的输出按 git tree 字节序排列，`tests/coverage.d/03d-session-state.md`（'c'）必然排在 `tests/test-session-state.sh`（'t'）之前。依据：我在 mktemp 临时仓库实测同布局四文件提交，`git diff --name-only BASE HEAD` 确定性输出 `common/.harness/lib/session-state-remove.sh`、`common/.harness/lib/session-state.sh`、`tests/coverage.d/03d-session-state.md`、`tests/test-session-state.sh`——与 `$EXACT4` 逐字比较在正确实现上必然假红，任务 1.3 步骤 8 首先触雷。本片文档把「逐字」一律按字节精确执行（如 stdout 逐字），忠实执行者不会自行 sort；结构母版 03c 同位置（03c tasks.md:141）是把 `D\t<path>` 两行按 git 输出序显式写死的，不存在该问题，03d 改用 `$EXACT4` 间接引用后引入了顺序错配（round 1 只核了 EXACT4 成员与上游集合口径，漏核顺序）。建议修法：将 tasks.md:16 的 `EXACT4` 定义重排为 git 输出序（`common/.harness/lib/session-state-remove.sh common/.harness/lib/session-state.sh tests/coverage.d/03d-session-state.md tests/test-session-state.sh`）——EXACT4 全部三处使用均为顺序敏感比较、无 pathspec 用途，重排零副作用；或在三处断言注明「按排序后集合比较」（但偏离本片逐字惯例，不推荐）。

## round1 findings 闭合核对

- **B1（阻断，`os.rename` 误用 `dir_fd`）：已闭合。** tasks.md:113 现为 `os.rename(name, name + ".held", src_dir_fd=parent_fd, dst_dir_fd=parent_fd)`。我在 `mktemp -d` 内实测该调用语义：rename 与随后 `os.mkdir(name, 0o700, dir_fd=parent_fd)` 均成功，`sess.held` 与新 `sess` 两目录并存在，注入后 identity 三方核对（held child fstat vs name 重取 stat）必然 inode 不符 → rc2 + 两目录保留，与步骤 6 (ii) oracle 完全对齐；mutant (a) 叠加 (ii) 时换入目录被误删、oracle 确定性 FAIL，自反证链恢复有效。(iii) 的 `os.mkdir(..., dir_fd=parent_fd)` 合法未动。
- **I1（重要，缺第三文件 setsid 负向断言）：已闭合。** 任务 1.3 步骤 4（tasks.md:107）新增 `! rg -q 'setsid' tests/test-session-state.sh` 并注明「裁定 4 对第三个 shell 交付文件的负向断言」，与 1.1 步骤 2、1.2 步骤 2 构成三环，落实裁定 4 明文承诺。
- **I2（重要，`git add -N` 后直接 commit）：已闭合。** 任务 1.1 步骤 5（:58）、1.2 步骤 6（:90）、1.3 步骤 8（:126）均在 working-tree 断言后、`git commit` 前补了真 `git add <交付文件>`，并统一注明「intent-to-add 不入提交，必须真 add，03c task-1.1 实测教训」；`git add -N` 保留用于 working-tree diff/numstat 断言（intent-to-add 下 `git diff` 可见新文件，断言语义不变），顺序正确。
- **M1（次要，(iii) inventory oracle 口径不清）：已闭合。** tasks.md:117 改为「前后完整 namespace inventory 逐字比较仅差被删的 feature 文件与被删的空 session 目录（该行 setup 含 feature），且 `concurrent` 目录保留」——明确覆盖文件项、说明 feature 来源、保留 concurrent 断言；候选结构段（:102）相应口径「仅差被删 feature 与被删的 session 目录」与之一致，两处不再与 design 测试策略节「只差被删空目录」产生歧义。

## 核对记录

- **B1 实测**：`mktemp -d` 内 `mkdir -p proj/sess` 后 python3 执行 `os.rename("sess","sess.held",src_dir_fd=fd,dst_dir_fd=fd)` + `os.mkdir("sess",0o700,dir_fd=fd)`，两目录均在场，无 TypeError——新写法语义与 oracle 吻合。
- **EXACT4 顺序实测**：mktemp 临时 git 仓库按四文件真实路径布局提交，`git diff --name-only BASE HEAD` 输出序为 remove → aggregator → coverage.d → test-session-state，与 `$EXACT4`（test 在 coverage 前）不一致，确认 I1 为确定性假红而非理论风险。任务 1.2 步骤 6 的两文件断言（remove → aggregator）顺序与 git 输出一致，无同类问题。
- **工具门**：亲跑 `python3 …/skills/spec/scripts/check-tasks.py <tasks.md>` rc=0；`git -C <repo> diff --check` rc=0。任务 2.6 步骤 6 引用的 check-req/check-criteria/check-analyze 脚本均存在于 skills 目录。
- **PLAN 对照**：PLAN.md:53（03d 行验收命令 `./tests/test-session-state.sh` → `RESULT PASS  session state`）、:54（03e 为本片 NEXT，与任务 2.5 `NEXT=03e-claude-session-lifecycle` 一致）、:80（03d 文件边界四件 + 不碰 02 COVERAGE.md）、:130（03d 详情：remove 接口/rc 表/PRUNE_BEFORE_IDENTITY/aggregator preflight-source-marker 顺序）、:186-187（03c→03d、03d→03e 依赖边）、:221（aggregator 缺席覆盖划给 03e/08，本片自愿加严）、:223-234（`--session-provider-fixture` 五值回滚命令表）逐行亲核，tasks 表述全部同构；`--dependency-absent` 外推已在 R8 注明依据。
- **DECISIONS 对照**：2026-09-01 03 round 2 错误表（0/1/2、remove 缺失幂等 0）、round 3（并发非空仍成功不删他项）、收窄 I1-I3（feature 缺失仍 prune）、PLAN v5.3 P5/P2 回流（03d 仅五模块完整才发布）、2026-09-02 03b1 上游集合裁定（后序累加 → UPSTREAM9）、2026-09-03 03c 验收行（03d 启动门已满足）逐条亲核，与 tasks 裁定 3/4/6/7 及 UPSTREAM9 定义一致。
- **真实模块核对**：grep 亲证 foundation 4 函数（含 `_harness_component_is_safe`）、path `_harness_session_path_core`、snapshot 三 export、signals `_harness_session_write_with_signals`——aggregator 点名的 9 个预期 export 名单与真实函数表相符；`pass  # HARNESS_TEST_MARKER_OS_ERROR` anchor 先例见于 path:94、snapshot:159；signals 为早返回 guard + 顶层单函数写法，与任务 1.1 步骤 2 唯一函数门兼容。
- **摘要字面量**：`tests/test-session-state-foundation.sh:274` 为 `RESULT PASS  session state foundation`，任务 2.1/2.2/2.3 的 `RESULT PASS  session state$` 行尾锚必要且正确；rollback 三入口摘要（snapshot safety / snapshot assurance / write interrupts）与真实测试逐字相符。
- **修复副作用扫描**：I2 修复未改变 numstat 预算链（110/50/230/160/400 各处自洽：1.3 步骤 8 working-tree ≤230=205+25、累计 ≤400）；I1 断言挂在步骤 4 静态门区，与 shfmt/shellcheck/bash -n 同组，位置合理；B1 修复未触碰「按候选实际命名对齐」豁免（仍只豁免变量名）。`$tmp` 隐式赋值风格（1.3 步骤 7、2.3/2.4 步骤 2）与 03c 母版 :78/:125/:141 逐字同款，沿 round 1 备案先例不另立 finding。
- **其余 round 1 已核项抽查**：需求并集 R1–R11 映射、孤儿产出链、裁定 2 双探针前提、裁定 3 双 mutant 论证、裁定 6/7 scoped rg 域与顺序门初态、任务 2.6 manifest awk 九行六列校验——本轮重读未见漂移，修复未波及。
