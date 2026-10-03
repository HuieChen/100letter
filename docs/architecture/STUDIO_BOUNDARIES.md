# 工作室结构与现有游戏边界

采用固定 CCGS 的主管→专业职责→审查/交接结构，保持现有 Godot 文件位置与入口，避免重构搬迁破坏旧进度。

| 目录/模块 | 责任 |
|---|---|
| design/ | 制作锚点、玩家动作与叙事/美术/音效合同；以用户要求为准 |
| production/epics/ | 按顺序的故事、一个实施责任、明确验收、依赖和完成记录 |
| production/studio-board.json | producer 管理当前唯一故事、已知未解决问题 |
| scripts/rebuild/final_case_state.gd | 玩法规则/事实/选择与存档，不由 UI 决定正确答案 |
| scripts/rebuild/mail_physics_state.gd | 同一信件的物理操作状态与前置条件 |
| scripts/rebuild/field_book.gd / final_paper_map.gd | 书页和地图展示/输入；游戏状态归 core |
| scripts/rebuild/final_playable.gd | 现有场景、模态和移动协调；跨界修改需查影响 |
| scripts/ui/ | 共享纸张控件与音效触发 |
| tests/ / tools/ | 游戏回归、真实证据与制作管线，分别记录结果 |
| assets/faefever_v2/ | 当前认可的生成素材；本轮没有修改 |
| third_party/ | 固定 MIT 技术参考；不加载它的权限、模型、hooks或代理运行设置 |

project.yaml 是 JSON 语法的合法 YAML，记录引擎、制作阶段、各职责的父级和可修改范围。当前执行方式为 sequential_role_passes：一个执行者按不同职责顺序检查，不能声称独立多代理复核，也不能冒充49个同时运行的代理。

dispatch 写出具名职责任务与输出路径；finish 检查每个职责的当前输入、原始证据、未解决问题及真正的原生检查。handoff 仅在这些检查满足后登记完成，推进下一个故事。impact 是影响分析，不自动发消息，也不拦截 Codex 的全部编辑操作；其结果必须由实施者实际用于回测和交接。

完整游戏验收、玩家认可与商业发行仍独立于这些制作记录。缺失/失败/过期记录保持未完成，不自动生成 PASS。
