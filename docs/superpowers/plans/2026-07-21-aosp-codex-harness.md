# AOSP Codex Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the existing Claude Code demo under `claude-code/` and add a from-scratch, runnable Codex three-layer AOSP harness demo plus a complete Chinese article under `codex/`.

**Architecture:** A startup wrapper selects a feature-specific root `AGENTS.md` before Codex starts, repository skills under `.agents/skills/` provide on-demand build workflows, and a deterministic feature script closes the build/deploy/verify loop. Codex hooks snapshot the feature per session and stop turns after branch drift; the teaching flow never launches Codex or requires AOSP/ADB.

**Tech Stack:** Bash 4+, Python 3 standard library for JSON parsing, Git, Codex `AGENTS.md`, repository skills, Codex command hooks, Markdown.

---

## File Map

- `README.md`: routes readers to both demos.
- `claude-code/**`: the mechanically relocated current demo.
- `codex/README.md`: runnable Codex demo guide.
- `codex/AOSP整机源码Codex-Harness工程探索.md`: long-form article.
- `codex/.codex/bin/codex-feature`: fail-closed feature selection and startup.
- `codex/.codex/bin/check-process-layer`: offline skill validation.
- `codex/.codex/hooks.json`: lifecycle hook registration.
- `codex/.codex/hooks/*.sh`: feature helpers, session snapshot, drift blocker.
- `codex/.agents/skills/**`: services and SELinux build workflows.
- `codex/features/dev-sidebar/**`: feature guidance, repository set, and verifier.
- `codex/run-demo.sh`: one-command demonstration.
- `codex/tests/test-harness.sh`: regression suite.

### Task 1: Relocate the Claude Code demo

**Files:**
- Create: `README.md`
- Move: `.claude/**`, `CLAUDE.md`, `CURRENT_FEATURE`, `features/**`, `frameworks/**`, `run-demo.sh`, `tests/**`, `.gitignore`, and current `README.md` under `claude-code/`

- [ ] **Step 1: Record the baseline**

Run `./tests/test-harness.sh`.

Expected: `PASS  demo harness startup, process layer, and strict verification`.

- [ ] **Step 2: Move only tracked demo files**

Use `git mv`. Do not move or delete `demo-out/`, `docs/`, or `.git/`. Create
the new root `README.md` with:

```markdown
# AOSP 整机源码 Harness Demo

本仓库包含两套彼此独立的 AOSP 整机源码 Harness 教学 Demo：

- [`claude-code/`](claude-code/)：Claude Code 版本。
- [`codex/`](codex/)：Codex 版本，包含可运行示例和完整探索文档。

两套 Demo 都不依赖真实 AOSP 源码树或 Android 设备。
```

- [ ] **Step 3: Verify the relocation**

Run:

```bash
./claude-code/tests/test-harness.sh
./claude-code/run-demo.sh
```

Expected: both exit `0`; the demo ends with `三层演示完毕`.

- [ ] **Step 4: Commit**

```bash
git add README.md claude-code
git commit -m "refactor: move Claude Code demo into subdirectory"
```

### Task 2: Build the Codex context-selection layer

**Files:**
- Create: `codex/CURRENT_FEATURE`
- Create: `codex/AGENTS.md` as a relative symlink
- Create: `codex/.codex/bin/codex-feature`
- Create: `codex/.codex/hooks/feature-common.sh`
- Create: `codex/features/dev-sidebar/{AGENTS.md,repos.tsv,check-branch.sh}`
- Create: `codex/frameworks/{base/PLACEHOLDER.java,native/PLACEHOLDER.cpp}`
- Create: `codex/tests/test-harness.sh`

- [ ] **Step 1: Write failing wrapper tests**

