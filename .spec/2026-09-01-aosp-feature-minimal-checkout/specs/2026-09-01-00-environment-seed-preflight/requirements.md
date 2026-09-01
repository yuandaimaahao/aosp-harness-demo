---
id: 2026-09-01-00-environment-seed-preflight
依赖: []
消费: seed-request/v1 输入描述符
产出: feature-closure dispatcher、preflight direct recovery ABI、seed/v1 与 terminal-report/v1 内容寻址 artifact/ref、public AOSP17 和 local LK7K 两类 seed 契约
验收方式: 混合判定
已由用户确认: true
确认依据: 用户批准 PLAN v4，并确认本地源码路径、envsetup、lunch 目标及后续 autopilot
---

> 用户原话：
> “可以用 `~/Project/lk7k-a17/system` 本地代码来做验证。”
>
> “`source build/envsetup.sh`”
>
> “`lunch sys_mssi_64_64only_cn_armv82-fooding-userdebug`”
>
> 上游计划：`PLAN.md` v4 的 `00-environment-seed-preflight`。

> Supersession applicability：门③ R24 已证明本原片 890–1310 行并由 PLAN v6 的 00a/00b 替代；下列 R1–R23、R25–R27 是 successor 的迁移合同，不冒充当前知识终止片实现。当前片只实现 R24 的 machine-readable supersession，以四个non-overlap task commits和exact two-parent merge交付；R25 的真实environment implementation recovery oracle仍由00a/00b各自requirements重新固定。

## 目标

由 `seed-request/v1` 驱动 `feature-closure preflight`，在 worktree 外的 `state-dir` 与 `OUT_DIR` 中产出可供后序直接消费的 `seed/v1` 或 `terminal-report/v1`。本片同时固化 public AOSP17 Cuttlefish 与 local LK7K product 两种 `source_scope`，以及 `AOSP_SOURCE_ROOT`、`AOSP_LUNCH_TARGET`、`AOSP_HARNESS_STATE_DIR`、`sys_mssi_64_64only_cn_armv82`、`fooding`、`userdebug`、`f_bavail`、`f_frsize`、`f_favail`、`MemAvailable`、`openat`、`mkdirat`、`O_NOFOLLOW`、`schema_version`、`kind`、`digest`、`evidence_class`、`fixture_only`、`COMMAND_UNAVAILABLE` 等稳定标识；通过固定 dispatcher/direct ABI、内容寻址发布、network namespace、syscall trace、源码状态和执行器审计，使后序能区分公共 baseline 与本地 vendor 证明。

## 需求

R1. [原话] 当执行本机 LK7K 验收时，系统必须使用调用侧已展开为 `/home/zzh0838/Project/lk7k-a17/system` 的用户指定源码路径。

R2. [原话] 当执行本机 LK7K 构建环境探针时，系统必须使用用户指定的 `source build/envsetup.sh` 与 `lunch sys_mssi_64_64only_cn_armv82-fooding-userdebug`。

R3. [计划] 当调用侧生成 descriptor 时，系统必须把源码绝对 realpath 写入输入；通用 CLI 不展开字面量 `~`、不硬编码用户路径，也不从 `AOSP_SOURCE_ROOT`、`AOSP_LUNCH_TARGET` 或 `AOSP_HARNESS_STATE_DIR` 覆盖 descriptor/CLI 参数。

R4. [计划] 当运行 envsetup/lunch 时，系统必须先切换到 descriptor 指定源码根，在 state-dir 后代临时 `OUT_DIR` 中记录封闭 build-variable 集与 exit code，不运行模块、整机、打包或刷机 goal。

R5. [计划] 系统必须把 `./common/.harness/bin/feature-closure SUBCOMMAND` 固化为唯一 dispatcher ABI，把合法 command name 限定为 ASCII regex `^[a-z][a-z0-9-]{0,31}$`，并从 dispatcher 自身 realpath 的 parent 固定解析 `../closure/v1/commands.d/SUBCOMMAND` 后仅 exec 该可执行 regular file。

