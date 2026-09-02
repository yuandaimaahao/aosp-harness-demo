# ledger — spec: 2026-09-02-03b-session-snapshot-safety
# plan: .spec/2026-08-31-aosp-harness-refactor/PLAN.md v5.7
# worktree: 尚未创建；requirements/design/tasks 门通过前禁止固定 execution BASE

> 会话压缩之后，「我刚做完什么」的记忆不可靠。这份文件和 git log 才是。
> `任务 N: 完成` 是唯一的恢复锚点。

---

## 前置证据

- 03a2 accepted HEAD: `b9582e51ab5769bee90016e7e3aadb9d895ffd12`；main merge: `744acdc`。
- dependency-present path race matrix: 37/37，九类计数 `9/3/9/3/3/3/3/3/1`，全 PASS。
- state-model prototype branch: `prototype/2026-09-02-03b-snapshot-state-model`，commit `e8ecc7a1f84638b9ba43004ceb3745f6fae45999`。
- runnable sizing prototype 同分支 commit `61b090233ad403ea9882ef9a60f4633fce522e38`：固定 shfmt 后 core 159 行、test 100 行，总计 259/400；17 次受检调用及同/异值并发、唯一 winner、代表攻击全部 PASS。
- 原型结论使 R2 明确：path core 返回后必须逐层重新持有并验证三个 managed suffix；read 的 non-creating 边界只覆盖 snapshot leaf。

## requirements

