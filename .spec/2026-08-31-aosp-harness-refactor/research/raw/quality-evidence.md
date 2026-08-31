# Quality evidence（原始命令与结果）

范围：只执行无需真实 AOSP、ADB、CVD 或外部设备的检查。除受任务授权创建本文件及同目录 `quality-findings.md` 外，不修改产品源码、测试或规格状态。以下 `output` 为命令执行接口返回的原样 stdout/stderr；每项单列退出码。

## E00 — 执行环境

```bash
bash --version | head -1
git --version
python3 --version
uname -srm
```

```text
GNU bash, version 5.2.21(1)-release (x86_64-pc-linux-gnu)
git version 2.43.0
Python 3.12.3
Linux 6.6.87.2-microsoft-standard-WSL2 x86_64
```

退出码：`0`

## E01 — CI / 静态门禁配置与本机工具可用性

```bash
set +e
files="$(find . -path './.git' -prune -o -path './.spec' -prune -o -type f \( -path '*/.github/workflows/*' -o -name 'Makefile' -o -name 'Justfile' -o -name 'Taskfile.yml' -o -name 'package.json' -o -name 'pyproject.toml' -o -name 'tox.ini' -o -name '.pre-commit-config.yaml' -o -name '.shellcheckrc' -o -name '.editorconfig' -o -name '.yamllint' -o -name '.yamllint.yml' \) -print)"
if [[ -n "$files" ]]; then printf '%s\n' "$files"; else echo 'CI_OR_GATE_CONFIGS=0'; fi
for tool in shellcheck shfmt bats actionlint gitleaks git-secrets; do
  if command -v "$tool" >/dev/null 2>&1; then printf '%s=%s\n' "$tool" "$(command -v "$tool")"; else printf '%s=MISSING\n' "$tool"; fi
done
exit 0
```

```text
CI_OR_GATE_CONFIGS=0
shellcheck=MISSING
shfmt=MISSING
bats=MISSING
actionlint=MISSING
gitleaks=MISSING
git-secrets=MISSING
```

退出码：`0`

## E02 — 全部 Shell 入口的 Bash 语法基线

```bash
set +e
count=0
failures=0
while IFS= read -r file; do
  count=$((count + 1))
  if ! bash -n "$file"; then
    echo "SYNTAX_FAIL $file"
    failures=$((failures + 1))
  fi
done < <(find claude-code codex common -type f \( -name '*.sh' -o -path '*/bin/*' \) | sort)
echo "BASH_FILES=$count SYNTAX_FAILURES=$failures"
exit "$failures"
```

```text
BASH_FILES=29 SYNTAX_FAILURES=0
```

退出码：`0`

## E03 — Claude Code 版离线回归

```bash
./claude-code/features/.harness/tests/test-harness.sh
```

```text
PASS  demo harness startup, process layer, and strict verification
```

退出码：`0`

## E04 — Codex 版离线回归

```bash
./codex/tests/test-harness.sh
```

```text
PASS  Codex feature context selection and branch checks
```

退出码：`0`

执行接口记录墙钟时间约 `9.19s`。

## E05 — Shared 版离线回归

```bash
./common/tests/test-harness.sh
```

```text
RESULT PASS  shared Harness regression suite
```

退出码：`0`

执行接口记录墙钟时间约 `1.12s`。

## E06 — Codex 真实模式允许 SKIP 的隔离探针

该探针用导出的 Bash `adb` 函数提供确定性返回，不会解析或调用外部 `adb` 可执行文件，也不接触设备。应用查询故意返回空结果。

```bash
bash -c '
adb() {
  case "$*" in
    "-s demo-serial shell getprop sys.boot_completed") printf "1\\r\\n" ;;
    "-s demo-serial shell pidof system_server") printf "1423\\r\\n" ;;
    "-s demo-serial shell cat /proc/stat") printf "btime 100\\r\\n" ;;
    "-s demo-serial logcat -b crash -d -v epoch,nsec -T 100.000000000") return 0 ;;
    "-s demo-serial shell service list") printf "42 sidebar: [android.os.ISidebar]\\r\\n" ;;
    "-s demo-serial shell pm list packages") return 0 ;;
    *) return 97 ;;
  esac
}
export -f adb
ANDROID_SERIAL=demo-serial ./codex/features/dev-sidebar/verify-sidebar.sh --allow-skip
'
```

