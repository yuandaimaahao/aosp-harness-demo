# 2026-09-01-02-offline-quality-gate 实现计划

## Gate contract 与分层实现

### 任务 1.1: 锁定 CLI 与 offline 依赖预检

文件: 创建 `tests/test-quality-gate.sh`、创建 `scripts/check.sh`
消费: 无
产出: scripts/check.sh --offline —— 仅接受唯一 mode 参数；CLI 或十个 core 命令预检失败时在 syntax/root-test 前退出 2，空 fixture 成功时末行精确为总 PASS
需求: R1, R2, R9
必需: 是

- [ ] 步骤 1: 创建可清理的临时 Git fixture、断言 rc/末行/marker 的 helper 与 `QUALITY_GATE_NESTED=1` 防递归分支；污染 PATH 前保存并验证 `host_bash="$(command -v bash)"` 为绝对可执行路径，再用它启动每个 gate。表驱动覆盖无参数、`--unknown`、`--offline extra` 以及逐个隐藏 `bash git python3 rg find sort awk sed grep sha256sum`；缺 bash case 也必须由 `"$host_bash" fixture/scripts/check.sh --offline` 启动且传入的 PATH 中没有 bash。每个失败 case 都放入非法 `.sh` 和会写 marker 的根测试，并断言 rc `2`、stderr 含 usage 或 gate 自己输出的 `missing required command: <name>`、两个 marker 均为 `0`、无总 PASS。

  ```bash
  host_bash="$(command -v bash)"
  [[ "$host_bash" == /* && -x "$host_bash" ]]
  if [[ "${QUALITY_GATE_NESTED-}" == 1 ]]; then
    printf 'RESULT PASS  offline quality gate child\n'
    exit 0
  fi
  offline_required=(bash git python3 rg find sort awk sed grep sha256sum)
  set +e
  PATH="$case_bin" "$host_bash" "$fixture/scripts/check.sh" --offline \
    >"$stdout_file" 2>"$stderr_file"
  rc=$?
  set -e
  [[ "$rc" -eq 2 && ! -s "$syntax_marker" && ! -s "$test_marker" ]]
  grep -Fq "missing required command: $missing" "$stderr_file"
  ```
- [ ] 步骤 2: 跑 `bash ./tests/test-quality-gate.sh`，确认红阶段非零且首个失败标签为 `FAIL  cli no-argument: expected rc=2`，因为 gate 尚不存在。
- [ ] 步骤 3: 在 `scripts/check.sh` 实现唯一参数 parser、十命令 `command -v` 预检、从脚本位置求绝对 repo root 与统一 `quality_protocol_error`；此片只让无受管错误/根测试的 fixture 输出精确总 PASS，所有错误只写 stderr。

  ```bash
  quality_protocol_error() { printf 'error: %s\n' "$*" >&2; exit 2; }
  [[ "$#" -eq 1 && ( "$1" == --offline || "$1" == --ci ) ]] ||
    quality_protocol_error 'usage: scripts/check.sh --offline|--ci'
  mode="$1"
  for command_name in bash git python3 rg find sort awk sed grep sha256sum; do
    command -v "$command_name" >/dev/null 2>&1 ||
      quality_protocol_error "missing required command: $command_name"
  done
  repo_root="$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)"
  cd -- "$repo_root"
  ```
- [ ] 步骤 4: 跑 `bash ./tests/test-quality-gate.sh`，确认 13 个 preflight case 全部通过，exit `0` 且末行精确为 `RESULT PASS  offline quality gate contract`。
- [ ] 步骤 5: 跑 `chmod +x ./scripts/check.sh ./tests/test-quality-gate.sh && bash -n ./scripts/check.sh && bash -n ./tests/test-quality-gate.sh && for file in ./scripts/check.sh ./tests/test-quality-gate.sh; do test -z "$(git diff --no-index --check /dev/null "$file" 2>&1 || :)" || exit 1; done`，确认两个未跟踪入口可执行、语法和全文件空白检查均通过；本任务对 test/gate 的累计改动分别不超过 45/25 行。

### 任务 1.2: 自动发现并执行 offline 核心

