---
id: 2026-09-01-00a-seed-contract-runtime
依赖: []
消费: 2026-09-01-00-environment-seed-preflight 的 supersession/v1 replacement、R1-R27 owner 与预算合同，并以 DECISIONS 2026-09-02 canonical numeric ABI supersession 替代原 signed/unsigned-64 JSON number 接受域
产出: seed-contract-runtime/v1 marker+Python module API；`./common/.harness/bin/feature-closure verify-seed INPUT` 或 `verify-seed --ref REF --artifact-store STORE [--require-public-real]`；同 grammar 的 `common/.harness/closure/v1/commands.d/verify-seed` direct recovery ABI
验收方式: 混合判定
已由用户确认: true
确认依据: 用户已授权 autopilot；design round 1 触发门②重开，三轮 fresh independent regression review 的第 3 轮以 0 finding PASS，agent 自动确认
---

> 用户原话：
> “批准 plan v4”
>
> “ok，后续走 autopilot 流程”
>
> 上游口径：`PLAN.md` v6 的 `2026-09-01-00a-seed-contract-runtime` 与 `DECISIONS.md`。

## 目标

在不读取真实 AOSP、不中断现有 harness 的前提下，交付后序 00b–05 共同消费的只读 dispatcher、closed seed/evidence schema、canonical digest、受限 state-dir、内容寻址 object store、原子 ref publisher、`verify-seed` 与独立 direct recovery ABI。路径实现固定使用 `openat`、`mkdirat`、`O_NOFOLLOW` 与 `forbidden_roots`；runtime exports 固定覆盖 `ContractError`、`RUNTIME_ABI`、`load_artifact`、`canonical_bytes`、`domain_digest`、`validate_state_paths`、`resolve_ref`、`publish_object`、`publish`；错误与 commit-point 标识固定覆盖 `ARGUMENT_ERROR`、`OUT_REF_CONTRACT`、`DIGEST_COLLISION`、`REF_BUSY`、`REF_DURABILITY_UNCERTAIN`、`OBJECT_LINK`、`PUBLISH_PRECOMMIT_FAILED`、`PUBLISH_OBJECT_ORPHANED`；schema 固定覆盖 `schema_version`、`kind`、`seed_content`、`seed_identity`、`real_source`、`env_pass`、`envsetup`、`lunch`。00a 只证明契约和持久化机制，不把 fixture 伪装成 real-source public seed。

## 需求

R1. [计划] 系统必须把 `./common/.harness/bin/feature-closure SUBCOMMAND` 固化为唯一 dispatcher ABI，把合法 command name 限定为 ASCII regex `^[a-z][a-z0-9-]{0,31}$`，并从 dispatcher 自身 realpath 的 parent 固定解析 `../closure/v1/commands.d/SUBCOMMAND` 后仅 exec 该可执行 regular file。

R2. [计划] 系统必须把 `common/.harness/closure/v1/commands.d/verify-seed INPUT` 与 `common/.harness/closure/v1/commands.d/verify-seed --ref REF --artifact-store STORE [--require-public-real]` 固化为两个互斥 production；dispatcher 形式只增加 `verify-seed` 子命令，positional form 不得带 ref/store/public-real option，ref form 不得带 positional input，missing/repeated/reordered/extra option 必须 `ARGUMENT_ERROR`，direct command 在 dispatcher 缺席时仍可独立执行。

R3. [计划] 当 runtime 读取 JSON artifact 时，系统必须拒绝非 UTF-8、duplicate/unknown/missing key、float、bool-as-integer、越界 integer与非法 enum，并只接受本节 artifact 的 `schema_version=1` 与 kind；只有本节显式声明 sorted/unique 的 array 才拒绝重复或乱序，argv/path/summary 等 semantic-order array 必须保留输入顺序且允许重复；`seed_content` 与 `seed_identity` 仅为内部 digest payload，不得要求 `schema_version`/`kind`，也不得独立发布。

R4. [计划] 当 runtime canonicalize payload 时，系统必须使用 RFC 8785 UTF-8 bytes 与本节固定 ASCII domain separator 求 SHA-256；JSON key 输入顺序变化不得改变 digest，任一承重字段变化必须改变对应 digest。

R5. [计划] 凡具备 state-dir 写入能力，系统必须要求 state-dir 是已存在、可写、无 symlink 分量且 normalized absolute path 等于 realpath 的目录，并以逐分量 `openat`/`mkdirat` 加 `O_NOFOLLOW` 创建 artifact/ref parent；artifact-store 参数必须精确等于 `STATE_DIR/artifacts/v1`，object directory 固定为 `ARTIFACT_STORE/sha256`，out-ref 必须是 state-dir 后代且 existing object/ref/parent 均以 no-follow regular-file/directory 规则读取，拒绝 literal tilde、relative、missing、non-directory、unwritable、escape 与 symlink path。

R6. [计划] 当校验 state-dir 隔离时，系统必须让调用者通过 runtime API 的 `forbidden_roots` 传入 harness repo、`.repo/manifests`、`.repo/repo` 与所有 source/project worktree realpath，并按 path-component containment 拒绝 state-dir/store/out-ref 与任一 root 相等或位于其后代；尚不存在的 leaf 必须按已解析 parent 加 lexical basename 判定。

