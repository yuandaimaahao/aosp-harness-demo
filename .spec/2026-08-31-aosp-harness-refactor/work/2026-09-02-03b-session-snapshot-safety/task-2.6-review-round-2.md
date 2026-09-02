# 任务 2.6 Review Round 2: fix round 1 范围受限 re-review

审查对象: `acceptance/acceptance-report.md`（唯一被修文件）、`task-2.6-report.md`（fix round 1 说明）、`evidence/task-2.6-evidence.tsv`（重算）。本 reviewer 为全新上下文，与实现者、控制器、round 1 reviewer 无关；范围只限 round 1 finding 的闭合与新问题排查。核对为只读 + evidence TSV 哈希实测，未重跑任何前序验证命令。

## 结论

**PASS** — 阻断 0 / 重要 0 / 次要 0

round 1 的 1 条重要 + 2 条次要 finding 全部按要求闭合，归属经源报告逐字核实为真；修复未引入新的无出处声称，未改动区域与 round 1 已核内容一致；evidence TSV 十行 sha256/bytes 全部实测一致，green 报告 fix round 1 说明完整如实。

## 核对记录

### ① 重要 finding（fallback 核验次数失真）→ 已闭合

- 现 acceptance 报告第 14 行改为：字面 `rg -i fallback` 对两文件零匹配的出处只归 `task-1.2-report.md` 步骤 4，「无 fallback」结论另由 `task-1.1-report.md` 的 fallback 路径模式核对（`os.rename(`/`os.replace(`/`os.link(`/`shutil.` 无匹配、`renameat2` 单一调用点）支持。task-2.1 的无出处引用已删除。
- 归属真实性实测：task-1.2 报告第 113 行逐字为 `rg -n -i 'fallback' ... # 无匹配`、第 180 行复述「`rg -i fallback` 对两文件均无匹配」——出处成立；task-1.1 报告第 102–104 行逐字为 renameat2 单一调用点 + `os\.rename(\|os\.replace(\|os\.link(\|shutil\.` 无匹配——模式核对归属成立；task-2.1 报告全文（大小写不敏感）无 `fallback` 提及，删除正确。
- 同行保留的八 anchor 三处核验归属（task-1.1 grep -c 表 / task-1.2 步骤 4 rg -c / task-2.1 步骤 3）为 round 1 已实测成立的内容，本轮未动，抽查 task-1.2 第 111、177–179 行仍逐字支持。

### ② 次要 finding 1（R2/R3/R5 粒度超源报告字面）→ 已闭合

- R2 行（第 54 行）改为「active 测试矩阵编译在单次运行内部、3 次重复全 rc0（具体 case 粒度以测试 blob 为准，源报告未逐项列举）」；R3 行（第 55 行）同式处理并标注「具体损坏类别与 rc 粒度以测试 blob 为准」；R5 行（第 57 行）保留的「同/异值并发」「winner/victim/temp 前后比对」「`failures` 计数器归零收敛到最终 PASS」在 task-1.2 报告第 97、174–176 行均有逐字出处，超出字面的具体 rc 分布已删除并标注以 blob 为准。三行现均与源报告字面粒度一致。

### ③ 次要 finding 2（signal 段机制句与实证句混排）→ 已闭合

- 第 15 行已显式拆为「机制约定（design 契约，出处为 design『write signal cleanup』时序图与错误处理表）」与「本片基础测试实证（`task-1.2-report.md` 步骤 4/results，覆盖上述契约的真实 Python PID 与首信号锁存子集）」两部分；handler 先于 temp 安装、first_signal 锁存、ownership 转移、cleanup 不遮蔽 129/130/143 均归在 design 契约半句内，测试实证半句只声称 PID/TEMP barrier/首信号锁存与 3 次重复 rc0 逐字节相同——后者有 task-1.2 第 97–102 行出处（round 1 亦实测 repeat-{1,2,3}.stdout md5 一致）。design 契约与测试实证不再混排，03b1 边界声明保留。

### ④ 新问题排查 → 未发现

- 逐句重读 acceptance 报告全文：改动区域（第 14、15、54、55、57 行）之外的内容与 round 1 已逐字/实测核过的描述一致（固定标识、active 摘要、五个验证任务小节、manifest 现状、R1/R4/R6–R9 行、结论节），无被顺带改动的痕迹；R4 行「`renameat2`/`RENAME_NOREPLACE` 单一调用点、无 `os.rename/replace/link/shutil` fallback」归 task-1.1，与该报告第 102–104、175 行字面一致。
- 新增措辞（「支持同一『无 fallback』结论」「覆盖上述契约的 … 子集」等）均为保守表述，未把 design 意图或 blob 细节冒充为源报告字面证据，未引入新的无出处声称。

### ⑤ evidence TSV 与 fix round 1 说明

- `evidence/task-2.6-evidence.tsv` 十行三列（path/sha256/bytes），本 reviewer 逐行重算 sha256 与字节数，与当前文件全部一致。
- `task-2.6-report.md` 末尾「## fix round 1」节如实说明：只改 acceptance 报告一个文件、未创建 commit、未碰 manifest/ledger，三条修复内容与上述实测吻合，并声明 TSV 已重算（实测属实）。

## Findings

### 阻断（0）

无。

### 重要（0）

无。

### 次要（0）

无。

## 复核建议

无后续修复项；可交控制器执行任务 2.6 步骤 3–6（manifest 第 8 行追加、awk 全量核验、mark/ledger/sync、终门重跑）。
