---
paths:
  - "**/Android.bp"
  - "**/Android.mk"
---
你正在读/改构建文件。提醒：`compile_commands.json` 是结构快照——改了 `Android.bp/Android.mk`、
新增 `.c/.cpp` 进模块、或 `repo sync` 之后它就过期了，clangd 会对新结构失准。
改完记得后台跑一次树根 `./gen-compdb-clangd.sh`（几分钟，只跑 soong 分析不编译）。
只改函数体/逻辑不用跑——clangd 实时读源文件内容。
另注意：clangd 用的是 **feature 精简库**（compdb-feature/）。无参跑脚本时，仓集**按当前分支自动读
`features/<分支>/compdb-repos.txt`**（单一事实源，切 feature 自动跟随；当前 dev-sidebar = frameworks/base、
frameworks/native、packages/apps/SidebarApp）。若把新模块建在清单之外的仓，改 `features/<分支>/compdb-repos.txt`
（长期）或临时 `./gen-compdb-clangd.sh <仓...>`（一次性覆盖），否则新仓文件没有精确编译参数。
