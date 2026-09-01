# 03a1 round6 sizing prototype report

## Verdict

**BLOCKED** — round6补齐所有承重oracle后，固定`shfmt 3.14.0`格式的19-case代表原型已是**400/400行**；把缺失18 rows改为共享循环而非复制case body后，实际可运行的37-case投影仍为**411/400行**，超出11行。两份原型都真实执行通过，因而这不是粗略估算。按本轮约束，不删除或弱化oracle来压线，必须先回PLAN做最小测试专用拆片。

## Artifacts and fixed point

- `round6-session-path-races.prototype.sh`：19个代表case，400行。
- `round6-full37-projection.prototype.sh`：实际补齐37个唯一case，411行。
- `round6-evidence.log`：动态/inert/损坏组合、工具与边界原始摘要。
- 03a实现固定点：`f91f54d3d9832c803097bf171e9628b8d1adedab`。
- 生产provider前后SHA-256均为`07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`；实现worktree状态字节数为0。

所有新增产物只在主仓`.spec/.../work/2026-09-01-03a1-session-path-race-assurance/`。没有修改或提交生产/测试实现。

## Round6新增的承重证明

### Existing swap精确subtree rekey

`swap_delta()`从before inventory抽取`target`及`target/**`完整子树，机械生成同suffix的`target.old`及`target.old/**`集合；旧descendants精确进入`paths_removed`，重键后的全部path精确进入`paths_added`，原`target`只作为replacement进入`allowed_changed_paths`。每个重键对象的完整signature必须逐字等于rename前对象；replacement另受type、不同inode、EUID、mode、readlink target或空文件hash谓词约束。不存在“允许added但不要求removed”的模糊模型。

实际九个swap仍覆盖root/project/session × safe-dir/link/file。original目录与`victim`的type/dev/ino/mode/uid/hash保持；link replacement的`readlink`必须精确为`<name>.old`；replacement inode不同且不创建后续层。

### Mkdir-success replacement runtime original

MANAGED的`before_open/made=true` hook在rename之前用`os.stat(..., follow_symlinks=False)`采集刚创建original的`type,dev,ino,mode,uid`，写入同一个私有hook记录。post oracle从`target.old`的实际完整signature生成逐字expected hook，并要求有序hook完全相等；同时delta predicate要求`target.old`为EUID/0700 directory、replacement为0755不安全目录。该证据来自运行时original，不是预先猜测inode。

### 全部主动self-disproof

正常run必须按精确顺序记录14个真实`AssertionError`拒绝，否则在成功摘要前失败：

1. protected完整signature；
2. unexpected inventory path；
3. 丢失真实`allowed_changed_paths`；
4. symlink `readlink` target；
5. regular-file SHA-256；
6. mode；
7. inode；
8. EEXIST第二个有序hook；
9. marker count；
10. hook sentinel缺失；
11. phase；
12. made；
13. catch；
14. case invocation缺失。

这保留round5已有的protected/unexpected/allowed-changed/EEXIST second-hook覆盖，并把requirements/design点名的marker/call/sentinel/phase/made/catch/readlink/hash/mode/inode逐类变为主动红结果。`assert_hooks`仍是整列表逐字比较，因此额外或乱序hook也失败。

## 执行结果

- 19-case代表原型：rc0、精确41-byte stdout、stderr 0、case total/unique=`19/19`。
- 37-case投影：rc0、精确41-byte stdout、stderr 0、case total/unique=`37/37`；九family计数为9/3/9/3/3/3/3/3/1。
- 完整依赖下`--dependency-absent`、真实provider缺席default/flag、结构完整但foundation缺席default/flag、结构完整但core不可用default/flag：全部rc0、精确摘要、0 case。
- marker missing/duplicate × foundation missing/core unavailable × default/flag八组合：全部在inert分支前fail closed，rc1、stdout 0、case 0、无成功摘要。
- only-anchor copy继续先做三个marker各一次检查，只替换目标marker-bearing line一次，并逐字比较fixture copy与`source.replace(original, replacement, 1)`的期望结果；provider hash前后不变。

固定工具均通过：`bash -n`；`shfmt v3.14.0 -d -i 2 -ci -bn`；`ShellCheck 0.11.0 -x -S warning`。

## Sizing结论

19-case代表原型在补齐完整replacement谓词和14项主动反证后已经**400行、余量0**。为避免逐行扩张的高估，另一个投影直接把EEXIST、managed families和wrong-EUID改为data-driven循环，并真实执行全部37 rows；格式化后仍是**411行、超限11行**。因此round5的351+31≈382估算不再成立：它没有支付精确subtree rekey、runtime-original以及全部主动反证的真实成本。

## 最小PLAN拆片建议

将当前03a1替换为两个连续、纯测试、私有依赖的spec；03b必须等待二者PASS：

1. **03a1a private race oracle driver**：唯一拥有`tests/lib/session-path-race-driver.py`，交付only-anchor copy、hook协议、完整signature/inventory/delta、subtree rekey、runtime-original和14项self-disproof；提供可直接执行的私有self-test入口。不得修改provider/foundation、不得发布runtime API/capability、不得被默认dispatcher发现。该片单独回滚只删除helper。
2. **03a1b exhaustive race entrypoint**：依赖03a1a，唯一拥有`tests/test-session-path-races.sh`，交付anchor-first shell dispatcher、dependency-absent/inert/八损坏组合、37-row矩阵与固定摘要，并调用已冻结的私有driver接口。先回滚03a1b即可撤掉默认测试入口，再可独立回滚03a1a。

PLAN需为两个spec分别写owner、BASE、`<=400` exact2 gate和回滚命令，并明确03a1a通过不代表03a1 capability完成、没有consumer/public capability；只有03a1b最终验收PASS后才解除03b gate。这个拆片只分离shell entrypoint与Python oracle driver，不拆family语义、不复制oracle，也不改变生产依赖边界。
