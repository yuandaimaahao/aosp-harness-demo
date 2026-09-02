# 2026-09-02-03b1-session-snapshot-assurance 验收归档

## 改了什么

新增 exact 单文件（BASE `8a164f212c398a95703a38fb919af2b31c6e1662` → accepted HEAD `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`，346 行 ≤400）：

- `tests/test-session-snapshot-assurance.sh`（346 行）：默认发现、shfmt-clean 的 snapshot assurance 矩阵，固定摘要 `RESULT PASS  session snapshot assurance`（PASS 后两空格逐字），只接受无参数/`all`/唯一 `--dependency-absent`。只复制 03b provider 到 mktemp 隔离副本并在八个无副作用 anchor（CAPTURE_READY / SNAPSHOT_MANAGED_BEFORE_OPEN / MANAGED_EXPECTED_EUID / SNAPSHOT_EXPECTED_EUID / SNAPSHOT_BEFORE_OPEN / TEMP_BEFORE_PUBLISH / PUBLISH_RESULT / OS_ERROR）注入攻击：held capture fd 同名路径重建、managed 三层与 snapshot leaf 的 stat→open mutation（link/inode/missing × read/write）、无特权 wrong-owner、强制一字节 short read、真实 EIO、libc 缺 symbol/ENOSYS、确定性 EEXIST 后 same/different/disappear/unsafe，以及 write child 在 TEMP_BEFORE_PUBLISH barrier 后的 HUP/INT/TERM 清理（含 post-close、signal+cleanup-close-error 五次 close、rename 未提交/已提交窗口）。注入前核对八 marker 与 `renameat2` 各精确一次、无 rename/link fallback；provider 物理缺席时三种调用走同一零 active case inert 摘要 rc0；provider 存在但类型/symlink/`bash -n`/source/三 export/anchor/renameat2 次数损坏一律 fail closed rc1 无 PASS。断言计数 241 = prototype 240 + `ASSURANCE_UNLINK_LOG` rename 已提交窗口旧 temp 名 ENOENT oracle 1。

七任务全部完成，review manifest 七行六列连续（awk 全量核验 rc=0），每任务独立 review 均 round1 一次 PASS。candidate（2.1）/full 181-commit（2.2）/真实 `git clone --depth 1 file://`（2.3）/隔离 rollback（2.4）/03c 顺序门七项（2.5）零 delta 验证全 PASS；实现以 fast-forward `c7a18ed` 合入 main，post-merge 回归（default + offline，发现恰一次）全绿；worktree 与分支已清理零残留。

执行期一处 spec 修订记录：tasks.md E3 export 检查原行文 standalone source 与健康 provider 矛盾（provider 三 export 以 foundation/path 函数已声明为条件），实证后修订为先 source 两个上游 lib 再 `declare -F`（与 active 流同环境），经任务 1.1 独立 reviewer 复核确认最小且正确、fail-closed 七类语义不变。

## 验收证据路径

- 验收报告：`.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/acceptance/acceptance-report.md`
- 任务报告/日志/review：`.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/`（task-*-report.md、task-*-review-round-*.md、evidence/、review-manifest.tsv）
- ledger：`.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-02-03b1-session-snapshot-assurance/ledger.md`

## 适用范围

本片只交付 assurance 测试，不修改 03b snapshot provider 及任何前序模块/测试，不设置 `HARNESS_SESSION_STATE_PROVIDER_VERSION`、不发布运行时 API。03c（Bash signals facade）启动门——dependency-present 完整矩阵（checks=241）、exact1/400（346）、full/depth-1/offline 与回滚证据入 ledger——已由本验收满足并记录于 DECISIONS.md；inert PASS 未作为本片任何验收证据。03d/03e 继续全部缺席。
