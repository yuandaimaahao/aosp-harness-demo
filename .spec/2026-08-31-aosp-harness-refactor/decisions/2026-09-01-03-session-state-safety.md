# 2026-09-01-03-session-state-safety

结论：foundation 成立并已合入 main。

## 改了什么

- 新增公开的 C-locale 安全名称校验 `harness_validate_feature_name <name>`。
- 新增私有 fresh-root foundation：四级根选择、physical parent、root/project/session fd 链，以及固定 `0|1|2` 结果协议。
- 新增独立离线测试，覆盖 source 零副作用、危险路径零创建、同根两 project × 两 session、fresh nonlink/EUID/0700 和真实 `OSError` 映射。
- 未发布四个状态 public API，也未设置完整 provider capability marker；03a–03d 继续按独占模块完成 hardening、snapshot、signals、remove 与 aggregator。

## 验收证据

- `work/2026-09-01-03-session-state-safety/acceptance-report.md`
- Source HEAD：`ac985df39effd937b11ddb436593b33e7eadc248`
- Evidence commit：`da7159f0e5fb01af48d4c2638dc7a7b50af65835`
- Review manifest：`work/2026-09-01-03-session-state-safety/review-manifest.tsv`