文件: 修改 `tests/test-quality-gate.sh`、修改 `scripts/check.sh`
消费: scripts/check.sh --offline —— 仅接受唯一 mode 参数；CLI 或十个 core 命令预检失败时在 syntax/root-test 前退出 2，空 fixture 成功时末行精确为总 PASS
产出: scripts/check.sh --offline —— 预检后以 LC_ALL=C、NUL 边界发现全部受管 Shell，先 bash -n 再按序 fail-fast 执行 tests/test-*.sh，成功末行精确为总 PASS
需求: R1, R3, R4, R9
必需: 是

- [ ] 步骤 1: 扩展同一 fixture：加入 gate 自身、无扩展名 Bash、空格路径、实际 LF 路径、非法 `.sh`、`.git/.spec` 下脚本和指向仓库外非法脚本的 symlink；PATH 中 fake `bash` 对每个 `-n` 目标以 NUL 记录后委托保存的绝对 `host_bash`，fake `sort` 断言 `LC_ALL=C`。精确断言 gate/无扩展名/空格/LF/非法 `.sh` 各被 `-n` 一次，symlink 与 `.git/.spec` 路径零次，且全部 `-n` 记录先于首个 root marker；fixture 的 `tests/test-quality-gate.sh` 仅在 `QUALITY_GATE_NESTED=1` 时写唯一 child marker，否则写 body marker，断言普通 gate 调用只写一次 child、body 为零。另以非字典序创建三个根测试，断言语法失败时测试零调用、成功时 C 序各一次、中间失败的 stdout/stderr marker 各原样一次且后续 marker 为零。

  ```bash
  if [[ "${1-}" == -n ]]; then
    printf '%s\0' "$2" >>"$SYNTAX_LOG"
  fi
  exec "$HOST_BASH" "$@"
  # fixture/tests/test-quality-gate.sh
  [[ "${QUALITY_GATE_NESTED-}" == 1 ]] || { printf 'body\n' >>"$BODY_LOG"; exit 97; }
  printf 'RESULT PASS  offline quality gate child\n'
  fixture="$(cd -- "$fixture" && pwd -P)"; unrelated="$(mktemp -d)"
  mkdir -p "$unrelated/tests"
  printf '#!/bin/bash\nprintf poison >>%q\n' "$outside_marker" >"$unrelated/tests/test-poison.sh"
  (cd -- "$unrelated" && "$host_bash" "$fixture/scripts/check.sh" --offline)
  [[ ! -s "$outside_marker" ]]
  ```

- [ ] 步骤 2: 加入真实仓库边界 case：保存三个 `CURRENT_FEATURE` 的 `git hash-object`，以私有 poison PATH 与 `GIT_ALLOW_PROTOCOL=file` 普通调用真实 `--offline`（调用方不得预设 `QUALITY_GATE_NESTED`），用 Python `subprocess.run(..., timeout=30)` 限制递归风险；断言输出仅含一次 child marker，ShellCheck/shfmt/Gitleaks、adb/cvd/curl/wget/ssh/repo/ninja、Claude/Codex 日志总调用数为 `0` 且三个 hash 不变。跑 `bash ./tests/test-quality-gate.sh` 确认红阶段首错含 `managed shell syntax was not checked`。

  ```bash
  "$host_python" - "$repo_root" "$host_bash" <<'PY'
  import os, subprocess, sys
  result = subprocess.run([sys.argv[2], "./scripts/check.sh", "--offline"], cwd=sys.argv[1],
                          env=os.environ.copy(), text=True, capture_output=True, timeout=30)
  assert result.returncode == 0, (result.stdout, result.stderr)
  assert result.stdout.count("RESULT PASS  offline quality gate child") == 1
  PY
  ```
- [ ] 步骤 3: 在 gate 用 `find -print0`、首行精确 Bash shebang 检测、数组和 `LC_ALL=C sort -z` 实现 `quality_list_shell_files`；排除 `.git/.spec`、只接受普通文件且不跟随 symlink，再让 `quality_run_core` 先逐文件 `bash -n`、后逐个直接继承双流运行 C 序根测试，任一非零归一为 rc `1` 并短路。

  ```bash
  quality_list_shell_files() {
    find . -path './.git' -prune -o -path './.spec' -prune -o -type f -print0 |
      while IFS= read -r -d '' path; do
        [[ "$path" == *.sh || "$(sed -n '1p' "$path")" == '#!/usr/bin/env bash' ||
          "$(sed -n '1p' "$path")" == '#!/bin/bash' ]] && printf '%s\0' "${path#./}"
      done | LC_ALL=C sort -z
  }
  for test_path in "${root_tests[@]}"; do
    QUALITY_GATE_NESTED=1 bash "$test_path" || return 1
  done
  ```
