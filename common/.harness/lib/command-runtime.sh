#!/usr/bin/env bash

_HARNESS_COMMAND_RUNNER='import os,signal,subprocess,sys,time
kind,timeout_s,attempts_s,delay_s,root=sys.argv[1:6]; argv=sys.argv[7:]
timeout=float(timeout_s); attempts=int(attempts_s); delay=float(delay_s)
latched=0; child=None; internal=False
diag=open(root+"/diag","ab",buffering=0); raw=open(root+"/raw","ab",buffering=0)
def alive(pgid):
 try: os.killpg(pgid,0); return True
 except ProcessLookupError: return False
def send(pgid,sig):
 try: os.killpg(pgid,sig)
 except ProcessLookupError: pass
def handler(sig,_frame):
 global latched
 if not latched: latched=sig
 if child is not None: send(child.pid,sig)
for sig in (signal.SIGHUP,signal.SIGINT,signal.SIGTERM): signal.signal(sig,handler)
final_rc=2
for n in range(1,attempts+1):
 outp=root+("/out-%d"%n); errp=root+("/err-%d"%n); completed=False; timed=False
 try:
  start=time.monotonic()
  with open(outp,"wb",buffering=0) as out,open(errp,"wb",buffering=0) as err:
   os.chmod(outp,0o600); os.chmod(errp,0o600)
   child=subprocess.Popen(argv,stdout=out,stderr=err,start_new_session=True)
   while child.poll() is None and not latched and time.monotonic()-start < timeout: time.sleep(.01)
   timed=not latched and child.poll() is None
   if timed: send(child.pid,signal.SIGTERM)
   if child.poll() is not None and alive(child.pid): send(child.pid,signal.SIGTERM)
   deadline=time.monotonic()+1
   while alive(child.pid) and time.monotonic()<deadline: time.sleep(.01)
   if alive(child.pid): send(child.pid,signal.SIGKILL)
   child.wait()
   for _ in range(100):
    if not alive(child.pid): break
    time.sleep(.01)
   if alive(child.pid): raise RuntimeError("pgid")
  elapsed=int((time.monotonic()-start)*1000)
  rc=128+(-child.returncode) if child.returncode < 0 else child.returncode
  if latched: result="signal:%d"%latched; final_rc=128+latched
  elif timed: result="timeout"; final_rc=124
  else: result="rc:%d"%rc; final_rc=rc
  first=os.fsencode(argv[0])
  diag.write(("runtime: class=%s attempt=%d/%d argc=%d argv0_len=%d argv0_hex=%s result=%s elapsed_ms=%d\n"%(kind,n,attempts,len(argv),len(first),first.hex(),result,elapsed)).encode("ascii"))
  completed=True
 except BaseException:
  internal=True
  if child is not None:
   send(child.pid,signal.SIGTERM); end=time.monotonic()+1
   while alive(child.pid) and time.monotonic()<end: time.sleep(.01)
   if alive(child.pid): send(child.pid,signal.SIGKILL)
   try: child.wait()
   except BaseException: pass
 if os.path.exists(errp):
  try:
   with open(errp,"rb") as source: raw.write(source.read())
  except BaseException: internal=True
 if internal or latched: break
 terminal=final_rc==0 or n==attempts or kind not in ("query","reconnect")
 if terminal:
  if completed:
   try: os.replace(outp,root+"/terminal")
   except BaseException: internal=True
  break
 try:
  if delay:
   end=time.monotonic()+delay
   while not latched and time.monotonic()<end: time.sleep(min(.01,end-time.monotonic()))
 except BaseException: internal=True
 if internal or latched: break
with open(root+"/status","w",encoding="ascii",newline="\n") as status:
 status.write("rc\t%d\nsignal\t%d\ninternal\t%d\n"%(final_rc,latched,1 if internal else 0))
os.chmod(root+"/status",0o600)
'

_harness_command_error() {
  printf '%s\n' "$1" >&2
  return 2
}