R6. [计划] 系统必须把 `common/.harness/closure/v1/commands.d/preflight --descriptor FILE --state-dir ABS_DIR --out-ref ABS_REF` 固化为 direct recovery ABI；dispatcher 形式只在该 argv 前增加 `preflight`，两种形式不得改变其余参数。

R7. [计划] 当 CLI 读取输入时，系统必须把 descriptor 只解释为不可变 `seed-request/v1`，把 state-dir/out-ref 只解释为运行时位置，把成功输出解释为 `seed/v1`；00 是两类 seed schema/producer/fixture 与固定 public/local ref 的唯一 owner，后序只通过 ref 重算 object。

R8. [计划] 凡具备 state-dir 消费能力，系统必须要求 state-dir 是已存在、可写、无 symlink 分量且 normalized absolute path 等于 realpath 的目录，并以逐分量 `openat`/`mkdirat` 加 `O_NOFOLLOW` 创建 store、OUT_DIR 和 ref parent，拒绝 symlink/non-directory leaf。

R9. [计划] 当校验路径隔离时，系统必须枚举 harness repo、`.repo/manifests`、`.repo/repo` 和 locked manifest 中每个现存 project 的 `git worktree list --porcelain`，按 path-component containment 拒绝 state-dir/store/OUT_DIR/out-ref 与任一 worktree 相等或位于其后代；尚不存在的 leaf 按已解析 parent 加 lexical basename 判定。

R10. [计划] 当 seed 工作区可读时，系统必须按下文 closed schema 记录 manifest/Repo commits、launcher digest、locked manifest digest、去凭据 URL、Repo/Git/Python identity、project/host/container/resource/lunch/source-state/guard evidence 与 seed content digest。

R11. [计划] 当 source scope 为 public AOSP17 Cuttlefish 时，系统必须要求 `role=public_aosp17_cuttlefish`、`public_aosp_baseline=true`、`vendor_context=false` 和 `platform_family=aosp-17`；00 只有在 real public invocation exit 0、固定 public ref 可重算且 `evidence_class=real_source` 时输出 `GATE CONTINUE_PUBLIC`，否则输出 `GATE PLAN_REVIEW` 并停止进入 01，02/verify-proof 只消费该 public ref。

R12. [计划] 当 source scope 为 local LK7K product 时，系统必须要求 `role=local_lk7k_product`、`public_aosp_baseline=false`、`vendor_context=true`、product=`sys_mssi_64_64only_cn_armv82`、release=`fooding` 和 variant=`userdebug`；后序不得用它替代 public baseline。

R13. [默认] 在检查磁盘资源期间，系统必须以 unsigned-64 饱和乘法计算 `f_bavail * f_frsize` available bytes，以 `f_favail` 计 available inodes，拒绝 descriptor 中 available-bytes 小于 214748364800 或 inode 小于 1000000 的 threshold，并分别比较 available inodes 与 available bytes 是否不小于 threshold、estimated disk upper bound 两者中的对应要求。

R14. [默认] 在检查内存资源期间，系统必须拒绝 descriptor 中 effective-memory threshold 小于 34359738368，优先在存在 `cgroup.controllers` 时读取完整 v2 pair，否则读取完整 v1 pair；v2 用 `memory.max-memory.current`，v1 用 `memory.limit_in_bytes-memory.usage_in_bytes`，`max` 或不小于 2^60 的 limit 视为无限，负 remaining 截为 0，所选 pair 不完整则 remaining=null，并以 host `MemAvailable` 与非 null remaining 的较小值比较 request threshold。

R15. [默认] 在检查 CPU 资源期间，系统必须拒绝 descriptor 中 effective-CPU threshold 小于 8，优先选择完整 v2 provider、否则完整 v1 provider；cpuset 不可读时取 online set，quota 不可读/`max`/非正时取无限，online 与 cpuset intersection cardinality 再与 quota/period rational 取较小值，并以交叉乘法判断该 rational 是否不小于 request threshold。

