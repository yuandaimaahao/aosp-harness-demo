# Task 1.5 fix round 1 report

Status: DONE

Commits: [7b9a0bb9892792593144da2284b4bb763a16721a]

## Findings 闭合

- I1：`run_static` 在启动 fixture gate 前显式设置两个不同的非空 poison：`GITLEAKS_CONFIG=poison-primary` 与 `GITLEAKS_CONFIG_TOML=poison-toml`；fake 的两次调用记录仍精确要求二者均为 `unset`。
- I2：canary 文件写入失败显式转为 protocol error；canary Gitleaks rc 改由 `if ...; then rc=0; else rc=$?; fi` 捕获，不依赖函数处于 OR-list 时的隐式 errexit；trap 在 repo 内判定前注册，显式清理失败转为 protocol error，且只有清理成功才解除 trap。
- I3：config-bytes、config-digest、empty-rules、global-allowlist、canary rc 0、canary rc 2、repo 内 TMPDIR 与 worktree failure 各自带 case 标签，并明确断言 stdout 不含总 PASS。
- 未修改 workflow、coverage 或任务 2.1 文件。

## 红阶段

- 命令：`bash ./tests/test-quality-gate.sh`
- 退出码：1
- 首个新增失败：`AssertionError: explicit secret failure handling`
- 红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-02-offline-quality-gate/task-1.5-fix1-red-stage.log

## 绿阶段

- `bash ./tests/test-quality-gate.sh`：rc 0，末行 `RESULT PASS  offline quality gate contract`。
- `bash ./scripts/check.sh --offline`：rc 0，末行 `RESULT PASS  aosp-harness offline quality gate`。
- config SHA、两份 Bash 语法、三个文件全文件空白、`git diff --check` 与提交后工作树清洁检查：均通过。
- 相对 `9be78e07d4e3a722a9c034423cc1ce6372a1e52e` 的最终任务预算为 test/gate/config `23/20/2`，累计行数为 `118/73/2`，满足 `24/20/2` 与 `169/105/2` 上限。

## 完整 canary 零匹配证明

执行命令（查询词仅在运行时由两片拼接）：

```bash
canary_prefix=AKIA
canary_suffix=ABCDEFGHIJKLMNOP
git grep -F -- "${canary_prefix}${canary_suffix}"
```

结果：rc `1`，整个 tracked working tree 零匹配。

## Fix Numstat

| File | Additions / deletions |
|---|---:|
| `scripts/check.sh` | 4 / 4 |
| `tests/test-quality-gate.sh` | 15 / 10 |

顾虑：无。所有 contract 测试继续使用 fake 工具，不联网、不调用真实外部工具；使用普通 Conventional Commit，未 push 或 merge。
