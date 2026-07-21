#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: verify-sidebar.sh [--demo] [--allow-skip] [--since EPOCH] [--help]
EOF
}

usage_error() {
  usage >&2
  exit 2
}

demo=0
allow_skip=0
since_set=0
since=''

while (($# > 0)); do
  case "$1" in
    --demo)
      demo=1
      shift
      ;;
    --allow-skip)
      allow_skip=1
      shift
      ;;
    --since)
      (($# >= 2)) || usage_error
      [[ "$2" =~ ^[0-9]+([.][0-9]{1,9})?$ ]] || usage_error
      since="$2"
      since_set=1
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      usage_error
      ;;
  esac
done

if ((demo == 0)); then
  serial="${ANDROID_SERIAL-}"
  if [[ -z "$serial" || ! "$serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
    echo 'error: set ANDROID_SERIAL to a safe, explicit target serial' >&2
    exit 2
  fi
  ADB=(adb -s "$serial")
fi

pass_count=0
fail_count=0
skip_count=0

pass() {
  echo "PASS  $1"
  ((pass_count += 1))
}

fail() {
  echo "FAIL  $1"
  ((fail_count += 1))
}

skip() {
  echo "SKIP  $1"
  ((skip_count += 1))
}

normalize_query_output() {
  REPLY="${1//$'\r'/}"
  while [[ "$REPLY" =~ [[:space:]]$ ]]; do
    REPLY="${REPLY%?}"
  done
}

normalize_logcat_since() {
  local epoch="$1"
  local seconds fraction

  if [[ "$epoch" == *.* ]]; then
    seconds="${epoch%%.*}"
    fraction="${epoch#*.}"
  else
    seconds="$epoch"
    fraction=''
  fi
  while ((${#fraction} < 9)); do
    fraction+='0'
  done
  REPLY="$seconds.$fraction"
}

analyze_crash_buffer() {
  python3 -c '
import re
import sys

epoch_pattern = re.compile(r"^([0-9]+)(?:[.]([0-9]{1,9}))?$")

def epoch_nanoseconds(token):
    match = epoch_pattern.fullmatch(token)
    if match is None:
        return None
    seconds = int(match.group(1))
    fraction = (match.group(2) or "").ljust(9, "0")
    return seconds * 1_000_000_000 + int(fraction or "0")

baseline = epoch_nanoseconds(sys.argv[1])
if baseline is None:
    raise SystemExit(20)

for raw_line in sys.stdin:
    line = raw_line.strip()
    if not line:
        continue
    token = line.split(None, 1)[0]
    timestamp = epoch_nanoseconds(token)
    if timestamp is not None:
        if timestamp >= baseline:
            raise SystemExit(10)
    elif token[0].isdigit():
        raise SystemExit(20)

raise SystemExit(0)
' "$1"
}

boot_completed=''
boot_rc=0
if ((demo)); then
  if [[ "${DEMO_BOOT_QUERY_FAIL:-0}" == 1 ]]; then
    boot_rc=1
  else
    boot_completed="${DEMO_BOOT_COMPLETED-1}"
  fi
elif boot_completed="$("${ADB[@]}" shell getprop sys.boot_completed 2>/dev/null)"; then
  boot_rc=0
else
  boot_rc=$?
fi
if ((boot_rc == 0)); then
  normalize_query_output "$boot_completed"
  boot_completed="$REPLY"
fi

if ((boot_rc != 0)); then
  fail 'sys.boot_completed 查询失败'
elif [[ "$boot_completed" == 1 ]]; then
  pass 'sys.boot_completed = 1'
else
  fail 'sys.boot_completed != 1'
fi

system_server=''
system_server_rc=0
if ((demo)); then
  if [[ "${DEMO_SYSTEM_SERVER_QUERY_FAIL:-0}" == 1 ]]; then
    system_server_rc=1
  else
    system_server="${DEMO_SYSTEM_SERVER-1423}"
  fi
elif system_server="$("${ADB[@]}" shell pidof system_server 2>/dev/null)"; then
  system_server_rc=0
else
  system_server_rc=$?
fi
if ((system_server_rc == 0)); then
  normalize_query_output "$system_server"
  system_server="$REPLY"
fi

if ((system_server_rc != 0)); then
  fail 'system_server 查询失败'
elif [[ -n "${system_server//[[:space:]]/}" ]]; then
  pass "system_server pid = $system_server"
else
  fail 'system_server pid 为空'
fi

baseline=''
baseline_ready=0
if ((since_set)); then
  baseline="$since"
  baseline_ready=1
else
  stat_output=''
  stat_rc=0
  if ((demo)); then
    if [[ "${DEMO_BOOT_TIME_QUERY_FAIL:-0}" == 1 ]]; then
      stat_rc=1
    else
      stat_output="btime ${DEMO_BOOT_TIME-100}"
    fi
  elif stat_output="$("${ADB[@]}" shell cat /proc/stat 2>/dev/null)"; then
    stat_rc=0
  else
    stat_rc=$?
  fi
  if ((stat_rc == 0)); then
    normalize_query_output "$stat_output"
    stat_output="$REPLY"
  fi

  if ((stat_rc != 0)); then
    fail 'btime 查询失败'
  else
    while IFS= read -r stat_line; do
      if [[ "$stat_line" =~ ^btime[[:space:]]+([0-9]+)[[:space:]]*$ ]]; then
        baseline="${BASH_REMATCH[1]}"
        baseline_ready=1
        break
      fi
    done <<<"$stat_output"
    if ((baseline_ready == 0)); then
      fail 'btime 解析失败'
    fi
  fi
fi

if ((baseline_ready)); then
  normalize_logcat_since "$baseline"
  logcat_since="$REPLY"

  crash_log=''
  crash_rc=0
  if ((demo)); then
    if [[ "${DEMO_CRASH_QUERY_FAIL:-0}" == 1 ]]; then
      crash_rc=1
    else
      crash_log="${DEMO_CRASH_LOG-}"
    fi
  elif crash_log="$("${ADB[@]}" logcat -b crash -d -v epoch,nsec -T "$logcat_since" 2>/dev/null)"; then
    crash_rc=0
  else
    crash_rc=$?
  fi

  if ((crash_rc != 0)); then
    fail 'crash buffer 查询失败'
  else
    analysis_rc=0
    if analyze_crash_buffer "$baseline" <<<"$crash_log"; then
      analysis_rc=0
    else
      analysis_rc=$?
    fi
    case "$analysis_rc" in
      0) pass "crash buffer 自 $baseline 起无崩溃" ;;
      10) fail "crash buffer 自 $baseline 起发现崩溃" ;;
      *) fail 'crash buffer 解析失败' ;;
    esac
  fi
fi

service_list=''
service_rc=0
if ((demo)); then
  if [[ "${DEMO_SERVICE_QUERY_FAIL:-0}" == 1 ]]; then
    service_rc=1
  elif [[ "${DEMO_SERVICE_REGISTERED:-1}" == 1 ]]; then
    service_list='42 sidebar: [android.os.ISidebar]'
  fi
elif service_list="$("${ADB[@]}" shell service list 2>/dev/null)"; then
  service_rc=0
else
  service_rc=$?
fi
if ((service_rc == 0)); then
  normalize_query_output "$service_list"
  service_list="$REPLY"
fi

if ((service_rc != 0)); then
  fail 'service list 查询失败'
elif grep -Eq '(^|[[:space:]])sidebar:' <<<"$service_list"; then
  pass 'sidebar 服务已注册'
else
  fail 'sidebar 服务未注册'
fi

package_list=''
package_rc=0
if ((demo)); then
  if [[ "${DEMO_PACKAGE_QUERY_FAIL:-0}" == 1 ]]; then
    package_rc=1
  elif [[ "${DEMO_APP_INSTALLED:-1}" == 1 ]]; then
    package_list='package:com.android.sidebar'
  fi
elif package_list="$("${ADB[@]}" shell pm list packages 2>/dev/null)"; then
  package_rc=0
else
  package_rc=$?
fi
if ((package_rc == 0)); then
  normalize_query_output "$package_list"
  package_list="$REPLY"
fi

if ((package_rc != 0)); then
  fail 'package list 查询失败'
elif grep -Eq '^package:com[.]android[.]sidebar[[:space:]]*$' <<<"$package_list"; then
  pass 'com.android.sidebar 已安装'
else
  skip 'com.android.sidebar 未安装'
fi

echo "SUMMARY PASS=$pass_count FAIL=$fail_count SKIP=$skip_count"
if ((fail_count > 0)); then
  echo 'RESULT FAIL'
  exit 1
elif ((skip_count > 0 && allow_skip == 0)); then
  echo 'RESULT INCOMPLETE'
  exit 1
elif ((skip_count > 0)); then
  echo 'RESULT PASS (SKIP allowed)'
else
  echo 'RESULT PASS'
fi