R16. [默认] 当 Repo workspace 含 tracked change 或 recursive untracked entry 时，系统必须保持环境可继续，写入 `source_state=dirty`、按 manifest project path 去重的 affected count、`clean_source_proof=false` 与可重算 source-state digest；clean 时 count=0 且 flag=true。

R17. [计划] 在 preflight 执行期间，系统必须以 unprivileged user+network namespace 运行 envsetup/lunch，以 trace 收集全部 descendant process/file/network syscall；非 loopback external network 成功、源码 mutation、sync/download、ninja/compiler、模块/整机 goal 和打包入口的成功计数必须均为 0，仅 `soong_ui --dumpvars-mode` 且不含 `--make-mode` 的配置查询属于有效 lunch probe。

R18. [计划] 当重算源码状态时，系统必须在 probe 前后使用 locked manifest 和每个 project 的 HEAD、`git status --porcelain=v2 -z --untracked-files=all`、下文 entry digest 生成 source-state；任何 probe 实际读取的 ignored regular/symlink input 必须由 trace 枚举并加入 seed content，任何 ignored write 必须计作源码 mutation。

R19. [计划] 当全部 contract、environment、lunch、guard 和 before/after digest 检查通过时，系统必须 exit 0，stdout 精确一行 `ENV PASS SCOPE_ID`，stderr 为空，先发布 evidence objects 与 `seed/v1`，最后在独占 ref lock 下发布 scope 对应的 `kind=env_pass` ref。

R20. [计划] 如果发生有效请求下的源码/Repo/envsetup/tool/worktree-enumeration/resource/namespace/trace/lunch/guard/source-stability 不可用，系统必须 exit 20，stdout 精确一行 `ENV NOT-AVAILABLE REASON_CODE`，stderr 为空，先发布不超过 120 行的 terminal artifact，最后在独占 ref lock 下发布 `kind=terminal_report` ref，并使控制平面输出 `GATE PLAN_REVIEW`、停止进入 01。

R21. [计划] 如果发生下文 validation priority 中的 argument/command/descriptor/path/ref/digest contract error，系统必须在任何 publish commit point 前 exit 30，stdout 为空，stderr 精确一行 `CONTRACT ERROR_CODE`，且 existing object/ref sentinel bytes 不变。

R22. [计划] 如果发生 output digest collision、existing ref corruption、ref lock conflict 或 object/ref publish fault，系统必须以 exit 30、空 stdout 和精确一行 `CONTRACT ERROR_CODE` 按下文 post-observation matrix 返回；允许留下可重算且无 ref 的 orphan content object，任何可见 ref 必须指向 matching object，不声称 post-commit fault能全量回滚。

R23. [计划] 当 dispatcher/direct ABI 使用同一 deterministic fixture 时，系统必须得到相同 exit/stdout/stderr/artifact digest/ref bytes；dispatcher 缺席不影响 direct module，command 缺失或不可执行时 dispatcher 必须 exit 30 并返回 `COMMAND_UNAVAILABLE`。

R24. [计划] 当 tasks estimate 预测 non-generated diff 超过 800 行或 human-review test/descriptor summary 超过 160 行时，系统必须在 implementation 前回 PLAN 拆为 00a/00b；当 actual 值超限时，系统必须在 implementation acceptance 前执行同一拆分，不以超预算实现通过 00。

R25. [计划] 当 00 exact merge commit 已写入 ledger 时，系统必须在 isolated worktree revert 该 commit，确认 dispatcher path 不存在，再由 rollback test 安装 `commands.d/recovery-fixture` 并直接执行得到 exit 0、stdout 精确 `RECOVERY PASS recovery-fixture`、stderr 为空，同时现有 harness test/parity/dev-sidebar demo verifier 分别输出其精确 PASS 行。

R26. [默认] 当 resource threshold 等于 measured value 或比 measured value 大 1 时，系统必须分别通过该资源项或按 exit 20 处理。

R27. [默认] 如果发生任一 threshold 缺失、为负、为 float 或超过 unsigned-64，系统必须按 validation priority 以 exit 30 处理。

