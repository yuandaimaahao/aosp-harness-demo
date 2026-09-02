# requirements review — 2026-09-02-03b1-session-snapshot-assurance round 1

- 审查对象：`.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-02-03b1-session-snapshot-assurance/requirements.md`（工作树 70 行版本，相对 main ffddb95 已修改未提交）
- 对照材料：PLAN.md v5.7（03b1 节、全局约束、依赖契约、回滚矩阵）、DECISIONS.md（41 行全表）、03b requirements.md / design.md、main 上 `common/.harness/lib/session-state-snapshot.sh`、prototype commit `cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e` 及 round3 sizing evidence
- 审查人：独立文档审查（全新上下文，非起草者/控制器）

## 结论

**PASS** —— 阻断 0 / 重要 1 / 次要 3

草稿可进入下一轮；建议在 design 前修掉重要 finding F1（上游 tracked 文件集合不一致），次要 finding 可一并顺手处理。

## ① 规格符合性（对 PLAN v5.7 03b1 节逐点）

| PLAN 03b1 要求 | 判定 | 依据 |
|---|---|---|
| 只新增 shfmt-clean `tests/test-session-snapshot-assurance.sh`，不修改 snapshot provider | ✅ | R1「只新增一个默认发现且 shfmt-clean…不修改 session-state-snapshot.sh 及任何前序模块或测试」 |
| provider-copy 逐项反证 held capture 同名重建、managed/snapshot stat→open mutation、wrong-owner、短读、真实 EIO、缺 symbol、ENOSYS、EEXIST 四分支 | ✅ | R4–R7 全覆盖，rc 表与 03b 逐字一致 |
| 核对全部 marker 精确一次、无 rename/link fallback、winner/victim/temp 完整 delta、child HUP/INT/TERM 清理 | ✅ | R3（八 marker 各精确一次、renameat2 精确一次、无 fallback）、R5–R8 |
| provider 物理缺席时默认与 `--dependency-absent` 走同一零 case inert 摘要 | ✅ | R2 |
| provider 存在但类型/marker/协议损坏必须 fail closed | ✅ | R2（非普通文件/symlink/三 export 缺席/anchor 次数错 fail closed rc1 无 PASS） |
| 换入对象核对注入身份与精确 shape | ✅ | R5、R7 及验收清单第 5/7 条 |
| EEXIST 全 oracle 前 temp 已清、完整 winner 指纹（dev/inode/uid/mode/nlink/size/hash） | ✅ | R7「进入 winner 首次 name-stat 前证明 owned temp 已清」+ 七元指纹 |
| post-close / early-second / post-rename-success / signal+cleanup-close-error 四行、五次 close、锁存 rc 优先 | ✅ | R8「owned temp/session/三层 ancestor 共五次 close 尝试且锁存信号码优先于 cleanup 错误」 |
| exact1/400、candidate/full/depth-1/offline、固定工具版本、六列 manifest | ✅ | R9（shfmt v3.14.0、ShellCheck 0.11.0 逐字验证后只对 exact 单文件跑三门；numstat ≤400） |
| 独立回滚验证与 03c 顺序门，inert PASS 不能解除 | ⚠️ | R10 机制完整（隔离临时分支、exact 删除入口、四类资产 `test ! -e`/`show-ref`/`worktree list`/`rg` 机械查缺），但 03c 启动门枚举缺 PLAN 原文的「full/depth-1/offline 与回滚证据入 ledger」字样（见 F5） |
| prototype `cbdbdde` 308/400、240 项断言支撑可实施性 | ✅ | 本审查实跑复核（见抽查 S4） |

全局约束与 DECISIONS 对照：不修改 provider（PLAN 文件边界表 03b1 行）✅；exact 单文件 + 六列 manifest（PLAN 审查规模节）✅；固定工具 shfmt `-d -i 2 -ci -bn` / ShellCheck `-x --severity=warning`（DECISIONS 2026-09-01 02 contract 裁定）✅；信号 rc 129/130/143（DECISIONS 2026-09-01 03 round 3）✅；inert/fail-closed 分流与顺序门（DECISIONS 2026-09-02 PLAN v5.6/v5.7、03b 验收行）✅；回滚命令表要求的 `--dependency-absent` 测试参数（PLAN 回滚验收节 03/03a/03b 行）✅ R1 提供。未发现与 DECISIONS 任何一行冲突。

## ② 文档质量

- 占位符：无 TBD/TODO/待定。✅
- 内部矛盾：1 处（F1，R9 与不变量 4 的上游文件集合不一致）。
- 有需求无验证：R1–R10 均能在验收清单 11 条及主验证命令中找到对应判据（R1→清单1，R2→清单1/2，R3→清单3，R4→清单4，R5→清单5，R6→清单6，R7→清单7，R8→清单8，R9→清单9/11，R10→清单10/11）。✅
- 判据可执行：rc 值、双流空、字节精确 stdout、指纹七元组、五次 close 计数、`git diff --name-only/numstat`、`test ! -e`/`show-ref`/`worktree list`/`rg` 均可机械执行；prototype 实跑证明矩阵可跑（S4）。✅
- EARS 句式与来源标记：R1–R10 均为「当/如果…系统必须…」并标 [计划]；PLAN v5.7 与 DECISIONS 已覆盖全部口径，标 [计划] 合规。✅
- 验收清单：11 条均为可勾事实陈述（rc、计数、逐字比较、机械命令）。✅
- 不变量：4 项（2–4 区间内），每项带阈值（均 ≤0）与验证方式（指纹比较/inventory delta/find 计数/git diff name-only）。✅

