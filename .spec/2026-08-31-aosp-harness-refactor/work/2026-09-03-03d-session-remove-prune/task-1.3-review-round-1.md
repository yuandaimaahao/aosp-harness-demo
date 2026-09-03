# Review: task 1.3 03d-session-remove-prune round 1
verdict: PASS
阻断: 0 / 重要: 0 / 次要: 0

## findings

- 无阻断/重要/次要发现。以下两点为记录性观察，不构成 finding：
  - 报告第 49 行红证据路径与「红阶段证据: 」标签同行、路径后 `$` 紧跟行尾零尾随字符——与 task-1.1/1.2 已 PASS review 接受的格式逐字同构（task-1.1-review-round-1.md:37 的口径即此格式），符合先例解释。
  - fixture 的「完整五 API predicate 为 false」以「哨兵占名 + source rc 非零 + marker ≠ 1」合取判定（test-session-state.sh:86-94），与 design「consumer 忽略任何已加载前序函数」的裁定一致，非语义缺口。

## 核对记录

**1. 提交面 — 全过。** TASK_BASE `df38c345`..HEAD 恰 1 提交 `test(session): add complete provider integration matrix`（Conventional），恰 `tests/coverage.d/03d-session-state.md` + `tests/test-session-state.sh` 两新文件（git tree 序 fragment 在前）。execution BASE `d8c2baae`..HEAD name-only 逐字等于 EXACT4 四文件（git 输出序），numstat 110+46+18+204=378 ≤ 400。`-- $UPSTREAM9` 空、`git status --porcelain` 空、`-- tests/COVERAGE.md` 空。HEAD 逐字 = `388a83d5816659428e510bd9540d2a88cc2613e7`。

**2. default/all 实跑 — 过。** worktree 内两跑各 rc0，stderr 各 0B；`printf 'RESULT PASS  session state\n' | cmp -s - out` 通过；od 核出双空格（`P A S S ␣ ␣ s`）与单 `\n` 结尾；default 与 all 的 stdout cmp 逐字一致。

**3. checks 探针 — 过。** 仓库内 `mktemp -d "$PWD/.count.XXXXXX"` 副本，python3 rindex 定位末处 printf 字面量前插 `printf 'checks=%d\n' "$checks" >&2`：default 与 all 各 rc0、stdout 仍逐字固定摘要、两 err 逐字一致均 `checks=72`（与报告 N=72 一致）。provider-absent clone（删 aggregator）index 首处插两空格缩进 `${checks:-0}` 探针：default rc0、stdout 逐字 inert 摘要、err 逐字 `checks=0`——亲跑复现。

**4. 矩阵覆盖 vs R3/R4/R7/R8 — 过（逐行读 + 抽查重造）。** feature 存在删除+三层 prune（:148-151，inv_eq 空）；缺失幂等仍 prune（:153-159，借 path core 造安全空目录后 prune 至空）；并发非空（:174-194，绝对 inventory `.\n./project\n./project/concurrent\n` 等价且强于前后 diff 口径，concurrent 保留、root 未被尝试）；rc 表：合法 0/双流空、unsafe ID :160 与 unsafe 对象 :162-163 rc2 固定 stderr 且对象保留、EIO anchor 注入 :190 rc1 固定 stderr、无 rc3 rg 断言 :116-117；换入攻击 :191-192 rc2 + 双目录保留；EIO/swap/conc 注入均用 `src_dir_fd/dst_dir_fd` 的 os.rename 与 dir_fd mkdir（:187-188）；发布面：marker=1 :122、五 API declare -F 循环 :123-126、四转接各一行 rg（^…$ 双锚）:121、无逻辑副本 :119-120、path/write/read 透传 :153-171、remove 透传贯穿全矩阵；六类 fixture :78-100+:196-198（五 missing-* 断言双流空，aggregator-absent 不断言双流）；argv 非法表 5 行 :135-139。独立抽查（mktemp 内 source aggregator 实调）：write→remove 三层全 prune 至 root 消失 rc0；path 造空目录后 remove 缺失幂等 rc0 仍 prune；mkdir feature 造 unsafe 对象 rc2 `error: unsafe session state` 且对象保留——三抽查全复现。