R5/R6 的 filesystem threat model 固定为：state-dir 目录拓扑在一次 runtime invocation 内稳定；static symlink、non-regular leaf、containment escape，以及稳定拓扑下由 runtime lock 协调的并发 publisher 均在范围内。同一 effective UID 的外部对手在调用期间主动 rename/move/delete 已验证或刚由 `mkdirat` 创建的目录分量不在范围内，因为 Linux/POSIX 没有 atomic create-directory-and-return-fd primitive；若实现检测到此类拓扑变化，必须 fail closed 并 best-effort 清理，但不对该排除场景声明能定位已被移走且名称未知的 inode。此边界不得放宽 symlink/no-follow、forbidden-root 或正常 failure 的零越界写入判据。

R7. [计划] 当发布 object 时，系统必须把 bytes 写入 `STATE_DIR/artifacts/v1/sha256/<64-lower-hex-digest>`，使用同目录 temp、file fsync、mode 0444、hard-link no-replace 与 object-dir fsync；同 digest 同 bytes 幂等复用，同 digest 不同 bytes 必须 `DIGEST_COLLISION`。

R8. [计划] 当发布或解析 ref 时，系统必须在首次观察 existing ref/object 前取得 adjacent `OUT_REF.lock` 排他锁并持有至 ref-dir fsync 或解析完成；lock parent 必须是已验证的 ref parent，existing lock 必须以 `openat(...,O_NOFOLLOW)` 打开且为 effective uid owner、owner-only mode 0600 regular file，missing leaf 只能在该 parent 以 lexical basename、`O_CREAT|O_NOFOLLOW`、0600 创建；lock symlink/non-regular/wrong owner/wrong mode/open error 是 `OUT_REF_CONTRACT`，只有合法 lock fd 的 nonblocking contention 是 `REF_BUSY`。发布时必须先保证 matching object durable，再以同目录 temp、file fsync、atomic replace 与 ref-dir fsync 发布精确 ref bytes。

R9. [计划] 如果发生 object commit 后 ref commit 前故障，系统必须允许保留无 ref 的 immutable orphan object；如果发生 ref rename 后或 ref-dir fsync 故障，系统必须返回 `REF_DURABILITY_UNCERTAIN`，且可见 ref 只能是旧 bytes 或解析到 matching object 的 intended bytes，重放必须幂等。

R10. [计划] 当 `verify-seed` 接收 fixture file 时，系统必须完整重算 schema、domain digest、nested digest、cross-field success invariant 与 canonical object bytes；合法 public ABI golden 只输出 `SEED ABI PASS`，不得产生 `real_source` 证明。Positional fixture 没有 store 参数，因而只验证 embedded contract、不声称 external evidence closure；ref-mode 和 producer 必须验证下文 evidence closure。

R11. [计划] 当 `verify-seed --ref REF --artifact-store STORE --require-public-real` 成功时，系统必须要求 ref kind 为 `env_pass`、object kind 为 `seed`、`evidence_class=real_source`、`source_scope.role=public_aosp17_cuttlefish`、`public_aosp_baseline=true`、`vendor_context=false`、`platform_family=aosp-17`，并要求 success invariants 与四个 referenced evidence objects 全部通过；stdout 精确一行 `SEED ABI PASS public_aosp17_cuttlefish` 且 stderr 为空。00a 只以不写 production ref 的 pure predicate/evidence-closure seam 验成功分支并以 fixture/local/vendor ref 验负分支，真实 positive ref integration 归 00b。

R12. [计划] 如果发生 pre-publish argument/command/schema/path/ref/digest contract error，系统必须按 Deterministic state machine 的 exact code 全序 exit 30、stdout 为空、stderr 精确一行 `CONTRACT ERROR_CODE`，且 object/ref/temp/sentinel byte changes 为 0；只有成功完成 observation、取得 lock 并进入 publish stages 后的 fault 才可进入 R9/R15 状态。

R13. [计划] 当 dispatcher 与 direct ABI 使用同一 deterministic fixture/ref 时，系统必须得到相同 exit/stdout/stderr、canonical object/ref bytes、artifact/nested digest 与 public predicate 结果；command 缺失、symlink 或不可执行时 dispatcher 必须 exit 30、stdout 为空、stderr 精确 `CONTRACT COMMAND_UNAVAILABLE`。

R14. [计划] 当 00b–05 的 direct wrapper 启动时，系统必须先读取 regular file `common/.harness/closure/v1/runtime/seed-contract-runtime.version` 的精确 bytes `seed-contract-runtime/v1\n`，再从 `common/.harness/closure/v1/lib/seed_contract_runtime.py` import `ContractError`、`RUNTIME_ABI`、`load_artifact`、`canonical_bytes`、`domain_digest`、`validate_state_paths`、`resolve_ref`、`publish_object` 与 `publish`；marker/module/export 缺席、symlink、bytes/version 不符或 import 失败必须在调用 API 前 exit 30、stdout 为空、stderr 精确 `CONTRACT RUNTIME_UNAVAILABLE`，不得产生 object/ref 写入。