- [ ] 步骤 4: 跑 `bash ./tests/test-quality-gate.sh`，确认 managed-set、syntax、排序、双流、短路、poison 与 hash case 全部通过，exit `0` 且末行为 contract PASS。
- [ ] 步骤 5: 跑 `bash ./scripts/check.sh --offline`，确认 exit `0` 且 stdout 末行为 `RESULT PASS  aosp-harness offline quality gate`；再跑 `git diff --check`，本任务新增 test/gate 改动分别不超过 45/30 行、累计不超过 90/55 行。

### 任务 1.3: 固定 CI 工具预检

文件: 修改 `tests/test-quality-gate.sh`、修改 `scripts/check.sh`
消费: scripts/check.sh --offline —— 预检后以 LC_ALL=C、NUL 边界发现全部受管 Shell，先 bash -n 再按序 fail-fast 执行 tests/test-*.sh，成功末行精确为总 PASS
产出: scripts/check.sh --ci —— 在 core 之前要求 ShellCheck 0.11.0、shfmt 3.14.0、Gitleaks 8.30.1，缺失或错版本返回 2 且 syntax/root-test 零调用
需求: R5, R9
必需: 是

- [ ] 步骤 1: 为三个 fake 工具各写正确版本响应，再表驱动构造“缺失”和“错版本”六个 case；每个 fixture 同时放非法 Shell 与 root marker，断言 rc `2`、stderr 同时含工具名和期望版本、syntax/root-test marker 均为 `0`、无总 PASS。

  ```bash
  tool_cases=(
    'shellcheck|0.11.0' 'shfmt|3.14.0' 'gitleaks|8.30.1'
  )
  case "${0##*/}:$1" in
    shellcheck:--version) printf 'version: %s\n' "$FAKE_VERSION" ;;
    shfmt:--version) printf 'v%s\n' "$FAKE_VERSION" ;;
    gitleaks:version) printf '%s\n' "$FAKE_VERSION" ;;
    *) exit 90 ;;
  esac
  ```
- [ ] 步骤 2: 跑 `bash ./tests/test-quality-gate.sh`，确认红阶段非零且首错为 `FAIL  ci shellcheck missing: expected rc=2 before core`。
- [ ] 步骤 3: 在 gate 的 mode 分支中仅为 `--ci` 增加三工具存在性与版本字符串预检，顺序固定在 `quality_run_core` 之前；`--offline` 路径不得执行三个命令的 `--version`。

  ```bash
  if [[ "$mode" == --ci ]]; then
    for tool_spec in shellcheck:0.11.0 shfmt:3.14.0 gitleaks:8.30.1; do
      tool="${tool_spec%%:*}"; expected="${tool_spec#*:}"
      command -v "$tool" >/dev/null 2>&1 || quality_protocol_error "missing $tool $expected"
    done
    [[ "$(shellcheck --version | awk '/^version:/ {print $2}')" == 0.11.0 ]] ||
      quality_protocol_error 'expected shellcheck 0.11.0'
    [[ "$(shfmt --version)" == v3.14.0 ]] || quality_protocol_error 'expected shfmt 3.14.0'
    [[ "$(gitleaks version)" == 8.30.1 ]] || quality_protocol_error 'expected gitleaks 8.30.1'
  fi
  ```
- [ ] 步骤 4: 跑 `bash ./tests/test-quality-gate.sh`，确认六个 CI preflight case 与全部 offline case 通过，exit `0` 且末行为 contract PASS。
- [ ] 步骤 5: 跑 `bash -n ./scripts/check.sh && bash -n ./tests/test-quality-gate.sh && git diff --check`；本任务新增 test/gate 改动分别不超过 20/15 行、累计不超过 110/70 行。

### 任务 1.4: 落地 canonical baseline 与增量静态检查

