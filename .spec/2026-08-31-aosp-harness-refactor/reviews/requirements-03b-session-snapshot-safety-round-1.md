# 03b requirements 独立审查 round 1

结论：**NEEDS_CHANGES，不可进入实现。** Blocking 4、Important 3、Minor 0。

## Blocking

### B1 — path capture 仍按 pathname reopen，存在第二次 TOCTOU

R2 只要求分离文件；prototype 由 path core 写入临时路径后，Python 再按名字打开。攻击者可换入另一条后缀和属性均合法的 path，使 snapshot 操作错误目录。必须改为 held fd：exclusive 创建、立即 unlink、path core 写入同 fd、解析器继承并 fstat/lseek/read，禁止 pathname reopen；增加重建同名文件仍读取原 fd 与 fd OS 错 fixture。

### B2 — 03b→03c 没有可组合的信号清理 seam

03b 把 temp、fd、随机名和 publish 点封装在 Python 内；PLAN 却要求不修改 03b 的 03c 负责 Python owned-temp cleanup 与 publish 前 signal。03c 既无法访问资源，也不能安全复制写算法。必须重划边界：推荐 03b worker 自身安装 child signal cleanup 并拥有 `TEMP_BEFORE_PUBLISH`，03c 只做 Bash facade/转发/process-group/first-signal-wins；同步 PLAN、协议、文件 owner 与回滚。

### B3 — 259 行 prototype 不足以证明完整 exact2/400

159+100 只覆盖 17 次调用，未覆盖 source/inert、CLI/双流、path rc、managed mutation、wrong-owner、六类内容、三类 stat-open、EIO/ENOSYS/EEXIST lifecycle、短读和 checkout。prototype 还把 managed link 错分为1、EEXIST winner 消失错分为3、只做一次 `os.read`。要求完整 formatted runnable candidate 覆盖 R1–R7 active family；若超过400，必须回 PLAN 拆 assurance 片。

### B4 — `RENAME_NOREPLACE` 关键失败分支不可确定性证伪

已有 winner 会被预读短路，并发结果也不能证明真实进入 rename EEXIST。必须增加 deterministic publish seam，覆盖 EEXIST 后 same/different/disappear/unsafe，并覆盖 libc symbol 缺失与 ENOSYS；逐项证明 rc/双流/winner/temp/no-fallback。

## Important

### I1 — wrong-owner 必须在 open 前归类安全错

真实 wrong-owner 0600 可能先因 EACCES 被误归 OS1。name stat 后应先校验 type/EUID/0600/nlink1，再进入 marker/open/fstat；需 snapshot expected-EUID exact-once provider-copy anchor 或等价无特权 fixture。

### I2 — managed suffix root 语义与错误分类不精确

当前 prototype 只比 project/session，未定义 root 如何验证，并把 ELOOP/ENOTDIR 映射为1。需明确 path core 输出中 physical parent/root 的信任边界，或重算 selector；root/project/session 各有 static/mutation 表，link/type/identity/owner/mode→2，真实 I/O/消失→1。

### I3 — 短读与“六类内容”未闭合

必须循环读取到 EOF 或累计130 bytes，130 bytes 即拒绝；用 provider-copy/mock 短读证明合法最大文件不误判。六类固定为：空文件、129-byte feature+LF、非ASCII、无LF、多LF、合法LF后额外字节。

## 已通过

- 03a2 dependency-present 37/37 与九类证据满足启动顺序。
- foundation validate、path core 签名及 0/1/2 依赖协议一致。
- 03b 不发布 marker/public API、03d 才聚合完整 capability 的边界一致。
- R9 上游回滚与 03c 资产缺席门一致。

最终裁定：先修 B1–B4，并以完整 runnable sizing 重证 exact2/400；round 1 不 PASS。
