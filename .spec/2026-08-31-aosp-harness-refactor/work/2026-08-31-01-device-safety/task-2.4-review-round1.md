# 任务 2.4 独立验收 Review（Round 1）

结论：**PASS**

审查范围：`d9566179fadb9a3a5e4347806ec2f258a5885ba5..bcd0c9b0b675c384c346dcd0171a055b67a2712c` 的压缩 diff。仅静态审查 brief、实现报告、压缩前后脚本；按要求未重跑实现者已报告的验证。

## 规格符合性

逐项核对如下，压缩后均保留：

1. **10 个 invalid serial：覆盖完整。** `invalid_serials` 仍为缺失、`-bad`、`.bad`、`_bad`、`:bad`、`bad/path`、`bad value`、`$'bad\nvalue'`、`bad;value`、`bad+value` 共 10 项；LF 使用 Bash ANSI-C quoting，仍是实际换行而非反斜杠文本。每项仍断言 rc `2`、stderr 含 `ANDROID_SERIAL`、fake ADB 日志为空。
2. **2 个 valid serial：覆盖完整且断言未弱化。** `demo-serial`、`A0._:-z` 均要求 ADB 日志非空；`awk index($0,p)==1` 逐行验证精确行首 `adb -s <serial> `；同时仍断言 rc `0` 与末行精确 `RESULT PASS`。非空断言避免空日志令逐行检查恒真。
3. **4 个 flag priority / zero-ADB 组合：覆盖完整。** Claude、Codex 各跑 serial 缺失和非法 `-bad` 两项，共 4 项；每项合取断言 rc `2`、stderr 含 `--allow-skip requires --demo`、不含 `ANDROID_SERIAL`、ADB 日志为空，仍能证明 flag 校验优先。
4. **2 个 Demo SKIP：覆盖完整。** Claude、Codex 各一次 `DEMO_APP_INSTALLED=0 --demo --allow-skip`；仍分别断言 rc `0`、至少一行 `^SKIP  `、末行精确 `RESULT PASS (SKIP allowed)`、零 ADB 调用。
5. **fake ADB 错误路径：覆盖完整。** 未知 serial 仍须精确退出 `91`，未知命令仍须精确退出 `92`；两条拒绝调用也都必须出现在日志中。fake ADB 仍先校验分离参数 `-s` 与期望 serial，再按命令白名单响应，未知命令 fail-closed。
6. **skill 目标计数：覆盖完整。** fenced Bash extractor 语义未变；synthetic fixture 仍证明普通 build block 与行内反引号不会被计入，两个真实 skill 仍各要求设备块计数精确为 `1`。
7. **唯一 preflight：覆盖完整。** checker 仍要求 `device_serial="${ANDROID_SERIAL-}"` 和完整安全 regex 各精确出现一次，且都严格位于首个 ADB 之前；缺失、重复、同一行伪装和注释伪装均保留负向取证。
8. **standalone-adb / `device_serial` allowlist 历史负向：全部保留。** 表驱动数组逐一保留 `chained`、`devices`、`other-serial`、`duplicate-preflight`、`zero-arg`、`operator-adb`、`same-line-preflight`、`comment-preflight`、`reassignment`、`redirect-adb`、`append-serial` 11 项；命令与 mode 按索引一一对应。checker 仍扫描每个独立 `adb` 词并要求整行以 `adb -s "$device_serial" ` 开头，同时拒绝 allowlist 外的 `device_serial` 引用。
9. **4 个 mutation：覆盖完整。** 两个真实 skill 仍各生成 regex 弱化和首条裸 ADB 两种 mutation，共 4 个；仍要求替换计数精确为 `1`、文件确实改变，并由同一个生产 checker 分别以 `missing safe serial preflight` / `bare adb` 拒绝。mutation selftest 中“接受不安全 checker 必须使外层断言失败”的反恒真保护也保留。
10. **3 套 legacy：覆盖完整。** Claude、Codex、common 三个原入口仍全部执行，且都在私有 fake ADB `PATH` 前缀环境中运行；单项失败仍累加到总失败数。
11. **默认入口：语义保留。** 无参数默认仍按 `fixture → claude-invalid-serial → claude-valid-serial → flag-demo → skills → legacy` 顺序运行；任何 scope 非零或累计失败都会提前返回，因此失败时不会打印总成功行；仅全部成功时末行精确输出 `RESULT PASS  device safety`。独立的 `skill-blocks`、`skill-contract-selftest`、`mutation-selftest` scope 仍注册可运行，与压缩前一致。
12. **范围与预算：符合。** `d9566179..bcd0c9b0` 只修改 `tests/test-device-safety.sh`。基线 `2f3e46b..bcd0c9b` 六文件 numstat 为 `11+1+9+4+4+1+15+2+5+0+268+0 = 320`，满足 `320 ≤ 400`。

## 压缩前后行为语义

- 重复 capture 被收敛为 `device_safety_capture`，但缺失 serial 仍通过 `env -u ANDROID_SERIAL`，非缺失值仍仅作为子进程环境赋值；各 case 仍重建独立 fake ADB 目录和空日志。
- fixture、valid、flag、Demo 的多段断言被表驱动/单行合取表达式替代，但成功条件集合未减少；失败仍通过 `device_safety_fail` 写 stderr 并累计全局失败数。
- skill 常量、skill 路径和 synthetic case 被数组化，旧 case 与新表项数量、顺序和 payload 一致；checker 的首 ADB、唯一 preflight、ADB 前缀和变量 allowlist 判定未改变。
- mutation helper 的局部返回写法被压缩，但所有调用者仍以累计失败数作为最终判据；不存在 mutation 被接受后仍可令对应 scope 成功的路径。
- 默认 `all` 的 scope 集合、顺序、短路点和成功末行与压缩前一致。

## 质量审查

- **删覆盖 / 弱化断言：** 未发现。所有指定矩阵、历史负向、mutation 与 legacy 入口均有一一对应；关键复合断言的合取条件未减少。
- **恒真：** 未发现。valid 日志前缀检查前有非空门；mutation 拒绝同时要求 checker 非零和 checker 内 failure 计数大于零；accepted-checker selftest 保留。
- **全局状态污染：** 未发现导致误判的污染。`ADB_LOG`、`EXPECTED_SERIAL` 和 fake bin 每个 fixture 重置；capture 输出变量虽为共享状态，但每次调用均覆盖且只被紧邻断言消费。mutation checker 的失败计数在 subshell 内隔离。
- **短路：** 未发现安全覆盖被意外跳过。默认 `all` 只在已有失败后停止，与压缩前相同；`skills` 仅在真实 contract 通过后执行 mutation，亦与压缩前相同。各矩阵内部仍继续覆盖全部表项。
- **安全隔离：** 私有 fake ADB 仍在每次设备相关子进程的 `PATH` 首位；拒绝路径以空日志取证，成功路径由 fake ADB 的 serial/命令白名单约束，legacy 也继承私有 PATH。未见可落到开发机真实 ADB 的新增路径。
- **YAGNI / scope creep：** 未发现。变更仅为根测试的共享 helper、常量和表驱动压缩；没有新增生产行为、公共 runtime 或任务外抽象。
- **可维护性：** 大量单行复合语句降低可读性，但这是在 400 行硬预算内对原有逻辑的机械压缩，未改变判据，也没有形成独立的正确性或后续修改阻断问题，因此不列 finding。

## Findings

### 阻断

无（0）。

### 重要

无（0）。

### 次要

无（0）。

## ⚠️ 警告

无（0）。

最终判定：**PASS**。
