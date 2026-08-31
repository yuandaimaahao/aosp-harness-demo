---
id: 2026-09-01-02-offline-quality-gate
依赖: [2026-08-31-01-device-safety]
消费: "tests/test-device-safety.sh —— 无参数；全部通过时退出 0 且 stdout 末行为 RESULT PASS  device safety，任一断言失败时退出非零"
产出: "scripts/check.sh --offline|--ci —— 成功时退出 0 且 stdout 末行为 RESULT PASS  aosp-harness offline quality gate；参数/依赖/工具预检错误返回 2，语法/测试/静态/秘密检查失败返回 1，失败时不得输出该成功末行"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户通过 PLAN v4 中 02-offline-quality-gate 的目标、独立判据和本地/CI 工具策略，并明确要求后续按 autopilot 执行；新增默认口径已按该授权裁定并写入 DECISIONS
---

> 用户原话：
> “$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；用户已通过 PLAN v4，并要求后续按 autopilot 执行。

## 目标

建立一个稳定、可扩展且本地不依赖可选静态工具或外部环境的根级离线质量门禁；CI 用固定工具链执行增量 Shell 与 working-tree 秘密检查，后续规格只需新增根级测试即可进入同一验收入口。

## 术语

- “受管 Shell 入口”是仓库根目录下除 `.git/`、`.spec/` 外的普通文件，且路径以 `.sh` 结尾或首行精确为 `#!/usr/bin/env bash`、`#!/bin/bash`；不跟随符号链接。枚举与排序固定使用 `LC_ALL=C`。
- “历史 baseline”只指从锚点 `b143821925e279401334d09a788ba9a969df5c7c` 的 Git tree 按上条规则枚举出的全部 30 个受管 Shell 入口，并按 `path<TAB>git-blob\n`、`LC_ALL=C` 排序形成的 `scripts/shell-quality-baseline.tsv`；canonical 文件 SHA-256 必须为 `62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f`，同时固定在 gate 与 contract test。CI 运行时只校验该固定文件，无需读取锚点历史。baseline 变更必须形成新的 PLAN/DECISIONS 裁定，单独追加当前 blob 不构成授权。

## 需求

R1. [默认] 当 `scripts/check.sh` 收到唯一参数 `--offline` 时，系统必须先对全部受管 Shell 入口执行 bash 语法检查，再按 `LC_ALL=C` 路径字典序逐个执行普通文件 `tests/test-*.sh`，且仅在全部成功后以退出码 `0` 和末行精确 `RESULT PASS  aosp-harness offline quality gate` 结束；无参数、未知参数或额外参数必须返回 `2`。

R2. [默认] 如果发生 offline 必需的 bash、git、python3、rg、find、sort、awk、sed、grep、sha256sum 任一命令缺失，系统必须在任何语法或测试执行前向 stderr 指明缺失命令、返回 `2` 且不打印总成功行。

R3. [默认] 当后续规格使 `tests/test-*.sh` 集合发生变化时，系统必须从工作树自动发现当前集合，不得在 gate 中硬编码 provider 测试文件名；语法错误或任一测试失败时必须返回 `1`，分别原样转发失败测试的 stdout/stderr，停止后续测试且不打印总成功行。

R4. [计划] 在 `--offline` 运行期间，系统必须不探测、不调用也不因缺少 ShellCheck、shfmt、Gitleaks 而改变语义，并且不得访问网络、真实 ADB/CVD、AOSP build 或已安装的 Claude/Codex 客户端。

R5. [默认] 如果发生 `scripts/check.sh --ci` 所需的 ShellCheck `0.11.0`、shfmt `3.14.0`、Gitleaks `8.30.1` 任一命令缺失或版本不符，系统必须在运行语法/测试/静态检查前向 stderr 指明工具与期望版本、返回 `2` 且不打印总成功行。