R15. [计划] 当 fault injection 位于 `OBJECT_LINK` 前、object link 后 ref rename 前、ref rename 后 fsync 前或无 fault 时，系统必须分别满足 `PUBLISH_PRECOMMIT_FAILED`、`PUBLISH_OBJECT_ORPHANED`、`REF_DURABILITY_UNCERTAIN` 或原始成功状态；受控 fault injection 返回前必须清除本 invocation 创建的全部 temp。意外终止遗留的 `.*.tmp.<pid>.<nonce>` 必须 mode 0600 且不可被 resolver 识别为 object/ref；ref-dir stale temp 仅由持有同一 ref lock 的后续 invocation best-effort 清理，object-dir stale temp 不被并发 publisher 自动清理且其 maintenance 不属于 00a。

R16. [计划] 当 00a exact merge SHA 写入 ledger 时，系统必须从该 merge 在 isolated worktree 先创建一个 descendant fixture commit，唯一新增 executable `common/.harness/closure/v1/commands.d/recovery-fixture` 且该 wrapper 实现 R14 pre-import check；随后 `git revert -m 1 --no-edit MERGE_SHA`，证明 wrapper 仍为 regular executable、dispatcher/marker/module/verify-seed 均消失，wrapper exit 30、stdout 为空、stderr 精确 `CONTRACT RUNTIME_UNAVAILABLE`，并逐字核对旧 harness test/parity/dev-sidebar demo 的三个 PASS 行。fixture commit 与 revert 只存在于隔离 worktree。

R17. [计划] 当 tasks estimate 超过 supersession ceiling 730 行或 schema/test review summary estimate 超过 140 行时，系统必须在 implementation 开始前回 PLAN 拆分；当 actual non-generated diff 超过 730 行或 actual summary 超过 140 行时，必须在 implementation acceptance 前回 PLAN 拆分。项目级 800/160 是不可放宽的外层绝对上限，不得把 731–800 或 141–160 当作 00a 可接受区间。

R18. [计划] 在 00a 实现与验收期间，系统必须不执行 AOSP `envsetup`、`lunch`、`m/mm/mmm`、ninja、package、flash、`repo sync`、Git fetch/clone 或下载；fixtures 不得读取 `/home/zzh0838/Project/lk7k-a17/system` 并宣称真实环境证明。

## Runtime API

`seed_contract_runtime.py` 的 stable imports 与 keyword-only signatures 固定为：

- `RUNTIME_ABI == "seed-contract-runtime/v1"`；`ContractError` 是唯一 expected failure carrier，构造参数和只读 `.code` 均为 exact error-code string；wrapper 只捕获 `ContractError` 并翻译为 `CONTRACT CODE`，其他 exception（包括 Python call-shape binding `TypeError`）统一 `CONTRACT RUNTIME_INTERNAL`。
- `load_artifact(*, path: str, expected_kind: str) -> dict`；`canonical_bytes(*, value: object) -> bytes`；`domain_digest(*, domain_ascii: str, value: object) -> str`，最后一个返回值必须是 64-lower-hex。
- `validate_state_paths(*, state_dir: str, out_ref: str | None, artifact_store: str, forbidden_roots: tuple[str, ...]) -> StatePaths`；`StatePaths` 是只读 mapping，exact keys 为 `{state_dir,artifact_store,object_dir,out_ref,ref_parent,lock_path}`，value 是 normalized absolute string，只有 out-ref absent 时后三项为 null。
- `resolve_ref(*, state_dir: str, ref: str, artifact_store: str, forbidden_roots: tuple[str, ...], require_public_real: bool = False) -> dict`；取得 R8 lock 后解析并返回 verified object dict。
- `publish_object(*, state_dir: str, artifact_store: str, object_kind: str, payload: dict, forbidden_roots: tuple[str, ...], fault_point: str | None = None) -> ObjectResult`；仅接受 `source_state|trace|command_journal`，`ObjectResult` exact keys `{digest,object_path}`，用于 00b 的无 ref evidence object。
- `publish(*, state_dir: str, out_ref: str, artifact_store: str, object_kind: str, payload: dict, ref_kind: str, semantic_exit: int, forbidden_roots: tuple[str, ...], fault_point: str | None = None) -> PublishResult`；`PublishResult` exact keys `{digest,object_path,ref_path,semantic_exit}`。