文件: 修改 `tests/test-quality-gate.sh`、修改 `scripts/check.sh`、创建 `scripts/shell-quality-baseline.tsv`
消费: scripts/check.sh --ci —— 在 core 之前要求 ShellCheck 0.11.0、shfmt 3.14.0、Gitleaks 8.30.1，缺失或错版本返回 2 且 syntax/root-test 零调用
产出: scripts/shell-quality-baseline.tsv —— 30 行 C 序 path<TAB>git-blob canonical 文件且 SHA-256 为 62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f、scripts/check.sh --ci —— exact pair 命中才豁免，否则运行固定 ShellCheck/shfmt argv
需求: R6, R9
必需: 是

- [ ] 步骤 1: 从锚点 `b143821925e279401334d09a788ba9a969df5c7c` 的 Git tree 按受管规则生成 30 行 canonical TSV；断言行数、严格 C 序、path/blob 唯一、40 位小写 blob 和文件 SHA-256 精确匹配 requirements，禁止从当前工作树自授权扩增。

  ```bash
  anchor=b143821925e279401334d09a788ba9a969df5c7c
  git ls-tree -r -z "$anchor" |
    while IFS= read -r -d '' entry; do
      meta="${entry%%$'\t'*}"; path="${entry#*$'\t'}"; mode="${meta%% *}"
      [[ "$mode" == 100644 || "$mode" == 100755 ]] || continue
      [[ "$path" != .spec/* && "$path" != .git/* ]] || continue
      first="$(git show "$anchor:$path" 2>/dev/null | sed -n '1p')"
      [[ "$path" == *.sh || "$first" == '#!/usr/bin/env bash' || "$first" == '#!/bin/bash' ]] || continue
      printf '%s\t%s\n' "$path" "$(git rev-parse "$anchor:$path")"
    done | LC_ALL=C sort >scripts/shell-quality-baseline.tsv
  ```
- [ ] 步骤 2: 扩展 contract：原始 baseline pair 命中时两静态工具零调用；新增/变化 Shell 必须分别收到 `shellcheck -x --severity=warning` 与 `shfmt -d -i 2 -ci -bn`；单独追加当前 pair、改摘要、重复、乱序、畸形与非锚点条目均返回 `2` 且秘密工具零调用，任一静态 fake 非零使 gate 返回 `1`。

  ```bash
  python3 - "$shellcheck_log" -x --severity=warning "$candidate" <<'PY'
  from pathlib import Path
  import sys
  got = Path(sys.argv[1]).read_bytes().split(b'\0')
  assert got[-1] == b'' and got[:-1] == [arg.encode() for arg in sys.argv[2:]], got
  PY
  python3 - "$shfmt_log" -d -i 2 -ci -bn "$candidate" <<'PY'
  from pathlib import Path
  import sys
  got = Path(sys.argv[1]).read_bytes().split(b'\0')
  assert got[-1] == b'' and got[:-1] == [arg.encode() for arg in sys.argv[2:]], got
  PY
  baseline_mutations=(append-current wrong-digest duplicate unsorted malformed non-anchor)
  ```
- [ ] 步骤 3: 跑 `bash ./tests/test-quality-gate.sh`，确认红阶段非零且首错为 `FAIL  baseline canonical digest mismatch`。
- [ ] 步骤 4: 在 gate 内固定 baseline 摘要，先校验摘要和 30 行 canonical 格式/顺序/唯一性，再用 `git hash-object` 判断 exact pair；以 NUL 数组把其余受管文件逐个传给两个固定 argv，baseline 协议错误返回 `2`、静态 finding 返回 `1`。

  ```bash
  baseline_sha=62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f
  [[ "$(sha256sum "$baseline_file" | awk '{print $1}')" == "$baseline_sha" ]] ||
    quality_protocol_error 'baseline canonical digest mismatch'
  declare -A approved=()
  while IFS=$'\t' read -r path blob; do approved["$path"]="$blob"; done <"$baseline_file"
  for path in "${shell_files[@]}"; do
    [[ "${approved[$path]-}" == "$(git hash-object "$path")" ]] && continue
    shellcheck -x --severity=warning "$path" || return 1
    shfmt -d -i 2 -ci -bn "$path" || return 1
  done
  ```