R6. [默认] 当 `--ci` 工具预检通过时，系统必须先执行与 `--offline` 相同的语法与根测试，再对不匹配批准 baseline 的全部受管 Shell 入口执行 `shellcheck -x --severity=warning` 与 `shfmt -d -i 2 -ci -bn`；随后必须校验 `.gitleaks.toml` 字节精确为 `[extend]`、`useDefault = true` 两行且 SHA-256 为 `27630a96d6c55755cc37620f3933d5cab94b1eb78a726a32e11212972525d76e`，清除 GITLEAKS_CONFIG/GITLEAKS_CONFIG_TOML，用运行时拼接的临时 AWS access-key canary 证明同一 config/argv 的真实 Gitleaks 精确返回 `1`，再执行 `gitleaks dir --no-banner --redact --exit-code 1 --config <repo>/.gitleaks.toml <repo>`；baseline/config 摘要或格式不符、canary 未被检出必须返回 `2`，工具对真实工作树执行后的任意非零必须归一为检查失败 `1`。

R7. [默认] 当仓库 CI 被 push、pull request 或 workflow dispatch 触发时，系统必须使用 `ubuntu-24.04` x86_64 runner，从三个官方 release tag 下载固定 Linux x86_64/amd64 资产并校验已裁定 SHA-256，安装后只调用一次 `./scripts/check.sh --ci`；workflow 中的版本、资产、摘要必须与 gate 契约一致。

R8. [默认] 系统必须提供 `tests/COVERAGE.md` 需求到测试矩阵，表头固定包含 Test、Specs/requirements、Protected behavior、Offline boundary、Status；每个已存在根级 `tests/test-*.sh` 必须精确出现一次且各字段非空，Status 只能为 active，不得把文件数、函数数或调用数表述为行/分支覆盖率。

R9. [默认] 系统必须提供离线 gate contract 回归，使用临时 fixture 与 fake 工具分别证明无参数、未知参数、额外参数三类 CLI 错误，必需依赖/CI 工具预检早于语法和根测试，受管集合与 Bash 语法失败，C-locale 字典序发现，stdout/stderr 转发和短路，offline 可选工具隔离，批准 baseline 命中，baseline 扩增/摘要变化拒绝，新增或变化 Shell 必检，固定 Gitleaks 两次调用的 argv/env/canary/失败传播，三类 CI trigger/runner/资产摘要以及 COVERAGE 字段；回归不得下载工具或访问外部服务。

## 验收标准

主验证命令: bash ./scripts/check.sh --offline
期望输出: 退出码为 `0`，stdout 末行精确为 `RESULT PASS  aosp-harness offline quality gate`

验收清单:

- [ ] fixture 中的 gate 自身、一个无扩展名 Bash 入口、一个新根测试和一个语法错误 `.sh` 均被受管集合发现；语法错误时 gate 返回 `1`、根测试不执行且无总成功行。
- [ ] fixture 以非字典序创建三个根测试；成功时按 `LC_ALL=C` 路径序各执行一次，中间失败时其 stdout/stderr 唯一 marker 各原样出现一次、后续 marker 不出现、gate 返回 `1` 且无总成功行。
- [ ] 无参数、未知参数、额外参数三类调用均返回 `2`、stderr 含 usage、syntax/root-test marker 为 `0` 且无总成功行；对十个 offline 必需命令逐个构造缺失 case，也均在 syntax/root-test marker 为 `0` 时返回 `2`；私有 poison `PATH` 与 `GIT_ALLOW_PROTOCOL=file` 下运行真实 `--offline` 时，ShellCheck/shfmt/Gitleaks 及 `adb`、`cvd`、`curl`、`wget`、`ssh`、`repo`、`ninja`、Claude/Codex poison 日志调用数均为 `0`。
- [ ] 对 ShellCheck、shfmt、Gitleaks 分别构造缺失和错版本 fake，`--ci` 均在 syntax/root-test marker 为 `0` 时返回 `2` 并报告期望版本；三者版本正确时，fake 断言 ShellCheck/shfmt 参数和 Gitleaks canary/工作树两次调用的精确参数、扫描根、显式 config 及两个配置环境变量已清除。
- [ ] canonical baseline 精确为 30 行和固定摘要，原始 `path + blob` 可豁免历史文件；单独追加新增/变化文件当前 pair、修改摘要、重复/乱序/畸形/非锚点条目均返回 `2`；baseline 不变时新增或变化 Shell 入口必须调用两个静态工具；config 精确内容/摘要与临时 canary 自检均通过，空规则、全局 allowlist 或 canary 返回 `0` 必须返回 `2`，任一静态工具或工作树 Gitleaks 非零使 gate 返回 `1`。
- [ ] CI workflow 精确包含 `push`、`pull_request`、`workflow_dispatch`，runner 为 `ubuntu-24.04`，三个官方 tag/资产/SHA-256 与 requirements 的 autopilot 裁定一致，且最终质量步骤只出现一次 `./scripts/check.sh --ci`。
- [ ] `tests/COVERAGE.md` 使用 R8 的五列表头；`tests/test-device-safety.sh` 与 `tests/test-quality-gate.sh` 各精确出现一次且五列非空，自动发现的每个根测试路径都有唯一 `active` 行，文档不含数字覆盖率宣称。

