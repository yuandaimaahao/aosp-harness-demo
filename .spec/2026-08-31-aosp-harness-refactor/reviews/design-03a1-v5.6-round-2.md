# 03a1 design v5.6 review — round 2

Reviewer: `review_plan_v5_2`

Verdict: **NEEDS_CHANGES** — blocker 0 / important 2 / minor 1

审查范围：复核round1 B1、I1–I4、M1，并同步审查因路径隔离与canonical inventory回流的requirements R3/R6及验收清单；对照当前design、requirements、PLAN v5.6、round7 final report/evidence和400行prototype。未修改spec、PLAN或prototype，本文为唯一新增文件。

## Round 1 findings复核

| finding | 状态 | 精确证据 |
|---|---|---|
| B1 workspace/log可alias并改坏provider | ✅ 设计边界闭合 | `requirements.md:25,48`与`design.md:64-68`现要求physical parent、absent leaf、0700、CASE_LOG直接子项、`O_EXCL|O_NOFOLLOW`/0600 held-fd及0-case/provider不变反证；prototype `:46-62`在child前执行，`:387-393`通过持有fd一次写/读。报告/evidence列出direct、parent/leaf alias、existing、symlink、hardlink七类rc1/0-case/provider-same。 |
| I1 run-matrix泄漏self-test-only反证 | ✅ 闭合 | `requirements.md:25,48`与`design.md:64,110,165`明确合法非37子集；prototype仅在`:251-254,358-386,394-397`的`mode == "self-test"`分支运行inventory probe和14项反证。本reviewer实跑1-row `real-eio`子集rc0、38B PASS且log仅该ID；final evidence另有逆序2-row及完整37-row。 |
| I2 self-test固定family顺序不符 | ✅ 闭合 | prototype `:15-20`已按swap/wrong-euid/eexist/五managed/EIO构造；`design.md:84`与验收`requirements.md:47`一致，`:395`逐字校验37 ID hash `721b...9bc8`。 |
| I3 inventory未按C-locale排序 | ✅ 语义闭合 | R6 `requirements.md:31`和`design.md:94`统一为relative-path filesystem bytes；prototype `:143-150`以`os.fsencode(relative-path)`排序，`:251-254`逆序创建`z-last/a-first`并断言canonical `a-first/z-last`。 |
| I4 full/depth-1缺private self-test证据 | ✅ 闭合 | `round7-evidence.log:45-56`分别记录full与真实file-URL depth-1的protocol 28B/self-test 38B/shell direct 41B/offline 394B；不再用03a2的41B摘要替代03a1门。 |
| M1 design声称文件capture、prototype用PIPE | ✅ 闭合 | `design.md:86`已改为独立capture且不限定媒介，与R2和prototype `:210-213`一致。 |

R3/R6及验收清单没有发现新的职责回流：03a1只解释合法rows，完整37-row外部生成仍归03a2；R3的物理路径capability、0-case/provider不变和合法子集均可机械验收；R6的bytes排序与逆序fixture闭合。九节、R1–R9映射、frontmatter consume/produce、CLI 0/1/2、exact1/400、default non-discovery、manifest与ledger-before-03a2顺序门仍完整。

## Important

### I1 — 400/400 prototype不兼容design声明的Python 3.8下限

- 位置：`design.md:9,199,205`；round7 driver `:47`。
- 证据：prototype调用`Path.stat(follow_symlinks=False)`；`pathlib.Path.stat`的`follow_symlinks`参数在Python 3.10才提供。本reviewer使用仓库环境现有Python 3.9实跑同一`self-test`，得到rc1、stdout 0，精确失败为`TypeError: stat() got an unexpected keyword argument 'follow_symlinks'`。round7 full/depth-1证据只证明当前Python 3.12，没有证明声明的`Python >=3.8`。
- 影响：design的支持边界与“400/400完整可执行原型已支付”不成立；implementation若原样落地会在受支持的3.8/3.9主机失败，且当前无LOC headroom。
- 可执行修复：将`:47`等行替换为Python 3.8已有的`parent.lstat()`（等行，不增加LOC），在Python 3.8或至少3.9重新跑protocol/self-test、1-row subset和完整37-row并记录版本/rc/精确双流；或者明确回流并提高Python下限，但需同步项目工具基线。

### I2 — prototype在写CASE_LOG之后才做最终provider oracle，且没有design声明的逐case provider hash

- 位置：`design.md:68,72,157-165`；`requirements.md:25,29,48-49`；round7 driver `:225,387-400`。
- 证据：design说每个case后及全部结束后都验provider SHA，并声称case log在全部oracle闭合后一次写入。prototype逐case只把label加入`executed`（`:225`），`:390`已经向held log fd写入完整成功日志，直到`:398`才比较production provider bytes；没有逐case provider hash检查。若最终provider oracle失败，进程虽rc1，但CASE_LOG已经呈现完整成功执行记录。
- 影响：实际语句顺序不满足design的“全部oracle后写log”，round7 400/400也没有支付“逐case + 最终”两层provider证明；tasks实现者无法同时按design和prototype执行。
- 可执行修复：至少把最终provider bytes check等行前移到case-log write之前；再二选一并统一文本：按R5的before/after口径删除design“每个case后”承诺，或用等行压缩在每case后真实检查并重新计数/实跑。增加provider-final-oracle破坏反证，要求rc1时CASE_LOG仍为0 bytes。

## Minor

### M1 — prototype额外拒绝relative/non-normalized workspace，requirements/design没有声明该CLI约束

- 位置：`requirements.md:25`；`design.md:66`；round7 driver `:46-50`。
- 证据：R3只要求parent物理存在且非symlink、leaf缺席；prototype还要求`workspace.is_absolute()`且`parent.resolve(strict=True) == parent`，因此物理安全但使用relative path或含`..`的workspace也会rc1。report的“全路径物理”不足以成为CLI grammar。
- 影响：不影响未来03a2当前使用的absolute temp path，但private CLI的可接受输入集合不唯一。
- 可执行修复：在R3/design明确要求absolute、normalized workspace与同样normalized的direct-child log，或删除额外限制并用dir-fd建立等价物理边界。

## Mechanical/runtime evidence

- `check-req.py`: rc0
- `check-criteria.py`: rc0
- `check-analyze.py`: rc0
- `check-plan.py`: rc0
- `git diff --check`: rc0（写本报告前）
- LOC：driver 400/400；entrypoint 109/400。
- 当前Python 3.12实跑：driver protocol/self-test、1-row run-matrix和shell entrypoint均rc0，成功摘要精确；1-row log仅含输入ID。
- Python 3.9反证：driver self-test rc1、stdout 0，在`Path.stat(follow_symlinks=False)`抛TypeError。

## 最终判定

**NEEDS_CHANGES**。上一轮六项finding主体已闭合，R3/R6回流本身内聚；但I1必须恢复声明的Python下限，I2必须使provider oracle与CASE_LOG提交顺序唯一化并重新支付400行证据，之后再做round3复审。