**5. 双 mutant 亲跑 — 过。** (a) `git clone --no-local` 副本删 `PRUNE_BEFORE_IDENTITY` 后 stat 重取+identity 核对段（assert 替换源 exact-once）→ rc1、stdout `RESULT FAIL session state checks=72 failures=3` 无 PASS，stderr 恰 `swap rc want=2 got=0` / `swap stderr bytes want=0 got=1` / `swap both dirs retained want=yes got=no` 三行；(b) feature ENOENT 分支改 `raise SystemExit(0)` → rc1、`failures=1`、stderr 恰 `missing feature still prunes want=0 got=1` 一行。均与报告及 mutant-a/b.*.log 一致；注入仅发生于临时 clone，worktree porcelain 注入后仍为空，临时目录已删。

**6. inert surface — 过。** provider-absent clone 无参数/all/`--dependency-absent` 三面各 rc0、stdout 逐字同一摘要、stderr 0B（亲跑）；signals export 全局改名 clone default 同口径（亲跑）；dependency-present worktree 下 `--dependency-absent` 同一 inert 摘要 rc0 0B（亲跑）。

**7. 静态门 — 过。** 固定 TOOLS 逐字核 shfmt `v3.14.0`、ShellCheck `version: 0.11.0`；三 shell 文件 `shfmt -d -i 2 -ci -bn` 无输出、`shellcheck -x --severity=warning` rc0、`bash -n` rc0、`git diff --check` rc0；`rg setsid` 三文件零命中；`rg -cF "printf 'RESULT PASS  session state\n'"` = 恰 2（:18 inert、:204 active 末行），结构注释（:3-5）只写摘要文字不含调用字面量；`$` 行尾锚用于四转接断言（:121，^…$ 成对），其余 rg 为 -cF 字面量无需锚。

**8. coverage fragment — 过。** 18 行 ≤ 25，03d 独占声明在场，COVERAGE.md 零变更（git 核）；抽查 R3（unsafe id/object rc2、EIO 行、无 rc3 → :160/:162/:190/:116）、R4（幂等 prune + 并发非空 → :158-159/:193-194）、R7（marker/五 API/四转接/透传 → :121-126/:153-171）三行与测试实际区段真实对应。

**9. 报告契约 — 过。** red 记录六行 schema + assertion 共 7 行，cat -A 全行 `$` 收尾零尾随；green 报告 task/base/head/files/commands/results 六节齐（外加 M2 节，属简报要求的正面落实）；红证据路径行 cat -A 核 `…red.txt$` 零尾随，格式同 1.1/1.2 已接受先例；evidence.tsv 恰 28 行，逐行重算 sha256/bytes **全 fresh**（all_fresh_bad=0）；报告引用日志（default/all/count-*/argv-bad/fixtures/mutant-a.*/mutant-b.*/absent/shfmt/shellcheck/bashn/red.*）全部存在且在包内；M2 行数核实：run_fixture 78–103 = 26 行、六类循环 195–198 = 4 行、注入区段 173–189 = 17 行，与报告逐字一致。

**10. 偏离评估 — 可接受。** (1) 对照 tasks 候选结构段逐项点人头：CLI 四态/argv 非法表 5 行、依赖探测、inert 出口（printf 第 1 处）、remove 矩阵四行（含双 inventory 口径）、rc 表四态+无 rc3、EIO/swap/conc 三注入行、发布面六项（marker/五 API/四转接/无副本/透传四例/validate）、六类 fixture、active 出口（printf 第 2 处）、字节比较禁 command substitution——oracle 用例零缺失；压缩仅限 CLI 单 case 键合并（`$#:${1-}:${2-}` 模式表）、helper 合并（run_expect/tree_expect/stream_is/inv_eq）与注释精简，不涉 oracle 语义。(2) `run_expect` 的 stderr 期望带 `\n`（如 `'error: unsafe session state\n'`）经 `stream_is` 的 `printf '%b'` 落文件后 cmp 比字节，与简报「stderr 逐字 `error: unsafe session state\n`」的契约精确对齐，修复合理。
