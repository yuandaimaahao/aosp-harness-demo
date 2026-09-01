# 03a1 round7 split-prototype sizing report

## Verdict

**PASS** — round6的411/400单文件已真实拆成两个可运行、可独立计数的测试专用文件：私有Python driver为**400/400 LOC**，shell entrypoint为**109/400 LOC**。两文件各自不超过400，Python 3.8语法级兼容与可用Python 3.9运行、完整37-row、合法逆序子集、driver的14项active self-disproof、workspace/log capability反例、Shell matrix-order self-disproof、缺席/损坏状态、固定工具以及full/depth-1 staged protocol/self-test/direct/offline全部实跑通过。

## Runnable artifacts and boundary

- `round7-prototype/tests/lib/session-path-race-driver.py`
- `round7-prototype/tests/test-session-path-races.sh`
- `round7-evidence.log`

所有round7产物只在主仓`.spec/.../work/2026-09-01-03a1-session-path-race-assurance/`。03a实现固定在`f91f54d3d9832c803097bf171e9628b8d1adedab`；production provider SHA-256仍为`07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`，03a implementation worktree clean，foundation/provider/core tests的diff为空。

## Stable private CLI

```text
session-path-race-driver.py protocol
session-path-race-driver.py self-test FOUNDATION PROVIDER
session-path-race-driver.py run-matrix FOUNDATION PROVIDER ABSENT_WORKSPACE CASE_TSV CASE_LOG
```

Contracts：

- `protocol`：rc0、stderr空、stdout逐字`session-path-race-driver-v1\n`；不读取foundation、provider、entrypoint或matrix。
- `self-test`：只读取显式foundation/provider，自行创建临时workspace与内建37-row数据，不读取未来shell entrypoint；执行所有37 case和14项self-disproof，成功为rc0、stderr空、stdout逐字`RESULT PASS  session path race driver\n`。
- `run-matrix`：读取四列TSV：`id<TAB>family<TAB>layer<TAB>variant`；至少一行且ID唯一。当前契约以`pathlib.Path`解析argv后判定：workspace必须absolute，CASE_LOG必须因`case_log.parent == workspace`而同样absolute；Path已经词法消去的`.` alias与canonical拼写等价并允许，解析后仍含`..`的workspace会因`parent.resolve(strict=True) != parent`拒绝，仍含`..`的log会因parent不等于workspace拒绝，relative workspace/log均拒绝。workspace parent还必须预先存在、全路径物理且为directory，driver以`parent.lstat()`兼容Python 3.8/3.9检查末级对象。workspace leaf必须物理缺席，并由driver以`parents=False`创建后通过fd固定为0700/EUID。`CASE_LOG`必须是workspace直接子项且缺席，driver以`O_RDWR|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC`、0600创建，验证EUID/link-count并只通过该持有fd写/读。driver机械拒绝非法family/layer/variant或ID不匹配；合法非37子集也只执行输入rows，并在核对真实executed set后按TSV输入顺序写log。成功stdout逐字为38-byte private摘要`RESULT PASS  session path race driver\n`，Shell必须完整消费并逐字匹配。
- misuse/未知mode为rc2；协议、row、oracle或执行失败为rc1；任何失败都不打印private PASS摘要。

Shell在任何依赖分支前逐字验证`protocol`。driver存在但为directory、symlink、语法损坏、protocol非零或文本不匹配时fail closed。只有driver物理缺席才与provider/foundation/core缺席一样走inert；broken symlink不会被误当缺席。provider缺席优先inert，即使driver路径不安全也不读取它。

## Ownership and non-circularity

Private driver唯一拥有only-anchor provider copy/hook、完整signature/inventory/delta、swap subtree rekey、mkdir runtime-original signature、各family解释器及14项active self-disproof。它不导入、读取或执行entrypoint；`self-test`的37-row数据完全自足。

`self-test`的family顺序固定为swap(9)、wrong-euid(3)、eexist(9)、mkdir-replace(3)、mkdir-failure(3)、post-mkdir-disappear(3)、open-disappear(3)、final-stat-disappear(3)、real-eio(1)，有序37 ID+LF的固定SHA-256为`721b3687bda848db7b6481c527f491e6733cf376dbade3dd37b319fce8029bc8`，driver会在摘要前逐字比较。14项active self-disproof只在`self-test`分支运行；`run-matrix`不借用它们，1-row及逆序2-row合法子集都已独立成功。

Shell在参数验证后立即生成外部37-row TSV，在读取provider、driver或core并进入任何inert分支之前完成校验。九类具名计数为：swap=9、wrong-EUID=3、EEXIST=9、mkdir-replacement=3、mkdir-failure=3、post-mkdir disappearance=3、open disappearance=3、final-stat disappearance=3、EIO=1，总计37。调用前要求37行、37个唯一ID与上述九类精确计数；调用后把case-log逐字比较TSV第一列，再次要求37/37。这样矩阵所有权在shell，driver只验证/解释数据，而非通过case名称清单冒充执行。

Shell还在每次正常调用中启动一个隔离child fixture：显式损坏matrix为38行/重复EIO，同时让provider物理缺席，逐字要求child rc1、stdout 0且无成功摘要。该active self-disproof证明matrix gate真实执行且位于provider-absent inert之前；如果顺序回退，child会错误打印PASS并使parent失败。

## Preserved race/oracle proof