所有 path result 均为 normalized absolute string。CLI production 的 unknown/missing/repeated/positional option 与成功绑定后的 runtime value type/combination invalid 统一 `ARGUMENT_ERROR`；stable Python callable 的 unknown keyword、missing keyword 或 positional call-shape 由解释器抛 `TypeError`，属于 caller programmer error，不是 expected contract failure，CLI boundary 按上一条映射 `RUNTIME_INTERNAL`。两个 publisher 的 `payload` 都必须是 caller 提供的完整 artifact dict，包含 exact `schema_version:1` 与 `kind`，runtime 不增删 envelope，且 `object_kind == payload.kind`。任何 temp/object/ref 写入前，runtime 必须按 object_kind 唯一 dispatch 本节 closed schema、nested/cross-field digest 与 domain；错误为 `DESCRIPTOR_SCHEMA_INVALID`，object bytes exact 为 `RFC8785(payload)+LF`，object path digest 对不含 LF 的 RFC8785 bytes 使用对应 domain。`publish_object` 只接受并验证 `source_state|trace|command_journal`，先校验 state-dir/full forbidden-roots/store，再执行 R7 的 temp/fsync/link/collision 合同但不创建 lock/ref；object link 前 fault 是 `PUBLISH_PRECOMMIT_FAILED`，link 后 object-dir fsync fault 是 `PUBLISH_OBJECT_ORPHANED`。`publish` 只接受 `semantic_exit in {0,20}`、`seed/env_pass` 或 `terminal_report/terminal_report` 映射：seed 发布前验证四-object evidence closure，terminal-report 发布前验证每个 non-null completed digest 指向 matching kind object，再按 R7–R9/R15 执行。CLI ref form 必须从 exact `STATE_DIR/artifacts/v1` 的 STORE 以 `parent.parent` 推导 state-dir，要求 REF 是同一 state-dir 后代，并以 harness repo realpath 作为 verifier 的 forbidden root；该 verifier 路径不接受 source/project roots，00b 发布调用必须传入 R6 的完整 forbidden-roots 集合。

## Stable data ABI

所有 JSON artifact 拒绝 duplicate key、float、非 UTF-8、escaped/raw lone surrogate、unknown/missing field；signed integer 必须在 I-JSON safe range `-(2^53-1)..2^53-1`，其余 integer 均为 `0..2^53-1`，boolean 不算 integer。payload 使用 RFC 8785 UTF-8 bytes；fixture/golden bytes 只验证本节，不创造字段。Object key 输入顺序变化必须 canonicalize 为相同 bytes/digest；只有明确声明 sorted/unique 的 array 才要求严格递增并对重复/乱序报 schema invalid，semantic-order array 原样保序且允许重复。

### seed-request/v1 input

Top-level exactly `{schema_version,kind,source_root,envsetup_relpath,lunch,source_scope,resource_minimums,estimated_disk_upper_bound_bytes}`。

| field | type/value |
|---|---|
| `schema_version` / `kind` | integer `1` / string `seed_request` |
| `source_root` / `envsetup_relpath` | absolute realpath string / normalized relative string `build/envsetup.sh` |
| `lunch` | object exactly `{target,product,release,variant}`，all nonempty strings |
| `source_scope` | object exactly `{role,public_aosp_baseline,vendor_context,platform_family}`；public is `public_aosp17_cuttlefish,true,false,aosp-17`，local is `local_lk7k_product,false,true,aosp-17` |
| `resource_minimums` | object exactly `{available_bytes,available_inodes,effective_memory_bytes,effective_cpus}`，I-JSON safe unsigned integers；threshold missing/negative/float/bool/>`2^53-1` is `DESCRIPTOR_SCHEMA_INVALID` |
| `estimated_disk_upper_bound_bytes` | I-JSON safe unsigned integer |

Request digest is `SHA-256("aosp-harness/seed-request/v1\0" + RFC8785(payload))`; input bytes stay unchanged.

### source-state/v1 evidence

Payload top-level is exactly `{schema_version:1,kind:"source_state",manifest_sha256,projects}`；`manifest_sha256` 是 64-lower-hex。`projects` 按 UTF-8 `path` strictly sorted/unique，每项 exactly `{path,head,status_sha256,entries}`：`path` 是 nonempty normalized relative UTF-8 string，`head` 是 40/64-lower-hex，`status_sha256` 是 exact porcelain-v2 NUL bytes 的 64-lower-hex SHA-256。`entries` 按 decoded `path_b64` raw bytes strictly sorted/unique，每项 exactly `{path_b64,status_record_b64,entry_kind,mode,content_sha256,symlink_target_sha256}`；两个 `*_b64` 都是 canonical RFC 4648 base64 string，`entry_kind` 是 `regular|symlink|missing`，`mode` 是 uint。`regular` 要求 `content_sha256` 为 64-lower-hex、`symlink_target_sha256=null`；`symlink` 要求前者 null、后者 64-lower-hex；`missing` 要求 `mode=0` 且两 digest 均 null。Rename/copy records contribute both raw paths；untracked directories are never folded. Per-project digest is `SHA-256("aosp-harness/project-source-state/v1\0" + RFC8785(project item))`; workspace digest is `SHA-256("aosp-harness/source-state/v1\0" + RFC8785(top-level payload))`.

### trace/v1 evidence

Payload is exactly `{schema_version:1,kind:"trace",records,counts}`。`records` 按 `sequence` strictly increasing/unique，每项 exactly `{sequence,process_ordinal,syscall,result,errno,exec_argv_b64,paths,address_family,classification}`；`sequence`/`process_ordinal` 是 safe uint，`syscall` 是 nonempty ASCII string，`result` 是 I-JSON safe signed integer，`errno` 在 result nonnegative 时必须 null、negative 时必须是 nonempty stable errno ASCII name。`exec_argv_b64` 对 execve/execveat 是 canonical base64 string array，保留 argv 顺序并允许重复；其他 syscall 必须 null。`paths` 是 semantic operand-order array、允许重复，每项 exactly `{role,dirfd,raw_b64,resolved_b64}`；role 是 `path|oldpath|newpath|target|linkpath|source_fd|destination_fd`，dirfd 是 I-JSON safe signed integer 或 null，raw/resolved 都是 canonical base64 string。`address_family` 是 null 或 `AF_INET|AF_INET6|AF_UNIX|AF_OTHER`。

