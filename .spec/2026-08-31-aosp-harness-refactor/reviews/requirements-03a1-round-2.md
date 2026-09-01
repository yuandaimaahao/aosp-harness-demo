# 03a1 requirements review — round 2

Reviewer: `review_plan_v5_2`

Verdict: **NEEDS_CHANGES** — blocker 1 / important 0 / minor 0

前四项finding基本闭合；新blocker是损坏provider与core-unavailable组合态优先级未定义，round3原型先判core会把损坏anchor误报inert PASS。要求provider存在时先验anchor，结构损坏始终fail closed，再判core/flag，并补八个组合case。
