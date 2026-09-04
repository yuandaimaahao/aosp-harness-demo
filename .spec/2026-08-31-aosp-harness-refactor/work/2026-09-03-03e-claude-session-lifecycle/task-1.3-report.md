# 任务 1.3 报告：一次性交付完整默认发现生命周期测试

## 结论

Status: **DONE_WITH_CONCERNS**（步骤 2–6 全部完成并核验通过；步骤 7 的独立 diff review 与
`review-package.sh`/manifest 落盘按 brief 由 controller 负责，本次续跑未执行——见「顾虑」）。

## Commits

- `5b2e66b3be9079aa31b4b6eba2da88888a3aaeba` — `test(claude): add session lifecycle matrix`
  （单文件新增 `tests/test-claude-session-lifecycle.sh`，176 insertions）

TASK_BASE（任务 1.2 HEAD）= `a8d03d1d59b42f2503a2dc3a2e906c9204efafb3`
TASK_HEAD（本任务 HEAD）= `5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03e-claude-session-lifecycle/evidence/task-1.3-red.txt

## 一行测试摘要

`bash ./tests/test-claude-session-lifecycle.sh` → `RESULT PASS  claude session lifecycle`，rc=0，
dependency-present 完整矩阵 checks=137；`--dependency-absent`/`absent` fixture legacy surface
checks=12（非零 case inert）。

---

## 步骤 2：候选创建与行数预算核验

- 承接现状（未提交候选，174 行）基础上，仅补一处「rule 3」要求但候选中缺失的断言：R3 设计的
  `write` rc 分支表 `rc3`（异值冲突：基线已在场且值不同，拒绝改写、stderr 报错、继续 rc0）此前
  完全没有可达路径被覆盖——自然场景下 `read` 若真报告基线在场（rc0），hook 根本不会调用
  `write`；唯一能让真实 `write()` 撞见"已存在且值不同"的方式是让 `read` 谎报缺席（rc3）。为此加了
  一段 **shim aggregator**：复制真实 `session-state.sh` 到 `$tmp/real-agg.sh`，向树内的
  `session-state.sh` 追加一行 `harness_session_state_read() { return 3; }`（source 真 provider 后
  再覆写，四个真实 API 中只有 `read` 被替换，`write`/`path`/`remove` 仍是真实实现），复用已建立
  基线的会话 `s-startup`（值 `dev-sidebar`）、并把 `CURRENT_FEATURE` 保持在上一步测试已置的
  `dev-next`（无需额外赋值行），断言：`hook_expect` rc0/marker=0，且
  `state/$pid/s-startup/feature` 仍为 `dev-sidebar`（未被改写）、stderr 恰好出现一次
  `已存在且值不同`；随后立即用保存的 `$tmp/real-agg.sh` 还原树内 aggregator。
- 新增净 2 行（`tests/test-claude-session-lifecycle.sh:112-113`），把候选行数从 174 推到
  **176**（预算上限，余量归零）。
- 行数断言：`wc -l tests/test-claude-session-lifecycle.sh` = `176` ≤ 176 ✅
- 摘要字面量断言：`rg -cF "printf 'RESULT PASS  claude session lifecycle\n'"` = `2` ✅
- **区段起止行号（供 green 报告口径）**：
  - v1 SessionStart 矩阵区段：**94–120 行**（27 行；含新增的 rc3 shim 冲突用例 112–113 两行）——
    从 `mk_tree v1` 起，经 startup/fork/clear/resume 四 source 建基线循环、steady stdout、
    project-id/link、five-api predicate、同值幂等、compact 缺失报错、"基线在场不改写"、
    本次新增"write rc3 异值冲突"、illegal stdin 三行落 legacy，到 `rm -f -- "$snap"` 结束。
  - 七类 fixture 表驱动机制：`fixture_case()` 函数定义 **82–85 行**（4 行）；CLI 顶层单跑分派
    `--session-provider-fixture` **87–88 行**；`absent`/`--dependency-absent`/真实依赖缺席自动
    分流 **89–92 行**；主动路径（dependency-present）内跑第二至七类（`absent` +
    missing-foundation/path/snapshot/signals/remove）的表驱动循环 **147–149 行**（3 行）。
  - `legacy_surface()`（七类 fixture 与 absent surface 共用的行为断言体）：**61–81 行**（21 行）。

## 步骤 3：固定工具版本与静态检查

- `"$TOOLS/shfmt" --version` = `v3.14.0` ✅
- `"$TOOLS/shellcheck" --version` 含 `version: 0.11.0` ✅
- `"$TOOLS/shfmt" -d -i 2 -ci -bn tests/test-claude-session-lifecycle.sh` → 无输出（rc0）✅
- `"$TOOLS/shellcheck" -x --severity=warning tests/test-claude-session-lifecycle.sh` → rc0 ✅
- `bash -n tests/test-claude-session-lifecycle.sh` → rc0 ✅
- `git diff --check` → rc0，无输出 ✅
- **回归验证（rc3 断言有效性自证）**：临时破坏 `load-feature.sh` 的 rc3 处理分支（还原自
  `/tmp/load-feature.sh.bak`），重跑候选，`start write conflict`/`start conflict kept + logged`
  两个新断言按预期 FAIL（连同其下游因基线被误改写而级联 FAIL 的用例，共 8 处 FAIL，
  `checks=137 failures=8`），证明新增 oracle 确实检出该回归；随即用备份还原 `load-feature.sh`，
  `git diff --stat` 确认无残留改动。

## 步骤 4：dependency-present 实跑

- 无参数、`all` 两次独立运行：均 rc0、stdout 逐字节等于
  `printf 'RESULT PASS  claude session lifecycle\n'`、stderr 0 字节。
- checks 计数探针（仓内 `mktemp -d "$PWD/.count.XXXXXX"` 内的候选副本，用 python3 `rindex`
  定位最后一处摘要 `printf` 并在其前插入 `printf 'checks=%d\n' "$checks" >&2`）：default 与
  `all` 两次探针跑的 stderr（`probe-default.err`/`probe-all.err`）`cmp -s` 逐字一致，且各自匹配
  `^checks=[1-9][0-9]*$`；**实际 N = 137**（dependency-present 完整矩阵：v1 SessionStart/UPS/
  SessionEnd 全部 case + 七类 fixture 全部 case + 结构核对 + settings.json + CLI 非法表 + demo
  收敛断言的 `check_eq`/`hook_expect` 内部 `check_eq` 总次数）。探针目录已删除。
- argv 非法表五行：`--bogus`、`all extra`、`--dependency-absent=x`、`--session-provider-fixture`
  （缺值）、`--session-provider-fixture bogus` —— 均 rc1、stdout 0 字节（无 PASS）。
- 六个合法 `--session-provider-fixture` 取值（missing-foundation/path/snapshot/signals/remove/
  absent）：逐个 rc0、stdout 逐字节等于同一固定摘要、stderr 0 字节。

## 步骤 5：dependency-absent 隔离实跑

- `git clone --no-local . "$tmp/r"` 后以 `cp` 放入本任务候选（clone 只含已提交内容，候选此前
  未提交），删除 `$tmp/r/common/.harness/lib/session-state.sh`；无参数/`all`/`--dependency-absent`
  三次运行均 rc0、stdout 逐字节等于同一固定摘要、stderr 0 字节。
- 非零 case 机械核验：候选副本用 python3 `index` 在**第一处**摘要 `printf`（legacy surface 出口）
  前插入 `printf 'checks=%d\n' "${checks:-0}" >&2`，跑 default，双流落
  `$tmp/absent-probe.out`/`$tmp/absent-probe.err`；rc0、stdout 匹配同一摘要、
  `$tmp/absent-probe.err` 匹配 `^checks=[1-9][0-9]*$`；**实际 N = 12**（absent surface 执行的全部
  legacy 行为 case：SessionStart 覆盖写快照+sync+message+marker、UPS 无漂移/漂移两行告警、
  SessionEnd 幂等删除+重复幂等 等，对应 `legacy_surface()` 体内的 `check_eq`/内部
  `hook_expect` 次数），确认非零 case inert（与 03d 的 checks=0 口径不同）。
- 另起 `git clone --no-local . "$tmp/e"`，同样 `cp` 候选，删除
  `common/.harness/lib/session-state-remove.sh`，跑 default：rc0、同一固定摘要、stderr 0 字节
  （missing-remove 自动落 legacy）。
- 结束后两个 clone 与临时目录已 `rm -rf`。

## 步骤 6：提交与累计核验

- `git add -N` 后 working-tree `git diff --name-only` 恰为
  `tests/test-claude-session-lifecycle.sh` 单文件，`git diff --numstat` 总和 = 176 ≤ 176。
- 真提交：`git commit -m "test(claude): add session lifecycle matrix"` →
  `5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`。
- 对 `BASE_SHA=cc04996e1e405c00e16be3b57d3ef62d90cd7fd1` 累计核验：
  - `git diff --name-only "$BASE_SHA" "$TASK_HEAD"` 逐字等于 `EXACT6`（六文件，顺序一致）✅
  - `git diff --numstat "$BASE_SHA" "$TASK_HEAD" | awk '{s+=$1+$2} END{print s+0}'` = `367` ≤ 400 ✅
  - `git diff --name-only "$BASE_SHA" "$TASK_HEAD" -- $UPSTREAM12` 为空 ✅
  - `git status --porcelain` 为空 ✅
- 残留 `.count.zp1lck/` 已在收尾时 `rm -rf` 删除；最终 `git status --porcelain` 确认工作树干净。

## 顾虑

1. **步骤 7（独立 diff review / `review-package.sh` / manifest 落盘）未执行**：brief 步骤 7 描述的
   是 controller 侧动作（生成 evidence package、取得独立 reviewer PASS、由 controller 写
   `review-manifest.tsv` 一行）。本次续跑范围（用户指令）明确为「按 brief 步骤 2→3→4→5→6 顺序
   跑，最后写 report」，未要求本次执行步骤 7，故未调用 `review-package.sh`，也未追加
   `review-manifest.tsv` 行。这是本次范围内的已知缺口，需 controller 后续按步骤 7 补齐并给出
   PASS 后再 `mark 1.3`。
2. rc3 异值冲突的 shim aggregator 测试把候选行数恰好推到硬上限 176（余量归零）；后续若还有任何
   遗漏断言需要补充，将没有行数空间，需先考虑拆分或压缩非 oracle 部分（不能压缩 oracle 语义）。
