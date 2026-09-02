# 2026-09-02-03b-session-snapshot-safety 验收报告

> 本报告由任务 2.6 步骤 2 生成，内容全部提取自各任务报告与日志（路径见各节引用），未凭记忆编造。

## 固定标识

- accepted HEAD: `ab1e870ece16bbc24e1a86f84110366f84aae0d9`（任务 2.1 审计后固定，见 `task-2.1-report.md`；任务 2.2–2.5 均复核 implementation worktree HEAD 逐字等于该值且 clean）
- execution BASE_SHA: `3d15a0d76c2a2e6c8541c5d47001a55f0ca18649`
- exact2 / 400: `BASE..HEAD` 恰好新增两文件 `common/.harness/lib/session-state-snapshot.sh`（208 行）与 `tests/test-session-snapshot.sh`（192 行），numstat 208+192=**400 <= 400**（`task-1.1-report.md`、`task-1.2-report.md`、`task-2.1-report.md` 三处独立核验一致）

## active 摘要、八 anchor 与 signal 协议

- active 摘要: dependency-present 下 `bash ./tests/test-session-snapshot.sh`（default 与 `all`）均 rc0、stderr 0B、stdout 逐字节为 `RESULT PASS  session snapshot safety\n`；`bash ./scripts/check.sh --offline` 中该摘要恰好出现 1 次，末行 `RESULT PASS  aosp-harness offline quality gate`（`task-2.1-report.md` results 表）。
- 八 anchor 精确一次: `HARNESS_TEST_MARKER_CAPTURE_READY` / `SNAPSHOT_MANAGED_BEFORE_OPEN` / `MANAGED_EXPECTED_EUID` / `SNAPSHOT_EXPECTED_EUID` / `SNAPSHOT_BEFORE_OPEN` / `TEMP_BEFORE_PUBLISH` / `PUBLISH_RESULT` / `OS_ERROR` 在生产文本 `session-state-snapshot.sh` 中各恰好 1 次（`task-1.1-report.md` grep -c 表格、`task-1.2-report.md` 步骤 4 rg -c、`task-2.1-report.md` 步骤 3 三处核验一致），均为无副作用文本点、不读测试环境变量；字面 `rg -i fallback` 对两文件零匹配的出处为 `task-1.2-report.md` 步骤 4，另有 `task-1.1-report.md` 的 fallback 路径模式核对（`os.rename(`/`os.replace(`/`os.link(`/`shutil.` 无匹配、`renameat2` 单一调用点）支持同一「无 fallback」结论。
- signal 协议结论：机制约定（design 契约，出处为 design「write signal cleanup」时序图与错误处理表）——write worker 在创建任何同 session `.snapshot-*` owned-temp 之前安装 HUP/INT/TERM handler；首个 handler 入口先原子锁存 first_signal，后续重入只返回；close 前转移 fd ownership，cleanup 错误不遮蔽已锁存信号码（129/130/143）；read worker 不承诺信号码，只承诺 `0|1|2|3` 协议（design 错误处理表末行）。本片基础测试实证（`task-1.2-report.md` 步骤 4/results，覆盖上述契约的真实 Python PID 与首信号锁存子集）：以真实 background 方式验证越过 TEMP barrier 后 `ps` 所见 PID 已是 Python worker 且信号命中同一 PID；该信号/并发/攻击矩阵编译在单次测试运行内部，重复 3 次全部 rc0 且摘要逐字节相同，非 flaky。完整 provider-copy 动态信号矩阵属 03b1，本片只交付 anchor 与基础证明。

## 五个验证任务的关键证据与结论

### candidate（任务 2.1，`task-2.1-report.md`，日志 `evidence/task-2.1-logs/`）

