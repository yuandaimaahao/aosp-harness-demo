# review 包 1e3d297a..5f867fa8

## commit 列表

```
5f867fa Add verifier contract assurance test
```

## diff --stat

```
 tests/test-verifier-contract-assurance.sh | 331 ++++++++++++++++++++++++++++++
 1 file changed, 331 insertions(+)
```

## diff

```diff
diff --git a/tests/test-verifier-contract-assurance.sh b/tests/test-verifier-contract-assurance.sh
new file mode 100755
index 0000000..3688cfe
--- /dev/null
+++ b/tests/test-verifier-contract-assurance.sh
@@ -0,0 +1,331 @@
+#!/usr/bin/env bash
+set -uo pipefail
+TMP=$(mktemp -d /tmp/verifier-assurance.XXXXXX) || exit 1
+rc=0
+trap 'rc=$?; if [[ -e $TMP || -L $TMP ]]; then rm -rf -- "$TMP" || rc=1; fi; exit "$rc"' EXIT
+python3 - "${BASH_SOURCE[0]}" "$TMP" "$@" <<'PY'
+import ast, hashlib, itertools, json, os, pathlib, re, shutil, signal, stat, subprocess, sys
+
+class Failure(Exception):
+    pass
+def check(ok, label):
+    if not ok: raise Failure(label)
+def capture(argv, env=None):
+    return subprocess.run(argv, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
+def exact(p, rc, out=b'', err=b'', label='protocol'):
+    check((p.returncode, p.stdout, p.stderr) == (rc, out, err), label)
+SELF = pathlib.Path(sys.argv[1]).absolute()
+TMP = pathlib.Path(sys.argv[2])
+ROOT = SELF.parent.parent.resolve()
+PASS = b'RESULT PASS  verifier contract assurance\n'
+PATHS = ('common/.harness/bin/verify-sidebar.sh', 'docs/verifier-contract.md', 'tests/test-verifier-contract.sh')
+KEYS = ('boot', 'system_server', 'boot_time', 'crash', 'service', 'package')
+VALUES = ('BOOT_COMPLETED', 'SYSTEM_SERVER', 'BOOT_TIME', 'CRASH_LOG', 'SERVICE_LIST', 'PACKAGE_LIST')
+ARGS = [['shell', 'getprop', 'sys.boot_completed'], ['shell', 'pidof', 'system_server'], ['shell', 'cat', '/proc/stat'], ['logcat', '-b', 'crash', '-d', '-v', 'epoch,nsec', '-T', '100.000000000'], ['shell', 'service', 'list'], ['shell', 'pm', 'list', 'packages']]
+DETAILS = ['boot completed', 'system_server alive', 'crash-free since baseline', 'sidebar service registered', 'sidebar package installed']
+ERRORS = {'boot': ('boot parse failed', 'boot incomplete'), 'system_server': ('system_server parse failed', 'system_server missing'), 'boot_time': ('crash baseline parse failed', ''), 'crash': ('crash buffer parse failed', 'crash found since baseline'), 'service': ('service list parse failed', 'sidebar service missing'), 'package': ('package list parse failed', 'sidebar package missing')}
+USAGE = 'Usage: verify-sidebar.sh [--demo] [--since EPOCH] [--allow-skip]'
+SERVICE_ANCHOR = 'SERVICE = re.compile(rb"^[0-9]+[ \\t]+([^ \\t]+):[ \\t]+\\[[^][\\r\\n]+\\][ \\t]*$")'
+RUNNER_SOURCE = '''import json, os, pathlib, signal, sys
+cfg = json.loads(pathlib.Path(os.environ['VC_CONFIG']).read_text())
+a = sys.argv[1:]
+if pathlib.Path(sys.argv[0]).name == 'adb':
+    key = {'getprop':'boot','pidof':'system_server','cat':'boot_time','service':'service','pm':'package'}.get(a[3], 'crash') if a[2] == 'shell' else 'crash'
+    a = ['adb'] + a
+else: key = a[0]
+log = pathlib.Path(cfg['log']); number = len(list(log.iterdir()))
+encoded = [os.fsencode(v) for v in a]
+(log / ('%03d.json' % number)).write_text(json.dumps({'key':key,'argc':len(a),'argv':[[len(v),v.hex()] for v in encoded]}))
+if key == cfg.get('diagnostic'): sys.stderr.write('runner diagnostic\\n')
+sys.stdout.buffer.write(bytes.fromhex(cfg['values'][key]))
+if key == cfg.get('signal'): os.kill(os.getpid(), signal.SIGTERM)
+sys.exit(cfg.get('rc',7) if key == cfg.get('fail') else 0)
+'''
+def write(path, data, executable=False):
+    path.parent.mkdir(parents=True, exist_ok=True)
+    path.write_bytes(data if isinstance(data, bytes) else data.encode())
+    if executable: path.chmod(0o700)
+def cleanup(path):
+    if os.path.lexists(path): shutil.rmtree(path)
+    check(not os.path.lexists(path), 'cleanup')
+def success_summary(path):
+    check(not os.path.lexists(path), 'mutant-cleanup-before-pass')
+    sys.stdout.buffer.write(PASS)
+def embedded(source):
+    return source.split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0]
+def once(source, anchor, label):
+    check(source.count(anchor) == 1, label)
+def readiness(files):
+    for p in files:
+        check(p.is_file() and not p.is_symlink() and ROOT in p.resolve().parents, 'dependency-type')
+    check(os.access(files[0], os.X_OK), 'provider-executable')
+    hashes = [hashlib.sha256(p.read_bytes()).digest() for p in files]
+    source, doc, base = [p.read_text() for p in files]
+    for anchor in ('USAGE = "' + USAGE + '"', 'command = [runner, key.lower(), "--"] + command', '["shell", "service", "list"]', SERVICE_ANCHOR): once(source, anchor, 'provider-anchor')
+    for p in (files[0], files[2]): exact(capture(['bash', '-n', str(p)]), 0, label='dependency-syntax')
+    tree = ast.parse(embedded(source)); compile(tree, str(files[0]), 'exec')
+    parser = next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='parse')
+    check({n.value for n in ast.walk(parser) if isinstance(n,ast.Constant) and isinstance(n.value,str) and n.value.startswith('--')}=={'--demo','--since','--allow-skip','--help'},'help-parser-set')
+    calls = [n for n in ast.walk(tree) if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id == 'query']
+    calls.sort(key=lambda n:n.lineno)
+    query_keys = [ast.literal_eval(n.args[0]).lower() for n in calls]
+    check(query_keys == list(KEYS), 'provider-query-set')
+    production_args = [[ast.literal_eval(v) if isinstance(v, ast.Constant) else 'SEC.NNNNNNNNN' for v in n.args[3].elts] for n in calls]
+    wanted = [a[:] for a in ARGS]; wanted[3][-1] = 'SEC.NNNNNNNNN'
+    check(production_args == wanted, 'provider-query-set')
+    once(doc, 'Real mode issues these separated argv in order', 'doc-query-set')
+    check(re.findall(r'^\d+[.] `([^`]+)`$', doc, re.M) == [' '.join(['adb','-s','SERIAL']+a) for a in wanted], 'doc-query-set')
+    once(doc, 'Query failure\nfixtures are', 'doc-fixture-set'); once(doc, 'Value fixtures are', 'doc-fixture-set')
+    fixture_names = re.findall(r'`(DEMO_[A-Z_]+)`', doc)
+    expected_fixtures = ['DEMO_'+k.upper()+'_QUERY_FAIL' for k in KEYS] + ['DEMO_'+v for v in VALUES]
+    check(fixture_names == expected_fixtures and [ast.literal_eval(n.args[1]) for n in calls] == list(VALUES), 'doc-fixture-set')
+    check(set(re.findall(r'--[a-z-]+', USAGE)) | {'--help'} == set(re.findall(r'--[a-z-]+', doc.split('## Query transport')[0])), 'help-doc-set')
+    once(base, "printf '%s\\n' 'RESULT PASS  verifier contract'", 'base-anchor')
+    exact(capture(['bash',str(files[2])], env={'PATH':os.environ['PATH']}), 0, b'RESULT PASS  verifier contract\n', label='base-protocol')
+    return source, hashes
+
+# Expected IDs are independent of the execution table and loops below.
+EXPECTED_TEXT = '''expect_case grammar_service_ascii_tabs
+boot_empty boot_zero boot_one boot_other boot_vt boot_crlf boot_doublecr system_empty system_one system_many system_zero system_leading system_lf system_vt system_unicode system_badutf
+btime_empty btime_missing btime_one btime_many btime_tab btime_tail btime_bad btime_unicode btime_badutf btime_crlf btime_doublecr
+crash_empty crash_early crash_equal crash_late crash_nanoearly crash_nanoequal crash_header crash_leading crash_bad crash_unicode crash_badutf crash_crlf crash_doublecr
+service_empty service_target service_other service_unicode service_control service_bracket service_cr service_doublecr service_noindex service_crlf
+package_empty package_target package_other package_many package_bad package_unicode package_control package_crlf package_doublecr
+demo_default demo_skip demo_explore demo_fail_skip demo_data direct_pass direct_fail runner_diagnostic runner_signal runner_spawn serial_missing serial_slash serial_space serial_control serial_unicode serial_low serial_high
+runner_relative runner_missing runner_directory runner_symlink runner_owner runner_noexec help manifest_codec adapter_rc adapter_signal
+boot_tab boot_badutf system_crlf system_other btime_bare btime_mixed btime_leading crash_badutf_token crash_unicode_token crash_tabheader crash_vtheader service_mixed package_mixed
+since_integer since_nanobelow since_nanoequal since_nanoabove since_huge
+'''
+TABLE = r'''boot_empty|boot|parse|b''
+boot_zero|boot|business|b'0'
+boot_one|boot|pass|b'1'
+boot_other|boot|parse|b'2'
+boot_vt|boot|parse|b'\v1'
+boot_crlf|boot|pass|b'1\r\n'
+boot_doublecr|boot|parse|b'1\r\r\n'
+boot_tab|boot|pass|b' \t1\t '
+boot_badutf|boot|parse|b'\xff'
+system_empty|system_server|business|b''
+system_one|system_server|pass|b'1'
+system_many|system_server|pass|b' 1\t234 \t56\n'
+system_zero|system_server|parse|b'0'
+system_leading|system_server|parse|b'01'
+system_lf|system_server|parse|b'1\n2'
+system_vt|system_server|parse|b'1\v2'
+system_unicode|system_server|parse|b'\xd9\xa1'
+system_badutf|system_server|parse|b'\xff'
+system_crlf|system_server|pass|b'1\r\n'
+system_other|system_server|parse|b'123x'
+btime_empty|boot_time|parse|b''
+btime_missing|boot_time|parse|b'cpu 12'
+btime_one|boot_time|pass|b'btime 100'
+btime_many|boot_time|parse|b'btime 100\nbtime 100'
+btime_tab|boot_time|pass|b'btime\t100'
+btime_tail|boot_time|pass|b'btime 100 \t'
+btime_bad|boot_time|parse|b'btime 1x'
+btime_unicode|boot_time|parse|b'btime \xd9\xa1'
+btime_badutf|boot_time|parse|b'btime \xff'
+btime_crlf|boot_time|pass|b'btime 100\r\n'
+btime_doublecr|boot_time|parse|b'btime 100\r\r\n'
+btime_bare|boot_time|parse|b'btime'
+btime_mixed|boot_time|parse|b'btime 100\nbtime nope'
+btime_leading|boot_time|parse|b' btime 100'
+crash_empty|crash|pass|b''
+crash_early|crash|pass|b'99.999999999 x'
+crash_equal|crash|business|b'100 x'
+crash_late|crash|business|b'101 x'
+crash_nanoearly|crash|pass|b'99.999999999\tx'
+crash_nanoequal|crash|business|b'100.000000000 x'
+crash_header|crash|pass|b'--------- header\n'
+crash_leading|crash|pass|b' 100 x\n\t101 x'
+crash_bad|crash|parse|b'100.1234567890 x'
+crash_unicode|crash|pass|b'\xd9\xa1 x'
+crash_badutf|crash|pass|b'\xff x'
+crash_crlf|crash|business|b'100 x\r\n'
+crash_doublecr|crash|parse|b'100\r\r\n'
+crash_badutf_token|crash|parse|b'100\xff x'
+crash_unicode_token|crash|parse|b'100\xd9\xa1 x'
+crash_tabheader|crash|pass|b'\t100 x'
+crash_vtheader|crash|pass|b'\v100 x'
+service_empty|service|business|b''
+service_target|service|pass|b'1 sidebar: [x]'
+service_other|service|business|b'1 sidebar2: [x]'
+service_unicode|service|parse|b'1\xc2\xa0sidebar: [x]'
+service_control|service|parse|b'1\vsidebar: [x]'
+service_bracket|service|parse|b'1 sidebar: [[x]]'
+service_cr|service|parse|b'1 sidebar: [x\r]'
+service_doublecr|service|parse|b'1 sidebar: [x]\r\r\n'
+service_noindex|service|parse|b' sidebar: [x]'
+service_crlf|service|pass|b'1 sidebar: [x]\r\n'
+service_mixed|service|parse|b'1 sidebar: [x]\nbad'
+package_empty|package|skip|b''
+package_target|package|pass|b'package:com.android.sidebar'
+package_other|package|skip|b'package:com.android.other'
+package_many|package|pass|b'package:com.example.a\npackage:com.android.sidebar\n'
+package_bad|package|parse|b'package:1com.android.sidebar'
+package_unicode|package|parse|b'package:com.\xd9\xa1'
+package_control|package|parse|b'package:com.android.sidebar\v'
+package_crlf|package|pass|b'package:com.android.sidebar\r\n'
+package_doublecr|package|parse|b'package:com.android.sidebar\r\r\n'
+package_mixed|package|parse|b'package:com.android.sidebar\nbad'
+run_case grammar_service_ascii_tabs|service|pass|b'1\tsidebar:\t[x]\t'
+'''
+def main():
+    check(sys.argv[3:] in ([], ['all'], ['--dependency-absent']), 'args')
+    info = TMP.lstat()
+    check(stat.S_ISDIR(info.st_mode) and not TMP.is_symlink() and info.st_uid == os.geteuid() and stat.S_IMODE(info.st_mode) == 0o700 and not list(TMP.iterdir()) and ROOT not in TMP.resolve().parents and TMP.resolve() != ROOT, 'temp')
+    files = [ROOT / p for p in PATHS]
+    if not any(os.path.lexists(p) for p in files): cleanup(TMP); success_summary(TMP); return
+    check(sys.argv[3:] != ['--dependency-absent'], 'dependency-present')
+    source, hashes = readiness(files)
+    expected = EXPECTED_TEXT.replace('expect_case ', '').split()
+    for prefix, count in [('cli',23),('since',9),('query',6),('service_ascii',80),('surface',41)]: expected += [prefix+'_'+str(i) for i in range(count)]
+    check(len(expected) == len(set(expected)), 'expected-duplicate')
+    write(TMP/'expected', '\n'.join(sorted(expected))+'\n'); executed = []
+    def record(name):
+        check(name not in executed, 'case-duplicate'); executed.append(name)
+        with (TMP/'executed').open('a') as f: f.write(name+' PASS\n')
+    runner = TMP/'runner'; write(runner, '#!'+sys.executable+'\n'+RUNNER_SOURCE, True)
+    write(TMP/'bin/adb', runner.read_bytes(), True)
+    defaults = dict(zip(KEYS, [b'1',b'1423',b'btime 100',b'',b'42 sidebar: [x]',b'package:com.android.sidebar']))
+    def run_case(name, key='', value=b'', outcome='pass', args=(), mode='runner', serial='A._:-9', invalid=None, fail='', sig='', diagnostic='', override=None, demo=None, label=None):
+        label = label or name; values = defaults.copy()
+        if key: values[key] = value
+        log = TMP/'log'; cleanup(log); log.mkdir()
+        cfg = {'values':{k:v.hex() for k,v in values.items()},'log':str(log),'fail':fail,'signal':sig,'diagnostic':diagnostic}
+        write(TMP/'config', json.dumps(cfg))
+        env = {'PATH':str(TMP/'bin')+':'+os.environ['PATH'], 'VC_CONFIG':str(TMP/'config'), 'ANDROID_SERIAL':serial}
+        if mode != 'direct': env['HARNESS_VERIFIER_QUERY_RUNNER'] = str(runner if invalid is None else invalid)
+        if demo: env.update(demo)
+        result = capture(['bash',str(override or files[0]),*args], env)
+        write(TMP/'stdout', result.stdout); write(TMP/'stderr', result.stderr)
+        actual = [json.loads(p.read_text()) for p in sorted(log.iterdir())]
+        normalized = '100.000000000'
+        if '--since' in args:
+            s = args[args.index('--since')+1].split('.'); normalized = str(int(s[0]))+'.'+(s[1] if len(s)>1 else '').ljust(9,'0')
+        selected = [k for k in KEYS if not (k=='boot_time' and '--since' in args) and not (k=='crash' and (key=='boot_time' and outcome!='pass' or fail=='boot_time'))]
+        if '--demo' in args: selected=[]
+        wanted=[]
+        for k in selected:
+            a=ARGS[KEYS.index(k)][:]
+            if k=='crash': a[-1]=normalized
+            a=['adb','-s',serial]+a
+            if mode!='direct': a=[k,'--']+a
+            raw=[os.fsencode(v) for v in a]; wanted.append({'key':k,'argc':len(a),'argv':[[len(v),v.hex()] for v in raw]})
+        statuses=['PASS']*5; details=DETAILS[:]
+        if key and outcome!='pass':
+            i=[0,1,2,2,3,4][KEYS.index(key)]; statuses[i]='SKIP' if outcome=='skip' else 'FAIL'; details[i]=ERRORS[key][0 if outcome=='parse' else 1]
+        for k in (fail,sig):
+            if k:
+                i=[0,1,2,2,3,4][KEYS.index(k)]; statuses[i]='FAIL'; details[i]=('crash baseline' if k=='boot_time' else k)+' query failed'
+        if demo and 'DEMO_BOOT_QUERY_FAIL' in demo: statuses[0]='FAIL'; details[0]='boot query failed'
+        if mode=='spawn':
+            statuses=['FAIL']*5; details=['boot query failed','system_server query failed','crash baseline query failed','service query failed','package query failed']; wanted=[]
+        counts=[statuses.count(s) for s in ('PASS','FAIL','SKIP')]; code=1 if counts[1] else (2 if counts[2] and '--allow-skip' not in args else 0)
+        terminal='RESULT FAIL' if code==1 else ('RESULT INCOMPLETE' if code==2 else 'RESULT PASS'+(' (SKIP allowed)' if counts[2] else ''))
+        out='\n'.join([s+'  '+d for s,d in zip(statuses,details)]+['SUMMARY PASS=%d FAIL=%d SKIP=%d'%tuple(counts),terminal])+'\n'
+        err=b'query runner execution failed\n'*5 if mode=='spawn' else (b'runner diagnostic\n' if diagnostic and mode!='direct' else b'')
+        check(actual==wanted, label); exact(result,code,out.encode(),err,label); record(name)
+    for row in TABLE.strip().splitlines():
+        name,key,outcome,value=(row[9:] if row.startswith('run_case ') else row).split('|',3); run_case(name,key,ast.literal_eval(value),outcome)
+    for i,spaces in enumerate(itertools.product((' ','\t',' \t','\t '),(' ','\t',' \t','\t '),('',' ','\t',' \t','\t '))): run_case('service_ascii_'+str(i),'service',('1'+spaces[0]+'sidebar:'+spaces[1]+'[x]'+spaces[2]).encode())
+    for i in range(9): run_case('since_'+str(i),args=('--since','1.'+'2'*(i+1)))
+    run_case('since_integer',args=('--since','0001'))
+    for name,value,outcome in [('below',b'1.199999999 x','pass'),('equal',b'1.2 x','business'),('above',b'1.200000001 x','business')]: run_case('since_nano'+name,'crash',value,outcome,args=('--since','1.2'))
+    run_case('since_huge','crash',b'999999999999999999999999999999.9 x','pass',args=('--since','1000000000000000000000000000000'))
+    for i,k in enumerate(KEYS): run_case('query_'+str(i),fail=k,diagnostic=k)
+    for name,kw in [('direct_pass',{'mode':'direct','diagnostic':'boot'}),('direct_fail',{'mode':'direct','fail':'boot','diagnostic':'boot'}),('runner_diagnostic',{'diagnostic':'service'}),('runner_signal',{'sig':'boot'}),('serial_low',{'serial':'0'}),('serial_high',{'serial':'Z._:-9'})]: run_case(name,**kw)
+    spawn=TMP/'spawn'; write(spawn,'#!/no/such/interpreter\n',True); run_case('runner_spawn',mode='spawn',invalid=spawn)
+    def preflight(name, args=(), serial='0', invalid=None, rc=2, out=b'', err=None):
+        log=TMP/'log'; cleanup(log); log.mkdir()
+        env={'PATH':os.environ['PATH'],'ANDROID_SERIAL':serial,'HARNESS_VERIFIER_QUERY_RUNNER':str(invalid or runner),'VC_CONFIG':str(TMP/'config')}
+        if serial is None: env.pop('ANDROID_SERIAL')
+        p=capture(['bash',str(files[0]),*args],env)
+        exact(p,rc,out,err if err is not None else (USAGE+'\n').encode(),name); check(not list(log.iterdir()),name); record(name)
+    badcli=[['--demo','--demo'],['--allow-skip','--allow-skip'],['--since','1','--since','2'],['--since'],['--since','1','extra'],*([ '--since',v] for v in ('','-1','+1','.1','1.','1.1234567890','١',os.fsdecode(b'\xff'))),['--wat'],['positional'],['--help','--demo'],['--help','--allow-skip'],['--help','--since','1'],['--demo','--help'],['--help','--help'],['--since','0','--help'],['--demo','--since'],['--allow-skip']]
+    for i,a in enumerate(badcli): preflight('cli_'+str(i),a,err=b'error: --allow-skip requires --demo\n' if a==['--allow-skip'] else None)
+    for name,value in [('missing',None),('slash','a/b'),('space','a b'),('control','a\tb'),('unicode','设备')]: preflight('serial_'+name,serial=value,err=b'error: set ANDROID_SERIAL to a safe, explicit target serial\n')
+    noexec=TMP/'noexec'; write(noexec,'x'); link=TMP/'link'; link.symlink_to(runner)
+    foreign=pathlib.Path('/usr/bin/true'); check(foreign.stat().st_uid!=os.geteuid(),'foreign-fixture')
+    for name,path in [('relative','relative'),('missing',TMP/'absent'),('directory',TMP),('symlink',link),('owner',foreign),('noexec',noexec)]: preflight('runner_'+name,invalid=path,err=b'error: invalid query runner\n')
+    preflight('help',['--help'],rc=0,out=(USAGE+'\n').encode(),err=b'')
+    for name,args,key,outcome,demo in [('demo_default',('--demo',),'','pass',{}),('demo_skip',('--demo',),'package','skip',{'DEMO_PACKAGE_LIST':''}),('demo_explore',('--demo','--allow-skip'),'package','skip',{'DEMO_PACKAGE_LIST':''}),('demo_fail_skip',('--demo','--allow-skip'),'package','skip',{'DEMO_PACKAGE_LIST':'','DEMO_BOOT_QUERY_FAIL':'7'}),('demo_data',('--demo',),'service','parse',{'DEMO_SERVICE_LIST':'$(touch '+str(TMP/'injected')+')'})]: run_case(name,key,b'',outcome,args=args,demo=demo)
+    check(not (TMP/'injected').exists(),'fixture-executed')
+    log=TMP/'log'; cleanup(log); log.mkdir()
+    raw=[b'boot',b'--',b'adb',b'-s',b'0',b'',b' ',b'\t',b'a b\t',b'\xff']
+    exact(capture([str(runner),*[os.fsdecode(v) for v in raw]],{'VC_CONFIG':str(TMP/'config')}),0,b'1',label='manifest-codec')
+    check(json.loads((log/'000.json').read_text())=={'key':'boot','argc':10,'argv':[[len(v),v.hex()] for v in raw]},'manifest-codec'); record('manifest_codec')
+    query=next(n for n in ast.parse(embedded(source)).body if isinstance(n,ast.FunctionDef) and n.name=='query')
+    ns={'demo':False,'runner':str(runner),'serial':'0','subprocess':subprocess,'sys':sys}; exec(compile(ast.Module(body=[query],type_ignores=[]),'<query>','exec'),ns)
+    for name,field,wanted in [('adapter_rc','fail',7),('adapter_signal','signal',143)]:
+        cfg=json.loads((TMP/'config').read_text()); cfg.update(fail='',signal='',diagnostic=''); cfg[field]='boot'; write(TMP/'config',json.dumps(cfg)); os.environ['VC_CONFIG']=str(TMP/'config')
+        check(ns['query']('BOOT','BOOT_COMPLETED','1',ARGS[0])[0]==wanted,name); record(name)
+    def layout(name):
+        root=TMP/name
+        for relative,p in zip(PATHS,files): write(root/relative,p.read_bytes(),relative.endswith('.sh'))
+        write(root/'tests/test-verifier-contract-assurance.sh',SELF.read_bytes(),True); return root
+    for i in range(41):
+        root=layout('surface'); targets=[root/p for p in PATHS]; argv=[]
+        if i<3:
+            for p in targets: p.unlink()
+            argv=[[],['all'],['--dependency-absent']][i]
+        elif i<6: targets[i-3].unlink()
+        elif i<9: p=targets[i-6]; p.unlink(); p.mkdir()
+        elif i<12: p=targets[i-9]; p.unlink(); p.symlink_to(files[i-9])
+        elif i==12: write(targets[0],targets[0].read_bytes().replace(b'import os',b'import (',1),True)
+        elif i==13: write(targets[0],targets[0].read_bytes().replace(b'USAGE =',b'OLD_USAGE =',1),True)
+        elif i==14: write(targets[1],targets[1].read_bytes().replace(b'service list`',b'service listx`',1))
+        elif i==15: write(targets[2],targets[2].read_bytes()+b'\nexit 1\n',True)
+        elif i==16: write(targets[2],targets[2].read_bytes().replace(b'RESULT PASS  verifier contract',b'WRONG',1),True)
+        elif i==17: targets[0].chmod(0o600)
+        elif i==18: argv=['--dependency-absent']
+        elif i<22: p=targets[i-19]; p.unlink(); os.mkfifo(p)
+        elif i<25: p=targets[i-22]; p.unlink(); p.symlink_to(root/'missing')
+        elif i==25: write(targets[0],targets[0].read_bytes().replace(('USAGE = "'+USAGE+'"').encode(),(('USAGE = "'+USAGE+'"\n')*2).encode(),1),True)
+        elif i==26: write(targets[1],targets[1].read_bytes()+b'\nQuery failure\nfixtures are\n')
+        elif i==27: write(targets[2],targets[2].read_bytes()+b"\nprintf '%s\\n' 'RESULT PASS  verifier contract'\n",True)
+        elif i==28: write(targets[2],b'(\n'+targets[2].read_bytes(),True)
+        elif i==29: write(targets[0],targets[0].read_bytes().replace(b'print("RESULT PASS"',b'print("WRONG"',1),True)
+        elif i<36: argv=[['unknown'],['all','extra'],['all','all'],['--dependency-absent','extra'],['--dependency-absent=1'],['--demo']][i-30]
+        elif i<39:
+            for j,p in enumerate(targets):
+                if j!=i-36: p.unlink()
+        elif i==39: write(targets[1],targets[1].read_bytes().replace(b'DEMO_BOOT_COMPLETED',b'DEMO_WRONG',1))
+        else: write(targets[2],targets[2].read_bytes()+b'\necho WRONG\n',True)
+        p=capture(['bash',str(root/'tests/test-verifier-contract-assurance.sh'),*argv])
+        if i<3: exact(p,0,PASS,label='surface-absent')
+        else: check(p.returncode==1 and PASS not in p.stdout,'surface-damaged')
+        record('surface_'+str(i)); cleanup(root)
+    check(sorted(executed)==sorted(expected),'mutant-case-manifest')
+    manifest=[line.split() for line in (TMP/'executed').read_text().splitlines()]
+    check(all(len(row)==2 and row[1]=='PASS' for row in manifest) and sorted(row[0] for row in manifest)==sorted(expected),'mutant-case-manifest')
+    check((TMP/'expected').read_text()=='\n'.join(sorted(executed))+'\n','mutant-case-manifest')
+    if os.environ.get('VC_ASSURANCE_CHILD') != '1':
+        def mutated(text,old,new):
+            once(text,old,'mutant-anchor'); check(old!=new,'mutant-change'); return text.replace(old,new,1)
+        for name,old,new,key,value in [('mutant-argv-service','["shell", "service", "list"]','["shell", "service", "listx"]','service',b'1 sidebar: [x]'),('mutant-service-grammar',SERVICE_ANCHOR,SERVICE_ANCHOR.replace('+','*',1),'service',b' sidebar: [x]')]:
+            copy=TMP/'provider-mutant'; write(copy,mutated(source,old,new),True); exact(capture(['bash','-n',str(copy)]),0,label='mutant-syntax'); compile(embedded(copy.read_text()),str(copy),'exec')
+            try: run_case(name,key,value,'parse' if 'grammar' in name else 'pass',override=copy,label=name)
+            except Failure as e: check(str(e)==name,'mutant-label')
+            else: raise Failure('mutant-survived')
+        for kind in ('case','cleanup'):
+            root=layout('mutant'); target=root/'tests/test-verifier-contract-assurance.sh'; text=target.read_text()
+            old=next(l+'\n' for l in text.splitlines() if l.startswith('run_'+'case grammar_service_ascii_tabs')) if kind=='case' else '    cleanup(TMP)  # cleanup_success_'+'before_summary\n    success_summary(TMP)\n'
+            new='' if kind=='case' else '    success_summary(TMP)\n    cleanup(TMP)  # cleanup_success_'+'before_summary\n'
+            write(target,mutated(text,old,new),True); exact(capture(['bash','-n',str(target)]),0,label='mutant-syntax'); compile(embedded(target.read_text()),str(target),'exec')
+            child=TMP/('child-'+kind); child.mkdir(mode=0o700)
+            code="import pathlib,sys; s=pathlib.Path(sys.argv[1]).read_text(); exec(compile(s.split(\"<<'PY'\\n\",1)[1].rsplit('\\nPY',1)[0],sys.argv[1],'exec'),{'_child':True})"
+            child_env=os.environ.copy(); child_env['VC_ASSURANCE_CHILD']='1'
+            p=capture([sys.executable,'-c',code,str(target),str(child)],child_env)
+            exact(p,1,b'',('FAIL mutant-'+('case-manifest' if kind=='case' else 'cleanup-before-pass')+'\n').encode(),'mutant-self'); cleanup(root)
+    check(hashes==[hashlib.sha256(p.read_bytes()).digest() for p in files],'dependency-hash')
+    cleanup(TMP)  # cleanup_success_before_summary
+    success_summary(TMP)
+try:
+    main()
+except Exception as exc:
+    try: cleanup(TMP)
+    except Exception: exc=Failure('cleanup')
+    print('FAIL '+(str(exc) if isinstance(exc,Failure) else type(exc).__name__),file=sys.stderr)
+    sys.exit(1)
+PY
```
