# 2026-09-01-02-offline-quality-gate 验收报告

验收基线：`8145561504cfe1270fde2eef9271cf35d1d54d20`

验收 HEAD：`83eac79c013cd50216b8638005105fb98bcd2977`

## ① 判据执行结果

### 公开入口

```text
$ bash ./scripts/check.sh --offline
PASS  demo harness startup, process layer, and strict verification
PASS  Codex feature context selection and branch checks
RESULT PASS  shared Harness regression suite
RESULT PASS  device safety
RESULT PASS  offline quality gate child
RESULT PASS  aosp-harness offline quality gate
exit=0

$ bash ./tests/test-quality-gate.sh
RESULT PASS  offline quality gate contract
exit=0

$ bash ./tests/test-device-safety.sh
PASS  demo harness startup, process layer, and strict verification
PASS  Codex feature context selection and branch checks
RESULT PASS  shared Harness regression suite
RESULT PASS  device safety
exit=0
```

### 文件范围、预算与摘要

```text
$ git diff --name-only 81455615..83eac79c
.github/workflows/quality.yml
.gitleaks.toml
scripts/check.sh
scripts/shell-quality-baseline.tsv
tests/COVERAGE.md
tests/test-quality-gate.sh

$ wc -l <六个实现文件>
73   scripts/check.sh
30   scripts/shell-quality-baseline.tsv
2    .gitleaks.toml
26   .github/workflows/quality.yml
4    tests/COVERAGE.md
154  tests/test-quality-gate.sh
289  total

$ sha256sum scripts/shell-quality-baseline.tsv .gitleaks.toml
62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f  scripts/shell-quality-baseline.tsv
27630a96d6c55755cc37620f3933d5cab94b1eb78a726a32e11212972525d76e  .gitleaks.toml
```

六个单文件上限 `105/30/2/42/8/200` 全部满足，总计 `289 <= 387`；BASE..HEAD 恰好六个实现文件。`git diff --check`、worktree clean、完整 canary token tracked-tree 零匹配、三个 `CURRENT_FEATURE` 的 BASE..HEAD diff 均为 exit `0`。

### 规格机械收敛

```text
$ check-tasks.py && check-req.py && check-criteria.py && check-analyze.py && sync-ledger.py
exit=0

$ check-converge.py <spec-dir> 81455615 83eac79c --repo <worktree>
exit=0
```

## ② 逐条对照 requirements

- R1：通过。唯一 `--offline`、全受管 Shell syntax-first、C 序根测试、精确总 PASS 已由真实 gate 与 contract 共同验证。
- R2：通过。十项 core 依赖逐个缺失均返回 `2`，syntax/root marker 为零；缺 Bash case 使用绝对 host Bash 启动 gate。
- R3：通过。工作树自动发现、空格/LF 路径、双流转发、fail-fast、从无关 cwd 调用均有可失败 oracle。
- R4：通过。真实 offline poison 运行中可选静态工具、网络/ADB/CVD/build/client 调用均为零；三个 feature hash 不变。
- R5：通过。三工具各有 missing/wrong 六 case，并有全正确版本组合穿透 preflight 的正向 case。
- R6：通过。canonical baseline、exact pair、增量 ShellCheck/shfmt argv、config 摘要、poison env 清除、repo 外 canary、两次 Gitleaks、清理与 rc `2/1` 分类均由 contract 验证。
- R7：通过。workflow canonical oracle 锁定三 trigger、`ubuntu-24.04`、三份官方资产/摘要/安装映射/顺序与唯一 CI gate step。
- R8：通过。coverage 五列、非空、`active`、根测试集合相等，以及重复/未知/双向数字 coverage 宣称负例均通过。
- R9：通过。直接 contract exit `0` 且末行精确；全部 fixture/fake 检查离线运行，无下载或外部服务。

不变量：

- 外部网络/ADB/CVD/AOSP build/客户端真实调用数为 `0`：通过 poison contract。
- 三套旧回归与 device-safety 失败数为 `0`：根 gate 与直接 device-safety 均 exit `0`。
- 三个 `CURRENT_FEATURE` 内容 hash 变化数为 `0`：BASE..HEAD diff exit `0`，contract 前后 hash 也通过。

## ③ 执行期裁定（按判断错误代价降序）

1. baseline 裁定：采用锚点的 exact `path + Git blob` baseline，只豁免未变化历史内容。若判断错误，代价是历史静态债务延后清理；若不做，则 400 行预算内无法形成绿色 CI，并会越权修改后续 spec 文件。
2. 熔断 I2：gate 求得绝对 `repo_root` 后立即 `cd`，并从无关 cwd 做 caller poison 回归。若判断错误，代价是扫描/执行调用方目录，破坏 R1/R3 并带来非预期脚本执行。
3. 熔断 I3：workflow/coverage 使用表驱动结构 oracle，并为 docs oracle 保留 test 行预算。若判断错误，代价是 workflow/coverage 假绿，或触发 200 行硬门而需回 PLAN 拆片。
4. 熔断 I1：parser 固定 `mode`，静态 argv 用 NUL 字节数组逐索引比较。若判断错误，代价是 CI mode 未定义或 contract 永久假红，阻断 1.3/1.4。
5. 熔断 M1：canonicalize canary temp 并拒绝 repo 内 TMPDIR。若判断错误，代价是 canary 落入工作树并污染最终秘密扫描。
6. 提交规范裁定：用户明确本仓库为个人项目，使用 Conventional Commit，不采用 Transsion 五段式。若判断错误，代价是提交不能进入公司 Gerrit；本项目不向该系统推送。

## ④ 跳过的门禁

无 `SKIPPED` 项。门②、门③、门④按用户授权的 autopilot 自动通过，但 requirements/design/tasks 的独立 agent review 均实际执行；门④三轮到达熔断上限后的 findings 已逐条裁定并在实现/review 中闭合。

## ⑤ 挂账 findings

- Task 1.4 round 2 次要项：contract baseline validator 与生产 `awk` predicate 相似。验收裁定不追加修复：固定 canonical SHA-256 是独立的字节级 oracle，且 append/替换/重复/乱序/畸形 mutation 会真实失败，因此该相似性没有成为唯一证据。若判断错误，代价是两侧同错时可能放过 baseline 格式回归；后续 baseline 变更仍必须重新走 PLAN/DECISIONS。

其余执行期阻断/重要 findings 均已修复并经全新 reviewer 复审 PASS。

## ⑥ 结论

建议验收通过。R1-R9、三条不变量、六文件范围、单文件/总行预算、canonical 摘要、公开末行与收敛检查均在本轮重新执行并满足；没有未闭合的阻断或重要 finding。
