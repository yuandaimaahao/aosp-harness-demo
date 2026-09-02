# 03b requirements 独立审查 round 2

结论：**NEEDS_CHANGES，修复后由 controller 逐项裁定。** Blocking 4、Important 4、Minor 0。

## Blocking

1. R2 已先创建 held capture，R4 却要求 Python 在“任何 temp”前装 handler，字面不可实现。
2. 当时的 `1da4595` 基础测试未覆盖 managed disappearance、suffix mismatch、完整 same/different/concurrent-loser winner 指纹和默认 provider 缺席自动 inert，不能支撑 398/400 的完整性声明。
3. base 与 assurance 用 command substitution 比较 read 成功输出，会吞尾随 LF，无法证明唯一 `feature+LF`。
4. EEXIST no-temp 注入点位于 winner 的 stat/属性检查之后，只证明 open 前已清理，未证明整个 winner oracle 前已清理。

## Important

1. write/read worker 的信号承诺不一致；应明确 child latch 和 `129|130|143` 只属于 write。
2. “安全 ASCII feature”不是自足字节语法，且缺 `.bad\n`、`a b\n`、`a/b\n` fixture。
3. 03b1/03c 顺序门未机械排除 branch/ref、worktree、execution BASE 与 dispatch 记录。
4. rollback 的 tracked 删除与 checkout clean 同时要求但未定义提交/恢复时序。

## Controller 修复与裁定

- **B1/I1 已采纳：** R2 明确 unlinked capture 不属于同 session `.snapshot-*` publish owned-temp；R4 明确只有 write worker 在创建此类 owned-temp 前安装三信号 handler，read 只承诺普通 `0|1|2|3`。
- **B2 已采纳：** runnable base 增加 managed 三层 disappearance、suffix mismatch、默认 provider 物理缺席自动 inert；首次/同值/异值和第二波并发幂等/loser均比较包含 dev/inode/uid/mode/nlink/size/hash 的整树指纹。固定格式从 398 降至 core199+base195=394/400。
- **B3 已采纳：** base read 与 assurance short-read 均改用输出文件 hex 比较，逐字节包含唯一 `0a`，多一个空行会失败。
- **B4 已采纳：** assurance 的 no-temp 注入移到 EEXIST unlink 后、调用 `read_snapshot` 前，早于 winner 初次 name-stat；same/different仍核注入 winner 的完整指纹。
- **I2 已采纳：** R3 固定为 `^[A-Za-z0-9][A-Za-z0-9._-]{0,127}\n$` 字节语法，基础损坏表加入三种非法 ASCII。
- **I3 已采纳：** R9 固定 03b1/03c 规范 ID，并要求通过 spec path、`show-ref`、`worktree --porcelain`、ledger/dispatch/BASE 搜索四类检查顺序资产。
- **I4 已采纳：** rollback 改为从 accepted HEAD 建立隔离临时分支并提交 exact 两文件删除 commit，在 clean checkout 验收后丢弃。

修复候选为 prototype code commit `d5ce273ad14b38ffd9474fbf043254eeef1e758a`，证据 commit `aebfd896f3c39a2846bb4fc77b530107e180ccb9`。固定 shfmt 3.14.0、ShellCheck 0.11.0、bash-n、base/assurance 实跑、逐字输出、diff-check全绿；assurance 274/400、227项断言。默认 provider 物理缺席的 disposable repo 也得到唯一 PASS 字节与空 stderr。

所有 finding 均有直接契约或 runnable oracle 闭环，无忽略项；controller 裁定 requirements 门通过，可进入 design。
