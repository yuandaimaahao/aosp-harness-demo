# 03a execution-backed sizing — 不进入生产 diff

## 当前权威实测

早期 `prototypes/` 的 311 行/40 case 结果只保留为设计历史；它没有包含生产测试在pinned shfmt后的真实展开，不能再作为400行门依据。当前权威证据是：

- 权威报告：`../../work/2026-09-01-03a-session-path-safety/v5.5-round2-sizing-report.md`
- 输入：实现HEAD `fad7bf384d9d8807f1f268649bc8ed19e10cf4b0`
- 方法：只在临时目录删除完整anchor-driven mutation组，应用task4 dispatcher/精确流/managed-body位置修复；另生成可运行03a1三层共享driver。实现worktree未修改且保持clean。首版`v5.5-sizing-report.md`因真实foundation缺席证据路径错误及03a1仅有抽取骨架而被round1 review否决，只保留历史。

固定工具与结果：

```text
shfmt 3.14.0: shfmt -w/-d -i 2 -ci -bn
ShellCheck 0.11.0: shellcheck -x --severity=warning
114 common/.harness/lib/session-state-path.sh
278 tests/test-session-path.sh
392 total
```

pinned shfmt无diff、ShellCheck零warning，`392 <= 400`，余量8行。正常default/source/roots/显式dependency-absent与真实foundation文件缺席default/flag均实跑为精确33-byte PASS、stderr空、rc0。

## 03a保留边界

- 完整private provider：source guard、public validate调用、四级root selector、fresh/EEXIST/existing统一nofollow fd hardening、固定错误映射。
- `source-validate`：source副作用inventory、三个单依赖缺席、all-missing inert、private/public surface、validate顺序与fake-python零调用。
- `roots-static`：HARNESS/XDG/TMP/default/physical root、危险root、post-mkdir disappearance、2×2隔离、root/project/session link/file/mode攻击。
- 结构：三个生产anchor各一次；三个checkpoint phase在全文件和提取的`open_managed`函数体内各一次；移动phase到无关函数的self-disproof会失败；无`fchmod`。
- dispatcher：foundation真实缺席时default/显式flag都走all-missing inert；foundation存在时只运行source-validate与roots-static；用文件`cmp`逐字保留摘要末尾LF。

## 移出03a的边界

03a不再接受`--case mutations`，不执行任何anchor-driven provider-copy mutation。以下全部移入独占单文件`03a1-session-path-race-assurance`：

- root/project/session existing safe-dir/link/file swap；
- EEXIST safe/unsafe/disappearing winner与mkdir-success replacement；
- ordinary mkdir failure、mkdir/post-mkdir/open/final-stat disappearance；
- wrong EUID、真实EIO、made/catch/phase sentinel；
- victim/replacement inode/mode/hash/inventory完整签名。

03a1可运行共享driver经pinned shfmt为269行并实跑19个child/case：包含三层×safe-dir/link/file的9个swap，以及把EEXIST三分类、mkdir replacement、wrong EUID、mkdir/post-mkdir/open/final-stat disappearance与EIO分布到不同层的10个代表case；每例使用共享stream/signature/inventory oracle。完整37-case矩阵剩18个data rows/calls，余量131行。若实现复制三层case body、删除完整对象签名或最终超过400，此证据失效并必须回PLAN。

## 拒绝条件

- 03a最终exact2超过400行，或pinned shfmt/ShellCheck不通过：拒绝并回PLAN。
- 为压行删除source/inert、root/static、anchor/phase、fake-python零调用、精确stream/rc或dispatcher oracle：拒绝。
- 将任一anchor-driven dynamic mutation偷回03a，或在03a1 PASS前启动consumer：拒绝。
- 原型与实测只支持Linux kernel >=3.15、glibc >=2.28、Bash >=5.0、Python >=3.8，不外推其他平台。
