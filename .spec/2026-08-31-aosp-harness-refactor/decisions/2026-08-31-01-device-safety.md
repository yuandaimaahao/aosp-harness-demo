# 2026-08-31-01-device-safety 成立结论

结论：成立，已合入 `main`。

## 改了什么

- Claude 真实 verifier 在首次 ADB 前校验显式 `ANDROID_SERIAL`，所有 shell/logcat 调用固定到同一 `adb -s` 目标。
- Claude 与 Codex 在真实模式优先拒绝 `--allow-skip`；Demo 的既有 SKIP/PASS 探索语义保持不变。
- `build-services-jar`、`build-sepolicy` 的真机代码块增加唯一 serial preflight，并让所有枚举的 ADB 命令使用同一 `device_serial`。
- 新增根级离线安全回归，覆盖非法/合法 serial、flag 优先级、Demo SKIP、skill contract/mutation 和三套 legacy 入口。

## 确认的后续契约

- 安全 serial 格式为 `^[A-Za-z0-9][A-Za-z0-9._:-]*$`；缺失或非法值返回 `2`，且在此之前不得调用 ADB。
- `--allow-skip` 只属于 Demo；真实模式的组合错误返回 `2`，并先于 serial 错误。
- 后续 verifier runtime/adapters 必须保持固定设备目标和上述错误优先级。
- skill 真机示例故意限制为可静态证明的简单单行 ADB；复杂 shell 组合应拆行，而不是扩大 parser 接受面。

## 验收证据

- 六块验收报告：`work/2026-08-31-01-device-safety/acceptance-report.md`
- 任务报告与独立 reviews：`work/2026-08-31-01-device-safety/`
- 主验证入口：`tests/test-device-safety.sh`
- 合入 HEAD：`bcd0c9b0b675c384c346dcd0171a055b67a2712c`
