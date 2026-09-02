# 03b tasks 独立审查 round 1

结论：**NEEDS_CHANGES，不可进入 execute。** Blocking 6、Important 4、Minor 1。

阻断项：原任务2把capture/exec、managed fd链与大攻击表塞入同一纵切；代码步骤只给算法摘要而没有固定prototype片段；任务3–5误把完整03b1 provider-copy矩阵列为03b必做验证；任务2提前消费尚未存在的TEMP barrier；任务3–6红因不唯一；任务6在diff review前错误使用accepted HEAD。重要项：write-existing未明确接共享read oracle；首任务未说明上游接口；终产出签名不一致；manifest直到末任务才声明。次要项：六任务超过5却仍用单级编号。

全部采纳：改为七个`1.1`–`1.6`,`2.1`纵切，capture/exec与managed fd分开；每段绑定`a708ce6`具体函数/行段与唯一转换；完整动态assurance退回03b1，仅保留03b基础真实并发/信号；每个阶段设exact sentinel/rc红因；TEMP PID验证后移；先diff review/re-review再固定accepted HEAD和跑checkout/rollback；manifest从任务1创建并逐任务追加。当前spec前序产出链仍以`消费: 无`通过机械规则，另设“外部消费接口”逐字给出foundation/path/03a2协议；requirements验收清单新增终交付锚点`session-snapshot-core-v2`。
