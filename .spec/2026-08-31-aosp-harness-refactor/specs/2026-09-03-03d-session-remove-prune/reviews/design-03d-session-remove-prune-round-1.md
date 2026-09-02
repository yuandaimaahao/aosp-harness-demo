# Review: design 03d-session-remove-prune round 1
verdict: PASS
阻断: 0 / 重要: 0 / 次要: 2

## findings

- [M1] design.md:7（概述第一决策行） 弃用理由称 path core「把根缺失映射 unsafe/rc2」——与源码事实不符。`session-state-path.sh:51-55,99-101` 中 root leaf 与其余层级一样走 `open_managed` 的 fresh mkdir 分支，根缺失会被**创建**而非 rc2；真正映射 rc2 的是 physical parent/base 缺失（`select_root`→`physical_dir` 的 `resolve(strict=True)` 失败 → UnsafeState，path.sh:31-38,96-98）。承重论据（path core creating、与 R3 non-creating 不可调和）成立且充分，仅该子句误述了被弃用方的行为，可能误导 tasks/实现期对「同源 root 选择」的复刻。建议改为「physical parent/base 缺失经 strict resolve fail closed rc2，而 root/project/session 缺失一律 fresh mkdir（creating）」。
- [M2] design.md:205（sizing 分解） `tests/test-session-state.sh` 预算 205 行相对同构实测偏紧：03c 测试实际 325 行（DECISIONS.md:44，预算 345）承载的矩阵更小，本片要装入 remove 矩阵+aggregator 发布面+六类 fixture+双 mutant 注入。表驱动 fixture 循环（~35 行）是主要压缩手段，但属未验证假设。design 已写明「无 runnable prototype、纯分解预算」与超额回 PLAN 拆片预案（备选拆动态攻击行为独立 assurance 片），方向正确，故仅次要；建议 tasks 阶段最先落定 fixture 表驱动循环与 mutant 注入的真实行数，超预算早拆片而非后期压缩 oracle。

## 核对记录

实际读取/执行（全部亲核，未仅信 design 转述）：