不变量（不许劣化，2-4 项）:

- 离线验收的真实网络/ADB/CVD/AOSP build/客户端调用数 ≤ `0`，验证: `tests/test-quality-gate.sh` 的 poison 日志、`GIT_ALLOW_PROTOCOL=file` 与真实 `bash ./scripts/check.sh --offline`。
- 当前三套旧回归和 device-safety 回归失败数 ≤ `0`，验证: `bash ./scripts/check.sh --offline` 的自动发现与 `tests/test-device-safety.sh` 内 legacy 聚合。
- 三个 `CURRENT_FEATURE` 的前后内容 hash 变化数 ≤ `0`，验证: `tests/test-quality-gate.sh` 在 gate 前后保存并逐字比较 `git hash-object claude-code/CURRENT_FEATURE codex/CURRENT_FEATURE common/CURRENT_FEATURE` 输出。

## 超出范围

- 不在本 spec 清零全部历史 ShellCheck/shfmt 债务；批准 baseline 只豁免锚点提交中内容未变化的条目，新内容必须通过固定参数的静态检查。
- 不引入数字行/分支覆盖率阈值，不把当前测试体量外推成覆盖率结论；文档与 readiness 的最终完整性由 `10` 处理。
- 不执行真实 ADB、CVD、AOSP build、Claude/Codex 客户端或外部服务；CI workflow 的下载步骤只在 CI 安装阶段运行，gate contract 回归保持无网络。
- 不修改后续 session、lease、verifier、runtime、registry 或 adapter 行为；它们只通过新增根级测试被自动纳入 gate。
- 实现仍受 PLAN 的 8 个非生成文件、400 行新增+删除 review-package 硬门约束；本 requirements 不用未绑定占位符重复定义该流程门。
- 不发布或推送。

## 实现可行性预算

本片只允许 6 个非生成实现文件，新增+删除预算如下；tasks 若无法在这些上限内给出可审查的表驱动 fixture，必须在执行前回 PLAN 拆片。

| 文件 | 最大新增+删除行 |
|---|---:|
| `scripts/check.sh` | 105 |
| `scripts/shell-quality-baseline.tsv` | 30 |
| `.gitleaks.toml` | 2 |
| `.github/workflows/quality.yml` | 42 |
| `tests/COVERAGE.md` | 8 |
| `tests/test-quality-gate.sh` | 200 |
| 合计 | 387 |

## autopilot 裁定

- 必答问题 `0` 个，带推荐问题 `0` 个；本地/CI 分流、自动发现、版本固定和 gate test 均来自已确认 PLAN，具体默认已按用户的 autopilot 授权裁定。
- Offline 必需依赖按当前被消费回归的真实调用面固定为 Bash、Git、Python 3、ripgrep 和列出的基础命令；缺失属于可诊断的协议/环境错误 `2`，不伪装成测试失败。
- 工具固定为 ShellCheck `0.11.0`（`shellcheck-v0.11.0.linux.x86_64.tar.xz`，`https://github.com/koalaman/shellcheck/releases/download/v0.11.0/`）、shfmt `3.14.0`（`shfmt_v3.14.0_linux_amd64`，`https://github.com/mvdan/sh/releases/download/v3.14.0/`）、Gitleaks `8.30.1`（`gitleaks_8.30.1_linux_x64.tar.gz`，`https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/`）。对应 SHA-256 依次为 `8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198`、`fe42021c7272ef2d67ea36cbc3031683c625d0badec733ef3a57b567246a0b66`、`551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb`。
- 当前历史 Shell 不满足固定 ShellCheck/shfmt 参数，无法在本片预算内清零；采用锚定提交、固定摘要的 immutable baseline 做增量收紧。若判断错误，代价是历史未改脚本暂时保留静态债务；若不设 baseline，8 文件/400 行内无法得到绿色 CI，且会越权修改后续 spec 的文件。
