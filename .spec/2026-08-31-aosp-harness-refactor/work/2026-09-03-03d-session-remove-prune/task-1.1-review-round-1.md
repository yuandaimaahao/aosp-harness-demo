# Review: task 1.1 03d-session-remove-prune round 1

verdict: PASS
阻断: 0 / 重要: 0 / 次要: 2

## findings

- [M1] `task-1.1-report.md` commands/results — 实现者超出 tasks.md「本任务只做 source 契约与静态门，R3/R4 由任务 1.3 封闭」的口径，自行加跑了冒烟矩阵与双 anchor 注入自检。依据：tasks.md 任务 1.1 头部权威结构末句。评估：自检全部在 `mktemp -d` provider 副本上进行，未触碰已提交模块（UPSTREAM9 diff 为空、单文件提交），结论与我独立复跑结果一致，不损害交付正确性；仅属范围纪律瑕疵。建议：无需修复；任务 1.3 仍以正式矩阵封闭，勿以本自检替代。
- [M2] tasks.md 步骤 2 写明「用 apply_patch 一次性创建」，报告未声明实际落盘工具，产物层面无法核验；但候选为单提交、110 行完整文件、无逐段拼装痕迹（锚点 exact-once、无未定义引用、shfmt/shellcheck 全净），工具偏差不影响交付正确性。建议：无需修复。

## 核对记录

**1. 提交面（worktree 内亲跑）**
- `git log --oneline d8c2baae..HEAD` 恰 1 提交 `0bb53a0`，HEAD=`0bb53a040249ddb5fef1a16c89e6d99a7710cd25` 与报告一致；message `feat(session): add non-creating verified remove module` 为 Conventional。
- `git diff --name-only BASE HEAD` 恰 `common/.harness/lib/session-state-remove.sh`；numstat=`110 0`（110≤110）；`-- $UPSTREAM9` 九文件 diff 为空；`git status --porcelain` 空。**通过**。

**2. source 契约（worktree 内隔离 bash 亲跑）**
- 齐全态（foundation→path→snapshot→signals→remove）：rc0，stdout/stderr 各 0B；`declare -F _harness_session_remove_core` 在场；四个 public API 逐个缺席；`declare -p HARNESS_SESSION_STATE_PROVIDER_VERSION` 非 0（未定义）。
- signals export 缺席态（只 source foundation/path/snapshot + 候选）：rc0，双流各 0B，remove export 缺席。
- guard 语义：候选单行 `declare -F ... || return 0 2>/dev/null || exit 0` 与 signals:16-20 的 if 块两行式同含 `return 0 2>/dev/null || exit 0` early-return，语义等价（source 时 return 生效、直接执行时 fallback exit 0），03c 同款。**通过**。

**3. 静态门（固定 TOOLS 目录复跑）**
- 版本钉死：shfmt v3.14.0、shellcheck 0.11.0。`shfmt -d -i 2 -ci -bn` 无输出 rc0；`shellcheck -x --severity=warning` rc0；`bash -n` rc0；`git diff --check` rc0。
- `rg -cF 'pass  # HARNESS_TEST_MARKER_OS_ERROR'`=1（候选:81，与 path.sh:94 逐字同字面同缩进）；`rg -cF 'pass  # PRUNE_BEFORE_IDENTITY'`=1；`rg -c '^[a-z_0-9]+\(\)'`=1（唯一函数定义）；`setsid`/`HARNESS_SESSION_STATE_PROVIDER_VERSION`/`mktemp` 均无匹配；`rc3|return 3|SystemExit(3)|exit 3` 无匹配（无 rc3 分支）。**通过**。

**4. 语义抽查（mktemp 内亲跑，独立驱动，未用实现者脚本）**
- (a) feature 存在 → rc0、双流 0B、feature 删除、session/project/root 三层全 prune、physical parent 零残留。
- (b) feature 缺失但目录存在 → rc0、空层级全 prune。
- (c) 并发非空（project 下另建 other/feature）→ rc0、sess 被 prune、other 条目保留、非空 proj 保留。
- (d) unsafe ID（`..`、控制字节 `\x01`）→ 各 rc2 + `error: unsafe session state$`（cat -A 无多余字符）；arity 1/3 参同样 rc2 同 stderr。
- (e) EIO anchor 注入（checkpoint 后 `raise OSError(errno.EIO, ...)`）→ rc1、stdout 0B、stderr 逐字 `error: session state operation failed\n`。
- (f) PRUNE_BEFORE_IDENTITY 换入（rename src_dir_fd/dst_dir_fd + 同名 mkdir）→ rc2、stderr 逐字 `error: unsafe session state\n`、新 `sess` 与 `sess.held` 两目录均保留。
- (g) 各分支 stdout 恒 0B；加验 wrong-mode 目录（755）与 wrong-mode feature（644）各 rc2 且不删除，与 smoke.log case7 一致。**全部通过**。

**5. 报告契约**
- 红记录 `task-1.1-red.txt` 恰六行 schema + `assertion=` 行；其 stdout_sha256/stderr_sha256 与 evidence 日志 `red.stdout.log`（0B）/`red.stderr.log`（85B，内容 "No such file or directory"）实际哈希一致。
- green 报告含 task/base/head/files/commands/results 六节；base/head 与 git 实际一致；「红阶段证据: 」行 cat -A 核为路径独占一行、`$` 紧跟行尾、零尾随字符。
- evidence.tsv 19 行、每行恰 3 列（awk NF 核）；逐行重算 sha256/bytes 与实况全部一致（fail=0），含报告文件本身（TSV 生成后未被再改）。
- 报告引用的 smoke.log/anchor-eio.log/anchor-swap.log/export-inventory.log/export-absent-inventory.log/review-package.* 全部存在，内容支撑结论；review-package 生成的 `review-d8c2baae-0bb53a04.md` 存在且 diff 与提交面一致。`review-manifest.tsv` 已创建为空文件（controller 待 PASS 后追加，符合流程）。**通过**。

**6. 自报偏离评估**
1. guard 单行式 —— 语义等价，双态实跑验证，**不影响**。
2. apply_patch vs 文件写入工具 —— 产物面无拼装痕迹，**不影响**正确性（记 M2）。
3. 超范围冒烟+双 anchor 自检 —— 未改已提交模块、证据与我独立复跑一致，**不影响**证据有效性（记 M1）。
4. 首次换入自检 setup 失误修正重跑 —— 最终 anchor-swap.log 与我独立复跑（rc2、双目录保留、逐字 stderr）一致，**不影响**证据有效性。
