---
paths:
  - "**/Android.bp"
  - "**/Android.mk"
---
你正在读/改构建文件。提醒：`compile_commands.json` 是结构快照——改了 `Android.bp/Android.mk`、
新增 `.c/.cpp` 进模块、或 `repo sync` 之后它就过期了，clangd 会对新结构失准。
改完记得后台跑一次树根 `./gen-compdb-clangd.sh`（几分钟，只跑 soong 分析不编译）。
只改函数体/逻辑不用跑——clangd 实时读源文件内容。
另注意：clangd 用的是 **feature 精简库**（compdb-feature/，默认只含 frameworks/base、
frameworks/native、packages/apps/SidebarApp）；若把新模块建在这些仓之外，要把仓前缀传给脚本
（`./gen-compdb-clangd.sh <仓...>`）或改脚本 REPOS 默认值，否则新仓文件没有精确编译参数。
