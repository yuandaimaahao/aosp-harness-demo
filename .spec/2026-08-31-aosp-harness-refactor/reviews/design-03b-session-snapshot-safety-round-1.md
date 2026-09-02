# 03b design 独立审查 round 1

结论：**NEEDS_CHANGES，不可进入 tasks。** Blocking 1、Important 3、Minor 0。

## Blocking

1. prototype先`os.close(temp_fd)`、后`temp_fd = None`；信号若落在两者之间，finally会二次close并以EBADF遮蔽首信号、在unlink前退出，可能残留`.snapshot-*`。design未锁定close前ownership transfer、cleanup错误优先级，也没有close边界的确定性oracle。

## Important

1. 未定义renameat2未提交与已经提交但Python尚未更新ownership两个信号窗口；现有publish anchor和assurance未覆盖post-success。
2. handler逐个安装SIG_IGN前没有先锁存首信号；第二种信号在ignore循环完成前重入可能覆盖首信号码，原测试只覆盖ignore完成后的晚到信号。
3. verified-read Mermaid让path core直接把held fd交给Python，遗漏Bash worker收回path rc并最终exec的真实边界，与组件说明矛盾。

## 已通过

八节和exact两文件清单齐全；R1–R9全覆盖；frontmatter消费/产出逐字出现；EEXIST temp→winner-read、held capture和pathname不重开正确；无tasks实质内容、无implementation worktree。审查时固定工具、base/assurance和397/400 sizing均复跑通过。

## 修复方向

R4、design与prototype必须共同锁死：可中断close前转移并清空fd ownership；cleanup仍尝试unlink且latched signal优先；handler在任何可重入动作前一次性锁存首信号、重入只返回；provider-copy增加post-close、early-second-signal、post-rename-success三行动态oracle；read图补Bash worker和exec边界。
