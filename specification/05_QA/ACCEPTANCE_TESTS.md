# Acceptance Tests

## AT-01 LOCKED ASSETS
Given 用户锁定素材已经导入  
When 构建和运行游戏  
Then 原文件 SHA256 不变化，且不存在任何 AI 重绘替代文件被自动使用。

## AT-02 CASE 03 NO-OPEN PATH
Given 玩家拒绝拆 Case 03  
When 玩家访问居民楼 + 至少一个额外线索地点  
Then 玩家仍能推断正确去向并完成案件。

## AT-03 CASE 03 OPEN PATH
Given 玩家选择拆 Case 03  
When 完成拆信与修复  
Then 获得强线索、tamper_score 更新、信封外观呈现修复结果。

## AT-04 DELEGATION
Given Case 02 仍在玩家手上且尘缘可代送  
When 玩家委托尘缘  
Then 玩家节省移动时间，同时该信不可再拆且错过观景台提前线索。

## AT-05 CASE 04 FAIR DEDUCTION
Given 玩家从未拆 Case 04  
When 收集旧门牌 + 活动档案 + 笔迹/照片中的任意三条独立证据  
Then 可以合理锁定 Mira → June，而不依赖猜测。

## AT-06 CASE 04 MORAL OUTCOME
Given 玩家已经客观推理正确  
When 选择 Deliver / Hold / Return 之一  
Then 当日晚间出现不同可感知反馈，但 UI 不评价善恶。

## AT-07 CASE 05 END
Given 前四案已经进入已处理状态  
When 玩家打开 Case 05 并选择 File/Keep/Destroy  
Then 日终结算完成，存档有效，主谜题钩子出现。
