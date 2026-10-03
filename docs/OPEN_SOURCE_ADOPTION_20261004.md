# 开源工具实际采用记录 · 2026-10-04

按用户授权查找适用的游戏、交互、对话和测试项目。每个依赖先核对官方来源、许可证、引擎版本和实际用途。没有声称搜完互联网或把列出的候选全部装进游戏。

| 项目 | 已核实的用途与状态 | 本项目的处理 |
| --- | --- | --- |
| [GUT 9.7.1](https://github.com/bitwes/Gut/releases/tag/v9.7.1) | MIT；官方兼容表明确支持 Godot 4.7.x | **实际接入**开发测试：259 个原始文件固定到 `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605`，保留许可证，每个文件有哈希。8 项生产状态测试、580 条断言通过。 |
| [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) | MIT；角色职责、设计、实施、审查和交接结构 | **此前已经接入并继续使用**工程生产流程；顺序职责审查，不声称启动 49 个代理。详见 STUDIO_WORKFLOW.md。 |
| [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) | MIT；当前 v4 主线要求 Godot 4.6+；分支对话编辑器/运行时 | 候选。当前已有受观察事实约束的 NPC 对话。先保留其状态规则，后续新三信作者流程再评估迁移，未安装或声称使用。 |
| [Dialogic](https://github.com/dialogic-godot/dialogic) | 官方仓库的对话、角色与时间线工具 | 候选。和 Dialogue Manager 是重叠方案；尚未验证本工程状态与存档适配，不叠加安装。 |
| [Escoria](https://docs.escoria-framework.org/en/devel/) | Godot 点击冒险框架；官方提示 Godot 4 文档仍在开发中 | 候选及架构参考。核心框架替换涉及导航、库存和存档，未直接迁移。示例美术不等于代码许可证，不导入其示例画面。 |

## 可复跑的实际测试

```text
python tools/check_gut.py --verify-only
python tools/check_gut.py --godot <Godot 4.7.x 可执行文件>
```

不启用编辑器插件、autoload、自动更新或第三方 hooks。GUT 只用于开发测试，现有选定资源导出不包含它。引擎导入和测试使用独立 AppData；缺报告、断言不足、跳过或错误都判失败，不能仅凭退出码 0。原有引擎/UI 检查保留。

覆盖：未拆正文与未遇见人物不泄露；无效输入不改保管、时间、进度；重复取信不复制信封；UI 得到的字典副本不能改写原状态；主存档损坏恢复有效副本；实物工具取消后可保存、出门；远处 NPC 不能注入线索。真实状态，不用假实现或替身来让测试通过。

结果见 [GUT 复核](testing/GUT_20261004.md)。这些是模型测试，不替代 Windows 鼠标、声音试听、新手理解、参考美术或完整商业游戏验收。
