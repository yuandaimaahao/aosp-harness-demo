#!/usr/bin/env bash
set -euo pipefail

demo=0
allow_skip=0

usage() {
  printf '%s\n' 'Usage: verify-sidebar.sh [--demo] [--allow-skip]'
}

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
    --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if ((demo == 0)); then
  serial="${ANDROID_SERIAL:-}"
  [[ "$serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] || {
    echo 'error: 真实模式需要显式设置安全的 ANDROID_SERIAL' >&2
    exit 2
  }
  ADB=(adb -s "$serial")
fi

pass_count=0
fail_count=0
skip_count=0

pass_check() {
  echo "PASS  $1"
  pass_count=$((pass_count + 1))
}

fail_check() {
  echo "FAIL  $1"
  fail_count=$((fail_count + 1))
}

skip_check() {
  echo "SKIP  $1"
  skip_count=$((skip_count + 1))
}

if [[ "${DEMO_SKIP:-0}" == 1 ]]; then
  skip_check 'sidebar service registration（demo requested skip）'
elif ((demo)); then
  if [[ "${DEMO_SERVICE_REGISTERED:-1}" == 1 ]]; then
    pass_check 'sidebar service registered'
  else
    fail_check 'sidebar service missing'
  fi
else
  if service_output="$("${ADB[@]}" shell service list 2>/dev/null)" &&
     grep -Eq 'sidebar|Sidebar' <<<"$service_output"; then
    pass_check 'sidebar service registered'
  elif [[ -n "${service_output:-}" ]]; then
    fail_check 'sidebar service missing'
  else
    fail_check 'sidebar service query failed'
  fi
fi

if ((demo)); then
  boot_completed="${DEMO_BOOT_COMPLETED:-1}"
else
  boot_completed="$("${ADB[@]}" shell getprop sys.boot_completed 2>/dev/null || true)"
  boot_completed="${boot_completed//$'\r'/}"
  boot_completed="${boot_completed//$'\n'/}"
fi
if [[ "$boot_completed" == 1 ]]; then
  pass_check 'sys.boot_completed = 1'
else
  fail_check 'sys.boot_completed != 1'
fi

if ((demo)); then
  system_server="${DEMO_SYSTEM_SERVER:-1423}"
else
  system_server="$("${ADB[@]}" shell pidof system_server 2>/dev/null || true)"
fi
if [[ "$system_server" =~ ^[0-9]+([[:space:]]+[0-9]+)*$ ]]; then
  pass_check "system_server pid = $system_server"
else
  fail_check 'system_server pid 无效或查询失败'
fi

if ((fail_count > 0)); then
  echo 'RESULT FAIL'
  exit 1
fi
if ((skip_count > 0 && allow_skip == 0)); then
  echo 'RESULT INCOMPLETE'
  exit 2
fi
if ((skip_count > 0)); then
  echo 'RESULT PASS (SKIP allowed)'
else
  echo 'RESULT PASS'
fi
