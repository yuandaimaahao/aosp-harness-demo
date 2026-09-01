# review 包 7b9a0bb9..7b09181c

## commit 列表

```
7b09181 ci: add pinned quality workflow
```

## diff --stat

```
 .github/workflows/quality.yml | 26 ++++++++++++++++++++++++++
 tests/COVERAGE.md             |  4 ++++
 tests/test-quality-gate.sh    | 30 ++++++++++++++++++++++++++++++
 3 files changed, 60 insertions(+)
```

## diff

```diff
diff --git a/.github/workflows/quality.yml b/.github/workflows/quality.yml
new file mode 100644
index 0000000..e19d978
--- /dev/null
+++ b/.github/workflows/quality.yml
@@ -0,0 +1,26 @@
+name: Quality
+on: [push, pull_request, workflow_dispatch]
+jobs:
+  quality:
+    runs-on: ubuntu-24.04
+    steps:
+      - uses: actions/checkout@v4
+      - name: Install pinned quality tools
+        run: |
+          set -euo pipefail
+          root="$RUNNER_TEMP/aosp-harness-quality"; bin="$root/bin"
+          mkdir -p "$root/downloads" "$bin"
+          curl -fsSL -o "$root/downloads/shellcheck.tar.xz" https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.xz
+          printf '%s  %s\n' 8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198 "$root/downloads/shellcheck.tar.xz" | sha256sum -c -
+          tar -xJf "$root/downloads/shellcheck.tar.xz" -C "$root"
+          install -m 0755 "$root/shellcheck-v0.11.0/shellcheck" "$bin/shellcheck"
+          curl -fsSL -o "$root/downloads/shfmt" https://github.com/mvdan/sh/releases/download/v3.14.0/shfmt_v3.14.0_linux_amd64
+          printf '%s  %s\n' fe42021c7272ef2d67ea36cbc3031683c625d0badec733ef3a57b567246a0b66 "$root/downloads/shfmt" | sha256sum -c -
+          install -m 0755 "$root/downloads/shfmt" "$bin/shfmt"
+          curl -fsSL -o "$root/downloads/gitleaks.tar.gz" https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
+          printf '%s  %s\n' 551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb "$root/downloads/gitleaks.tar.gz" | sha256sum -c -
+          tar -xzf "$root/downloads/gitleaks.tar.gz" -C "$root"
+          install -m 0755 "$root/gitleaks" "$bin/gitleaks"
+          printf '%s\n' "$bin" >>"$GITHUB_PATH"
+      - name: Quality gate
+        run: ./scripts/check.sh --ci
diff --git a/tests/COVERAGE.md b/tests/COVERAGE.md
new file mode 100644
index 0000000..bee2dd1
--- /dev/null
+++ b/tests/COVERAGE.md
@@ -0,0 +1,4 @@
+| Test | Specs/requirements | Protected behavior | Offline boundary | Status |
+|---|---|---|---|---|
+| `tests/test-device-safety.sh` | 01 R1-R7 | Device targeting and legacy regressions | Fake ADB only | active |
+| `tests/test-quality-gate.sh` | 02 R1-R9 | Offline/CI quality-gate contract | Fixture and fake tools only | active |
diff --git a/tests/test-quality-gate.sh b/tests/test-quality-gate.sh
index 8ce871d..1601d5f 100755
--- a/tests/test-quality-gate.sh
+++ b/tests/test-quality-gate.sh
@@ -102,17 +102,47 @@ for mutation in "${mutations[@]}"; do cp "$baseline" "$static_fixture/scripts/sh
   wrong-digest) sed -i '1s/[0-9a-f]$/0/' "$static_fixture/scripts/shell-quality-baseline.tsv";; duplicate) head -n 1 "$baseline" >>"$static_fixture/scripts/shell-quality-baseline.tsv";;
   unsorted) sed -i '1{h;d};2{G}' "$static_fixture/scripts/shell-quality-baseline.tsv";; malformed) printf 'bad\n' >>"$static_fixture/scripts/shell-quality-baseline.tsv";; esac
   case "$mutation" in append-current) [[ "$(wc -l <"$static_fixture/scripts/shell-quality-baseline.tsv")" -eq 31 ]] || fail 'baseline append-current: expected row 31';; non-anchor) baseline_valid "$static_fixture/scripts/shell-quality-baseline.tsv" || fail 'baseline non-anchor: fixture format';; esac
   run_static; [[ "$static_rc" -eq 2 ]] || fail "baseline $mutation: expected rc=2"
   assert_calls protocol || fail "baseline $mutation: tools called"; done
 reset_secrets() { cp "$config" "$static_fixture/.gitleaks.toml"; cp "$repo_root/scripts/check.sh" "$baseline" "$static_fixture/scripts/"; }
 for mutation in config-bytes config-digest empty-rules global-allowlist; do reset_secrets; case "$mutation" in config-bytes) printf '# changed\n' >>"$static_fixture/.gitleaks.toml";; config-digest) sed -i "s/$config_sha/$(printf '0%.0s' {1..64})/" "$static_fixture/scripts/check.sh";; empty-rules) : >"$static_fixture/.gitleaks.toml";; global-allowlist) printf '[allowlist]\npaths = [".*"]\n' >"$static_fixture/.gitleaks.toml";; esac; run_static; [[ "$static_rc" -eq 2 && ! -s "$static_logs/gitleaks" ]] && no_total_pass || fail "$mutation: expected config rc=2 without total pass"; done
 reset_secrets; for canary_rc in 0 2; do run_static '' "$canary_rc"; [[ "$static_rc" -eq 2 && "$(grep -ao 'GITLEAKS_CONFIG=unset' "$static_logs/gitleaks" | wc -l)" -eq 1 ]] && no_total_pass || fail "canary rc $canary_rc: expected protocol failure without total pass"; done
 mkdir "$static_fixture/in-repo-tmp"; run_static '' 1 0 "$static_fixture/in-repo-tmp"; [[ "$static_rc" -eq 2 && ! -s "$static_logs/gitleaks" ]] && no_total_pass || fail 'in-repo TMPDIR: expected zero gitleaks calls without total pass'
 run_static '' 1 7; [[ "$static_rc" -eq 1 ]] && assert_gitleaks && no_total_pass || fail 'worktree gitleaks failure: expected rc=1 without total pass'
+quality_docs_oracle() { "$host_python" - "$1" "$2" <<'PY'
+import os,re,sys
+from pathlib import Path
+w='\n'.join(x for x in Path(sys.argv[1]).read_text().splitlines() if not x.lstrip().startswith('#'))
+assert 'on: [push, pull_request, workflow_dispatch]' in w and 'runs-on: ubuntu-24.04' in w
+assert 'root="$RUNNER_TEMP/aosp-harness-quality"; bin="$root/bin"' in w
+maps=(
+('curl -fsSL -o "$root/downloads/shellcheck.tar.xz" https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.xz','8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198','tar -xJf "$root/downloads/shellcheck.tar.xz" -C "$root"','install -m 0755 "$root/shellcheck-v0.11.0/shellcheck" "$bin/shellcheck"'),
+('curl -fsSL -o "$root/downloads/shfmt" https://github.com/mvdan/sh/releases/download/v3.14.0/shfmt_v3.14.0_linux_amd64','fe42021c7272ef2d67ea36cbc3031683c625d0badec733ef3a57b567246a0b66','install -m 0755 "$root/downloads/shfmt" "$bin/shfmt"'),
+('curl -fsSL -o "$root/downloads/gitleaks.tar.gz" https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz','551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb','tar -xzf "$root/downloads/gitleaks.tar.gz" -C "$root"','install -m 0755 "$root/gitleaks" "$bin/gitleaks"'))
+install_positions=[]
+for mapping in maps:
+ positions=[w.index(value) for value in mapping]; assert positions==sorted(positions),mapping
+ install_positions.append(positions[-1])
+path_at=w.index('printf \'%s\\n\' "$bin" >>"$GITHUB_PATH"'); assert max(install_positions)<path_at
+assert w.count('./scripts/check.sh --ci')==1
+assert re.search(r'- name: Quality gate\n\s+run: \./scripts/check\.sh --ci',w)
+c=Path(sys.argv[2]).read_text(); rows=[]
+assert '| Test | Specs/requirements | Protected behavior | Offline boundary | Status |' in c
+for line in c.splitlines():
+ cells=[cell.strip() for cell in line.strip().strip('|').split('|')]
+ if not line.startswith('|') or cells[0] in ('Test','---'): continue
+ assert len(cells)==5 and all(cells) and cells[4]=='active',cells
+ match=re.fullmatch(r'`(tests/test-[^`]+\.sh)`',cells[0]); assert match; rows.append(match.group(1))
+expected={'tests/'+entry.name for entry in os.scandir('tests') if entry.is_file(follow_symlinks=False) and entry.name.startswith('test-') and entry.name.endswith('.sh')}
+assert len(rows)==len(set(rows)) and set(rows)==expected,(rows,expected)
+assert not re.search(r'(行|分支|line|branch|覆盖率|coverage)[^|\n]{0,20}\d+(?:\.\d+)?%?',c,re.I)
+PY
+}
+quality_docs_oracle "$repo_root/.github/workflows/quality.yml" "$repo_root/tests/COVERAGE.md" || fail 'workflow quality contract'
 poison_log="$fixture/poison"; for name in shellcheck shfmt gitleaks adb cvd curl wget ssh repo ninja claude codex; do printf '#!%s\nprintf %s >>%q\nexit 88\n' "$host_bash" "$name" "$poison_log" >"$case_bin/$name"; chmod +x "$case_bin/$name"; done
 before="$("$host_git" hash-object claude-code/CURRENT_FEATURE codex/CURRENT_FEATURE common/CURRENT_FEATURE)"; PATH="$case_bin:$PATH" HOST_BASH="$host_bash" SYNTAX_MARKER="$syntax_marker" ROOT_LOG="$root_log" BODY_LOG="$body_log" GIT_ALLOW_PROTOCOL=file "$host_python" - "$repo_root" "$host_bash" <<'PY'
 import os,subprocess,sys
 r=subprocess.run([sys.argv[2],'./scripts/check.sh','--offline'],cwd=sys.argv[1],env=os.environ.copy(),text=True,capture_output=True,timeout=30); assert r.returncode==0 and r.stdout.count('RESULT PASS  offline quality gate child')==1,(r.stdout,r.stderr)
 PY
 [[ ! -s "$poison_log" && "$before" == "$("$host_git" hash-object claude-code/CURRENT_FEATURE codex/CURRENT_FEATURE common/CURRENT_FEATURE)" ]] || fail 'real offline boundary'
 printf 'RESULT PASS  offline quality gate contract\n'
```
