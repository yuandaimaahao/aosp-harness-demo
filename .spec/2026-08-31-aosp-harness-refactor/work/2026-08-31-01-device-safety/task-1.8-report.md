# Task 1.8 report — legacy aggregation and default entrypoint

Status: DONE

Commits: `61e5fa8 test: aggregate device safety regressions`

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-1.8-red-stage.log`

## 改动

- 在 `tests/test-device-safety.sh` 注册 `legacy` scope，并以该脚本创建的私有 fake-ADB bin 置于 `PATH` 首位的方式依序运行 Claude、Codex、common 三套旧回归。
- 注册默认 `all` scope，严格按 `fixture`、`claude-invalid-serial`、`claude-valid-serial`、`flag-demo`、`skills`、`legacy` 的顺序运行；任一失败立即返回非零。
- 无 `DEVICE_SAFETY_TEST_SCOPE` 时默认运行 `all`，并只在全部 scope 成功后输出精确末行 `RESULT PASS  device safety`。

## 验证

- `chmod +x ./tests/test-device-safety.sh` — exit 0。
- `bash -n ./tests/test-device-safety.sh` — exit 0。
- `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh` — exit 0。
- `DEVICE_SAFETY_TEST_SCOPE=legacy bash ./tests/test-device-safety.sh` — exit 0；三套旧回归全部通过，且以私有 fake ADB 的 `PATH` 运行。
- `bash ./tests/test-device-safety.sh` — exit 1，符合生产安全修复尚未落地时的预期红阶段；未输出成功末行，详情见上述证据。
- `git diff --check`、`git diff HEAD^ HEAD --check` — exit 0。

## 顾虑

- 当前分支尚未包含后续 2.1–2.3 的生产安全改造；因此新的默认全量入口按设计在 Claude serial 矩阵处保持红灯。生产任务完成后，预期无参入口才会输出最终成功末行。