- 固定工具版本逐字核验: shfmt `v3.14.0`、ShellCheck version 字段 `0.11.0`；对 exact 两文件 `shfmt -d -i 2 -ci -bn` 无 diff、`shellcheck -x --severity=warning` 无诊断、`bash -n` 均 rc0。
- default / `all` / offline 全 rc0、stderr 0B；offline 中 snapshot 摘要恰 1 次；四上游文件（foundation/path/03a1-driver/03a2-entrypoint）SHA-256 测试前后 `cmp` 一致。
- `BASE..HEAD` name-only exact 两文件、numstat 400 <= 400、`git diff --check` rc0、八 anchor 各 1 次、3 export 存在 / 4 public API 缺席 / provider marker 0 次、worktree clean。结论: candidate 全绿，固定 accepted HEAD，无需回流 1.1/1.2。

### full checkout（任务 2.2，`task-2.2-report.md`，日志 `evidence/task-2.2-logs/`）

- `git clone --no-local` rc0，full HEAD 逐字 = ACCEPTED_HEAD；default rc0（摘要逐字、恰 1 次），offline rc0（snapshot 摘要恰 1 次、末行 offline PASS），stderr 均 0B。
- 四上游 SHA-256 before/after `cmp` 一致；checkout clean（status/diff 均空）、HEAD 测试后不变；临时 checkout 已删除。结论: 完整历史 checkout 全绿。

### depth-1 checkout（任务 2.3，`task-2.3-report.md`，日志 `evidence/task-2.3-logs/`）

- 真实 `git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE"` rc0；HEAD 逐字 = ACCEPTED_HEAD、`git rev-list --count HEAD` = 1、`.git/shallow` 非空（含 ACCEPTED_HEAD 一行）。
- default 与 offline 全绿（同 2.2 的摘要/clean/上游 SHA 判据），stderr 均 0B；临时 checkout 已删除。结论: depth-1 checkout 全绿，浅克隆形态达标。

### rollback（任务 2.4，`task-2.4-report.md`，日志 `evidence/task-2.4-logs/`）

- 从 ACCEPTED_HEAD clone 后 `git rm` 两目标文件并提交普通 rollback commit `6c90230d8bcd06117db670c745c80442addf1831`（parent 逐字 = ACCEPTED_HEAD，仅存于已删除的临时 clone）；`git diff-tree --name-status` 恰好两个 D（snapshot 模块与测试），无其他条目。
- 在 rollback clean checkout 中：`bash tests/test-session-path.sh`、`session-path-race-driver.py self-test`、`bash tests/test-session-path-races.sh`、`bash ./scripts/check.sh --offline` 全 rc0、stderr 0B；offline 中 snapshot 摘要 0 次、`session-snapshot` 零提及；两目标文件物理缺席；implementation worktree HEAD 未变。结论: exact rollback 独立可回退且上游全部保持绿色。

### order 顺序门（任务 2.5，`task-2.5-report.md`，日志 `evidence/task-2.5-logs/`）

- NEXT1=`2026-09-02-03b1-session-snapshot-assurance`、NEXT2=`2026-09-02-03c-session-write-interrupts`：两者的 `$PROJECT/specs/$id`、`$PROJECT/work/$id` 均 `test ! -e`/`test ! -L` 通过（缺席且非 symlink）；`git show-ref --verify --quiet refs/heads/spec/$id` 均 rc1（分支缺席）。
- `git worktree list --porcelain` 对两者均无 branch 行、无约定 worktree 绝对路径、全文无 id 命中；限定域 rg（仅既有 `specs/*/ledger.md` 与 `work/*/execution-base.env` 存在文件）对 `dispatch.*$id|execution BASE.*$id|spec/$id` 均零匹配、双流空。结论: 03b1 与 03c 的四类资产全部机械核对缺席，顺序门保持关闭。

## review-manifest 现状

