# 2026-08-31-01-device-safety 实现计划

## 测试骨架与 verifier 判据

### 任务 1.1: 建立隔离 fixture 与 scope runner

文件: 创建 `tests/test-device-safety.sh`
消费: 无
产出: device_safety_register_scope <scope> <function>、device_safety_fake_adb_install <fixture> <serial>
需求: R6
必需: 是
状态: 完成

- [ ] 步骤 1: 跑 `test -e ./tests/test-device-safety.sh` 确认红阶段失败，因为根级安全测试入口尚不存在。
- [ ] 步骤 2: 按下列骨架创建 scope 注册、失败汇总和无位置参数 runner；未知 scope 向 stderr 报错并 exit 2。

  ```bash
  DEVICE_SAFETY_SCOPE_NAMES=()
  DEVICE_SAFETY_SCOPE_FUNCS=()
  device_safety_register_scope() {
    DEVICE_SAFETY_SCOPE_NAMES+=("$1")
    DEVICE_SAFETY_SCOPE_FUNCS+=("$2")
  }
  device_safety_run_scope() {
    local wanted="$1" i
    for ((i=0; i<${#DEVICE_SAFETY_SCOPE_NAMES[@]}; i++)); do
      [[ "${DEVICE_SAFETY_SCOPE_NAMES[$i]}" != "$wanted" ]] || {
        "${DEVICE_SAFETY_SCOPE_FUNCS[$i]}"
        return
      }
    done
    printf 'error: unknown DEVICE_SAFETY_TEST_SCOPE: %s\n' "$wanted" >&2
    return 2
  }
  ```

- [ ] 步骤 3: 按下列 argv/响应表实现私有 fake adb；日志必须包含命令名，未知 serial 或命令返回非零。

  ```bash
  printf 'adb ' >>"$ADB_LOG"
  printf '%q ' "$@" >>"$ADB_LOG"
  printf '\n' >>"$ADB_LOG"
  [[ "${1-}" == -s && "${2-}" == "$EXPECTED_SERIAL" ]] || exit 91
  shift 2
  case "$*" in
    'shell getprop sys.boot_completed') printf '1\n' ;;
    'shell pidof system_server') printf '1423\n' ;;
    'shell cat /proc/stat') printf 'btime 200\n' ;;
    logcat\ -b\ crash\ -d\ -v\ *\ -T\ *) exit 0 ;;
    'shell service list') printf '52 sidebar: [android.sidebar.ISidebar]\n' ;;
    'shell pm list packages') printf 'package:com.android.sidebar\n' ;;
    *) exit 92 ;;
  esac
  ```

- [ ] 步骤 4: 用 `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh` 自测完整日志、未知 serial/命令非零、私有 `PATH` 首项和 trap 清理注册；自测不得调用系统 adb。
- [ ] 步骤 5: 跑 `bash -n ./tests/test-device-safety.sh`，确认语法检查 exit 0。

### 任务 1.2: 增加 Claude 非法 serial 矩阵

文件: 修改 `tests/test-device-safety.sh`
消费: device_safety_register_scope <scope> <function>、device_safety_fake_adb_install <fixture> <serial>
产出: device_safety_run_claude_invalid_serial_matrix
需求: R2, R6
必需: 是
状态: 完成

