# 03a runnable sizing prototype — 不进入生产 diff

## 可复现实测

两个原型都是真实执行骨架，不再把 case 名称计数当作通过：

- `prototypes/session-state-path.sh`：136 行，包含完整source guard、public validate调用、四级root selector、三phase checkpoint、EEXIST catch、nofollow open/fstat、`ELOOP|ENOTDIR`安全分类、owner/mode/name-fd identity和固定错误映射。
- `prototypes/test-session-path.sh`：175 行，实际执行40个case；包含capture/逐字节断言、三个missing-dependency、arity/validate+fake-python、HARNESS/XDG/TMP/default/physical根、2×2隔离、三层×link/file/mode静态攻击，以及root层safe-dir/link/file swap、EEXIST safe/unsafe/disappearing、mkdir replacement、wrong EUID和真实EIO。

复现：

```bash
bash -n prototypes/session-state-path.sh prototypes/test-session-path.sh
bash prototypes/test-session-path.sh
wc -l prototypes/session-state-path.sh prototypes/test-session-path.sh
```

实测：

```text
PROTOTYPE PASS  session path sizing (40 executed cases)
136 prototypes/session-state-path.sh
175 prototypes/test-session-path.sh
311 total
```

## 实现预算

| 块 | 已实测 | 尚需上限 |
|---|---:|---:|
| provider完整控制流 | 136 | 0 |
| test实际功能/静态/root-race oracle | 175 | 0 |
| source declare-p/inventory细化、低优先级零变化 | 0 | 34 |
| foundation/offline/manifest与最终review修正 | 0 | 35 |
| 余量 | 0 | 20 |
| 合计 | 311 | 89 |

生产两文件硬门仍是400。execute每个task后检查BASE..HEAD numstat；达到380行时不再增加case，缺少任何R1–R7 oracle或超过400都回PLAN。project/session的穷举mutation不消耗这89行，已由PLAN v5.4移到独占`03a1-session-path-race-assurance`，且03a1通过前没有consumer。

## 03a1边界

03a1只新增`tests/test-session-path-races.sh`，复用本原型已跑通的copy/count/replace/sentinel driver，把root代表性mutation扩成root/project/session三层，并增加换入safe dir/link/file。它不修改provider、不发布API，独立400行门；03a回滚时该test以`--dependency-absent`走inert PASS。

## 拒绝条件

- 删除marker计数、catch sentinel、fake-python零调用、source保护或精确双流换行数：拒绝。
- 03a实现diff出现第3个文件或超过400：回PLAN。
- 将project/session穷举偷回03a、或让03b在03a1 PASS前开始：拒绝。
- 原型只证明既定Linux/glibc/Bash/Python最低版本设计可表达，不证明其他平台。