Start `codex/tests/test-harness.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/features/dev-test"
printf '%s\n' dev-test > "$FIXTURE/CURRENT_FEATURE"
printf '%s\n' '# feature: dev-test' > "$FIXTURE/features/dev-test/AGENTS.md"

HARNESS_ROOT="$FIXTURE" "$ROOT/.codex/bin/codex-feature" --dry-run >/dev/null
test -L "$FIXTURE/AGENTS.md"
test "$(readlink "$FIXTURE/AGENTS.md")" = features/dev-test/AGENTS.md

rm "$FIXTURE/AGENTS.md"
printf '%s\n' protected > "$FIXTURE/AGENTS.md"
set +e
output="$(HARNESS_ROOT="$FIXTURE" "$ROOT/.codex/bin/codex-feature" --dry-run 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
test "$(cat "$FIXTURE/AGENTS.md")" = protected
grep -Fq '普通文件' <<<"$output"

rm "$FIXTURE/AGENTS.md"
printf '%s\n' missing-feature > "$FIXTURE/CURRENT_FEATURE"
set +e
output="$(HARNESS_ROOT="$FIXTURE" "$ROOT/.codex/bin/codex-feature" --dry-run 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
test ! -e "$FIXTURE/AGENTS.md"
grep -Fq 'features/missing-feature/AGENTS.md' <<<"$output"
```

- [ ] **Step 2: Run the test to verify it fails**

Run `bash codex/tests/test-harness.sh`.

Expected: FAIL because `codex-feature` does not exist.

- [ ] **Step 3: Implement safe feature selection**

Create `feature-common.sh` with:

```bash
detect_feature() {
  local root="$1" repo candidate
  for repo in frameworks/base frameworks/native frameworks/av system/core; do
    [[ -e "$root/$repo/.git" ]] || continue
    candidate="$(git -C "$root/$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then printf '%s\n' "$candidate"; return 0; fi
  done
  [[ -f "$root/CURRENT_FEATURE" ]] || return 1
  tr -d '[:space:]' < "$root/CURRENT_FEATURE"
}

feature_context_path() {
  local root="$1" feature="$2" target="features/$feature/AGENTS.md"
  [[ -n "$feature" && -f "$root/$target" ]] || return 1
  printf '%s\n' "$target"
}

sync_feature_link() {
  local root="$1" target="$2" link="$root/AGENTS.md"
  if [[ -e "$link" && ! -L "$link" ]]; then
    printf 'error: %s 是普通文件，拒绝覆盖。\n' "$link" >&2
    return 1
  fi
  [[ -L "$link" && "$(readlink "$link")" == "$target" ]] && return 0
  ln -sfn "$target" "$link"
}
```

Implement `codex-feature` to resolve `HARNESS_ROOT`, detect the feature, resolve
its `AGENTS.md`, run the feature's checker when `.repo/` exists, switch the link
only after all checks pass, return for `--dry-run`, and otherwise:

```bash
cd "$ROOT"
exec codex "$@"
```

- [ ] **Step 4: Add the demo feature**

Set `CURRENT_FEATURE` to `dev-sidebar`. In `repos.tsv`, list
`frameworks/base`, `frameworks/native`, `packages/apps/SidebarApp`,
`build/make`, and `system/sepolicy` on `dev-sidebar`. Implement
`check-branch.sh` to report `MISSING` and `DRIFT`, plus a `--demo` sample with
one deliberate drift.

The feature `AGENTS.md` must include:

