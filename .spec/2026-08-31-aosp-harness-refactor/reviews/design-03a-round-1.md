# 03a design review round 1

结论：NEEDS_CHANGES（blocker 1 / important 4 / minor 1）

- blocker：单一 marker 运行位置在 mkdir/EEXIST 之后，无法真实制造 EEXIST 分支；需改为 marker 文本唯一的 multi-phase copy-replaced checkpoint，并用 catch sentinel 证明真进分支。
- important：mkdir 返回到首次 stat 之间无法证明 inode ownership，不应事后 fchmod namespace winner；依赖 umask+mkdir(0700) 并只校验。
- important：PLAN 只定义两 private export 依赖，design 额外把 private predicate 变成硬依赖；需对齐为 public validate + 两 private guard 并逐字列出。
- important：predicate fail-fast 需 fake python3 调用计数为0；124+248 只是分配表，需可运行/可计数骨架。
- minor：补 Linux/glibc/Bash/Python 下限。

其余八节、根语义、owner/public 边界和机械检查通过。
