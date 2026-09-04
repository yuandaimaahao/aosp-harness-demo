# 05 verifier contract requirements review — round 3

总裁定：**PASS**

合计：阻断 Blocking **0** / 重要 Important **0** / 次要 Minor **0**

- PLAN v6.0 增量：**PASS** — B0 / I0 / M0
- 当前 requirements：**PASS** — B0 / I0 / M0

审查范围：只复核 round 2 的 P-B1、R-B1、R-I1、R-I2、R-M1；未重跑 controller 已通过的 check-req/check-criteria/check-analyze/check-plan/diff-check，也未做开放式全仓审查。

## PLAN v6.0 增量结论

**PASS — B0 / I0 / M0。**

### P-B1 已闭合：physical provider、owner 与 rollback 形成同一套可执行边界

定位：`PLAN.md:12,60,88,151,167,204,228,306`；`DECISIONS.md:56`。

- 05 现在只新增 `common/.harness/bin/verify-sidebar.sh`、contract 文档和 contract test，不再修改 common/Claude/Codex 三个旧 verifier 入口。
- 09 独占 dispatcher、三个旧入口薄化、legacy fallback 与三入口 parity，并被明确禁止修改 05 canonical provider。因此 05/09 不再共享生产文件 hunk，v6.0 history 所述 owner 收窄与文件表、详情一致。
- `05 -> 09` 已把运行时边固定为 physical provider：present 时由 09 消费 canonical contract，物理缺席时由 09 自有 fallback 接管；09 测试必须覆盖 present/absent 与三入口 parity，且不得按文件内容猜版本。
- 05 独立回滚现在只删除 exact3。canonical provider 的物理缺席可无歧义触发 fallback，不会覆盖 09-owned dispatcher/入口 hunks；回滚表与 05 详情、直接边相互一致。
- 直接依赖仍保持 05 只依赖 02/04a、09 依赖 01/05/06/07；没有新增 05→06、04→05 等运行时边，实施顺序与 04a 启动门也未变化。

因此 round 2 P-B1 的“同文件修改、provider 不会物理缺席、无 capability 探测、rollback 覆盖 consumer hunk”四个问题均已消除，未引入新的依赖或回滚矛盾。

## 当前 requirements 结论

**PASS — B0 / I0 / M0。**

### R-B1 已闭合：design 前 runnable exact3/400 是明确硬门

定位：`requirements.md:41,59-60`；`PLAN.md:151`。

R8 已要求进入 tasks/implementation 前，在隔离临时工作树完成 fixed ShellCheck/shfmt 的 runnable exact3 prototype；prototype 必须包含完整三文件、真实执行 R7 全矩阵并输出固定摘要，并按 `git diff --numstat` 证明 additions+deletions 总和 `<=400`。未执行 skeleton、估算行数或删除 oracle 均不得放行，失败必须回 PLAN 拆片。该条是对 design 的前置条件，而不再只是 acceptance 末端预算检查。

本轮审查确认的是门定义完整；prototype 的实际行数与执行证据应由随后的门③产生，不能在 requirements review 中预先宣称已满足。

### R-I1 已闭合：五项 grammar 与分类唯一

定位：`requirements.md:21,23,25-33,39,55-56`。

R4 已给出实际五行判定表，而非把定义推迟到未来文档：

- boot：ASCII trim 后只允许 `0|1`，空/其他非空、business `0` 与 PASS `1` 分离。
- system_server：`[1-9][0-9]*` token 列表，空为 business FAIL，`0`/前导零/其他字符为 parse FAIL。
- crash：复用 R3 的唯一 btime、header/早期记录、`>=baseline` 与畸形数字 token 规则。
- service：完整行 grammar、精确 `sidebar` 服务名、空/合法缺服务/任一畸形行/PASS 均有唯一分类。
- package：完整 ASCII package-name grammar；只有语法合法的空/缺目标为 SKIP，任一畸形行 parse FAIL，目标完整行 PASS。