```markdown
- 修改 `frameworks/base/services/**` 前必须使用 `$build-services-jar`。
- 修改 `system/sepolicy/**` 前必须使用 `$build-sepolicy`。
- 收工前必须运行 `./features/dev-sidebar/verify-sidebar.sh`；只有 `RESULT PASS` 可以作为完成证据。
```

Also include bash/envsetup, no-generated-output, `rg` navigation, allowed-repo,
subagent task-card, API-update, SELinux, and ART-cache rules.

- [ ] **Step 5: Run tests and commit**

Run `bash codex/tests/test-harness.sh`; expected PASS. Then:

```bash
git add codex
git commit -m "feat(codex): add feature context selection"
```

### Task 3: Add session hooks and drift blocking

**Files:**
- Create: `codex/.codex/hooks.json`
- Create: `codex/.codex/hooks/{session-start.sh,check-branch-drift.sh}`
- Modify: `codex/tests/test-harness.sh`

- [ ] **Step 1: Append failing hook tests**

Parse `hooks.json` with Python. Invoke SessionStart with `session-a` and
`session-b` and assert separate snapshot files. Assert no output without drift.
After changing `CURRENT_FEATURE`, parse the drift output with:

```python
data = json.loads(output)
assert data["continue"] is False
assert "dev-test" in data["stopReason"]
assert "dev-next" in data["stopReason"]
assert "codex-feature" in data["systemMessage"]
```

Pass `HARNESS_ROOT="$FIXTURE"` and
`CODEX_HARNESS_STATE_DIR="$FIXTURE/state"` to hooks.

- [ ] **Step 2: Run tests to verify failure**

Run `bash codex/tests/test-harness.sh`.

Expected: FAIL because hook files do not exist.

- [ ] **Step 3: Register hooks**

Create:

```json
{
  "description": "Select and guard the active AOSP feature context.",
  "hooks": {
    "SessionStart": [{
      "matcher": "startup",
      "hooks": [{
        "type": "command",
        "command": "./.codex/hooks/session-start.sh",
        "timeout": 10,
        "statusMessage": "Recording the active AOSP feature"
      }]
    }],
    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "./.codex/hooks/check-branch-drift.sh",
        "timeout": 10,
        "statusMessage": "Checking AOSP feature consistency"
      }]
    }]
  }
}
```

- [ ] **Step 4: Implement hooks**

Parse stdin JSON with `python3`, sanitize `session_id` to `[A-Za-z0-9._-]`,
create the state directory with mode `700`, and use
`<safe-session-id>.feature`. SessionStart writes the current feature with no
output. No-drift also produces no output. Drift is serialized with `json.dumps`:

```json
{
  "continue": false,
  "stopReason": "AOSP feature drift: session started on '<old>', current feature is '<new>'.",
  "systemMessage": "Feature changed during this Codex session. Restart with ./.codex/bin/codex-feature before continuing."
}
```

- [ ] **Step 5: Run tests and commit**

Run `bash codex/tests/test-harness.sh`; expected PASS. Then:

```bash
git add codex/.codex codex/tests/test-harness.sh
git commit -m "feat(codex): block feature drift across turns"
```

### Task 4: Add repository process skills

**Files:**
- Create: `codex/.agents/skills/build-services-jar/SKILL.md`
- Create: `codex/.agents/skills/build-sepolicy/SKILL.md`
- Create: `codex/.codex/bin/check-process-layer`
- Modify: `codex/tests/test-harness.sh`

- [ ] **Step 1: Append failing skill tests**

```bash
grep -Fq 'm services' "$ROOT/.agents/skills/build-services-jar/SKILL.md"
grep -Fq 'services.jar' "$ROOT/.agents/skills/build-services-jar/SKILL.md"
grep -Fq 'verify-*.sh' "$ROOT/.agents/skills/build-services-jar/SKILL.md"
grep -Fq 'm selinux_policy' "$ROOT/.agents/skills/build-sepolicy/SKILL.md"
grep -Fq 'service_contexts' "$ROOT/.agents/skills/build-sepolicy/SKILL.md"
! grep -Fq 'paths:' "$ROOT/.agents/skills/build-services-jar/SKILL.md"
! grep -Fq 'paths:' "$ROOT/.agents/skills/build-sepolicy/SKILL.md"
```

Also run `check-process-layer` and assert both skill PASS lines plus
`RESULT PASS`.

- [ ] **Step 2: Run tests to verify failure**

Run `bash codex/tests/test-harness.sh`.

Expected: FAIL because skills do not exist.

- [ ] **Step 3: Write both skills**

Services frontmatter:

```yaml
---
name: build-services-jar
description: Build and deploy AOSP services.jar after changes under frameworks/base/services, including SystemServer services; use for compile targets, artifacts, push steps, ART cache risks, and feature verification.
---
```

Document bash envsetup, background `m services`, the success marker, artifact,
ADB state warning, ART recovery, `m update-api`, SELinux, and `verify-*.sh`.

SELinux frontmatter:

```yaml
---
name: build-sepolicy
description: Build and verify AOSP SELinux policy after changes under system/sepolicy, especially new system services requiring service_contexts, service types, allow rules, denial checks, and full feature verification.
---
```

Document `service_contexts`, service type and allow rules, background
`m selinux_policy`, deployment, denial inspection, and feature verification.

- [ ] **Step 4: Implement the offline checker**

Use a `require_text(file, text, label)` helper. Print exactly:

```text
PASS  build-services-jar skill 工件完整
PASS  build-sepolicy skill 工件完整
RESULT PASS
```

- [ ] **Step 5: Run tests and commit**

Run `bash codex/tests/test-harness.sh`; expected PASS. Then:

```bash
git add codex/.agents codex/.codex/bin/check-process-layer codex/tests/test-harness.sh
git commit -m "feat(codex): add AOSP build process skills"
```

### Task 5: Implement strict feature verification

**Files:**
- Create: `codex/features/dev-sidebar/verify-sidebar.sh`
- Modify: `codex/tests/test-harness.sh`

- [ ] **Step 1: Append failing verification tests**

Test strict SKIP, `--allow-skip`, old and new crash timestamps, crash-query
failure, and integer logcat epoch normalization. Core assertions:

```bash
set +e
output="$(DEMO_APP_INSTALLED=0 "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
grep -Fq 'RESULT INCOMPLETE' <<<"$output"

output="$(DEMO_APP_INSTALLED=0 "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo --allow-skip)"
grep -Fq 'RESULT PASS (SKIP allowed)' <<<"$output"

output="$(DEMO_CRASH_LOG='100.000 F AndroidRuntime: FATAL old crash' "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo --since 200)"
grep -Fq 'PASS  crash buffer 自 200 起无崩溃' <<<"$output"

set +e
output="$(DEMO_CRASH_LOG='300.000 F AndroidRuntime: FATAL new crash' "$ROOT/features/dev-sidebar/verify-sidebar.sh" --demo --since 200 2>&1)"
rc=$?
set -e
test "$rc" -ne 0
grep -Fq 'FAIL  crash buffer 自 200 起发现崩溃' <<<"$output"
```

- [ ] **Step 2: Run tests to verify failure**

Run `bash codex/tests/test-harness.sh`.

Expected: FAIL because the verifier does not exist.

- [ ] **Step 3: Implement arguments and state**

Parse `--demo`, `--allow-skip`, and `--since <nonnegative-number>`; invalid
usage exits `2`. Maintain `pass_count`, `fail_count`, and `skip_count` through
helpers that print fixed status labels.

- [ ] **Step 4: Implement assertions**

Check boot, `system_server`, crash buffer, service, and app. Demo mode uses
`DEMO_BOOT_COMPLETED`, `DEMO_SYSTEM_SERVER`, `DEMO_CRASH_LOG`,
`DEMO_CRASH_QUERY_FAIL`, `DEMO_SERVICE_REGISTERED`, and
`DEMO_APP_INSTALLED`. A missing demo app is `SKIP`; other missing essentials
are failures. Real mode reads `btime` when `--since` is absent. Normalize an
integer baseline to `.000` before `adb logcat -T`, and numerically ignore crash
lines older than the baseline.

- [ ] **Step 5: Implement final status**

```bash
if (( fail_count > 0 )); then
  echo "RESULT FAIL"; exit 1
elif (( skip_count > 0 && allow_skip == 0 )); then
  echo "RESULT INCOMPLETE"; exit 1
elif (( skip_count > 0 )); then
  echo "RESULT PASS (SKIP allowed)"
else
  echo "RESULT PASS"
fi
```

- [ ] **Step 6: Run tests and commit**

Run `bash codex/tests/test-harness.sh`; expected PASS. Then:

```bash
git add codex/features/dev-sidebar/verify-sidebar.sh codex/tests/test-harness.sh
git commit -m "feat(codex): add strict feature verification"
```

### Task 6: Add the integrated demo and README

**Files:**
- Create: `codex/run-demo.sh`
- Create: `codex/README.md`
- Modify: `codex/tests/test-harness.sh`

- [ ] **Step 1: Append failing integration tests**

```bash
grep -Fq './.codex/bin/codex-feature --dry-run' "$ROOT/run-demo.sh"
grep -Fq './.codex/bin/check-process-layer' "$ROOT/run-demo.sh"
grep -Fq './features/dev-sidebar/verify-sidebar.sh --demo' "$ROOT/run-demo.sh"
grep -Fq './tests/test-harness.sh' "$ROOT/run-demo.sh"
```

Run the demo with `SKIP_SELF_TESTS=1` to avoid recursion and assert context,
drift, process, verification, and completion headings.

- [ ] **Step 2: Run tests to verify failure**

Run `bash codex/tests/test-harness.sh`.

Expected: FAIL because `run-demo.sh` does not exist.

- [ ] **Step 3: Implement `run-demo.sh`**

Save and restore `CURRENT_FEATURE` with a trap. Demonstrate wrapper dry-run,
SessionStart plus drift blocking, expected `check-branch.sh --demo` failure,
process checker, strict verifier, and tests unless `SKIP_SELF_TESTS=1`. End with
`Codex 三层 Harness 演示完毕`.

- [ ] **Step 4: Write `codex/README.md`**

Document the directory tree, `./run-demo.sh`, commands for each layer, expected
results, Codex/Claude differences, and real-AOSP adaptation. Cite official
`AGENTS.md`, skills, hooks, config, subagents, and CLI docs. State that project
hooks require trust and can be reviewed with `/hooks`.

- [ ] **Step 5: Run tests and commit**

```bash
bash codex/tests/test-harness.sh
./codex/run-demo.sh
git add codex/run-demo.sh codex/README.md codex/tests/test-harness.sh
git commit -m "docs(codex): add runnable harness walkthrough"
```

Expected: commands pass and the demo ends with its completion line.

### Task 7: Write the long-form Codex article

**Files:**
- Create: `codex/AOSP整机源码Codex-Harness工程探索.md`
- Modify: `codex/tests/test-harness.sh`

- [ ] **Step 1: Add failing documentation tests**

Require headings for problem, official model, architecture, context, process,
verification, lifecycle, migration, testing, boundaries, and references.
Require official links containing:

```text
learn.chatgpt.com/docs/agent-configuration/agents-md
learn.chatgpt.com/docs/build-skills
learn.chatgpt.com/docs/hooks
learn.chatgpt.com/docs/config-file/config-advanced
learn.chatgpt.com/docs/agent-configuration/subagents
learn.chatgpt.com/docs/developer-commands
```

Reject claims of `paths 自动激活` and instructions to add `.claude/` or
`CLAUDE.md` to the Codex tree outside the explicit migration comparison.

- [ ] **Step 2: Run tests to verify failure**

Run `bash codex/tests/test-harness.sh`.

Expected: FAIL because the article does not exist.

- [ ] **Step 3: Write the article**

Use this outline:

```markdown
# AOSP 整机源码 Codex Harness 工程探索
## 一、问题：为什么 Codex 在整机源码树上仍需要 Harness
## 二、官方能力边界：Codex 提供了哪些承载面
## 三、方案总览：Codex 原生三层 Harness
## 四、第①层 上下文：启动前选对 AGENTS.md
## 五、第②层 流程：用 repository skills 渐进披露
## 六、第③层 验证闭环：只有 RESULT PASS 才算完成
## 七、串起来：一个 Codex 会话的完整生命周期
## 八、从 Claude Code 版迁移时不能直接照搬什么
## 九、工程化加固与测试
## 十、边界与下一步
## 结语
## 参考资料
```

Explain AOSP scale, repo/Gerrit pollution, Codex discovery, non-Git root
behavior, wrapper ordering, once-per-run instructions, hook state/trust,
progressive skill disclosure, the lack of documented path-scoped triggering,
explicit skill routing, deterministic verification, subagent task cards,
security boundaries, and future maintenance. Separate official guarantees,
demo choices, and real-tree recommendations.

- [ ] **Step 4: Verify and commit**

```bash
bash codex/tests/test-harness.sh
git diff --check
git add codex/AOSP整机源码Codex-Harness工程探索.md codex/tests/test-harness.sh
git commit -m "docs(codex): explain AOSP harness engineering"
```

Expected: tests pass and no whitespace errors appear.

### Task 8: Final regression and consistency review

**Files:**
- Modify only files with defects found by verification.

- [ ] **Step 1: Run all executable verification**

```bash
./claude-code/tests/test-harness.sh
./codex/tests/test-harness.sh
./claude-code/run-demo.sh
./codex/run-demo.sh
```

Expected: all exit `0` with documented completion lines.

- [ ] **Step 2: Check repository consistency**

```bash
git diff --check
git status --short
find codex \( -name CLAUDE.md -o -path '*/.claude/*' \) -print
```

Expected: no whitespace errors; only intentional status entries; `find` has no
output; existing `demo-out/` is untouched.

- [ ] **Step 3: Recheck official contracts**

Compare both Codex documents against the current manual sections for
`AGENTS.md`, skills, hooks, project-root detection, and subagents. Rewrite any
observation presented as a product guarantee.

- [ ] **Step 4: Repeat verification after corrections**

Repeat Steps 1 and 2. If corrections were required, commit only those files:

```bash
git add README.md claude-code codex
git commit -m "test: verify both AOSP harness demos"
```

