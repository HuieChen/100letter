# Codex 实施顺序

## Phase 0 — 资产保护与项目扫描
- 读取现有项目。
- 导入 LOCKED 素材。
- 对照 SHA256，不写回原文件。
- 建立 `assets/locked_user/` 只读约定。

## Phase 1 — 可运行壳
- Title
- 邮局主场景
- 5 封信数据加载
- 地图
- 地点切换
- 基础存档

验收：可从标题进入邮局，打开地图，去一个地点再回来。

## Phase 2 — 信件实际交互
- 拿起、拖动、翻面、缩放
- 状态保存
- 档案并排

验收：Case 01 能完整解决。

## Phase 3 — 地点调查与 NPC
- 热点系统
- 尘缘对话
- 线索记录
- NPC 代送

验收：Case 02 双路径可完成。

## Phase 4 — 拆信与修复
- 拆信工具
- tamper_score
- 碎片拼合
- 修复

验收：Case 03 可实际操作完成。

## Phase 5 — 高级推理与 Case 04
- 笔迹/照片/日期交叉线索
- 少量提问
- 延迟确认
- Deliver/Hold/Return/Attachment 分支

验收：三种主要选择均有后果。

## Phase 6 — Case 05 与日终
- 主角信
- File/Keep/Destroy
- 日终状态
- 自动存档

## Phase 7 — Polishing
- 所有过渡
- 交互音效
- hover / drag 反馈
- 文本节奏
- 性能
- 无 debug 占位

## Phase 8 — QA
执行 `05_QA/QA_PLAYTEST_CHECKLIST.md`。