- `check-req.py`、`check-criteria.py`、`check-analyze.py`、PLAN check 与 `git diff --check`：PASS。
- 独立审查 round 1：NEEDS_CHANGES，Blocking 4 / Important 3 / Minor 0。B1 held-fd path capture、B2 03b/03c signal seam、B3 完整 sizing、B4 publish deterministic seam；I1 pre-open owner、I2 managed suffix 边界、I3 short-read/六类内容均采纳。报告：`reviews/requirements-03b-session-snapshot-safety-round-1.md`。
- round 1 触发 PLAN 回流：03b worker 必须拥有 child signal cleanup 与 publish marker；完整 assurance 预计无法与生产模块共同塞入 exact2/400，先制作完整 runnable candidate，再决定新增 03b1 assurance 片的精确边界。
- PLAN v5.7 初版原型 `bb69bc9` 的稳定PID结论已被后续审查证伪，不再作为current sizing evidence；它只保留为发现nested-subshell问题的历史证据。
- PLAN v5.7 review round1途中发现原write core后台运行仍有外层Bash PID，并发现validate直接依赖及主表/owner表漏项。全部采纳：增加spawn-only worker export供03c直接background，普通core仅在隔离subshell调用；补`03 -> 03b`、validate+path双guard、03b1主表/owner/03c依赖。prototype follow-up `389b118e0fa3fcd1ce366333db92950f2e18359c`固定格式实跑219+174=393/400。
- 同轮继续证伪`389b118`的重复信号与工具门：child首信号后改为ignore三信号，基础测试真实越过TEMP barrier核PID并投递TERM+HUP，成功write也校验stdout空；中间prototype `7b3699d0580a2eea24a4f1ae9b6915100eb04b92`曾以199+200=399/400通过工具与运行，但后续PLAN round2证明其surface/strict worker仍不完整，故不再是current sizing evidence。
- PLAN review round1最终为NEEDS_CHANGES（Blocking 4 / Important 1 / Minor 1）；B1 child latch、B2 active PID/tool/stdout、B4 03c三export guard、I1 ledger current evidence和M1整体链均已回流。报告：`reviews/plan-v5.7-round-1.md`。
- PLAN review round2：NEEDS_CHANGES，Blocking 2 / Important 0 / Minor 0；指出03b缺四态source/完整surface/strict worker协议，03b1的held capture、short-read、EIO缺完整delta。报告：`reviews/plan-v5.7-round-2.md`。
- PLAN review round3：NEEDS_CHANGES，Blocking 2 / Important 2 / Minor 0；指出03b source rc、静态攻击整树delta与inventory/export属性不足，03b1 failure stdout、换入对象与EEXIST winner指纹不足，PLAN core协议引用悬空。报告：`reviews/plan-v5.7-round-3.md`。
- fix loop已达三轮上限，controller按可执行反例逐项采纳而非忽略：current prototype `1da459597c6d13bebd2d71fba6278bed39fcbd38`把03b内部helpers收进spawn-only worker调用进程，source只留三个export；四态probe逐字核source rc/双流/依赖体/完整function inventory/export属性，静态攻击核整树身份/属性/link/hash、victim及temp。03b1所有failure核stdout空，managed/snapshot换入对象核注入身份+精确shape，EEXIST same/different核注入dev/inode/uid/mode/nlink/size/hash，unsafe/missing核身份/shape；最终03b 199+199=398/400、03b1 271/400与227项断言，固定工具、bash-n、实跑、diff-check全PASS。强制source非零与unsafe前打印BAD两个provider副本均使base rc1/no-PASS，后者也使assurance rc1/no-PASS，证明新增oracle主动执行。PLAN同步写回自足write/read/worker流与rc协议。三轮全部承重finding因此有直接代码与实跑闭合，裁定门通过；证据：prototype commit `7a7b9393b5f425541305526eb48850bc2bc97c7a`中的两份sizing evidence。
- requirements round2：NEEDS_CHANGES（Blocking 4 / Important 4 / Minor 0），报告：`reviews/requirements-03b-session-snapshot-safety-round-2.md`。controller逐项采纳：区分capture与publish owned-temp、限定write信号协议、补managed disappearance/suffix/default inert/九类内容/第二波并发完整指纹、字节级read oracle，并把EEXIST no-temp反证前移到winner初次stat之前；R9固定顺序资产机械查缺与clean rollback commit。prototype code `d5ce273ad14b38ffd9474fbf043254eeef1e758a`固定格式core199+base195=394/400，assurance274/400且227项断言；证据commit `aebfd896f3c39a2846bb4fc77b530107e180ccb9`。固定工具、bash-n、base/assurance、provider物理缺席default inert、逐字双流及diff-check全PASS，全部finding闭环，controller裁定requirements门通过。
- requirements round3：独立review最终PASS（Blocking 0 / Important 0 / Minor 0），报告：`reviews/requirements-03b-session-snapshot-safety-round-3.md`。follow-up `7ffc213ee773abe88d25436998e71f9ff08f270a`再动态钉capture pathname absent与held fd 0600/nlink0并静态钉Python fd消费，reviewer追加审查PASS；最终core199+base198=397/400，assurance274/400/227项，证据commit `ba3cdb51c35572bf0c96bb99a7b5366c9af02ff2`。
- design round1：NEEDS_CHANGES（Blocking 1 / Important 3 / Minor 0），报告：`reviews/design-03b-session-snapshot-safety-round-1.md`。B1指出temp fd在close后清ownership会被信号打断并因finally二次close遮蔽信号码/跳过unlink；I1 post-rename线性化窗口、I2 handler ignore安装期重入、I3 read Mermaid缺Bash exec边界均采纳。R4/清单回流明确close前ownership transfer、latched signal错误优先级、first-signal状态机及rename pre/post commit语义；prototype code `d1296bacbdbe40b43b2adf2e7334ae473d79d6bd`与design同步增加post-close、early-second-signal和post-success provider-copy oracle，固定格式core202+base198=400/400、assurance293/400/236项，证据commit `c678895ff3bfb9d8bdb2ce13df1dbe52f2bb0f11`，固定工具、bash-n、base/assurance与diff-check全PASS。
- design round2：NEEDS_CHANGES（Blocking 1 / Important 0 / Minor 0），报告：`reviews/design-03b-session-snapshot-safety-round-2.md`。指出signal后cleanup-close错误仍可跳过unlink/后续managed close并遮蔽首信号；采纳为统一`close_all`错误collector、temp嵌套finally与顶层latched-signal优先。prototype runtime/base `a708ce6f0979c6644292b58b4a7b0d4afcdf821d`固定格式core208+base192=400/400；assurance `cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e`固定格式308/400、240项，signal+cleanup-close-error行核rc143、无winner/temp和owned+session+三ancestor共五次close；短路mutant只记录2次并使assurance rc1/no-PASS。固定工具、bash-n、base/assurance、逐字双流与diff-check全PASS；证据 `9f0dfbc5bca35df8fe9ea9ba249050a8aa4547fd`。
- design round3：PASS（Blocking 0 / Important 0 / Minor 0），报告：`reviews/design-03b-session-snapshot-safety-round-3.md`。独立复核确认round2 B1由全fd `close_all`、temp嵌套finally与latched-signal最终优先闭合；signal+cleanup-close-error确定性行核五次close、rc143、无winner/temp，修复前`df2c3f9`短路mutant在当前assurance下rc1、2/5次close、temp残留且无PASS。八节、R1–R9、逐字签名、图、错误表、exact2=400/400、assurance=308/400及阶段边界均通过。