```text
PASS  sys.boot_completed = 1
PASS  system_server pid = 1423
PASS  crash buffer 自 100 起无崩溃
PASS  sidebar 服务已注册
SKIP  com.android.sidebar 未安装
SUMMARY PASS=4 FAIL=0 SKIP=1
RESULT PASS (SKIP allowed)
```

退出码：`0`

## E07 — Claude Code 真实模式未固定 ADB serial 的隔离探针

该探针同样只使用导出的 Bash `adb` 函数。函数仅接受不带 `-s <serial>` 的参数序列；同时注入按其他实现规则应属非法的 `ANDROID_SERIAL=-s`。若脚本固定了 serial，mock 会返回 `97`。

```bash
bash -c '
adb() {
  case "$*" in
    "shell getprop sys.boot_completed") printf "1\\n" ;;
    "shell pidof system_server") printf "1423\\n" ;;
    "logcat -b crash -d -v epoch -T 200.000") return 0 ;;
    "shell service list") printf "52 sidebar: [android.sidebar.ISidebar]\\n" ;;
    "shell pm list packages") printf "package:com.android.sidebar\\n" ;;
    *) return 97 ;;
  esac
}
export -f adb
ANDROID_SERIAL=-s ./claude-code/features/dev-sidebar/verify-sidebar.sh --since 200
'
```

```text
===== verify dev-sidebar (demo=0 crash_since=200) =====
PASS  sys.boot_completed = 1
PASS  system_server 存活
PASS  crash buffer 自 200 起无崩溃
PASS  系统服务 sidebar 已注册
PASS  边栏 app com.android.sidebar 已安装
-------------------------------------------
PASS=5  FAIL=0  SKIP=0
RESULT PASS
```

退出码：`0`

## E08 — 测试体量盘点

```bash
printf 'claude_test_files=%s\n' "$(find claude-code/features/.harness/tests -maxdepth 1 -type f -name 'test-*.sh' | wc -l)"
printf 'codex_test_files=%s\n' "$(find codex/tests -maxdepth 1 -type f -name 'test-*.sh' | wc -l)"
printf 'common_test_files=%s\n' "$(find common/tests -maxdepth 1 -type f -name 'test-*.sh' | wc -l)"
printf 'codex_named_test_functions=%s\n' "$(rg -c '^test_[A-Za-z0-9_]+\(\)' codex/tests/test-harness.sh)"
printf 'codex_run_regression_calls=%s\n' "$(rg -c '^run_regression ' codex/tests/test-harness.sh)"
printf 'common_named_test_functions=%s\n' "$(rg -c '^test_[A-Za-z0-9_]+\(\)' common/tests/test-harness.sh)"
printf 'common_run_expect_calls=%s\n' "$(rg -c '^run_expect_success ' common/tests/test-harness.sh)"
printf 'claude_main_test_assertions=%s\n' "$(rg -c '^[[:space:]]*(test |grep -|if |[A-Za-z_]+_output=)' claude-code/features/.harness/tests/test-harness.sh)"
```

```text
claude_test_files=3
codex_test_files=1
common_test_files=1
codex_named_test_functions=47
codex_run_regression_calls=68
common_named_test_functions=16
common_run_expect_calls=16
claude_main_test_assertions=44
```

退出码：`0`

说明：这些是静态数量，不等同于独立测试用例数或覆盖率；Codex 的 68 次调用包含参数化地复用同一测试函数。

## E09 — 明显秘密签名的只读扫描

```bash
git grep -nE 'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|password[[:space:]]*[:=]|passwd[[:space:]]*[:=]|api[_-]?key[[:space:]]*[:=]|client[_-]?secret[[:space:]]*[:=]' -- .
```

```text
<无输出>
```

退出码：`1`（`git grep` 的“无匹配”状态）。

该结果只说明已跟踪文件未命中列出的有限模式；E01 显示本机无 `gitleaks` / `git-secrets`，不能据此证明不存在秘密。

## E10 — 基线后工作区状态

```bash
git status --short
find "${TMPDIR:-/tmp}" -maxdepth 1 -name '.aosp-harness-demo.feature-snapshot' -printf '%m %u %p\n' 2>/dev/null
```

```text
?? .spec/
```

退出码：`0`

说明：三套回归与两个 mock 探针后没有已跟踪文件变化；`.spec/` 在本轮开始前已整体为未跟踪目录。固定名 Claude 快照在本轮检查时不存在。