R7 要求覆盖 R4 每个适用格，R4 又明确 N/A 不得伪造成其他类别；query failure 则由 R2/R7 的六查询矩阵单列。因此 package SKIP、PID/service token 和 parse-vs-business 已可机械判定。

### R-I2 已闭合：serial 与 help 有精确正负 oracle

定位：`requirements.md:19,39,54,65`。

- R1 已逐字固定 serial allowlist `^[A-Za-z0-9][A-Za-z0-9._:-]*$`，并固定解析/重复/help 组合 → real allow-skip → serial → ADB 的拒绝优先级。
- R7 已点名 missing、`-bad`、路径分隔符、空白、控制字符及两个边界合法 serial，并要求核 rc、调用次数/顺序与统一 `-s` 串号；这覆盖 common canonical provider，不再依赖只覆盖旧入口的 01 测试。
- 单独 `--help` 已固定 rc0、stderr 空、零 ADB、stdout 参数集合与文档一致；help 组合则固定为前置 rc2。

### R-M1 已闭合：mandatory 语气与全阶段失败收口一致

定位：`requirements.md:39,43-45,49-61`。

- R7 已改为“当运行……必须”，主矩阵不再有条件式逃逸。
- R9 强制 candidate、full-history、真实 file-URL depth-1、exact rollback 四路；contract 与 offline 的不同固定摘要分别定义，depth-1、静态工具、manifest、converge 和后序资产缺席也均为硬门。
- R10 对查询/解析/fixture/case count/cleanup/static/budget/checkout/rollback/顺序门任一失败统一要求非零、禁止固定 PASS、清理 repo 内外状态，且禁止删 case、放宽 grammar 或忽略工具失败继续推进。它与 R9 的成功条件互补，不再允许失败后固定摘要假绿。

## Round 2 finding 闭合表

| Round 2 finding | Round 3 状态 | 裁定 |
|---|---|---|
| P-B1 05/09 common 同文件与 rollback | **已闭合** | 独立 physical provider；09 永不修改；物理缺席切 09-owned fallback |
| R-B1 缺 design-time runnable sizing | **已闭合** | R8 明确门③前 fixed-format runnable exact3、全矩阵、`<=400`，失败回 PLAN |
| R-I1 五项 grammar/判定表不完整 | **已闭合** | R4 五行 grammar、empty/business/parse/PASS-SKIP/N/A 全部固定 |
| R-I2 serial/help oracle 不完整 | **已闭合** | 精确 regex、missing/unsafe/boundary、单独 help 与组合失败均已点名 |
| R-M1 mandatory/失败收口 | **已闭合** | R7 mandatory，R9 四路 mandatory，R10 全失败族 fail-closed |

## 两个独立结论

### 规格符合性

**PASS。** PLAN 与 requirements 现在一致交付独立 canonical provider/doc/test；02/04a 只提供既有门禁与顺序证据，09 独占旧入口、dispatcher、fallback/parity。05→09 的 present/absent、文件 owner 和独立回滚均可机械解释，没有跨越 01/02/04a/06/07/09 边界。

### 需求质量

**PASS。** CLI、六查询、五项 grammar、时间边界、PASS/FAIL/SKIP/rc、demo/real fixtures、matrix coverage、design sizing gate和四路验收/失败收口均已形成唯一且可执行的判据；未发现新的假绿、遗漏或不可实现冲突。

## 熔断裁定

第三轮无剩余 finding，**无需触发 fix_loop_max=3 的承重裁定或新增 PLAN 回流**。门②可按 PASS 收口；下一阶段必须实际执行 R8 所定义的门③ prototype，只有 fixed-format exact3 完整矩阵实跑且 churn `<=400` 才可进入 tasks/implementation。

## 最终裁定

**PASS — PLAN B0/I0/M0；requirements B0/I0/M0；合计 B0/I0/M0。**