`review-manifest.tsv` 当前 7 行（快照见 `evidence/task-2.6-logs/manifest-rows.txt`）：seq 1–7 对应 task-1.1/1.2/2.1/2.2/2.3/2.4/2.5，六列齐全、base/head 相邻连续（首行 base = BASE_SHA、行 2 head = ACCEPTED_HEAD、行 3–7 base=head=ACCEPTED_HEAD）、reviewer 非空（opus/kimi），第 6 列全部为 **PASS**。第 8 行（task-2.6）由控制器在独立 review PASS 后追加并做 awk 全量核验（任务 2.6 步骤 3–4，不在本实现范围）。

## R1–R9 覆盖映射

| 需求 | 覆盖证据（引各任务验证结论） |
|---|---|
| R1（source 零副作用/inert surface） | `task-1.1-report.md`: source 四态（none/validate/path/both）rc0、export/inventory 无增量、3 export 仅 both 态出现、4 public API 与 provider marker 全缺席；`task-1.2-report.md`: 隔离 provider-absent default/flag/all 同一 inert surface、failure-stdout/source-rc self-disproof 正确检出违约 |
| R2（held capture + managed fd 链） | `task-1.1-report.md`: runtime 与固定 208 行 blob 逐字相同、官方 192 行 prototype test 打在目标 runtime 上 rc0、stdout 逐字固定摘要、stderr 0B；`task-1.2-report.md`: active 测试矩阵编译在单次运行内部、3 次重复全 rc0（具体 case 粒度以测试 blob 为准，源报告未逐项列举） |
| R3（verified read oracle 与内容表） | `task-1.2-report.md`: managed/snapshot 攻击表 case 编译在单次测试运行内、3 次重复全 rc0（具体损坏类别与 rc 粒度以测试 blob 为准，源报告未逐项列举） |
| R4（create-once publish + write signal cleanup） | `task-1.1-report.md`: `renameat2`/`RENAME_NOREPLACE` 单一调用点、无 `os.rename/replace/link/shutil` fallback；`task-1.2-report.md`: 真实 Python PID（TEMP barrier）与首信号锁存 case PASS；design 信号时序图与错误处理表 |
| R5（EEXIST 与并发 winner） | `task-1.2-report.md`: 同/异值并发与 winner/victim/temp 前后比对 case 编译在单次测试运行内、3 次重复全 rc0、`failures` 计数器归零收敛到最终 PASS（具体 rc 分布以测试 blob 为准，源报告未逐项列举） |
| R6（managed/snapshot 攻击 fail closed） | `task-1.2-report.md`: managed 三层 static 表、后缀不匹配、snapshot symlink/hardlink/directory/wrong-mode 与内容表均 fail closed，victim 不变；七 anchor + OS anchor 各精确一次留给 03b1 |
| R7（默认基础测试） | `task-1.2-report.md`: argv 全表（none/all/`--dependency-absent` rc0 固定摘要；unknown/extra/flag 带值 rc1 无 PASS）、真实 provider 缺席 inert、strict misuse 零 state；`task-2.1-report.md`: candidate default/all/offline 全绿 |
| R8（candidate/full/depth-1 验收） | `task-2.1-report.md`（candidate 全门）、`task-2.2-report.md`（full）、`task-2.3-report.md`（depth-1，count=1、shallow 非空）；exact2/numstat 400、固定版本、shfmt/ShellCheck/bash-n/diff-check/clean 全过 |
| R9（rollback 与顺序门） | `task-2.4-report.md`: rollback exact 两个 D 下 03a/03a1/03a2/offline 全绿、snapshot 发现 0 次；`task-2.5-report.md`: 03b1/03c spec 目录/分支/worktree/ledger/dispatch/BASE 记录全部机械核对缺席 |

## 结论

五个验证任务（candidate/full/depth-1/rollback/order）全部 PASS，八任务前七项 review 全部 PASS；03b 交付锚点 `session-snapshot-core-v2` 仅由 exact 两文件与固定基础摘要组成，不含 03b1 provider-copy assurance 入口。后续 manifest 第 8 行追加、awk 全量核验、mark/ledger/sync 与终门重跑由控制器按任务 2.6 步骤 3–6 执行。
