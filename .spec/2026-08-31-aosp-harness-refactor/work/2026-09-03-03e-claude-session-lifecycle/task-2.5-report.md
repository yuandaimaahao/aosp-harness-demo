# 任务 2.5 报告：收敛 manifest、ledger 与终交付（本次仅执行步骤 1–2）

## 范围说明

受控者本次显式限定：只做任务 2.5 的步骤 1–2（写 red、写 green 报告、写 acceptance
报告）；不派 subagent；不改 implementation 源码或 HEAD；不追加
`review-manifest.tsv`（第 8 行由 controller 在独立 review PASS 后写）；不改本片
`ledger.md`。步骤 3–6（controller 追加 manifest 第 8 行、八行 manifest 机械核验、
ledger 完成锚点写入与 sync-ledger、check-tasks/check-req/check-criteria/
check-analyze 与 candidate default/offline 收尾复核）均不在本次执行范围内，留待
controller 后续独立完成。

## 红阶段证据

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03e-claude-session-lifecycle/evidence/task-2.5-red.txt

红阶段失败原因：`acceptance/acceptance-report.md` 在本任务开始前物理缺席
（`test -s` 对不存在文件返回 rc=1，双流即目录本身尚未创建）。同时核对
implementation worktree `HEAD` 逐字等于 `ACCEPTED_HEAD`
（`5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`）且 `git status --porcelain` 为空
（clean），两项前置条件均通过，详见红阶段证据文件。

## 步骤 2：汇总 candidate/full/depth/rollback/order 到 green 与 acceptance

本节汇总任务 2.1（candidate + accepted head 声明）、任务 2.2（完整历史 + depth-1
checkout）、任务 2.3（隔离 rollback）、任务 2.4（04 顺序门核对）四份既有独立
review PASS 报告的机械核对结果，作为终交付证据包。本任务不重跑任何命令，只做
证据抄录与口径对齐；所有下列数字均可在对应任务报告中逐字核对到出处。

### accepted HEAD 与 execution BASE

- ACCEPTED_HEAD：`5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`（= 任务 1.3 TASK_HEAD，
  经任务 2.1 声明、四路 checkout 与本次红阶段核对反复确认逐字一致）
- execution BASE（BASE_SHA）：`cc04996e1e405c00e16be3b57d3ef62d90cd7fd1`
- implementation worktree 当前 HEAD（本次核对时刻）：`5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`，
  与 ACCEPTED_HEAD 逐字相等；`git status --porcelain` 空（clean）

### active 摘要与 checks 计数口径

- 主验证命令 `bash ./tests/test-claude-session-lifecycle.sh` 在 dependency-present
  （真实依赖在场，active）路径下：rc=0、stderr 0 字节、stdout 逐字节精确为
  `RESULT PASS  claude session lifecycle\n`（任务 2.1 candidate、任务 2.2 full/
  depth-1 三个独立 checkout 中均重复验证通过，四份日志互相印证）。
- checks 计数口径（任务 1.3 报告实测，插桩 `printf 'checks=%d\n' "$checks"` 于
  最后一次摘要 `printf` 之前）：
  - dependency-present 完整矩阵：**checks=137**（v1 SessionStart/UserPromptSubmit/
    SessionEnd 全部 case + 七类 fixture 全部 case + 结构核对 + settings.json 校验
    + CLI 非法表 + demo 相关断言累计）。
  - `--dependency-absent` / `absent` fixture legacy surface：**checks=12**
    （absent surface 执行全部 legacy 行为 case，非零 case inert，与 dependency-present
    的 137 不同口径不可混算）。
  - 只有 dependency-present（active）的 137 计入本片验收；absent/legacy-only 的
    12 不计入验收证据、也不解除任何顺序门。

### 七类 fixture

`--session-provider-fixture` 六值 + 默认 dependency-present 完整 provider 矩阵，
合计七类：

1. 完整 provider（dependency-present 主体，v1 全生命周期矩阵）
2. `absent`（aggregator 物理缺席，legacy surface）
3. `missing-foundation`
4. `missing-path`
5. `missing-snapshot`
6. `missing-signals`
7. `missing-remove`

后五类各自在 mktemp fixture 树内按类删除对应上游模块文件，使 aggregator
fail-closed（marker 与四状态 API 同生同灭），三 hook 各自只能落 legacy：rc=0、
stdout `compat: session-provider=legacy` 恰出现 1 次、v1 状态树缺席/为空。

### exact6/400

- BASE..ACCEPTED_HEAD 的 `git diff --name-only` 逐字恰为本片 exact 六文件（排序后
  与固定六文件列表零差异）：
  `claude-code/features/.harness/hooks/check-branch-drift.sh`、
  `claude-code/features/.harness/hooks/load-feature.sh`、
  `claude-code/features/.harness/hooks/session-end.sh`、
  `claude-code/features/.harness/settings.json`、`claude-code/run-demo.sh`、
  `tests/test-claude-session-lifecycle.sh`。
- `git diff --numstat` 总和：**367**（≤400 预算，任务 2.1 实测）。
- 上游十二 tracked 文件在 BASE..HEAD 范围 diff 为空（任务 2.1/2.2/2.3 各自独立
  `sha256sum -c` 复核，测试前后不变）。
- `git diff --check` rc0；worktree clean。

### 三 hook compat 字面量恰 1 处

任务 1.1 报告以子 shell 循环结构核对三个 hook 文件
（`load-feature.sh` / `check-branch-drift.sh` / `session-end.sh`）：

```
rg -oF 'compat: session-provider=legacy' "$h" | wc -l   # 每文件 == 1
```