## Stable data ABI

所有 JSON 拒绝 duplicate key、float、非 UTF-8、unknown/missing field；除 trace syscall `result`/`dirfd` 是 signed-64 外，integer 均为 0..2^64-1，array 保持下文排序。payload 使用 RFC 8785 UTF-8 bytes；artifact object 位于 `STATE_DIR/artifacts/v1/sha256/<64-lower-hex-digest>`，mode 0444。fixture/golden bytes 只验证本节，不创造字段。

### seed-request/v1 input

| field | type/value |
|---|---|
| `schema_version` / `kind` | integer `1` / string `seed_request` |
| `source_root` / `envsetup_relpath` | absolute realpath string / normalized relative string `build/envsetup.sh` |
| `lunch` | object exactly `{target,product,release,variant}`，all nonempty strings |
| `source_scope` | object exactly `{role,public_aosp_baseline,vendor_context,platform_family}`，values obey R11 or R12 |
| `resource_minimums` | object exactly `{available_bytes,available_inodes,effective_memory_bytes,effective_cpus}`，unsigned integers |
| `estimated_disk_upper_bound_bytes` | unsigned integer |

request digest is `SHA-256("aosp-harness/seed-request/v1\0" + RFC8785(payload))`; input bytes stay unchanged. Orchestration requires an existing absolute `AOSP17_SEED_REQUEST` file supplied by the public-source owner and passes it as `--descriptor`; CLI never reads that environment variable. Public out-ref is exactly `STATE_DIR/refs/aosp-feature-minimal-checkout/aosp17-services-env.json`. Local test generates its request from the three local `AOSP_*` wrapper variables and uses exactly `STATE_DIR/refs/aosp-feature-minimal-checkout/lk7k-a17-env.json`. Out-ref must equal the scope-derived absolute normalized path, its existing parent components must resolve under state-dir without symlink, and adjacent `OUT_REF.lock` is held exclusively from pre-observation ref validation through ref-dir fsync; nonblocking lock failure is `REF_BUSY`.

### source-state/v1 evidence

Payload top-level is exactly `{schema_version:1,kind:"source_state",manifest_sha256,projects}`. `projects` sorts by UTF-8 manifest path and each item is exactly `{path,head,status_sha256,entries}`; HEAD is 40/64 lower hex, status digest hashes the exact porcelain NUL bytes. `entries` sorts by decoded raw path bytes and each item is exactly `{path_b64,status_record_b64,entry_kind,mode,content_sha256,symlink_target_sha256}`; kind is `regular|symlink|missing`, mode is unsigned integer, and inapplicable digests are null. Rename/copy records contribute both raw paths; untracked directories are never folded. Per-project digest is `SHA-256("aosp-harness/project-source-state/v1\0" + RFC8785(project item))`; workspace digest is `SHA-256("aosp-harness/source-state/v1\0" + RFC8785(top-level payload))`.

### trace/v1 evidence

Payload is exactly `{schema_version:1,kind:"trace",records,counts}`. Capture uses one tracer stream, assigns process ordinal by first-seen PID and monotonic sequence by observed syscall order; records remain sequence ordered and each is exactly `{sequence,process_ordinal,syscall,result,errno,exec_argv_b64,paths,address_family,classification}`. `result` is signed-64, `errno` is null on result >=0 or stable errno name on failure, `exec_argv_b64` is an ordered array of raw argument byte strings only for execve/execveat and null otherwise. `paths` is an ordered array whose item is exactly `{role,dirfd,raw_b64,resolved_b64}`; role is `path|oldpath|newpath|target|linkpath|source_fd|destination_fd`, dirfd is signed-64 or null, and every path-bearing syscall records all operands. Resolution tracks each process cwd/root/fd table across chdir/chroot/open/dup/close/fork, resolves dirfd through proc fd links, resolves every existing symlink prefix, and resolves a missing leaf against its no-follow real parent.