- [ ] 步骤 5: 跑 `bash ./tests/test-quality-gate.sh`，确认 baseline mutation、candidate 和 static failure 全通过；再跑 `test "$(wc -l < scripts/shell-quality-baseline.tsv)" -eq 30 && test "$(sha256sum scripts/shell-quality-baseline.tsv | awk '{print $1}')" = 62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f && test -z "$(git diff --no-index --check /dev/null scripts/shell-quality-baseline.tsv 2>&1 || :)" && git diff --check`；本任务新增 test/gate/baseline 改动分别不超过 35/15/30 行、累计不超过 145/85/30 行。

### 任务 1.5: 用真实 canary 保护 Gitleaks 扫描

文件: 修改 `tests/test-quality-gate.sh`、修改 `scripts/check.sh`、创建 `.gitleaks.toml`
消费: scripts/shell-quality-baseline.tsv —— 30 行 C 序 path<TAB>git-blob canonical 文件且 SHA-256 为 62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f、scripts/check.sh --ci —— exact pair 命中才豁免，否则运行固定 ShellCheck/shfmt argv
产出: scripts/check.sh --offline|--ci —— 成功时退出 0 且 stdout 末行为 RESULT PASS  aosp-harness offline quality gate；参数/依赖/工具预检错误返回 2，语法/测试/静态/秘密检查失败返回 1，失败时不得输出该成功末行、.gitleaks.toml —— 字节精确为 [extend]\nuseDefault = true\n 且固定摘要
需求: R6, R9
必需: 是

- [ ] 步骤 1: 创建精确两行 config；扩展 fake Gitleaks 记录 NUL argv/env/target，并断言 gate 清除两个配置环境变量、先扫描 repo 外 canary 后扫描 repo、两次固定 options/config 完全相同且只有 target 不同、canary 文件由 `AKIA` 与 `ABCDEFGHIJKLMNOP` 运行时拼成并在第二次调用前已清理。

  ```bash
  printf '[extend]\nuseDefault = true\n' >.gitleaks.toml
  printf 'GITLEAKS_CONFIG=%s\0GITLEAKS_CONFIG_TOML=%s\0' \
    "${GITLEAKS_CONFIG-unset}" "${GITLEAKS_CONFIG_TOML-unset}" >>"$GITLEAKS_LOG"
  printf '%s\0' "$@" >>"$GITLEAKS_LOG"
  [[ "$call_index" -eq 1 ]] && exit "$CANARY_RC"
  exit "$WORKTREE_RC"
  ```
- [ ] 步骤 2: 表驱动断言 config 内容/摘要变化、空规则、全局 allowlist、canary fake 返回 `0` 或 `2` 都使 gate rc `2` 且不扫工作树；另把 `TMPDIR` 指到 fixture 仓库内，断言 gate 拒绝仓库内 canary、rc `2` 且 Gitleaks 零调用。canary 精确返回 `1` 后工作树 fake 非零必须归一 rc `1`，两阶段正确时才允许精确总 PASS；跑 `bash ./tests/test-quality-gate.sh` 确认红阶段首错含 `gitleaks config contract`。

  ```bash
  protocol_cases=(config-bytes config-digest empty-rules global-allowlist canary-rc-0 canary-rc-2)
  [[ "$canary_calls" -eq 1 && "$worktree_calls" -eq 0 && "$rc" -eq 2 ]]
  mkdir -p "$fixture/in-repo-tmp"
  set +e
  TMPDIR="$fixture/in-repo-tmp" "$host_bash" "$fixture/scripts/check.sh" --ci
  in_repo_tmp_rc=$?
  set -e
  [[ "$in_repo_tmp_rc" -eq 2 && "$in_repo_tmp_gitleaks_calls" -eq 0 ]]
  [[ "$worktree_failure_rc" -eq 1 ]]
  [[ "$success_calls" -eq 2 && "$success_last_line" ==
    'RESULT PASS  aosp-harness offline quality gate' ]]
  ```
