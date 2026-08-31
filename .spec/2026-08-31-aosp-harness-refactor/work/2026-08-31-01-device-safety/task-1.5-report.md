# 任务 1.5 报告：提取并计数 fenced 真机块

## Status

DONE

## Commits

- `b726dbf test: extract fenced device blocks`

## 改动

- 在 `tests/test-device-safety.sh` 增加 `device_safety_extract_device_blocks <skill-name> <path> <output-dir>`：仅解析精确 ````bash` / ```` 围栏，只有包含 `root`、`remount`、`push`、`reboot` 或 `shell` 目标 ADB 子命令的块才写入私有 `block-N.bash`，并输出提取计数。
- 新增 `skill-blocks` scope：合成 Markdown fixture 验证一个 build block 与一个 device block 时只提取后者（且行内反引号不参与），并要求 `build-services-jar`、`build-sepolicy` 各恰好一个真机 fenced block。

## 红阶段证据

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-1.5-red-stage.log

命令：

```bash
DEVICE_SAFETY_TEST_SCOPE=skill-blocks bash ./tests/test-device-safety.sh
```

退出码：`1`。精确 stderr：

```text
FAIL  build-sepolicy: expected exactly one fenced device block
```

这证明当前 `build-sepolicy` 的行内 ADB 不能被误计为真机 fenced block；本静态 scope 不执行 ADB。

## 验证

- `bash -n ./tests/test-device-safety.sh`：rc `0`。
- `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh`：rc `0`。
- `DEVICE_SAFETY_TEST_SCOPE=skill-blocks bash ./tests/test-device-safety.sh`：rc `1`，为上述预期红阶段；合成提取子测试先通过。
- `git diff --check`：rc `0`（提交前）。

## 顾虑

无。`skill-blocks` 的生产文件红灯由后续任务 2.3 尚未将 sepolicy 行内 ADB 改为 fenced 真机块引起；本任务未修改生产 skill 或 verifier。
