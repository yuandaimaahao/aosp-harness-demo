# THROWAWAY sizing prototype — 不进入生产或任务 diff

## 初始问题与已证伪结论

问题：收窄后的 provider 与单个根测试，是否能在 360 行 design 目标内覆盖全部承重 helper/oracle？

初始结论曾认为可展开为 provider 210 行、test 148 行、coverage 1 行，共 359；execute task 1.1/1.2 已用真实且独立 review 的 373 行证伪该物理行数估算。下列区间现在只保留为“逻辑 helper/case 是否漏项”的清单，不再作为压缩物理行目标。

## Execute 校准（PLAN v5.2）

| 证据/预算 | provider | test | coverage | 合计 |
|---|---:|---:|---:|---:|
| task 1.1/1.2 已 review 实测 | 118 | 255 | 0 | 373 |
| 剩余逻辑骨架 | 132 | 100 | 1 | 233 |
| 剩余可读实现预算 | 238 | 584 | 1 | 823 |
| 校准 design 目标 | 360 | 839 | 1 | 1200 |
| 聚合硬门余量 |  |  |  | 200（至 1400） |

生产剩余预算使用已实现段倍率上取整到 `1.8`；测试剩余预算使用现有逐字/零副作用 oracle 的高倍率 `5.84`，不假设把多个断言塞入单行。1400 只约束最终 3 文件聚合包；16 个任务仍分别生成小 diff 并接受独立 review，因此提高聚合门不等于放宽单轮未审代码。

## Provider 逻辑骨架（初始 210 行估算）

```text
001-002 shebang + source-only comment
003-007 _harness_component_is_safe(value)
008-022 five public functions: arity, silent predicate, op dispatch
023-034 facade: pending/child state, first trap, spawn gap, wait loop, final rc
035-040 Python imports, constants, ctypes renameat2 signature
041-047 private Unsafe/Missing/Conflict/Operation/Interrupted classes
048-054 first-signal-wins handler installed before mutation
055-060 centralized stdout/stderr/rc emitter
061-066 raw_path_is_safe(path, reject_root)
067-078 select_root(env, euid): HARNESS/XDG/TMP/default branches
079-085 split physical parent + leaf, strict realpath/open parent
086-093 stat_name + EXPECTED_EUID marker/assignment
094-104 open_managed: missing/create race, marker/open/fstat/fchmod/verify
105-114 open_snapshot: marker/open/fstat/owner/mode/nlink
115-128 bounded read + exact safe-name/LF parser + missing policy
129-137 make_temp: random name/open/fchmod/fstat/ownership state
138-144 write_all(temp_fd, feature bytes)
145-156 renameat2 + immediate errno + EEXIST winner mapping
157-164 write cleanup and publish ownership transition
165-174 remove snapshot: missing skip or verified relative unlink
175-188 prune reverse loop: PRUNE_BEFORE_IDENTITY marker, identity, rmdir errno mapping
189-194 reverse fd close and remove result
195-202 path/write/read/remove dispatcher branches
203-210 catch private/OS exceptions and call centralized emitter
```

remove 不复制遍历：dispatcher 组合 `open chain -> open_snapshot(remove) -> unlink if present -> prune(chain)`；`prune` 是一个 3-entry reverse loop。tasks 可在总目标内跨块调剂，但不得删除安全检查或合并可观察错误分支。

完整生产块预算仍为：

| 块 | 行 |
|---|---:|
| Bash predicate/API/signal facade | 34 |
| Python imports/ctypes/errors/signal | 26 |
| root selection + managed fd traversal | 44 |
| snapshot verifier/read | 24 |
| temp/write/publish | 36 |
| remove/prune | 30 |
| dispatch/close/output mapping | 16 |
| 合计 | 210 |

## Test 逻辑骨架（初始 148 行估算）

```text
001-004 shebang, strict mode, repo/provider paths
005-010 mktemp roots, poison bin/log, EXIT cleanup
011-016 fail(), run_case(), exact last-line discipline
017-022 capture_api() + assert_result()
023-030 validate table: invalid values plus 1/128 success
031-038 root success table: HARNESS, XDG, TMP, default
039-046 root unsafe table: empty, relative, dotdot, control, missing, slash
047-048 two projects x two sessions unique paths
049-056 API table: path/write/read/remove exact outputs and rc
057-064 directory/snapshot owner/mode/nlink/content
065-072 same-value idempotence + missing non-creating
073-080 mutate_provider() + exact marker/replacement/sentinel helper
081-087 parallel same/different result multisets + no temp
088-094 symlink/hardlink/directory/mode/content attack table
095-099 MANAGED and SNAPSHOT stat→open swap rows + victim hashes
100-104 EXPECTED_EUID + OS_ERROR mutations
105-112 empty hierarchy prune + ENOTEMPTY survivor
113-120 PRUNE_BEFORE_IDENTITY directory replacement case
121-128 TEMP_BEFORE_PUBLISH barrier helper: before_publish/race_loser/after_publish
129-136 child/facade/group x signals + first-signal/post-publish/winner inode
137-141 poison command log + static network token scan
142-144 coverage exact active row
145-147 exact file/line gate helper with pass/fail fixture values
148 unique RESULT PASS line
```

同类值只增加 table 数据，不复制 shell function。九个基础信号组合由 `for target in child facade group; for signal in HUP INT TERM` 生成；`race_loser`、`after_publish` 和连续双信号各保留独立表数据并复用 barrier/结果 oracle，facade spawn-gap 用 `pending_signal/child_pid/child_rc` 静态结构断言，不新增第七个 marker。每次 mutation 共用 copy/count/replace/sentinel helper，权限、内容和 link case 共用 Python setup helper。复用的目标是减少逻辑复制，不再要求落到初始 148/210 物理行；独立 case 名和精确断言不得合成“命令运行过”。

## 拒绝条件

- tasks 中任何承重 helper/case 未映射到上述名字：拒绝进入 execute。
- 任一任务 reviewer 判断增量无法在 10 分钟内审完：拆任务，不用 1400 聚合门掩盖粒度失真。
- implementation review package 出现第 4 个文件或总新增+删除超过 1400：无条件拒绝验收。