- Existing swap仍按subtree suffix把旧`target/**`精确记为removed，把`target.old/**`精确记为added，并把target replacement记为唯一changed path；重键对象完整signature逐字相同。
- Safe-dir/link/file replacement分别约束EUID/0700、精确`readlink <name>.old`、EUID/0600/空文件SHA-256，且inode不同。
- Mkdir-success replacement在MANAGED `before_open/made=true` hook中于rename前记录runtime original的type/dev/ino/mode/uid，post逐字要求`target.old`相同。
- Inventory先恢复每个relative path的filesystem bytes，再按bytes排序；self-test故意按`z-last`、`a-first`逆序创建并要求canonical结果为`a-first`、`z-last`。
- 14项active self-disproof保持精确顺序：protected signature、inventory、allowed delta、readlink target、file hash、mode、inode、EEXIST second hook、marker count、sentinel、phase、made、catch、case invocation。任一未真实拒绝都会在摘要前失败。

## Executed results

- Driver `self-test`：rc0、stdout 38、stderr 0；内部按上述family顺序实际执行37/37、固定有序ID hash比较与14项self-disproof均通过。
- Driver `run-matrix`完整矩阵：rc0、stdout 38、stderr 0、case-log 37/37，ID hash同为`721b...9bc8`。单个`swap-root-safe-dir`子集与输入顺序故意为`real-eio, swap-root-safe-dir`的2-row子集也均rc0/stdout38/stderr0，log只含输入ID且逐字保持该顺序，证明14项self-disproof没有泄漏进`run-matrix`。
- Workspace/log反例：`CASE_LOG`直指provider、workspace parent缺失、parent symlink alias、workspace leaf alias、既有regular log、symlink log、provider hardlink log各自均rc1、stdout 0、0 case、无PASS；每次provider SHA仍为`07af...4b64`，既有regular log内容也保持不变。成功子集实测workspace/log mode精确700/600。
- Raw-path五组合实测与当前契约一致：relative workspace为rc1/stdout0/无log；absolute raw `./` workspace+log为rc0/stdout38/stderr0并只记录所选1 case；absolute raw `../` workspace为rc1/stdout0/无log；canonical workspace加raw `../` log为rc1/stdout0/无log；absolute workspace加relative log为rc1/stdout0/无log。原型没有预先`normpath`并允许`..`。
- Final provider hash gate已经移动到持有fd写CASE_LOG之前。隔离provider/driver副本的确定性ordering self-disproof在一个case hook真实完成后、final hash前修改隔离provider；结果rc1、stdout 0、PASS缺席、case hook为1而CASE_LOG仍为0B，隔离provider保留变更且production provider SHA不变。此额外边界证明不计入`self-test`固定14项。
- Shell dynamic：rc0、外部stdout 41、stderr 0；TSV/case-log为37/37。按需求顺序的九类计数精确为swap=9、wrong-EUID=3、EEXIST=9、mkdir-replacement=3、mkdir-failure=3、post-mkdir disappearance=3、open disappearance=3、final-stat disappearance=3、EIO=1。
- Provider缺席且matrix完整时，default/flag均inert PASS；matrix损坏时，即使provider缺席，default/flag仍先以rc1、stdout 0、无摘要拒绝。Matrix完整后，provider absent才优先于坏driver进入inert。Provider存在且driver物理缺席时，default/flag也均inert PASS。
- Driver directory、symlink、protocol mismatch、syntax error、protocol execution failure：default/flag全部rc1、stdout 0、无成功摘要；run-matrix执行损坏的default同样fail closed。
- Foundation物理缺席或core unavailable的default/flag：在provider anchor与driver protocol完整时inert PASS。
- Marker missing/duplicate × foundation missing/core unavailable × default/flag八组合：全部在inert前rc1、stdout 0、无摘要。
- Driver无参数/额外protocol参数：rc2；非法TSV row：rc1、stdout 0、无private摘要。
- 固定工具：`shfmt v3.14.0 -d -i 2 -ci -bn`、`ShellCheck 0.11.0 -x -S warning`、`bash -n`全部rc0。Python 3.8 grammar的`ast.parse(feature_version=(3, 8))`、Python 3.9.25 `py_compile`、`protocol`、`self-test`和合法subset全部rc0；三次stdout/stderr分别为28/0、38/0、38/0 bytes。

Full staged checkout在99-commit完整历史上以Python 3.9.25显式运行driver `protocol`为rc0/stdout28/stderr0，`self-test`为rc0/stdout38/stderr0；shell direct与`bash ./scripts/check.sh --offline`也均rc0。真实file-URL `--depth 1` staged checkout精确HEAD为`f91f54d...`、commit count 1、`.git/shallow`为41 bytes；当前原型的Python 3.9 protocol/self-test再次得到相同结果。两种checkout的当前index都明确tracked `tests/lib/session-path-race-driver.py`与`tests/test-session-path-races.sh`；两种direct为41/0 bytes，两种offline为394/0 bytes且最后一行都是`RESULT PASS  aosp-harness offline quality gate`。

## Dependency and rollback contract

建议PLAN拆为：

1. **03a1 private driver**唯一拥有`tests/lib/session-path-race-driver.py`及上述稳定CLI；它不在默认test glob中、不发布runtime API/capability，可用`self-test`独立验收。
2. **03a2 shell entrypoint**依赖protocol v1，唯一拥有`tests/test-session-path-races.sh`和37-row TSV生成/计数/inert dispatcher；只有该片PASS才解除03b gate。

两片均可独立回滚，不规定固定先后顺序：只回滚03a1时，03a2会把driver物理缺席识别为inert，保持rc0、0 dynamic case和固定摘要；只回滚03a2时，剩余03a1 driver不被默认test glob发现，只能显式调用`self-test`。两片都回滚则完全撤销race assurance。任一片均不得修改03/foundation或03a provider/core test。