`classification` is record enum `other|external_network|source_mutation|sync_download|config_query|module_build|package`; top-level `counts` has exactly those keys as unsigned integers and counts only nonnegative syscall results. Digest is `SHA-256("aosp-harness/trace/v1\0" + RFC8785(payload))`; trace digest is run audit evidence and is excluded from stable seed identity.

### command-journal/v1 evidence

Payload is exactly `{schema_version:1,kind:"command_journal",records}`。Records 每项 exactly `{stage,argv_b64,cwd_b64,exit_code,trace_first_sequence,trace_last_sequence}`；stage enum/order 是 `manifest_before,source_state_before,namespace_probe,envsetup_lunch,manifest_after,source_state_after` 且每 stage 恰好一次；`argv_b64` 是 canonical base64 string array，按 argv 语义保序且允许重复；`cwd_b64` 是 canonical base64 string；exit/sequence 三字段均是 uint 且 `trace_first_sequence <= trace_last_sequence`。Digest is `SHA-256("aosp-harness/command-journal/v1\0" + RFC8785(payload))`; empty/missing/reordered stages are invalid.

### seed/v1 success output

Top-level is exactly `{schema_version:1,kind:"seed",evidence_class,request_digest,source_scope,source,manifest,tools,execution,resources,lunch,source_state,guard,seed_content_digest,seed_identity_digest}`. `evidence_class` is `real_source|fixture_only`.

| object | exact children and types |
|---|---|
| `source_scope` | same four fields/values as request |
| `source` | `{root,envsetup_relpath}`；root 是 normalized absolute realpath string，envsetup 是 normalized relative exact `build/envsetup.sh` |
| `manifest` | `{repository_commit,locked_xml_sha256,project_count,remotes,projects}`；commit 为 40/64-lower-hex、digest 为 64-lower-hex、count uint 且等于 projects length；remotes 按 name strictly sorted/unique，item `{name,fetch_url,review_url,mirror_url}`，name nonempty string，后三者为 credential-free string/null；projects 按 path strictly sorted/unique，item `{path,name,remote,revision,head,source_state_digest}`，path normalized relative，head 40/64-lower-hex，digest 64-lower-hex，其余 nonempty strings |
| `tools` | `{repo_checkout_commit,repo_launcher_path,repo_launcher_sha256,repo_version,git_version,python_version}`；checkout commit 为 40/64-lower-hex 或 null，launcher path normalized absolute，launcher digest 64-lower-hex，其余 nonempty strings |
| `execution` | `{host_arch,kernel_release,kind,container_digest}`；arch/kernel 是 nonempty strings，kind `host|container`；host 要求 digest null，container 要求 digest 为 64-lower-hex |
| `resources` | `{estimated_disk_upper_bound_bytes,minimums,measured,passed}`；estimate/minimums 复用 request；measured exact `{available_bytes,available_inodes,host_mem_available_bytes,cgroup_mem_remaining_bytes,effective_memory_bytes,online_cpu_count,cpuset_cpu_count,effective_cpu_numerator,effective_cpu_denominator}`，除 cgroup/cpuset 为 uint/null 外均为 uint，online/numerator/denominator >0，非空 cpuset >0，fraction 必须 reduced 且 denominator >0，effective memory 等于 host 与 non-null cgroup 的 min；passed exact `{disk,inodes,memory,cpu}` booleans，disk iff available bytes ≥ max(minimum bytes,estimate)，inodes iff available inodes ≥ minimum，memory iff effective memory ≥ minimum，cpu iff numerator ≥ minimum CPUs × denominator |
| `lunch` | `{target,product,release,variant,variables,out_dir_relative,envsetup_exit,lunch_exit}`；前四项 nonempty strings；variables exact `{TARGET_PRODUCT,TARGET_RELEASE,TARGET_BUILD_VARIANT,TARGET_ARCH,TARGET_2ND_ARCH,HOST_OS,HOST_ARCH}` string/null；out dir 是无 `.`/`..` 的 normalized relative UTF-8 path 且按 component 位于 `tmp/preflight` 后代；exits uint |
| `source_state` | `{state,clean_source_proof,affected_project_count,before_digest,after_digest,observed_ignored_inputs}`；state `clean|dirty`，proof bool，count uint，before/after 64-lower-hex；clean iff proof=true 且 count=0，dirty iff proof=false 且 count>0；ignored inputs 按 decoded logical raw path strictly sorted/unique，每项 exactly `{path_b64,resolved_path_b64,entry_kind,mode,content_sha256,symlink_target_sha256,target_content_sha256}`，path 为 canonical base64，kind `regular|symlink`，mode uint；regular 要求 content 64-lower-hex 且 symlink/target null，symlink 要求 content null 且 symlink/target 都为 64-lower-hex |
| `guard` | `{parent_netns_inode,probe_netns_inode,trace_digest,command_journal_digest,external_network_count,source_mutation_count,sync_download_count,module_build_count,package_count}`；inode/count uint，digest 64-lower-hex |