LOOP_RC=0，三文件逐一通过，`compat: session-provider=legacy` 字面量在每个 hook
文本中恰好出现一处（结构核对）；行为侧由七类 fixture 与 absent surface 的
stdout 出现次数 ==1 计数双重覆盖（任务 1.3 报告口径）。

### candidate（任务 2.1）

零 delta controller 验证：不改源码、不产生提交。审计 candidate（HEAD =
ACCEPTED_HEAD）：工具版本逐字断言 shfmt `v3.14.0`、ShellCheck version field
`0.11.0`；仅对 exact 六文件中五个 shell 文件运行 `shfmt -d -i 2 -ci -bn`、
`shellcheck -x --severity=warning`、`bash -n`，settings.json 经 python3 json
解析核验，全部 rc0/无输出；default 入口固定摘要逐字节匹配；
`bash ./scripts/check.sh --offline` rc0、本入口自动发现恰 1 次；上游十二文件
SHA-256 测试前后不变；累计 diff（name-only 六文件、numstat 367 ≤400、
UPSTREAM12 空、`git diff --check`、clean）全部通过。

### full / depth-1（任务 2.2）

- `git clone --no-local`（完整历史）与真实 `git clone --depth 1 file://...`
  （浅克隆）两个独立 mktemp checkout，HEAD 均逐字等于 ACCEPTED_HEAD。
- 两 checkout 内 default 入口固定摘要逐字节相等、`scripts/check.sh --offline`
  rc0 且本入口自动发现恰 1 次、末行 offline PASS；上游十二文件 SHA-256 测试
  前后不变；`git status --porcelain`/`git diff --stat` 均为空。
- depth-1 额外核：`git rev-list --count HEAD` = 1，`.git/shallow` 非空
  （内容即 ACCEPTED_HEAD 一行）。
- implementation worktree 全程未被写入，HEAD 未变，临时 checkout 已清理。

### rollback（任务 2.3）

从 ACCEPTED_HEAD 在隔离临时 `git clone --no-local` checkout 中构造 exact
rollback commit（`git rm` 两新增文件、`git checkout "$BASE_SHA" --` 恢复四修改
文件到 execution BASE 版本）：`git diff --name-status HEAD~1 HEAD` 恰六行
（2 D + 4 M，路径集合 = exact6）；`git diff "$BASE_SHA" HEAD` 为 0 字节（回退后
六文件与 execution BASE 逐字节一致）。该 clean checkout 中 03b 基础测试、03b1
assurance、03c signals、03d provider 四入口与 `scripts/check.sh --offline`
全部固定摘要逐字 PASS；offline 中本入口（`claude session lifecycle`）发现 0
次；两新增文件物理缺席；checkout clean。验证完毕后临时 checkout 已删除；
candidate/full/depth-1 未被触碰；implementation worktree HEAD/porcelain 全程
未变。

### order（任务 2.4，04 顺序门）

在 03e 尚未产出 dependency-present active 证据入 ledger 前，04 顺序门相关五类
资产（spec 目录、work 目录、`spec/` 分支、git worktree、ledger/dispatch/
execution-base 三类记录）机械核对为物理缺席/零匹配：

- `! ls -d "$PROJECT"/specs/*"$NEXT"` 与 `! ls -d "$PROJECT"/work/*"$NEXT"`
  均 rc0（缺席确认，`$NEXT` 为间接引用的规范 ID 片段变量，不在本报告内联展开）。
- `git show-ref | rg 'refs/heads/spec/.*'"$NEXT"` 与
  `git worktree list --porcelain | rg "$NEXT"` 均零匹配。
- 全部 `specs/*/ledger.md`（18 份，覆盖已有全部 spec 目录）/`work/*/dispatch.tsv`/
  `work/*/execution-base.env` 中对 `"$NEXT"` 字面量 `rg -q` 零匹配。
- 本任务仅只读机械核对，未创建/修改任何 04 顺序门相关资产，也未修改
  implementation 源码或移动 implementation worktree HEAD。

（遵照裁定 6：本报告与 acceptance 报告均只以「04 顺序门」指代该规范 ID 片段的
后续待办，不逐字写出规范 ID 全名；spec 目录已产生的 requirements/design/tasks
等规划文档允许出现该全名，禁令只针对 ledger/dispatch/execution-base 三类记录。）

## 环境不变量核对

- implementation worktree HEAD（红阶段核对时刻）：`5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`，
  与 ACCEPTED_HEAD 逐字相等。
- implementation worktree `git status --porcelain`：空（clean）。
- 本任务（步骤 1–2）未修改 `claude-code/`、`common/`、`tests/` 等 implementation
  源码文件；未追加 `review-manifest.tsv`；未修改本片 `ledger.md`；未派 subagent。

## 状态

DONE

（仅覆盖本次受限范围：步骤 1–2。步骤 3–6 尚未执行，留待 controller 后续独立
完成——包括 manifest 第 8 行追加、八行 manifest 机械核验、ledger 完成锚点写入
与 sync-ledger、收尾复核套件。）

## Commits

无（本任务未产生任何 implementation 源码 commit，仅新增验收资产文件：
`evidence/task-2.5-red.txt`、本报告 `task-2.5-report.md`、
`acceptance/acceptance-report.md`）。

## 一行测试摘要

红阶段 1 项核对 PASS（报告缺席 + HEAD=ACCEPTED_HEAD + clean）；green 汇总
candidate/full/depth-1/rollback/order 四份既有报告的机械核对结果，全部 PASS，
无重跑命令、无新失败。

## 顾虑

本次仅执行步骤 1–2，任务 2.5 全部六步骤尚未完成；manifest 第 8 行、ledger 完成
锚点与收尾复核套件需 controller 后续独立执行方可使任务 2.5 整体进入 DONE。
