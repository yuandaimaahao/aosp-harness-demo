# 03b tasks 独立审查 round 3

结论：**NEEDS_CHANGES，达到 fix_loop_max=3，交controller熔断裁定。** Blocking 4、Important 7、Minor 0。

阻断项：任务1.2 builder仍缺probe定义/切换且断言未来marker，sentinel缩进不一致；中间Python缺`errno/ctypes/secrets/signal`和临时dispatch/publish；partial/固定工具步骤没有完整命令与变量；任务2.3仍把full/depth/rollback/order/manifest/ledger塞在一起。重要项：test片段重叠；red资产未真实落盘；manifest awk不完整且fix后HEAD漂移；尾部状态动作过多且脚本参数不全；base=head review未定义evidence package；checkout命令/逐日志计数不完整；顺序门缺正式ID和限定搜索域。

controller裁定全部为承重finding并修复，不挂账：放弃不可靠的逐函数中间态，改为从已实跑、固定格式、设计三轮review后的`a708ce6`机械落地完整208行runtime，再以唯一路径转换机械落地192行base test；这消除builder、import、sentinel和片段重叠。candidate、full、depth-1、rollback、order、terminal拆为六个独立controller任务；每任务规定red/green/evidence package schema、完整变量、独立review与六列manifest。candidate发现源码缺陷必须回流实现任务，验收任务不得漂移HEAD；full/depth使用明确clone、HEAD、四上游SHA及分离default/offline日志；顺序门使用两个正式ID和限定ledger/work路径；terminal提供完整八行awk。

如果该裁定错误，代价是两个实现diff分别为208/192行，单次人工review可能接近10分钟上限；缓解依据是两blob已由design原型固定工具、base/assurance、三轮独立review和mutant反证验证，implementation review可先机械`cmp`确认零算法偏移。若保留原拆法，已证实的代价是执行到中间commit即NameError/截断builder，red/green证据无效。