Seed content digest payload is exactly `{locked_xml_sha256,projects,observed_ignored_inputs}`，复用上述 manifest projects 与 ignored-input schemas 且无 schema/kind；domain 是 `aosp-harness/seed-content/v1\0`。Seed identity digest payload is exactly `{source_scope,manifest,tools,execution_identity,lunch_identity,source_state_identity,seed_content_digest}` 且无 schema/kind，其中：`execution_identity` exactly `{host_arch,kind,container_digest}` 并复用 execution 类型/host-null 规则；`lunch_identity` exactly `{target,product,release,variant,variables}` 并复用 lunch 类型；`source_state_identity` exactly `{state,clean_source_proof,affected_project_count,before_digest,after_digest,observed_ignored_inputs}` 并复用 source-state 类型。其 domain 是 `aosp-harness/seed-identity/v1\0`。Seed artifact domain 是 `aosp-harness/seed-artifact/v1\0` over full seed payload。Resource values、kernel、trace/journal、lunch exits/OUT_DIR 与 scheduling 可改变 artifact digest，但 unchanged source/request 时不得改变 seed content/identity digest。

`verify-seed INPUT` 必须从 seed 重建 exact seed-request：`source.root -> source_root`、`source.envsetup_relpath`、lunch 的 target/product/release/variant、`source_scope`、`resources.minimums -> resource_minimums`、`resources.estimated_disk_upper_bound_bytes`，重算并等于 `request_digest`；同时要求上述重复字段逐值相等，再重算 source-state/content/identity/artifact digests。Positional INPUT 的任一 nested/cross-field/digest mismatch 为 `DESCRIPTOR_SCHEMA_INVALID`；ref-resolved object 的同类 mismatch 为 `REF_CORRUPT`。

所有 `seed`（包括 fixture_only）必须满足 success cross-field invariants：四个 `resources.passed` 全 true；`envsetup_exit=lunch_exit=0`；`guard.parent_netns_inode != guard.probe_netns_inode`；guard 的 `external_network_count,source_mutation_count,sync_download_count,module_build_count,package_count` 全为 0；`source_state.before_digest == source_state.after_digest`；以及 manifest count/source-state consistency。Ref resolution 和 seed publish 还必须在同一 ARTIFACT_STORE 中闭合四个 content-addressed evidence objects：before/after digest 各指向 canonical `source_state` object，guard digest 各指向 canonical `trace`/`command_journal` object，path digest 等于各自 domain digest且 kind matching；两个 source-state 的 `manifest_sha256` 都必须等于 seed `manifest.locked_xml_sha256`，projects path set 必须等于 manifest projects path set，每个 project item 重算的 project digest必须等于对应 manifest `source_state_digest`；trace counts 必须等于 guard 五类 count；journal 六个 stage exit 全为 0、每个 first/last sequence 都存在于 trace records，且 `envsetup_lunch.exit_code == lunch.lunch_exit`。任一 required evidence object missing 为 `ARTIFACT_MISSING`；kind/bytes/path/content/cross-field mismatch 在 ref/producer mode 为 `REF_CORRUPT`，positional embedded invariant mismatch 为 `DESCRIPTOR_SCHEMA_INVALID`。上述检查先于 `PUBLIC_SCOPE_REQUIRED`；后者只表示 structurally successful seed 的 evidence_class/source_scope 不满足 public identity predicate。

### terminal-report/v1 output

Payload is exactly `{schema_version:1,kind:"terminal_report",request_digest,primary_reason,failed_checks,completed_observation_digests,summary_lines}`；request digest 是 64-lower-hex。Environment reason 全序和值域 exact 为 `SOURCE_ROOT_UNAVAILABLE,REPO_METADATA_UNAVAILABLE,ENVSETUP_UNAVAILABLE,REPO_CLIENT_UNAVAILABLE,WORKTREE_ENUM_UNAVAILABLE,RESOURCE_DISK,RESOURCE_INODE,RESOURCE_MEMORY,RESOURCE_CPU,NETWORK_NAMESPACE_UNAVAILABLE,TRACE_UNAVAILABLE,LUNCH_FAILED,FORBIDDEN_EXECUTION,SOURCE_MUTATION,SOURCE_CHANGED`。`failed_checks` 必须 nonempty、strictly unique 且是该全序的 ordered subsequence；`primary_reason` 必须等于第一项。completed digests exactly `{source_state,trace,command_journal}`，各 value 为 64-lower-hex 或 null；`summary_lines` 是最多 120 个 UTF-8 string 的 semantic-order array，允许重复且不得含 timestamp、username、credential 或 source content。Digest domain is `aosp-harness/terminal-report/v1\0`.

### ref bytes