## 抽查记录（4 条，全部通过）

- S1 八 anchor 名：草稿目标节列出的八个 `HARNESS_TEST_MARKER_*` 与 03b requirements 目标节逐字一致；并对 main ffddb95 的 provider 实核 `grep -c`，八个 anchor 各精确 1 次，`renameat2` 全文件精确 1 次（line 110 ctypes 调用）。✅
- S2 rc 表与信号语义：EEXIST same/different/unsafe/disappear = 0/3/2/1、managed/snapshot mutation link/inode=2、认证后消失=1、EIO=1、HUP/INT/TERM=129/130/143、short read 逐字节产出精确 feature+LF 返 0——逐条与 03b requirements R2/R3/R4/R5 及 design 错误处理表一致；「五次 close（owned temp+session+三层 ancestor）」「锁存首信号优先于 cleanup 错误」「已提交 winner 绝不回滚、旧 temp 名只得 ENOENT」与 03b design 资源规则/数据模型及 DECISIONS 03b 验收行一致。✅
- S3 frontmatter 消费锚点：`session-snapshot-core-v2` 确为 03b 的产出锚点（03b requirements frontmatter 产出行与验收清单末条「终交付锚点 session-snapshot-core-v2」）；草稿消费描述（spawn-only worker write|read、signal-aware 两 core 私有协议、八 anchor、基础测试 dependency-present PASS 证据、无运行时 API）与 03b 产出实质一致。✅
- S4 prototype 声称实核：commit `cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e` 存在，`snapshot-assurance-r1.sh` 精确 308 行；round3 evidence 记录 227+13=240 项断言；本审查将该 prototype 以 `SNAPSHOT_CORE=<main 的 session-state-snapshot.sh>` 在 main ffddb95 工作树内实跑：rc=0、stdout 精确 40 字节 `RESULT PASS  session snapshot assurance\n`、stderr 0 字节。frontmatter「在当前 main（ffddb95）实跑 rc0」的声称成立。✅

## Findings

### 阻断（0）

无。

### 重要（1）

- F1（内部矛盾 / 判据二义）：R9 要求 candidate/full/depth-1 中「foundation/path/03a1-driver/03a2-entrypoint/snapshot」五文件 SHA-256 测试前后不变，但漏掉 `tests/test-session-snapshot.sh`；不变量 4 的 BASE..HEAD diff 钉的是「foundation.sh/path.sh/session-state-snapshot.sh/tests/test-session-snapshot.sh」四文件，反而丢掉 03a1-driver 与 03a2-entrypoint——而 03b 不变量 4 原本就含 driver 与 race entrypoint，03b1 不应在对上游的非劣化保证上倒退。两处机械判据覆盖集互不相同且均未覆盖全部六个上游 tracked 文件，controller 验收时无唯一权威集合。建议两处统一为六文件全集（foundation、path、race-driver、race-entrypoint、snapshot、snapshot 基础测试）。

### 次要（3）

- F2（判据自包含性）：R2 与验收清单第 1 条只说 inert 走「固定摘要」「逐字同一 inert 摘要」，未逐字写出 inert stdout 是否即为 `RESULT PASS  session snapshot assurance\n`；按目标节「成功唯一摘要」与 PLAN 全局不变量可推断是同一行，但期望输出节只定义了 dependency-present 分支，建议补一句 inert 摘要逐字等于同一固定行。
- F3（与 PLAN 逐字对齐）：R10 的 03c 启动门枚举为「accepted HEAD、dependency-present 完整矩阵、exact1/400、全 PASS manifest 入 ledger」，缺 PLAN 03b1 节原文的「full/depth-1/offline 与回滚证据入 ledger」；虽由 accepted HEAD 隐含（R9/R10 本身是验收前置），建议显式枚举以免门禁复核时口径漂移。
- F4（术语未机械定义）：R2 fail-closed 条件末尾的「协议损坏」未给出机械判定——同句已并列「三 export 缺席、anchor 非精确一次」，建议将「协议损坏」枚举为 renameat2 次数错/存在 rename 或 link fallback/source 后产生额外 export 或副作用等可 `rg` 核对的条件，或删除该兜底词。

## 附：审查执行命令（可复现）

```sh
# S1 anchor/renameat2 次数
for a in HARNESS_TEST_MARKER_CAPTURE_READY HARNESS_TEST_MARKER_SNAPSHOT_MANAGED_BEFORE_OPEN \
         HARNESS_TEST_MARKER_MANAGED_EXPECTED_EUID HARNESS_TEST_MARKER_SNAPSHOT_EXPECTED_EUID \
         HARNESS_TEST_MARKER_SNAPSHOT_BEFORE_OPEN HARNESS_TEST_MARKER_TEMP_BEFORE_PUBLISH \
         HARNESS_TEST_MARKER_PUBLISH_RESULT HARNESS_TEST_MARKER_OS_ERROR; do
  grep -c "$a" common/.harness/lib/session-state-snapshot.sh; done   # 全为 1
grep -c renameat2 common/.harness/lib/session-state-snapshot.sh      # 1

# S4 prototype 实跑（main ffddb95 工作树内临时目录，已清理）
git show cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e:.spec/.../prototype/snapshot-assurance-r1.sh > proto.sh
SNAPSHOT_CORE="$PWD/common/.harness/lib/session-state-snapshot.sh" bash proto.sh
# rc=0，stdout=RESULT PASS  session snapshot assurance\n（40B），stderr 空
```