`classification` is one of `other|external_network|source_mutation|sync_download|config_query|module_build|package`; counts has exactly these classes as unsigned integers and counts only result >=0. External network means successful connect/sendto/sendmsg to non-loopback AF_INET/AF_INET6. Source mutation covers successful write/pwrite/writev/pwritev, writable shared mmap/msync, open/creat with create/truncate/write/append, truncate/ftruncate/fallocate, copy_file_range/sendfile/splice destination, rename/unlink/mkdir/rmdir/link/symlink/mknod, chmod/chown/utime, setxattr/removexattr families when any resolved target/fd is under source root. Digest is `SHA-256("aosp-harness/trace/v1\0" + RFC8785(payload))`. Real trace digest is run audit evidence and is not part of stable seed identity.

### command-journal/v1 evidence

Payload is exactly `{schema_version:1,kind:"command_journal",records}`. Records are ordered and each is exactly `{stage,argv_b64,cwd_b64,exit_code,trace_first_sequence,trace_last_sequence}`; stage enum/order is `manifest_before,source_state_before,namespace_probe,envsetup_lunch,manifest_after,source_state_after` and every stage occurs exactly once. Digest is `SHA-256("aosp-harness/command-journal/v1\0" + RFC8785(payload))`; empty/missing/reordered stages are invalid.

### seed/v1 success output

Top-level is exactly `{schema_version:1,kind:"seed",evidence_class,request_digest,source_scope,source,manifest,tools,execution,resources,lunch,source_state,guard,seed_content_digest,seed_identity_digest}`. `evidence_class` is `real_source|fixture_only`; CLI real invocations always emit `real_source`, only deterministic golden generation emits `fixture_only`.

| object | exact children and types |
|---|---|
| `source_scope` | same four fields/values as request |
| `source` | `{root,envsetup_relpath}` strings |
| `manifest` | `{repository_commit,locked_xml_sha256,project_count,remotes,projects}`；commits/digests strings，count uint；remotes sort by name and contain `{name,fetch_url,review_url,mirror_url}` nullable credential-free strings；projects sort by path and contain `{path,name,remote,revision,head,source_state_digest}` strings，last digest is the project-source-state digest defined above |
| `tools` | `{repo_checkout_commit,repo_launcher_path,repo_launcher_sha256,repo_version,git_version,python_version}` strings or explicit null only for unavailable checkout commit |
| `execution` | `{host_arch,kernel_release,kind,container_digest}`；kind `host|container`，digest null iff host |
| `resources` | `{estimated_disk_upper_bound_bytes,minimums,measured,passed}`；minimums repeats request；measured exactly `{available_bytes,available_inodes,host_mem_available_bytes,cgroup_mem_remaining_bytes,effective_memory_bytes,online_cpu_count,cpuset_cpu_count,effective_cpu_numerator,effective_cpu_denominator}` with only cgroup/cpuset nullable；passed.disk iff available bytes ≥ max(request bytes, estimate)，inodes iff available inodes ≥ request inodes，memory iff effective bytes ≥ request memory，cpu iff rational ≥ request CPU |
| `lunch` | `{target,product,release,variant,variables,out_dir_relative,envsetup_exit,lunch_exit}`；variables exactly has `TARGET_PRODUCT,TARGET_RELEASE,TARGET_BUILD_VARIANT,TARGET_ARCH,TARGET_2ND_ARCH,HOST_OS,HOST_ARCH` as string/null；relative path is under `tmp/preflight`；exits uint |
| `source_state` | `{state,clean_source_proof,affected_project_count,before_digest,after_digest,observed_ignored_inputs}`；state `clean|dirty`；ignored inputs sort by logical raw path and each is exactly `{path_b64,resolved_path_b64,entry_kind,mode,content_sha256,symlink_target_sha256,target_content_sha256}` with kind `regular|symlink` and inapplicable digest null；a read symlink always hashes both target string and resolved target content |
| `guard` | `{parent_netns_inode,probe_netns_inode,trace_digest,command_journal_digest,external_network_count,source_mutation_count,sync_download_count,module_build_count,package_count}` integers/digests，namespace inode values differ |

