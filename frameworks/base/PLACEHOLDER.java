// DEMO 占位文件 —— 真实环境这里是 frameworks/base 仓的源码树（独立 git 仓）。
//
// 用途：演示"编辑本仓任意文件时，Claude Code 会按需加载同目录下的 CLAUDE.md"。
// 该 CLAUDE.md 由 SessionStart hook（.claude/hooks/load-feature.sh）按
// features/<分支>/repos.tsv 物化，内容 = 该仓单仓约定（features/dev-sidebar/frameworks-base.md）。
// 真实环境里这份 CLAUDE.md 写入本仓 .git/info/exclude，对 git 隐身、不进 gerrit；
// demo 里各仓非独立 git 仓，改由顶层 .gitignore 忽略（见 load-feature.sh 的降级说明）。
class Placeholder {}