harness_command_run() {
  local class=${1-} timeout=${2-} session=${3-} wait_seconds=${4-} request=${5-}
  [[ $# -ge 7 && ${6-} == -- ]] || {
    _harness_command_error 'error: invalid command runtime request'
    return
  }
  shift 6
  case $class in query | mutate | reconnect | build | cvd) ;; *)
    _harness_command_error 'error: invalid command runtime request'
    return
    ;;
  esac
  [[ $timeout =~ ^([1-9][0-9]{0,3}|[1-7][0-9]{4}|8[0-5][0-9]{3}|86[0-3][0-9]{2}|86400)$ && $session =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ && $wait_seconds =~ ^(0|[1-9][0-9]{0,2})$ && $wait_seconds -le 300 && -n ${1-} ]] || {
    _harness_command_error 'error: invalid command runtime request'
    return
  }
  local query=${HARNESS_COMMAND_QUERY_ATTEMPTS-3} reconnect=${HARNESS_COMMAND_RECONNECT_ATTEMPTS-6} delay=${HARNESS_COMMAND_RETRY_DELAY_SECONDS-1}
  [[ $query =~ ^[1-5]$ && $reconnect =~ ^([1-9]|[12][0-9]|30)$ && $delay =~ ^(0|[1-9]|[12][0-9]|30)$ ]] || {
    _harness_command_error 'error: invalid command runtime request'
    return
  }
  [[ $request == - || (-f $request && ! -L $request) ]] || {
    _harness_command_error 'error: command runtime lease provider'
    return
  }
  command -v python3 >/dev/null 2>&1 && python3 -c 'import sys;raise SystemExit(sys.version_info<(3,8))' >/dev/null 2>&1 || {
    _harness_command_error 'error: command runtime internal'
    return
  }
  local root template=${TMPDIR:-/tmp}/aosp-harness-command.XXXXXX
  root=$(mktemp -d "$template" 2>/dev/null) && python3 -c 'import os,stat,sys;p,t=sys.argv[1:];s=os.lstat(p);raise SystemExit(not(os.path.isabs(p) and p.startswith(t[:-6]) and stat.S_ISDIR(s.st_mode) and not stat.S_ISLNK(s.st_mode) and s.st_uid==os.geteuid() and stat.S_IMODE(s.st_mode)==0o700 and not os.listdir(p)))' "$root" "$template" >/dev/null 2>&1 || {
    _harness_command_error 'error: command runtime internal'
    return
  }
  local source_path=${BASH_SOURCE[0]} source_dir provider saved=$root/traps token='' legacy=0 runner_pid='' first_signal=0
  case $source_path in */*) source_dir=${source_path%/*} ;; *) source_dir=. ;; esac
  source_dir=$(cd -- "$source_dir" && pwd -P) || {
    command rm -rf -- "$root"
    _harness_command_error 'error: command runtime internal'
    return
  }
  provider=$source_dir/resource-leases.sh
  trap -p HUP INT TERM >"$saved" && chmod 600 "$saved" || {
    command rm -rf -- "$root"
    _harness_command_error 'error: command runtime internal'
    return
  }
  trap 'if [[ $first_signal == 0 ]]; then first_signal=1; [[ -z $runner_pid ]] || kill -HUP "$runner_pid" 2>/dev/null || :; fi' HUP
  trap 'if [[ $first_signal == 0 ]]; then first_signal=2; [[ -z $runner_pid ]] || kill -INT "$runner_pid" 2>/dev/null || :; fi' INT
  trap 'if [[ $first_signal == 0 ]]; then first_signal=15; [[ -z $runner_pid ]] || kill -TERM "$runner_pid" 2>/dev/null || :; fi' TERM
  local provider_failed=0 acquire_failed=0
  if [[ $request != - ]]; then
    if [[ ! -e $provider && ! -L $provider ]]; then
      [[ ${HARNESS_LEGACY_SINGLE_SESSION-} == 1 ]] && legacy=1 || provider_failed=1
    elif [[ -f $provider && ! -L $provider ]]; then
      # shellcheck source=/dev/null
      { source "$provider"; } >"$root/provider.out" 2>"$root/provider.err" || provider_failed=1
      [[ $provider_failed != 0 || -s $root/provider.out || -s $root/provider.err ]] && provider_failed=1
      declare -F harness_lease_acquire harness_lease_release >/dev/null || provider_failed=1
    else
      provider_failed=1
    fi
    if [[ $provider_failed == 0 && $legacy == 0 ]]; then
      harness_lease_acquire "$session" "$wait_seconds" "$request" >"$root/acquire.out" 2>"$root/acquire.err" || acquire_failed=1
      [[ $acquire_failed == 0 && ! -s $root/acquire.err && $(wc -c <"$root/acquire.out") == 33 ]] && IFS= read -r token <"$root/acquire.out" || acquire_failed=1
      [[ $token =~ ^[0-9a-f]{32}$ ]] || acquire_failed=1
    fi
  fi
  local attempts=1
  [[ $class == query ]] && attempts=$query
  [[ $class == reconnect ]] && attempts=$reconnect
  : >"$root/diag" && : >"$root/raw" && : >"$root/terminal"
  chmod 600 "$root/diag" "$root/raw" "$root/terminal"
  local runner_rc=2 status_rc=2 status_signal=0 internal=0 release_failed=0 cleanup_failed=0
  if [[ $provider_failed == 0 && $acquire_failed == 0 ]]; then
    runner_rc=0
    python3 -c "$_HARNESS_COMMAND_RUNNER" "$class" "$timeout" "$attempts" "$delay" "$root" -- "$@" &
    runner_pid=$!
    while :; do
      if wait "$runner_pid"; then runner_rc=0; else runner_rc=$?; fi
      kill -0 "$runner_pid" 2>/dev/null || break
    done
    runner_pid=''
    mapfile -t status <"$root/status" 2>/dev/null || internal=1
    [[ ${status[*]-} =~ ^rc[[:space:]]([0-9]+)[[:space:]]signal[[:space:]](0|1|2|15)[[:space:]]internal[[:space:]](0|1)$ ]] && status_rc=${BASH_REMATCH[1]} status_signal=${BASH_REMATCH[2]} internal=${BASH_REMATCH[3]} || internal=1
    [[ $first_signal == 0 ]] && first_signal=$status_signal
    [[ $runner_rc == 0 ]] || internal=1
  fi
  if [[ -n $token ]]; then
    harness_lease_release "$token" >"$root/release.out" 2>"$root/release.err" || release_failed=1
    [[ ! -s $root/release.out && ! -s $root/release.err ]] || release_failed=1
  fi
  exec {diag_fd}<"$root/diag" {raw_fd}<"$root/raw" {out_fd}<"$root/terminal" || cleanup_failed=1
  trap - HUP INT TERM
  # shellcheck source=/dev/null
  source "$saved" || cleanup_failed=1
  command rm -rf -- "$root" || cleanup_failed=1
  [[ $legacy == 0 ]] || printf '%s\n' 'compat: lease-provider=legacy' >&2
  command cat <&"$diag_fd" >&2
  if [[ $provider_failed != 0 ]]; then
    printf '%s\n' 'error: command runtime lease provider' >&2
  elif [[ $acquire_failed != 0 ]]; then
    printf '%s\n' 'error: command runtime lease acquire' >&2
  elif [[ $release_failed == 1 ]]; then
    printf '%s\n' 'error: command runtime lease release' >&2
  elif [[ $internal == 1 || $cleanup_failed == 1 ]]; then
    printf '%s\n' 'error: command runtime internal' >&2
  fi
  command cat <&"$raw_fd" >&2
  if [[ $provider_failed != 0 || $acquire_failed != 0 ]]; then return 2; fi
  if [[ $first_signal != 0 ]]; then return $((128 + first_signal)); fi
  if [[ $release_failed == 1 || $internal == 1 || $cleanup_failed == 1 ]]; then return 2; fi
  command cat <&"$out_fd"
  return "$status_rc"
}