Seed content payload is exactly `{locked_xml_sha256,projects,observed_ignored_inputs}` reusing the sorted manifest projects and ignored entries above; digest is `SHA-256("aosp-harness/seed-content/v1\0" + RFC8785(payload))`. Stable seed identity payload is exactly `{source_scope,manifest,tools,execution_identity,lunch_identity,source_state_identity,seed_content_digest}` where execution identity is host arch/kind/container digest, lunch identity excludes exits/OUT_DIR, source-state identity excludes trace/journal and uses before=after digest plus ignored inputs; digest is `SHA-256("aosp-harness/seed-identity/v1\0" + RFC8785(payload))`. Seed artifact digest is `SHA-256("aosp-harness/seed-artifact/v1\0" + RFC8785(full seed payload))`; downstream “seed digest” means `seed_identity_digest`, while run-varying resources/trace/journal only affect artifact digest. Two real runs with unchanged source/request must have equal seed content/identity digests even if artifact digests differ. `common/tests/fixtures/aosp17-services/seed.golden.json` is schema-valid public `fixture_only`;后序只消费固定 public ref 的 `real_source` object，不再消费 repo 内 `seed.json`。

### terminal-report/v1 output

Payload is exactly `{schema_version:1,kind:"terminal_report",request_digest,primary_reason,failed_checks,completed_observation_digests,summary_lines}`. `failed_checks` is unique and priority-sorted; completed digests is an object with exactly `{source_state,trace,command_journal}` nullable digest fields; summary lines is an array of at most 120 strings with no timestamp, username, credential or source content. Digest is `SHA-256("aosp-harness/terminal-report/v1\0" + RFC8785(payload))`.

### ref bytes

Ref bytes are exactly RFC 8785 of `{schema_version:1,kind,digest}` plus one LF. Kind is only `env_pass` for seed or `terminal_report` for terminal; digest always resolves to a matching object before ref commit.

## Deterministic state machine

Validation evaluates in this priority and stops at first error: `ARGUMENT_ERROR,INVALID_COMMAND,COMMAND_UNAVAILABLE,DESCRIPTOR_NOT_FOUND,DESCRIPTOR_INVALID_UTF8,DUPLICATE_JSON_KEY,UNSUPPORTED_SCHEMA_VERSION,DESCRIPTOR_SCHEMA_INVALID,SOURCE_ROOT_CONTRACT,STATE_DIR_CONTRACT,OUT_REF_CONTRACT,WORKTREE_MISMATCH,REF_BUSY,REF_CORRUPT`. All return exit 30, stdout empty, stderr exactly `CONTRACT CODE`; they precede observation/publication and create no object/ref. Existing ref is `REF_CORRUPT` unless it is exact three-field bytes resolving to a matching object.

For a valid contract, environment checks evaluate in this priority: `SOURCE_ROOT_UNAVAILABLE,REPO_METADATA_UNAVAILABLE,ENVSETUP_UNAVAILABLE,REPO_CLIENT_UNAVAILABLE,WORKTREE_ENUM_UNAVAILABLE,RESOURCE_DISK,RESOURCE_INODE,RESOURCE_MEMORY,RESOURCE_CPU,NETWORK_NAMESPACE_UNAVAILABLE,TRACE_UNAVAILABLE,LUNCH_FAILED,FORBIDDEN_EXECUTION,SOURCE_MUTATION,SOURCE_CHANGED`. Safe pre-lunch failures stop before lunch; otherwise all evaluated failures enter `failed_checks` in this order and the first is `primary_reason`. Exit is 20 with terminal artifact/ref.

After observation produces the intended output bytes, collision check and publish stages run in this order: `DIGEST_CHECK,OBJECT_TEMP,OBJECT_LINK,OBJECT_DIR_FSYNC,REF_TEMP,REF_RENAME,REF_DIR_FSYNC`. The producer holds the scope ref lock throughout; all conforming producers are single-writer for that ref.

