# Review: task 1.2 (b2fab190..a8d03d1d) round 1

verdict: NEEDS_CHANGES
阻断: 0 / 重要: 1 / 次要: 2

## 规格符合性

R7 全面符合：私有 mktemp 树带前缀模板（裁定 10）、单 EXIT trap、CURRENT_FEATURE 零写入、私有 TMPDIR/HARNESS_STATE_ROOT、v1 hook 全生命周期演示、$OLDPWD 正确引用仓库根、保留段完整。

## 质量

numstat 51/62 单文件、191/214 累计，在预算内。shfmt/shellcheck/bash-n 由 controller 验证通过。上游十二文件零变更。sep() 展开为 shfmt 合规必需（同 task 1.1 先例）。

## 红阶段判定

真红——clone+私有 TMPDIR 跑现状 demo，rc0 但生成全局快照 dev-sidebar，rg 命中 39/17 行。

## findings

### I1 (Important): drift 演示缺显式 rc==2 断言

hook demo drift 段用 `|| true` 掩盖退出码，design 要求「demo 断言 rc==2 后继续」。当前形式下任何非零 rc（1/126/127 等）都会静默通过。

修复：捕获 rc 并显式断言为 2，非 2 时 stderr 报错并退出。

### S1 (Minor): sep() 展开加 4 行

shfmt 要求展开为多行。在预算内（51/62），备案。

### S2 (Minor): $OLDPWD 维护性

OLDPWD 在当前代码中正确，但若在 cd(:31) 和 cp(:38) 之间插入另一个 cd 会静默失效。维护性建议，不阻塞。
