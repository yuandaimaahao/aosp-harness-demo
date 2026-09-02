# 03b design 独立审查 round 2

结论：**NEEDS_CHANGES，不可进入 tasks。** Blocking 1、Important 0、Minor 0。

round1的post-close ownership、early second-signal、post-rename winner和read图均已修复；但cleanup错误优先级只覆盖正常close后的信号。若信号在ownership transfer前到达，publish finally直接`os.close(temp_fd)`仍可能报错并跳过unlink；dispatch关闭session/ancestor也可能在首错处停止。现有assurance未注入“signal + cleanup close error”，不能证明R4/design声称的后续cleanup全部尝试和latched signal最终优先。

要求统一用嵌套try/finally或等价collector：记录每个close的OSError/Interrupted、继续全部fd，temp close无论结果都进入unlink，全部cleanup后再让首信号决定129/130/143；provider-copy必须确定性注入cleanup close错误并核unlink、信号码和所有close尝试。修复后重新证明exact2≤400。

其余通过：八节+文件清单、R1–R9、frontmatter签名、三项round1 Important、固定工具/base/assurance、机械检查、无tasks/implementation worktree/后序资产均符合。