| fault point | exit/code | permitted durable/visible state |
|---|---|---|
| `DIGEST_CHECK` finds same path/different bytes | 30 `DIGEST_COLLISION` | no object/ref change; this overrides original semantic exit 0/20 |
| before `OBJECT_LINK` | 30 `PUBLISH_PRECOMMIT_FAILED` | no new object/ref; old ref unchanged |
| after object link, before `REF_RENAME` | 30 `PUBLISH_OBJECT_ORPHANED` | intended immutable object may remain orphan; no new/dangling ref; old ref unchanged |
| after `REF_RENAME`, including ref dir fsync fault | 30 `REF_DURABILITY_UNCERTAIN` | ref may be old or exact intended bytes; if intended it resolves to matching object; replay is idempotent and any other bytes are `REF_CORRUPT` on next locked invocation |
| no fault | original 0 or 20 | object durable first, then exact ref durable |

Every exit-30 row above has empty stdout and stderr exactly `CONTRACT CODE`. Object uses same-directory temp+file fsync+chmod 0444+hard-link no-replace+object-dir fsync; same digest/same bytes reuses object, same digest/different bytes is collision. Ref uses same-directory temp+file fsync+atomic replace+ref-dir fsync. Temp files are removed best-effort and are never treated as objects/refs.

## Autopilot decisions

- Questions are 0/15 and rounds 0/2. User confirmed source path, lunch, PLAN v4 and autopilot; remaining choices are technical consistency decisions.
- 00 owns both seed scopes. Local LK7K is the real local verification input; public golden verifies ABI only. A real public seed is still mandatory before 02, so no vendor result is generalized.
- state-dir/path/schema errors are exit 30; valid-request environment shortages are exit 20. Post-commit faults follow the recoverable matrix instead of claiming impossible rollback.
- Defaults are 200 GiB, 1,000,000 inodes, 32 GiB and 8 CPUs; dirty source continues with non-clean proof. Local state-dir default is `/home/zzh0838/Project/.aosp-harness-state/aosp-feature-minimal-checkout`, never hardcoded in CLI.
- Guessing these ABI boundaries incorrectly would invalidate all downstream digests; they are therefore fixed here, recorded in DECISIONS and independently reviewed before design.

## 验收标准

Current R24-only terminal deliverables: `supersession/v1` manifest plus `supersession-validator/v1` modular dispatcher/core/pre-commit/accept/self-test and the three exact public PASS modes. They must prove PLAN v6 replacement/owner/budget, an execute-time frozen process baseline with zero `common/` increment, four non-overlap task commits, an exact six-path two-parent merge and isolated `git revert -m 1` before retro selects 00a; cumulative actual non-generated diff must remain `<=800` lines and every task review summary `<=160` lines. The implementation-oriented commands below remain migration criteria for successor 00a/00b and are not executed by this terminal.

主验证命令: bash -lc 'AOSP_SOURCE_ROOT="$HOME/Project/lk7k-a17/system" AOSP_HARNESS_STATE_DIR="$HOME/Project/.aosp-harness-state/aosp-feature-minimal-checkout" AOSP_LUNCH_TARGET="sys_mssi_64_64only_cn_armv82-fooding-userdebug" bash common/tests/test-environment-seed-preflight.sh --case pre-merge'
期望输出: fixture/local checks emit RESULT PASS environment-seed-preflight-local；then orchestration invokes `preflight --descriptor "$AOSP17_SEED_REQUEST" --state-dir "$AOSP_HARNESS_STATE_DIR" --out-ref "$AOSP_HARNESS_STATE_DIR/refs/aosp-feature-minimal-checkout/aosp17-services-env.json"`；inner public exit 0 emits ENV PASS public_aosp17_cuttlefish and GATE CONTINUE_PUBLIC, wrapper exit 0 ends RESULT PASS environment-seed-preflight；inner public exit 20 emits ENV NOT-AVAILABLE REASON_CODE and GATE PLAN_REVIEW, wrapper exit 20 ends RESULT TERMINAL environment-seed-preflight and autopilot stops before 01