- **mktemp 实测**（`mktemp -d` 内 python3，七项全过）：`os.unlink("feature", dir_fd=session_fd)` 删除成功；held child `fstat` vs parent fd 下 name re-stat 的 dev/inode identity 核对一致/换入后可检出不一致；`os.rmdir(name, dir_fd=parent_fd)` 空目录成功、重入 ENOENT(errno 2)、非空 ENOTEMPTY(errno 39)、`stat(follow_symlinks=False)` 对软链不报目录、unlink 目录 EISDIR(21)。design 的 syscall 流程 non-creating、ENOENT/ENOTEMPTY 幂等停止、identity 不符 rc2、EIO 及其他 OSError rc1 的归类与 rc 表自洽且可实现。design.md:8 的「实测确认」声明与本人独立复测一致。
- **path core creating 核实**：`session-state-path.sh:46-72` `open_managed` 对 ENOENT 执行 `os.mkdir(name, 0o700, dir_fd=)`——弃用理由主干成立（M1 仅针对 rc2 子句）。
- **embedded python3 先例**：foundation `_harness_session_state_run`(:27)、path core(:13)、snapshot worker(:6) 三处 heredoc python3 先例确认；anchor 先例确认：path `pass  # HARNESS_TEST_MARKER_OS_ERROR`(:94)、snapshot `os_checkpoint`(:158-159)——EIO 注入 anchor 方案沿 03a/03b 先例属实。
- **source guard 链与顺序唯一性**：亲读四模块 guard——foundation 无 guard；path(:2-4) 需 foundation 3 export；snapshot(:2-3) 需 validate+path_core；signals(:16-20) 需 snapshot 3 export。线性依赖链 → foundation→path→snapshot→signals→remove 是唯一全激活顺序，design.md:9,63 论证与源码一致。
- **9 export 名单逐字比对**：foundation `harness_validate_feature_name`(:10)/`_harness_session_state_run`(:17)/`_harness_session_state_foundation_path`(:120)、path `_harness_session_path_core`(:5)、snapshot `_harness_session_snapshot_worker`(:4)/`_harness_session_snapshot_write_core`(:206)/`_harness_session_snapshot_read_core`(:207)、signals `_harness_session_write_with_signals`(:22)，加本片 `_harness_session_remove_core`——design.md:61 名单与真实模块逐字一致、无多无少。（记录在案、不构成 finding：remove 依赖的 `_harness_component_is_safe` 不在 9 名点名单内，但它由 foundation 无条件定义且 `harness_validate_feature_name`(:11) 自身调用它，点名 export 在场即隐含其在场；PLAN:130 的点名检查本就是存在性检查。）
- **partial capability 不可能性**：临界区写法（全部 preflight/source/`declare -F` 完成后才进入纯函数定义+marker 赋值区）中间无可失败语句，source 中途失败时公共 API 尚未定义；私有 export 可能部分在场但不构成 capability（R6 只禁四个 public+marker），fixture 断言 consumer 忽略已加载前序函数——论证闭环。
- **frontmatter 逐字比对（程序化）**：python 提取 design.md:68 产出串与 requirements.md:5、design.md:74 消费串与 requirements.md:4，两次全串相等（含固定摘要反引号写法）。四个转接目标（path_core/write_with_signals/snapshot_read_core/remove_core 各 `"$@"` 单行）与 R7 逐字一致。
- **PLAN/DECISIONS 引用亲核**：PLAN.md:53（判据 `RESULT PASS  session state`）、:80（四文件边界+独占 fragment）、:130（03d 详情全要素）、:186/:187（03c→03d、03d→03e 边）、:221（aggregator 缺席归 03e/08，design:197 如实注明自愿加严）、:223-234（`--session-provider-fixture` 五值、:234 missing-remove 依据）；DECISIONS.md:25(round2 错误表)/:26(round3 prune 口径)/:28(收窄 I1-I3)/:29(B1)/:31(P5/P2 回流)/:42（九文件上游集合=六基线+03c 两文件）/:44(03c 验收行满足 03d 启动门)——全部相符。
- **PRUNE_BEFORE_IDENTITY 强度**：design:8「检查前确定性替换 fail closed rc2、检查后窗口不承诺保护、放弃更强宣称」与 DECISIONS:29 B1 逐义一致，无超宣称；数据模型不变量（:105）同样只承诺核对过的空目录/verified feature 被删。
- **测试策略 vs 判据**：R3/R4 全子句（存在删除+全层 prune、缺失幂等仍 prune、并发非空不删他项、rc 0/1/2、stderr 两文案、rg 证无 rc3、EIO anchor 注入 rc1、identity 攻击行 rc2 且新旧目录均保留）在 design:196 集成行全覆盖；六类 fixture 与 R8/不变量 3 计数一致；aggregator-absent 不断言双流空（design:197，门② I1 修复在 design 层同样遵守）；双 mutant 均能确定性 FAIL 对应 oracle 行；红证据「路径独占一行零尾随字符」照 03c 契约；字节比较禁 command substitution(design:203) 与 03c 同款。
- **sizing 算术**：110(8+12+25+22+10+20+8+5)+50(10+10+12+12+6)+205(18+70+30+35+25+12+6+9)+25=390≤400、余量 10 行，各分项加法复核无误；path 实测 114 行、03c 模块实测 45 行（wc 复核），类比基准数字准确。
- **文件清单**：恰四文件且与 R10 exact 集合逐字一致；验收资产字段为 03c 同构超集（多出的 03e 五类资产缺席机械核对记录正是 R11 要求）。
- **mermaid 4 块人工核对**（离线无渲染器）：graph TB 节点/边/虚线标签边 `-. text .->` 语法合法；三块 sequenceDiagram 的 participant/loop/alt-else-end/Note over 配对闭合、箭头形式合法，未发现语法错误。
- **错误处理表**：覆盖 inert、arity/ID rc2、root 选择 rc2、链 ENOENT 幂等 0、unsafe 链/feature rc2、identity 不符 rc2、ENOENT/ENOTEMPTY rc0、EIO rc1、aggregator 三类失败 rc1、CLI 非法 rc1、dependency-absent inert rc0、case 失败计数 rc1——happy path 之外场景无缺口。
- **需求映射**：R1–R11 每条在映射表出现且组件职责无重叠无缺口；controller 验收组件（R10/R11）职责与 requirements 验收清单第 8-10 条一致。

两条次要均不阻断：M1 是弃用理由中的事实性误述（决策本身成立），M2 是预算风险（预案已写明）。修订后可直接进入门③后续环节。
