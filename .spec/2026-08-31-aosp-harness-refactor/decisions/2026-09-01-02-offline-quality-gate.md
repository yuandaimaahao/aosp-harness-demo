# 2026-09-01-02-offline-quality-gate

结论：成立并已合入 main。

## 改了什么

- 新增统一 `scripts/check.sh --offline|--ci`，offline 自动发现受管 Shell 与根测试，CI 追加固定版本静态/秘密检查。
- 新增 canonical Shell blob baseline、两行 Gitleaks config、仓库外 canary 自检与 GitHub Actions 固定工具安装。
- 新增离线 contract 回归和五列 coverage 映射；后续 spec 新增 `tests/test-*.sh` 即自动进入根 gate。

## 验收证据

- `work/2026-09-01-02-offline-quality-gate/acceptance-report.md`
- Source HEAD：`83eac79c013cd50216b8638005105fb98bcd2977`
- Evidence commit：`b33b67096c84cdf23687c45bf3c36b0831d5f705`