- [ ] 步骤 3: 在 static 成功后校验 config 精确摘要；unset 两个环境变量，在 repo 外 `mktemp -d` 写入分片拼接 canary，注册 trap，以相同 `gitleaks dir --no-banner --redact --exit-code 1 --config <absolute-config> <target>` 要求 canary rc 精确 `1`，显式清理并解除 trap 后再扫绝对 repo root。

  ```bash
  config_sha=27630a96d6c55755cc37620f3933d5cab94b1eb78a726a32e11212972525d76e
  [[ "$(sha256sum "$config" | awk '{print $1}')" == "$config_sha" ]] ||
    quality_protocol_error 'gitleaks config contract'
  unset GITLEAKS_CONFIG GITLEAKS_CONFIG_TOML
  canary_dir="$(mktemp -d)"; canary_dir="$(cd -- "$canary_dir" && pwd -P)"
  case "$canary_dir/" in "$repo_root/"*) rm -rf -- "$canary_dir"; quality_protocol_error 'canary must be outside repository' ;; esac
  trap 'rm -rf -- "$canary_dir"' EXIT
  printf 'aws_access_key_id = %s%s\n' 'AKIA' 'ABCDEFGHIJKLMNOP' >"$canary_dir/canary.txt"
  gitleaks_args=(dir --no-banner --redact --exit-code 1 --config "$config")
  set +e; gitleaks "${gitleaks_args[@]}" "$canary_dir"; canary_rc=$?; set -e
  [[ "$canary_rc" -eq 1 ]] || quality_protocol_error 'gitleaks canary contract'
  rm -rf -- "$canary_dir"; trap - EXIT
  gitleaks "${gitleaks_args[@]}" "$repo_root" || exit 1
  ```
- [ ] 步骤 4: 跑 `bash ./tests/test-quality-gate.sh`，确认所有 Gitleaks/config case 通过，exit `0` 且末行为 contract PASS；再跑 `bash ./scripts/check.sh --offline`，确认真实 offline 仍 exit `0` 且末行为总 PASS。
- [ ] 步骤 5: 跑 `test "$(sha256sum .gitleaks.toml | awk '{print $1}')" = 27630a96d6c55755cc37620f3933d5cab94b1eb78a726a32e11212972525d76e && bash -n scripts/check.sh && bash -n tests/test-quality-gate.sh && test -z "$(git diff --no-index --check /dev/null .gitleaks.toml 2>&1 || :)" && git diff --check`；本任务新增 test/gate/config 改动分别不超过 24/20/2 行、最终累计不超过 169/105/2 行。

## CI 安装与 coverage 交付

### 任务 2.1: 固定 workflow 与 coverage 矩阵

文件: 修改 `tests/test-quality-gate.sh`、创建 `.github/workflows/quality.yml`、创建 `tests/COVERAGE.md`
消费: scripts/check.sh --offline|--ci —— 成功时退出 0 且 stdout 末行为 RESULT PASS  aosp-harness offline quality gate；参数/依赖/工具预检错误返回 2，语法/测试/静态/秘密检查失败返回 1，失败时不得输出该成功末行、.gitleaks.toml —— 字节精确为 [extend]\nuseDefault = true\n 且固定摘要
产出: CI workflow —— push/pull_request/workflow_dispatch 在 ubuntu-24.04 安装三份固定摘要工具并唯一一次调用 ./scripts/check.sh --ci、tests/COVERAGE.md —— 每个根 tests/test-*.sh 在五列表中唯一映射为 active、tests/test-quality-gate.sh —— 无参数且成功时 exit-0/末行为 RESULT PASS  offline quality gate contract
需求: R7, R8, R9
必需: 是