Post-merge rollback command: bash common/tests/test-environment-seed-preflight.sh --case rollback --merge-commit COMMIT_SHA_FROM_LEDGER
Post-merge expected output: exit 0；last stdout line exactly RESULT PASS environment-seed-preflight-rollback；after revert `test ! -e common/.harness/bin/feature-closure` passes；the rollback test creates only `common/.harness/closure/v1/commands.d/recovery-fixture`, direct execution exits 0 with stdout exactly RECOVERY PASS recovery-fixture and empty stderr；`bash common/tests/test-harness.sh` ends `RESULT PASS  shared Harness regression suite`；`bash common/.harness/bin/check-parity.sh` prints `PARITY PASS  Claude/Codex 共享同一公共契约`；`bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo` ends `RESULT PASS`

Acceptance checklist:
- [ ] Real dispatcher/direct module and independent outer `unshare -Urn`/`strace -ff`/poison PATH are invoked; request/seed/source-state/trace/journal/ref digests are independently recomputed, and empty journal/constant digest/fixed PASS mutations fail.
- [ ] Public ABI golden and local real request use the same closed schema; public golden is rejected as real proof, local seed is machine-labeled non-public, and only the fixed public ref resolving to real-source seed can emit GATE CONTINUE_PUBLIC and unlock 01/02.
- [ ] Success/terminal/validation/publish-fault fixtures assert exact exit/stdout/stderr/code/object/ref bytes for every priority and commit point, including orphan object and ref durability-uncertain replay.
- [ ] Path matrix covers literal tilde, relative/missing/unwritable/symlink state-dir, harness/manifests/repo/project worktrees, nonexistent leaf and out-ref symlink/escape.
- [ ] Source matrix covers clean, tracked, recursive untracked, rename, delete, symlink and actually-read ignored/target content plus every listed fd/path mutation family; outer trace independently resolves all path operands and proves external network, source mutation, sync/download, module build and package successful counts all zero.
- [ ] Resource provider fixtures cover disk multiplication, cgroup v1/v2/unlimited/unreadable, cpuset/rational quota, equality/plus-one and invalid/missing/negative/float/overflow thresholds.
- [ ] Two unchanged real invocations have equal seed-content and seed-identity digests despite scheduling/resource variance; only public inner exit 0 emits `GATE CONTINUE_PUBLIC`, while public exit 20 makes wrapper exit 20 with `GATE PLAN_REVIEW`. Successor 00a/00b post-merge gates consume only their ledger exact merge SHA and their re-fixed recovery fixtures; current R24-only terminal also records its exact merge SHA but runs only supersession rollback.
- [ ] Tasks estimate and final review report show non-generated diff ≤ 800 lines and generated summary ≤ 160 lines; over either threshold returns to PLAN for 00a/00b split before implementation acceptance.

Invariants (must not regress, 2-4):
- source mutation syscall and before/after manifest/source-state digest delta = 0（≤ 0），验证: bash common/tests/test-environment-seed-preflight.sh --case source-unchanged
- collision/validation failure changes to existing object/ref sentinel bytes = 0（≤ 0），验证: bash common/tests/test-environment-seed-preflight.sh --case digest-immutability
- external network plus sync/download/module-build/package successful execution count = 0（≤ 0），验证: bash common/tests/test-environment-seed-preflight.sh --case offline-command-guard
- visible dangling ref count after every publish fault = 0（≤ 0），验证: bash common/tests/test-environment-seed-preflight.sh --case failure-ref-rules

## 超出范围

- No `m services`, `m`, `mm`, `mmm`, ninja goal, whole build, package, flash or device validation; `soong_ui --dumpvars-mode` is configuration-only.
- No `repo sync`, Git fetch/clone, download or mirror/cache maintenance.
- No closure extraction, materialization, proof or build command from specs 01-05.
- No writes to tracked, untracked or ignored AOSP source; temporary output/evidence stays in external state-dir.
- No claim that local LK7K/vendor evidence is a public AOSP dependency baseline.