- [ ] 步骤 1: 按下列表驱动非法输入；`__UNSET__` 用 `env -u ANDROID_SERIAL`，其他值用分离环境参数传入，实际 LF 不得写成两个字符 `\` 和 `n`。

  ```bash
  invalid_serials=(
    '__UNSET__' '-bad' '.bad' '_bad' ':bad' 'bad/path' 'bad value'
    $'bad\nvalue' 'bad;value' 'bad+value'
  )
  ```

- [ ] 步骤 2: 每个 case 使用独立空日志运行 Claude 真实 verifier，逐项断言 rc 精确为 2、stderr 含 `ANDROID_SERIAL`、日志不存在或大小为 0；失败标签为 `FAIL  claude <case> ANDROID_SERIAL: expected rc=2 and zero adb calls`。

  ```bash
  [[ "$rc" -eq 2 ]] || device_safety_fail "$label: expected rc=2 and zero adb calls"
  grep -Fq 'ANDROID_SERIAL' "$stderr_file" || device_safety_fail "$label: missing ANDROID_SERIAL error"
  [[ ! -s "$adb_log" ]] || device_safety_fail "$label: expected zero adb calls"
  ```

- [ ] 步骤 3: 注册 `claude-invalid-serial` scope，跑 `DEVICE_SAFETY_TEST_SCOPE=claude-invalid-serial bash ./tests/test-device-safety.sh` 确认当前红阶段非零；首错为 `FAIL  claude missing ANDROID_SERIAL: expected rc=2 and zero adb calls`，且原始日志非空，证明当前裸 ADB 被 oracle 捕获。

### 任务 1.3: 增加 Claude 合法 serial 正向矩阵

文件: 修改 `tests/test-device-safety.sh`
消费: device_safety_register_scope <scope> <function>、device_safety_fake_adb_install <fixture> <serial>
产出: device_safety_run_claude_valid_serial_matrix
需求: R1, R6
必需: 是
状态: 完成

- [ ] 步骤 1: 对 `demo-serial`、`A0._:-z` 分别创建独立 fixture，运行 Claude 真实 verifier `--since 200` 并保存 rc/stdout/ADB 日志。

  ```bash
  valid_serials=('demo-serial' 'A0._:-z')
  for serial in "${valid_serials[@]}"; do
    expected_prefix="adb -s $serial "
    # run verifier with ANDROID_SERIAL="$serial" and private PATH
  done
  ```

- [ ] 步骤 2: 每个 case 断言 rc 为 0、stdout 末行精确 `RESULT PASS`、日志非空，且每一行而非仅首行都以精确 `adb -s <对应 serial> ` 开头。

  ```bash
  [[ "$rc" -eq 0 && "$(tail -n 1 "$stdout_file")" == 'RESULT PASS' ]]
  [[ -s "$adb_log" ]]
  [[ "$(grep -Fvc "$expected_prefix" "$adb_log")" -eq 0 ]]
  ```

- [ ] 步骤 3: 注册 `claude-valid-serial` scope，跑 `DEVICE_SAFETY_TEST_SCOPE=claude-valid-serial bash ./tests/test-device-safety.sh` 确认当前红阶段非零，首错为 `FAIL  claude demo-serial: expected adb -s prefix on every call`。

### 任务 1.4: 增加 flag 优先级与 Demo SKIP 矩阵

文件: 修改 `tests/test-device-safety.sh`
消费: device_safety_register_scope <scope> <function>、device_safety_fake_adb_install <fixture> <serial>
产出: device_safety_run_flag_and_demo_matrix
需求: R4, R5, R6, R7
必需: 是
状态: 完成

- [ ] 步骤 1: 用下列四组合分别运行两个真实 verifier；每组断言 rc 2、stderr 含精确短语且不含 `ANDROID_SERIAL`、ADB 日志为空。

  ```bash
  flag_cases=(
    'claude|__UNSET__' 'claude|-bad'
    'codex|__UNSET__' 'codex|-bad'
  )
  expected_error='--allow-skip requires --demo'
  ```

- [ ] 步骤 2: 对 Claude/Codex 分别以 `DEMO_APP_INSTALLED=0 --demo --allow-skip` 运行，断言 rc 0、至少一行匹配 `^SKIP  `、末行精确 `RESULT PASS (SKIP allowed)`。

  ```bash
  [[ "$rc" -eq 0 ]]
  grep -Eq '^SKIP  ' "$stdout_file"
  [[ "$(tail -n 1 "$stdout_file")" == 'RESULT PASS (SKIP allowed)' ]]
  ```

- [ ] 步骤 3: 断言两个 verifier 路径可执行；注册 `claude-flag-demo`、`codex-flag-demo`，再用 `flag-demo` 依次组合两者。
- [ ] 步骤 4: 跑 `DEVICE_SAFETY_TEST_SCOPE=flag-demo bash ./tests/test-device-safety.sh` 确认红阶段非零，首错为 `FAIL  claude real allow-skip missing serial: expected flag error before ANDROID_SERIAL`；原始日志非空或 rc 错误，不能被清空伪装为修复证据。

## Skill 静态 oracle

### 任务 1.5: 提取并计数 fenced 真机块

文件: 修改 `tests/test-device-safety.sh`
消费: device_safety_register_scope <scope> <function>
产出: device_safety_extract_device_blocks <skill-name> <path> <output-dir>
需求: R3, R6
必需: 是
状态: 完成

- [ ] 步骤 1: 实现 fenced Bash block 状态机；只把含目标 ADB 子命令的块落到私有 `output-dir/block-N.bash`，行内反引号不得算 fenced block。

  ```bash
  in_bash=0
  block=''
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$in_bash" -eq 0 && "$line" == '```bash' ]]; then
      in_bash=1; block=''; continue
    fi
    if [[ "$in_bash" -eq 1 && "$line" == '```' ]]; then
      if grep -Eq '(^|[;&][[:space:]]*)adb[[:space:]].*(root|remount|push|reboot|shell)' <<<"$block"; then
        count=$((count + 1))
        printf '%s\n' "$block" >"$output_dir/block-$count.bash"
      fi
      in_bash=0; continue
    fi
    [[ "$in_bash" -eq 0 ]] || block+="${block:+$'\n'}$line"
  done <"$path"
  ```

- [ ] 步骤 2: 对 `build-services-jar`、`build-sepolicy` 各要求目标计数精确为 1；零或多块均失败，sepolicy 当前行内 ADB 因计数为零必须被检出。
- [ ] 步骤 3: 用合成 Markdown fixture 验证“一个 build block + 一个 device block”只提取 device block；跑 `DEVICE_SAFETY_TEST_SCOPE=skill-blocks bash ./tests/test-device-safety.sh` 确认当前红阶段精确失败为 `FAIL  build-sepolicy: expected exactly one fenced device block`。

### 任务 1.6: 校验 serial preflight 与逐命令目标

文件: 修改 `tests/test-device-safety.sh`
消费: device_safety_extract_device_blocks <skill-name> <path> <output-dir>
产出: device_safety_check_skill_file <skill-name> <path>
需求: R3, R6
必需: 是
状态: 完成

- [ ] 步骤 1: 对唯一目标块取得首条 ADB 行号，并按精确片段验证 `device_serial` 取值和完整 regex 均位于该行之前。

  ```bash
  serial_line='device_serial="${ANDROID_SERIAL-}"'
  regex_line='if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then'
  first_adb="$(grep -nEm1 '(^|[;&][[:space:]]*)adb[[:space:]]' "$block" | cut -d: -f1)"
  serial_at="$(grep -nF "$serial_line" "$block" | cut -d: -f1)"
  regex_at="$(grep -nF "$regex_line" "$block" | cut -d: -f1)"
  [[ "$serial_at" -lt "$first_adb" && "$regex_at" -lt "$first_adb" ]]
  ```

- [ ] 步骤 2: 逐条读取含 `root/remount/push/reboot/shell` 的 ADB 命令，要求每条精确以 `adb -s "$device_serial"` 开头；目标块中出现其他 serial 变量或裸 ADB 即报 `bare adb`。

  ```bash
  expected_prefix='adb -s "$device_serial" '
  while IFS= read -r adb_line; do
    trimmed="${adb_line#"${adb_line%%[![:space:]]*}"}"
    [[ "$trimmed" == "$expected_prefix"* ]] || return 1
  done < <(grep -E 'adb[[:space:]].*(root|remount|push|reboot|shell)' "$block")
  ```

- [ ] 步骤 3: 注册 `skill-contract` scope；跑 `DEVICE_SAFETY_TEST_SCOPE=skill-contract bash ./tests/test-device-safety.sh` 确认当前红阶段首错精确为 `FAIL  build-services-jar device block 1: missing safe serial preflight`。

### 任务 1.7: 用逐 skill mutation 证明 oracle 可失败

文件: 修改 `tests/test-device-safety.sh`
消费: device_safety_check_skill_file <skill-name> <path>
产出: device_safety_run_skill_mutations
需求: R3, R6
必需: 是
状态: 完成

- [ ] 步骤 1: 对每个 skill 的临时副本只在唯一目标块做两种 mutation：把完整 regex 行改成仅空值判断；把第一条固定目标 ADB 去掉 `-s "$device_serial"`。每次修改前后用 `cmp -s` 证明文件已变，并断言替换计数精确为 1。

  ```bash
  unsafe_regex='if [[ -z "$device_serial" ]]; then'
  bare_prefix='adb '
  # awk 只在 extractor 返回的目标 block 边界内替换一次；替换计数 != 1 即失败。
  ```

- [ ] 步骤 2: 对两个 skill 共四个变体运行同一 `device_safety_check_skill_file`；regex 变体必须以 `missing safe serial preflight` 失败，裸 ADB 变体必须以 `bare adb` 失败，任一变体 exit 0 都算测试失败。
- [ ] 步骤 3: 用两个最小安全合成 skill 先跑 `mutation-selftest` scope 并确认 exit 0；再跑 `DEVICE_SAFETY_TEST_SCOPE=skills bash ./tests/test-device-safety.sh`，当前原文件仍应以 `FAIL  build-services-jar device block 1: missing safe serial preflight` 红灯失败。

### 任务 1.8: 聚合 legacy 与最终无参入口

文件: 修改 `tests/test-device-safety.sh`
消费: device_safety_register_scope <scope> <function>、device_safety_fake_adb_install <fixture> <serial>、device_safety_run_claude_invalid_serial_matrix、device_safety_run_claude_valid_serial_matrix、device_safety_run_flag_and_demo_matrix、device_safety_check_skill_file <skill-name> <path>、device_safety_run_skill_mutations
产出: tests/test-device-safety.sh —— 无参数；全部通过时退出 0 且 stdout 末行为 RESULT PASS  device safety，任一断言失败时退出非零
需求: R1, R2, R3, R4, R5, R6, R7
必需: 是
状态: 完成

- [ ] 步骤 1: 注册 `legacy` scope，在私有 fake adb `bin` 始终位于 `PATH` 首位的环境下逐项执行三套旧回归并断言 exit 0。

  ```bash
  legacy_tests=(
    './claude-code/features/.harness/tests/test-harness.sh'
    './codex/tests/test-harness.sh'
    './common/tests/test-harness.sh'
  )
  for legacy_test in "${legacy_tests[@]}"; do
    PATH="$fake_bin:$PATH" bash "$legacy_test" || device_safety_fail "legacy failed: $legacy_test"
  done
  ```

- [ ] 步骤 2: 注册 `all` 并作为无参数默认 scope，按 fixture、两个 Claude serial scope、flag-demo、skills、legacy 顺序运行；仅全部成功输出精确末行。

  ```bash
  for scope in fixture claude-invalid-serial claude-valid-serial flag-demo skills legacy; do
    device_safety_run_scope "$scope" || exit 1
  done
  printf 'RESULT PASS  device safety\n'
  ```

- [ ] 步骤 3: 跑 `chmod +x ./tests/test-device-safety.sh`，再逐条跑 `bash -n ./tests/test-device-safety.sh` 与 `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh`，确认直接执行入口和 fixture 基线为绿。
- [ ] 步骤 4: 跑 `bash ./tests/test-device-safety.sh` 确认生产修改前红阶段非零，首错为 `FAIL  claude missing ANDROID_SERIAL: expected rc=2 and zero adb calls`，末行不得是总成功结果。

## 最小生产修改

### 任务 2.1: 固定 Claude verifier 的设备目标

文件: 修改 `claude-code/features/dev-sidebar/verify-sidebar.sh`、修改 `claude-code/features/.harness/tests/test-harness.sh`
消费: tests/test-device-safety.sh —— 无参数；全部通过时退出 0 且 stdout 末行为 RESULT PASS  device safety，任一断言失败时退出非零
产出: claude-code/features/dev-sidebar/verify-sidebar.sh [--demo] [--allow-skip] [--since <epoch-seconds>]
需求: R1, R2, R4, R5, R7
必需: 是
状态: 完成

- [ ] 步骤 1: 跑 `DEVICE_SAFETY_TEST_SCOPE=claude-invalid-serial bash ./tests/test-device-safety.sh` 确认实现前首错为 missing serial 的 rc/零调用红灯，原始 fake ADB 日志非空。
- [ ] 步骤 2: 在参数解析后按下列顺序加入 flag 与 serial preflight；serial 分支只能在非 Demo 执行。

  ```bash
  if [[ "$DEMO" -eq 0 && "$ALLOW_SKIP" -eq 1 ]]; then
    echo 'error: --allow-skip requires --demo' >&2
    exit 2
  fi
  if [[ "$DEMO" -eq 0 ]]; then
    serial="${ANDROID_SERIAL-}"
    if [[ -z "$serial" || ! "$serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
      echo 'error: set ANDROID_SERIAL to a safe, explicit target serial' >&2
      exit 2
    fi
    ADB=(adb -s "$serial")
  fi
  ```

- [ ] 步骤 3: 把 Claude 真实 `adb shell` 和 `adb logcat` 改为 `"${ADB[@]}" shell` 与 `"${ADB[@]}" logcat`；Demo 分支不访问未定义的 ADB 数组。
- [ ] 步骤 4: 在 Claude 旧 fake adb 函数开头精确校验 `$1 == -s`、`$2 == demo-serial` 后 `shift 2`，并为对应真实 fixture 显式提供 `ANDROID_SERIAL=demo-serial`。
- [ ] 步骤 5: 用 `for file in ./claude-code/features/dev-sidebar/verify-sidebar.sh ./claude-code/features/.harness/tests/test-harness.sh; do bash -n "$file" || exit; done` 逐文件验证语法。
- [ ] 步骤 6: 分别跑 `DEVICE_SAFETY_TEST_SCOPE=claude-invalid-serial bash ./tests/test-device-safety.sh`、`DEVICE_SAFETY_TEST_SCOPE=claude-valid-serial bash ./tests/test-device-safety.sh`、`DEVICE_SAFETY_TEST_SCOPE=claude-flag-demo bash ./tests/test-device-safety.sh` 与 `DEVICE_SAFETY_TEST_SCOPE=legacy bash ./tests/test-device-safety.sh`，确认全部 exit 0。

### 任务 2.2: 关闭 Codex 真实模式 SKIP 假成功

文件: 修改 `codex/features/dev-sidebar/verify-sidebar.sh`
消费: tests/test-device-safety.sh —— 无参数；全部通过时退出 0 且 stdout 末行为 RESULT PASS  device safety，任一断言失败时退出非零
产出: codex/features/dev-sidebar/verify-sidebar.sh [--demo] [--allow-skip] [--since EPOCH] [--help]
需求: R4, R5, R7
必需: 是
状态: 完成

- [ ] 步骤 1: 跑 `DEVICE_SAFETY_TEST_SCOPE=codex-flag-demo bash ./tests/test-device-safety.sh`，确认实现前红阶段失败且首错为 `FAIL  codex real allow-skip missing serial: expected flag error before ANDROID_SERIAL`。
- [ ] 步骤 2: 在现有 serial 校验前加入下列 preflight，不改 Demo 或其他真实断言。

  ```bash
  if ((demo == 0 && allow_skip == 1)); then
    echo 'error: --allow-skip requires --demo' >&2
    exit 2
  fi
  ```

- [ ] 步骤 3: 跑 `bash -n ./codex/features/dev-sidebar/verify-sidebar.sh`，确认语法检查 exit 0。
- [ ] 步骤 4: 跑 `DEVICE_SAFETY_TEST_SCOPE=codex-flag-demo bash ./tests/test-device-safety.sh`，确认 Codex 两个真实优先级 case 与 Demo missing-app case 全部 exit 0。

### 任务 2.3: 固定 Claude skill 真机代码块的设备目标

文件: 修改 `claude-code/features/.harness/skills/build-services-jar/SKILL.md`、修改 `claude-code/features/.harness/skills/build-sepolicy/SKILL.md`
消费: tests/test-device-safety.sh —— 无参数；全部通过时退出 0 且 stdout 末行为 RESULT PASS  device safety，任一断言失败时退出非零、claude-code/features/dev-sidebar/verify-sidebar.sh [--demo] [--allow-skip] [--since <epoch-seconds>]、codex/features/dev-sidebar/verify-sidebar.sh [--demo] [--allow-skip] [--since EPOCH] [--help]
产出: device_serial —— 两个 Claude skill 真机代码块唯一允许的 ADB 目标变量
需求: R3
必需: 是
状态: 完成

- [ ] 步骤 1: 跑 `DEVICE_SAFETY_TEST_SCOPE=skills bash ./tests/test-device-safety.sh`，确认实现前红阶段失败且首错为 `FAIL  build-services-jar device block 1: missing safe serial preflight`。
- [ ] 步骤 2: 在 services.jar 部署块使用下列完整 preflight，并让每条 root/remount/push/reboot 都单独以固定前缀开头。

  ```bash
  device_serial="${ANDROID_SERIAL-}"
  if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
    echo 'error: set ANDROID_SERIAL to a safe, explicit target serial' >&2
    exit 2
  fi
  adb -s "$device_serial" root
  adb -s "$device_serial" remount
  adb -s "$device_serial" push out/target/product/vsoc_x86_64/system/framework/services.jar /system/framework/services.jar
  adb -s "$device_serial" reboot
  ```

- [ ] 步骤 3: 把 sepolicy 行内验证改成唯一 fenced Bash block，复用完全相同的 preflight，再使用以下命令。

  ```bash
  adb -s "$device_serial" shell dmesg | grep 'avc: denied'
  adb -s "$device_serial" shell service list | grep sidebar
  ```

- [ ] 步骤 4: 跑 `DEVICE_SAFETY_TEST_SCOPE=skills bash ./tests/test-device-safety.sh`，确认目标计数、原文件 contract 与两个 skill 各两类 mutation 全部 exit 0。
- [ ] 步骤 5: 用 `for file in ./tests/test-device-safety.sh ./claude-code/features/dev-sidebar/verify-sidebar.sh ./codex/features/dev-sidebar/verify-sidebar.sh ./claude-code/features/.harness/tests/test-harness.sh; do bash -n "$file" || exit; done` 逐文件验证所有修改 shell 文件语法。
- [ ] 步骤 6: 跑 `bash ./tests/test-device-safety.sh`，确认 exit 0 且 stdout 末行为 `RESULT PASS  device safety`。
- [ ] 步骤 7: 跑 `git diff --check`，确认六个实现文件没有空白错误。

### 任务 2.4: 压缩 device-safety 回归并恢复 diff 预算

文件: 修改 `tests/test-device-safety.sh`
消费: tests/test-device-safety.sh —— 无参数；全部通过时退出 0 且 stdout 末行为 RESULT PASS  device safety，任一断言失败时退出非零、device_serial —— 两个 Claude skill 真机代码块唯一允许的 ADB 目标变量
产出: tests/test-device-safety.sh —— 无参数；全部通过时退出 0 且 stdout 末行为 RESULT PASS  device safety，任一断言失败时退出非零
需求: R1, R2, R3, R4, R5, R6, R7
必需: 是
状态: 完成

- [ ] 步骤 1: 跑 `git diff --numstat 2f3e46baa2ed60d284da6c98dc28452c44f98786..HEAD` 确认验收红阶段总新增+删除为 818 行，超过 PLAN 的 400 行硬上限。
- [ ] 步骤 2: 仅重构根测试，合并重复 capture/fixture/断言与 Markdown 合成逻辑为表驱动 helper；不得修改两个 verifier、两个 skill 或 Claude legacy fixture，不得删除 invalid/valid serial、四个 flag 优先级、两个 Demo SKIP、逐 skill contract、四 mutation、三 legacy 回归中的任何一个判据。

  ```bash
  run_scopes=(
    fixture claude-invalid-serial claude-valid-serial
    claude-flag-demo codex-flag-demo skill-blocks
    skill-contract-selftest mutation-selftest skills legacy
  )
  for scope in "${run_scopes[@]}"; do
    DEVICE_SAFETY_TEST_SCOPE="$scope" bash ./tests/test-device-safety.sh || exit
  done
  ```

- [ ] 步骤 3: 保留无参数 `all` 的精确成功末行与失败时无成功末行语义；保留私有 fake ADB `PATH`、未知命令 fail-closed、实际 LF serial，以及 standalone-adb/device_serial 保守 allowlist 和其负向合成 cases。
- [ ] 步骤 4: 跑 `bash -n ./tests/test-device-safety.sh`，再执行步骤 2 的全部 scope，确认每项 exit 0。
- [ ] 步骤 5: 跑 `bash ./tests/test-device-safety.sh`，确认 exit 0 且 stdout 末行为 `RESULT PASS  device safety`；跑 `git diff --check` 确认无空白错误。
- [ ] 步骤 6: 跑 `test "$(git diff --numstat 2f3e46baa2ed60d284da6c98dc28452c44f98786..HEAD | awk '{sum += $1 + $2} END {print sum + 0}')" -le 400`，确认六文件总 diff 恢复到 PLAN 预算内。