- [ ] 步骤 1: 在 contract 增加静态 oracle：workflow 必须含三个 trigger、`ubuntu-24.04`、三个官方 tag/资产/摘要、RUNNER_TEMP 绝对 bin、三种 artifact-to-executable 映射、`install -m 0755`、最后才写 GITHUB_PATH，且独立 quality step 唯一一次出现 `./scripts/check.sh --ci`。

  ```bash
  quality_docs_oracle() { python3 - "$1" "$2" <<'PY'
  import os,re,sys
  from pathlib import Path
  w='\n'.join(x for x in Path(sys.argv[1]).read_text().splitlines() if not x.lstrip().startswith('#'))
  assert 'on: [push, pull_request, workflow_dispatch]' in w and 'runs-on: ubuntu-24.04' in w
  assert 'root="$RUNNER_TEMP/aosp-harness-quality"; bin="$root/bin"' in w
  maps=(
  ('curl -fsSL -o "$root/downloads/shellcheck.tar.xz" https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.xz','8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198','tar -xJf "$root/downloads/shellcheck.tar.xz" -C "$root"','install -m 0755 "$root/shellcheck-v0.11.0/shellcheck" "$bin/shellcheck"'),
  ('curl -fsSL -o "$root/downloads/shfmt" https://github.com/mvdan/sh/releases/download/v3.14.0/shfmt_v3.14.0_linux_amd64','fe42021c7272ef2d67ea36cbc3031683c625d0badec733ef3a57b567246a0b66','install -m 0755 "$root/downloads/shfmt" "$bin/shfmt"'),
  ('curl -fsSL -o "$root/downloads/gitleaks.tar.gz" https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz','551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb','tar -xzf "$root/downloads/gitleaks.tar.gz" -C "$root"','install -m 0755 "$root/gitleaks" "$bin/gitleaks"'))
  install_positions=[]
  for mapping in maps:
    positions=[w.index(value) for value in mapping]; assert positions==sorted(positions), mapping
    install_positions.append(positions[-1])
  path_at=w.index('printf \'%s\\n\' "$bin" >>"$GITHUB_PATH"'); assert max(install_positions)<path_at
  assert w.count('./scripts/check.sh --ci')==1
  assert re.search(r'- name: Quality gate\n\s+run: \./scripts/check\.sh --ci',w)
  c=Path(sys.argv[2]).read_text(); rows=[]
  assert '| Test | Specs/requirements | Protected behavior | Offline boundary | Status |' in c
  for line in c.splitlines():
    cells=[cell.strip() for cell in line.strip().strip('|').split('|')]
    if not line.startswith('|') or cells[0] in ('Test','---'): continue
    assert len(cells)==5 and all(cells) and cells[4]=='active', cells
    match=re.fullmatch(r'`(tests/test-[^`]+\.sh)`',cells[0]); assert match; rows.append(match.group(1))
  expected={'tests/'+entry.name for entry in os.scandir('tests') if entry.is_file(follow_symlinks=False) and entry.name.startswith('test-') and entry.name.endswith('.sh')}
  assert len(rows)==len(set(rows)) and set(rows)==expected, (rows,expected)
  assert not re.search(r'(行|分支|line|branch|覆盖率|coverage)[^|\n]{0,20}\d+(?:\.\d+)?%?',c,re.I)
  PY
  }
  ```
- [ ] 步骤 2: 增加 coverage oracle：解析五列表头，自动发现每个当前普通根 `tests/test-*.sh` 并要求精确一条五列非空、Status 精确 `active`；拒绝未知/重复测试、空字段和数字行/分支覆盖率宣称；跑 `bash ./tests/test-quality-gate.sh` 确认红阶段首错为 `FAIL  workflow quality contract`。

  ```bash
  quality_docs_oracle .github/workflows/quality.yml tests/COVERAGE.md ||
    quality_test_fail 'workflow quality contract'
  ```
- [ ] 步骤 3: 创建 workflow：checkout 后用 `set -euo pipefail` 下载三个 requirements 固定资产、逐份 `sha256sum -c`、按 design 映射解包并 `install -m 0755` 到 `$RUNNER_TEMP/aosp-harness-quality/bin`，全部成功后追加 `$GITHUB_PATH`；独立 step 只调用一次 gate CI mode。

  ```yaml
  on: [push, pull_request, workflow_dispatch]
  jobs:
    quality:
      runs-on: ubuntu-24.04
      steps:
        - uses: actions/checkout@v4
        - name: Install pinned quality tools
          run: |
            set -euo pipefail
            root="$RUNNER_TEMP/aosp-harness-quality"; bin="$root/bin"
            mkdir -p "$root/downloads" "$bin"
            curl -fsSL -o "$root/downloads/shellcheck.tar.xz" https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.xz
            printf '%s  %s\n' 8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198 "$root/downloads/shellcheck.tar.xz" | sha256sum -c -
            tar -xJf "$root/downloads/shellcheck.tar.xz" -C "$root"
            install -m 0755 "$root/shellcheck-v0.11.0/shellcheck" "$bin/shellcheck"
            curl -fsSL -o "$root/downloads/shfmt" https://github.com/mvdan/sh/releases/download/v3.14.0/shfmt_v3.14.0_linux_amd64
            printf '%s  %s\n' fe42021c7272ef2d67ea36cbc3031683c625d0badec733ef3a57b567246a0b66 "$root/downloads/shfmt" | sha256sum -c -
            install -m 0755 "$root/downloads/shfmt" "$bin/shfmt"
            curl -fsSL -o "$root/downloads/gitleaks.tar.gz" https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
            printf '%s  %s\n' 551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb "$root/downloads/gitleaks.tar.gz" | sha256sum -c -
            tar -xzf "$root/downloads/gitleaks.tar.gz" -C "$root"
            install -m 0755 "$root/gitleaks" "$bin/gitleaks"
            printf '%s\n' "$bin" >>"$GITHUB_PATH"
        - name: Quality gate
          run: ./scripts/check.sh --ci
  ```
- [ ] 步骤 4: 创建不超过 8 行的 coverage 五列表，把 `tests/test-device-safety.sh` 与 `tests/test-quality-gate.sh` 各唯一映射到规格、保护行为、离线边界和 `active`；跑 `bash ./tests/test-quality-gate.sh` 与 `bash ./scripts/check.sh --offline`，确认两者 exit `0` 且各自末行精确匹配公开契约。

  ```markdown
  | Test | Specs/requirements | Protected behavior | Offline boundary | Status |
  |---|---|---|---|---|
  | `tests/test-device-safety.sh` | 01 R1-R7 | Device targeting and legacy regressions | Fake ADB only | active |
  | `tests/test-quality-gate.sh` | 02 R1-R9 | Offline/CI quality-gate contract | Fixture and fake tools only | active |
  ```
- [ ] 步骤 5: 跑下列 `bash -c` 自查脚本，确认 branch base 至当前 HEAD、index、tracked working diff 与全部 untracked 的 NUL 安全集合排除正常 `.spec/` 工作文件后恰好是六个许可文件；脚本以备用 index 暂存第七文件并要求范围门真实失败，不接触用户 index，同时执行 105/30/2/42/8/200 单文件上限、总 387 行和全文件空白门。

  ```bash
  set -euo pipefail
  files=(scripts/check.sh scripts/shell-quality-baseline.tsv .gitleaks.toml
         .github/workflows/quality.yml tests/COVERAGE.md tests/test-quality-gate.sh)
  caps=(105 30 2 42 8 200); base="$(git merge-base main HEAD)"
  scope_check() {
    git_with_index() { if [[ -n "${QUALITY_INDEX-}" ]]; then GIT_INDEX_FILE="$QUALITY_INDEX" git "$@"; else git "$@"; fi; }
    { git diff --name-only -z "$base"...HEAD
      git_with_index diff --cached --name-only -z
      git_with_index diff --name-only -z
      git_with_index ls-files --others --exclude-standard -z
    } | python3 -c 'import sys
  got={p for p in sys.stdin.buffer.read().split(b"\0") if p and not p.startswith(b".spec/")}
  expected={p.encode() for p in sys.argv[1:]}
  assert got == expected, (got, expected)' "${files[@]}"
  }
  total=0
  for i in "${!files[@]}"; do
    lines="$(wc -l <"${files[$i]}")"; ((lines <= caps[i])); total=$((total + lines))
    test -z "$(git diff --no-index --check /dev/null "${files[$i]}" 2>&1 || :)"
  done
  ((total <= 387)); scope_check
  probe_dir="$(mktemp -d)"; probe=.quality-range-canary
  trap 'rm -f -- "$probe"; rm -rf -- "$probe_dir"' EXIT
  GIT_INDEX_FILE="$probe_dir/index" git read-tree HEAD
  : >"$probe"; GIT_INDEX_FILE="$probe_dir/index" git add -- "$probe"
  ! QUALITY_INDEX="$probe_dir/index" scope_check
  rm -f -- "$probe"; rm -rf -- "$probe_dir"; trap - EXIT
  ```
