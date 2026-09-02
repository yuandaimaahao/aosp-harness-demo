# 2026-09-01-aosp-feature-minimal-checkout 项目口径

> 前面的 spec 确认过的口径记在这里，后续 spec 起草 requirements 前先读。
> 已被本文件覆盖的条目不许再标 [推断] 去问用户。

| 日期 | 来自 spec | 口径 |
|---|---|---|
| 2026-09-01 | 门① | PLAN v4 已由用户批准；依 `PLAN.md` 的 review 熔断裁定继续。 |
| 2026-09-01 | 00-environment-seed-preflight 输入 | 本地 AOSP 树为 `~/Project/lk7k-a17/system`；编译初始化为 `source build/envsetup.sh`；lunch 目标为 `sys_mssi_64_64only_cn_armv82-fooding-userdebug`。 |
| 2026-09-01 | 范围边界 | LK7K/vendor/BSP 依赖可用于该本地产品的闭包验证，但必须单独标记 product/vendor role，不得外推为公开 AOSP 通用底座。 |
| 2026-09-01 | 执行模式 | 用户明确要求从 `00-environment-seed-preflight` 起的后续 spec 走 autopilot；每片创建时显式写入 `mode=autopilot`，不跳过独立 reviewer 与 G-VERIFY。 |
| 2026-09-01 | 00 输入输出 ABI（v6 已替代 owner/name） | `seed-request/v1` 是只读输入，成功输出的当前名称为 `seed/v1`、终止输出为 `terminal-report/v1`；00a 管 schema/runtime，00b 填充并发布，CLI 只从 descriptor 读取源码、lunch 和阈值。 |
| 2026-09-01 | 00 退出与发布 | state-dir 形态、symlink、worktree containment、out-ref 与 schema 错误统一 exit 30 且零写入；有效请求下的源码/工具/资源/namespace/lunch 不可用 exit 20，必须先发布 terminal artifact 再发布 ref。 |
| 2026-09-01 | 00 安全证据 | 探针进入 unprivileged user+network namespace；验收从真实 CLI 外层用 syscall trace、poison PATH 和独立 digest 重算证明源码 mutation、外网、同步/下载及模块编译均为零。 |
| 2026-09-01 | 00 默认值 | resource threshold 为 200 GiB available bytes、1,000,000 available inodes、32 GiB effective available memory、8 effective CPU；dirty workspace 在 00 可继续，但必须标记非 clean proof 并携带 digest/count。 |
| 2026-09-01 | 00 seed owner（v6 已拆分） | 00a 唯一拥有 schema/digest/store/ref/dispatcher，00b 唯一拥有 preflight/provider 并发布 `seed/v1`/terminal ref；两者均支持 public/local scope，public golden 只验 ABI，后序只接受 real-source public seed。 |
| 2026-09-01 | 00 publish fault | object commit 后 ref commit 前失败可留下无 ref 的 immutable orphan；ref rename 后 fsync 失败返回 durability-uncertain 并只容许旧 ref 或能解析到 matching object 的 intended ref，不宣称 POSIX post-commit fault 可全量回滚。 |
| 2026-09-01 | 00 控制门（v6 已替代） | preflight stdout 只输出 `ENV PASS SCOPE_ID` 或 `ENV NOT-AVAILABLE CODE`；local exit 0 仅证明本机 product 环境。control plane 只有在 `verify-seed --ref ... --require-public-real` exit 0 后记录 `GATE CONTINUE_PUBLIC`，否则记录 `GATE PLAN_REVIEW` 并停止进入 01。 |
| 2026-09-01 | PLAN v5 public chain | requirements round 3 熔断后，public request 由 `AOSP17_SEED_REQUEST` 传入，00 发布固定 `aosp17-services-env.json` ref，01–05 通过 `--descriptor-ref` 重算 real-source object；只有 `GATE CONTINUE_PUBLIC` 可进入 01。 |
| 2026-09-01 | 00 stable identity | downstream seed digest 是排除 trace 调度、瞬时资源和 OUT_DIR 的 `seed_identity_digest`；完整 seed artifact 保留 run evidence 且其 content digest 可随运行变化，同源重复运行必须保持 seed content/identity digest 相同。 |
| 2026-09-01 | 00 trace/source ABI | trace result/dirfd 为 signed-64，所有 path operand/fd/cwd/symlink resolution 进入 canonical record；source-state 同时固定 per-project/workspace digest，实际读取的 ignored symlink target 内容进入 seed identity。 |
| 2026-09-01 | 00 ref/resource ABI | public/local ref 名固定且 producer 对 ref 持独占锁；collision/ref corruption/publish fault 使用 post-observation 状态机。resource pass 使用 descriptor 下限、estimated disk upper bound、cgroup v2 优先/v1 fallback 和 rational CPU 公式。 |
| 2026-09-01 | PLAN v6 owner/rollback | 原 00 因 890–1310 行估算超 800 拆为 00a/00b；00a revert 后后序 direct wrapper 保留 commit 但精确 exit 30 `CONTRACT RUNTIME_UNAVAILABLE`，不联动回滚。00a/00b diff 高位分别 730/630 行。 |
| 2026-09-02 | 原 00 supersession merge（替代 single-parent 例外） | 门④三轮review证明单文件/single-parent修复链不满足10分钟review与base-relative gate；原00改为四个non-overlap task commits，最终以parent1=frozen process base、parent2=task tip的two-parent merge交付，并在隔离worktree执行`git revert -m 1 --no-edit MERGE_SHA`。动态冻结仍防止共享main的`common/`历史被误算。 |
| 2026-09-02 | 原 00 terminal 验收 | R24-only supersession validator 以 merge `a79edb650066bf47d6908fe00ec22c0d6749ef14` 验收；六路径 744/800、`common/` 增量 0、四任务独立 review、isolated revert 与旧 harness 三项回归 PASS。00a/00b migration criteria 尚未执行，retro 下一步选择 00a。 |
| 2026-09-02 | 00a canonical numeric ABI supersession | 为使 RFC 8785 bytes 跨 Python/ECMAScript 唯一且保持“承重值变化必改 digest”，00a 将原 00 的 JSON unsigned/signed-64 number 接受域显式替代为 I-JSON safe integers：unsigned `0..2^53-1`、signed `-(2^53-1)..2^53-1`，同时拒绝 raw/escaped lone surrogate；00b–05 producer/consumer 统一消费该新口径，越界 observation 不能截断或舍入，必须按 schema/trace unavailable 路径 fail closed。 |
| 2026-09-02 | 00a state-path rename threat model | Linux/POSIX `mkdirat` 不返回目录 fd，且 `openat(O_CREAT|O_DIRECTORY)` 为 `EINVAL`；因此无法在同一 UID 对手于 post-`mkdirat`/pre-open 窗口主动 rename 新目录时，同时保证识别 moved inode、清理未知新名字和零越界残留。00a 明确只保证稳定目录拓扑下的 static symlink/non-regular/containment 与多 publisher 安全；一次 runtime invocation 中同 UID 主动 rename/move/delete 已验证或新建目录不在威胁模型内。检测到拓扑变化时 fail closed 并 best-effort cleanup，但不对该排除场景声明零越界残留；00b–05 必须复用同一边界。 |
| 2026-09-02 | 00a runtime 与交付终态 | `seed-contract-runtime/v1`、dispatcher/direct ABI、closed schema、I-JSON/RFC 8785 digest、受限 state-dir、immutable object 与 locked atomic ref 已由 delivery merge `f9ead254b70c39532a276e8aa63a537d4cac7af6` 验收；该 merge 的 parent1 是 frozen base `c959efaf9887808621852aff28073cf1f8789ca7`，parent2 是 reviewed tip `8d27769692481fc76919ce0f5ea6d7f8c5840479`。candidate 为 active 与 accepted 时 descendant rollback 均必须可重跑；旧候选 `6bd8fddac2cc00d8b2a68d501750dec8eb4d7c1a` 已 superseded。`common` 实际增量 631/730，最终 review 57/140，未读取或执行真实 AOSP。 |
