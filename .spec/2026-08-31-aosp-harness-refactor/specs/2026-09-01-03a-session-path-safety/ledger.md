# ledger — spec: 2026-09-01-03a-session-path-safety
# plan: .spec/2026-08-31-aosp-harness-refactor/PLAN.md v5.4
# worktree: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a-session-path-safety

> 会话压缩之后，「我刚做完什么」的记忆不可靠。这份文件和 git log 才是。
> `任务 N: 完成` 是唯一的恢复锚点。

---

## Requirements

- 2026-09-01T19:05+08:00 选片：PLAN v5.3 与 03 foundation retro 均指向 03a-session-path-safety；用户已授权 autopilot，无新待问问题。
- round 1 dispatch reviewer=review_requirements_03a_r1; mechanics='check-plan + check-req + check-criteria + check-analyze + diff-check PASS'
- round 1 NEEDS_CHANGES blocker=0 important=3 minor=0：采纳三层MANAGED/EXPECTED_EUID条件注入与sentinel、fresh EEXIST safe/unsafe/disappearing `0|2|1`分类、present+三missing-export同shell source declare-p/declare-f/inventory oracle。若判断错误，代价是测试表较大；若不补，代价是丢失project/session校验、正常mkdir竞争误报1或source覆写上游仍可假绿。
- round 2 NEEDS_CHANGES blocker=0 important=3 minor=0：采纳三层mkdir-success→open/fchmod replacement且identity成立后才chmod、新core四级成功/优先级/physical symlink oracle、predicate wrapper两参数log+拒绝合法ID的调用证据。若判断错误，代价是增加三组mutation和四组根成功fixture；若不补，新inode替换可被chmod、core可选错根或复制predicate仍假绿。
- round 3 PASS blocker=0 important=0 minor=0 reviewer=review_requirements_03a_r3; mechanics='check-plan + check-req + check-criteria + check-analyze + foundation regression + diff-check PASS'
- 自动通过: 门②（autopilot）。依据：三轮全新上下文 requirements review 最终 PASS，R1–R7、逐层竞争/攻击 oracle、inert 回滚、exact2/400 和 manifest 闭合，所有机械检查通过。

## Design

- round 1 NEEDS_CHANGES blocker=1 important=4 minor=1：采纳multi-phase checkpoint、取消不可证明ownership的post-mkdir fchmod、将依赖对齐为public validate+两private exports、fake python3 fail-fast oracle、可运行sizing骨架与Linux/Bash/Python下限。此轮同时触发requirements/PLAN回流复审。若判断错误，代价是根选择实现仍在03a重建；若不修，EEXIST注入假绿且替换winner可被chmod。
- PLAN v5.3.1 incremental review PASS blocker=0 important=0 minor=0 reviewer=review_plan_v5_3_1；确认只澄清既有03->03a边，不改变回滚、图、顺序、owner或P1-P5。
- requirements design-backflow review PASS blocker=0 important=0 minor=0 reviewer=review_plan_v5_2；确认public validate guard、no-fchmod、multi-phase/catch、fake-python与exact2/400门闭合。
- round 2 NEEDS_CHANGES blocker=1 important=1 minor=0：sizing case inventory 未实际分派，无法证明剩余89行足够；Linux动态换入link/file可能以ENOTDIR失败，必须同ELOOP映射unsafe并补oracle。接受回PLAN拆独立race-assurance片，保持私有provider在通过assurance前无消费者。
- PLAN v5.4 round 1 NEEDS_CHANGES blocker=0 important=2 minor=0：补03a frontmatter/design的03a1 anchor直接消费边与v5.4依据；补foundation回滚命令中的race test inert oracle。
- PLAN v5.4 round 2 PASS blocker=0 important=0 minor=0 reviewer=review_design_03a_r1；P1-P5、依赖/回滚/owner/400行门与40-case原型闭合。
- requirements v5.4 backflow round 1 NEEDS_CHANGES blocker=0 important=2 minor=0：删除frontmatter误写的03d直接消费，三层EXPECTED_EUID残留收窄为root代表例并明确project/session归03a1。
- requirements v5.4 backflow round 2 PASS blocker=0 important=0 minor=0 reviewer=review_plan_v5_3；直接边、mutation边界、独立价值与311行原型闭合。
- design round 3 PASS blocker=0 important=0 minor=0 reviewer=review_plan_v5_2；40个case真实执行，错误分类/no-fchmod/validate/03a1边界与exact2/400闭合。
- 自动通过: 门③（autopilot）。依据：PLAN v5.4增量review、requirements backflow与design独立review最终均PASS，mechanical checks和runnable sizing均PASS。

## Tasks

- round 1 NEEDS_CHANGES blocker=0 important=4 minor=0：补任务内foundation-contract锚点和逐字产出消费，四个红阶段固定rc/首错，R7补完整manifest/clean命令，每任务review PASS后才派下一任务。
- round 2 NEEDS_CHANGES blocker=1 important=2 minor=0：最终exact2/400纳入task4与review fix最终HEAD；统一terminal delivery逐字文本；四个step3补最小Bash/Python骨架。
- round 3 PASS blocker=0 important=0 minor=0 reviewer=review_plan_v5_2；粒度、逐字接口、唯一红首错、逐任务review、最终HEAD exact2/400/manifest/clean与R1-R7并集全闭合。
- 自动通过: 门④（autopilot）。依据：tasks三轮独立review最终PASS，用户此前明确后续按autopilot执行。