Ref bytes are exactly RFC 8785 of `{schema_version:1,kind,digest}` plus one LF. Kind mapping is exact `env_pass -> seed` and `terminal_report -> terminal_report`; digest is 64 lower hex. Under lock，resolver 的 ref leaf missing 是 `ARTIFACT_MISSING`；ref symlink/non-regular/open error 或 noncanonical bytes/type/kind/digest 是 `REF_CORRUPT`；publisher 允许 missing ref 并创建它，但 existing ref 服从同一 `REF_CORRUPT` 规则。合法 ref 指向的 object missing 或 seed evidence closure object missing 是 `ARTIFACT_MISSING`；existing object 的 symlink/non-regular/open error/noncanonical bytes、wrong kind、path digest/content digest/nested/cross-field mismatch 均为 `REF_CORRUPT`；最后 `--require-public-real` predicate false 为 `PUBLIC_SCOPE_REQUIRED`。

## Error priority 与 publish matrix

不读取 ref/object 的 validation 按 entry stage 分层 stop-at-first。Dispatcher stage 只判：missing subcommand → `ARGUMENT_ERROR`，present name 不匹配 regex → `INVALID_COMMAND`，合法 name 的 target missing/symlink/non-regular/non-executable → `COMMAND_UNAVAILABLE`；它不得解析 command-specific argv，所以 target unavailable 与 invalid child argv 同时发生时必须是 `COMMAND_UNAVAILABLE`。成功 exec 后，direct wrapper 启动 stage 必须先做 R14 marker/module/import preamble，失败 `RUNTIME_UNAVAILABLE`；只有 preamble 成功才解析自身 grammar，invalid argv → `ARGUMENT_ERROR`，因此 direct runtime unavailable 与 invalid argv 同时发生时必须是 `RUNTIME_UNAVAILABLE`。随后 runtime stage 全序为：bound-value/combination `ARGUMENT_ERROR` → `DESCRIPTOR_NOT_FOUND` → `DESCRIPTOR_INVALID_UTF8` → `DUPLICATE_JSON_KEY` → `UNSUPPORTED_SCHEMA_VERSION` → `DESCRIPTOR_SCHEMA_INVALID`（含 positional nested mismatch 与 threshold missing/negative/float/bool/overflow）→ `SOURCE_ROOT_CONTRACT` → `STATE_DIR_CONTRACT` → `OUT_REF_CONTRACT` → `WORKTREE_MISMATCH`。不适用于当前 production 的 code 跳过；这些错误在 lock/publish 前 exit 30、stdout empty、stderr exact `CONTRACT CODE`，object/ref/temp/sentinel byte changes 为 0。

Valid pre-lock contract 后先打开/验证 lock leaf：contract failure 为 `OUT_REF_CONTRACT`；合法 fd 的 nonblocking contention 才为 `REF_BUSY`。取得 lock 后才首次观察 ref/object，resolver 错误全序为 `ARTIFACT_MISSING`（ref missing）→ `REF_CORRUPT`（ref leaf/type/bytes）→ `ARTIFACT_MISSING`（primary/evidence object missing）→ `REF_CORRUPT`（object leaf/bytes/kind/path/content/nested/cross-field）→ `PUBLIC_SCOPE_REQUIRED`；均 exit 30 且无 object/ref/temp/sentinel byte change。Publisher 的 missing ref 是合法 create case，其余 existing ref 顺序相同；发布 stage 全序为 `DIGEST_CHECK,OBJECT_TEMP,OBJECT_LINK,OBJECT_DIR_FSYNC,REF_TEMP,REF_RENAME,REF_DIR_FSYNC`。高优先级 validation 必须屏蔽低优先级 fault injection；同一阶段只能产生下表唯一 code。

| commit point | exit/code | durable state |
|---|---|---|
| `DIGEST_CHECK` same path/different bytes | 30 `DIGEST_COLLISION` | no object/ref change；overrides semantic 0/20 |
| before `OBJECT_LINK` | 30 `PUBLISH_PRECOMMIT_FAILED` | no new object/ref；old ref unchanged |
| after object link, before `REF_RENAME` | 30 `PUBLISH_OBJECT_ORPHANED` | intended immutable object may remain orphan；no dangling ref；old ref unchanged |
| after `REF_RENAME`, including ref-dir fsync | 30 `REF_DURABILITY_UNCERTAIN` | ref is old or exact intended bytes；intended ref resolves matching object |
| no fault | original 0/20 | object durable first，then exact ref durable |

## Autopilot decisions

- Questions 0/15，rounds 0/2。用户已批准 PLAN 与后续 autopilot；没有待用户回答的问题，numeric ABI 由 autopilot 按本节及 DECISIONS 的显式 supersession 裁定。
- 验收方式保持“混合判定”：机器判 exact bytes/digest/exit/channel/path/fault/rollback，人只检查 schema 是否覆盖 PLAN 的共享 runtime 边界。
- public golden 只验 ABI；00a 对 `require_public_real` 只做 pure predicate seam 与负例，不创建伪 `real_source` production ref，也不输出 `GATE CONTINUE_PUBLIC`。
- design review 暴露 RFC 8785 与 full 64-bit JSON number 不可兼得后，autopilot 明确选择 I-JSON safe-integer supersession；禁止 00b 对越界 observation 静默截断/舍入。
- 已定：实现不得读取真实 AOSP；00b 才负责 environment/source/trace/resource/lunch evidence。

## 验收标准

主验证命令: bash common/tests/test-seed-contract-runtime.sh
期望输出: exit 0；完整 stdout 精确一行 `RESULT PASS seed-contract-runtime` 加 LF；stderr 为空；dispatcher/direct 子进程输出均由测试捕获并逐字断言，不泄漏到主命令 stdout

验收清单:
- [ ] dispatcher/direct parity matrix 覆盖 valid fixture、invalid command、missing/symlink/non-executable command，逐例断言 exit、完整 stdout、完整 stderr。
- [ ] schema/digest matrix 对六种 artifact kind 与两个内部 digest payload 的每个顶层/nested field 覆盖 missing/unknown/duplicate/type/boundary；sorted/unique array 逐项验 duplicate/out-of-order，semantic-order array 验顺序保留与合法重复，object key reorder 验 canonical bytes/digest 相等，run-evidence mutation 只改变 artifact digest而不改变 identity digest。
- [ ] canonical numeric/string matrix 逐字覆盖 `2^53-1` accept、`2^53` reject、`-(2^53-1)` accept、`-2^53` reject、escaped high/low lone surrogate reject、合法 surrogate pair/raw Unicode accept，并核对 exact canonical bytes 与 digest。
- [ ] argument carrier matrix 逐字覆盖 CLI unknown/missing/repeated/reordered/positional option → exact `ARGUMENT_ERROR`；成功绑定后的 runtime value/type/combination invalid → `ContractError("ARGUMENT_ERROR")`；Python API unknown/missing/positional call-shape → 原生 `TypeError`；CLI boundary 必须至少注入一次由 stable callable unknown/missing/positional call-shape 产生的 binding `TypeError`，并断言 exit 30、stdout empty、stderr exact `CONTRACT RUNTIME_INTERNAL` 且无 traceback，其他 unexpected exception 不能替代此 case。
- [ ] staged mixed-fault matrix 逐字覆盖 invalid subcommand+invalid child argv → `INVALID_COMMAND`；missing/symlink/non-executable target+invalid child argv → `COMMAND_UNAVAILABLE`；direct runtime unavailable+invalid argv → `RUNTIME_UNAVAILABLE`；runtime available+invalid argv → `ARGUMENT_ERROR`。
- [ ] path/store/ref matrix 覆盖 literal tilde、relative/missing/unwritable/symlink/containment、missing/ref-symlink/nonregular ref、invalid/contended lock、collision、corrupt ref 与四个 publish commit point，逐例核对 exact code 和 sentinel/object/ref/temp 状态。
- [ ] public golden 被标为 `evidence_class=fixture_only`；`--require-public-real` 的 unit seam 验 matching public predicate/evidence closure，CLI/ref integration 覆盖 fixture/local/vendor/malformed、failed-resource/lunch/guard/source-stability 与 missing/wrong-kind/corrupt evidence 负例，真实 positive integration 明确留给 00b。
- [ ] final review 证明 non-generated diff ≤730、schema/test summary ≤140；rollback 从唯一 ledger merge SHA 创建 descendant wrapper fixture 后 isolated revert，wrapper 保留并 exact `RUNTIME_UNAVAILABLE`，旧 harness 三项精确 PASS。

不变量（不许劣化，5 项）:
- validation/collision failure 对 existing object/ref sentinel byte changes = 0（≤ 0），验证: bash common/tests/test-seed-contract-runtime.sh --case digest-immutability
- 在稳定目录拓扑下，path/symlink/containment failure 在 state-dir 外创建的 filesystem entries = 0（≤ 0）；同 UID 主动目录 rename/move/delete 排除项只验证 fail closed + best-effort cleanup，验证: bash common/tests/test-seed-contract-runtime.sh --case path-confinement
- 每个 publish fault 后 visible dangling ref count = 0（≤ 0），验证: bash common/tests/test-seed-contract-runtime.sh --case failure-ref-rules
- `--require-public-real` 接受 failed success-invariant/evidence-closure 的 seed 数 = 0（≤ 0），验证: bash common/tests/test-seed-contract-runtime.sh --case public-real-gate
- 00a rollback 后 retained-wrapper/旧 harness regression failures = 0（≤ 0），验证: bash common/tests/test-seed-contract-runtime.sh --case rollback --ledger .spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00a-seed-contract-runtime/ledger.md

Rollback 的三个旧 harness oracle 固定为：`bash common/tests/test-harness.sh` 末行 `RESULT PASS  shared Harness regression suite`；`bash common/.harness/bin/check-parity.sh` 完整 stdout `PARITY PASS  Claude/Codex 共享同一公共契约`；`bash common/.harness/features/dev-sidebar/verify-sidebar.sh --demo` 末行 `RESULT PASS`，三者均 exit 0。

## 超出范围

- 不执行或验证真实 AOSP source、manifest、Repo、resource、namespace、trace、envsetup/lunch；这些属于 00b。
- 不创建 real-source public/local seed，不把 fixture digest 写入固定 public/local production ref。
- 不实现 feature lock、closure extraction/materialization/proof、repo-unit build 或 feature integration。
- 不运行 sync/download/module build/package/flash/device validation，不修改用户 AOSP 工作区。
- 不修改 00b–05 尚未创建的 direct command；只固定其 runtime marker/version failure contract。
