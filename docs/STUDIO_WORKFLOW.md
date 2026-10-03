# Solmere 开发工作流程

接入来源：[Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)。固定提交 `b21fa0f7f289fc3e726cf36fb12b9bc1e7a51e4d`；MIT，保留原许可证与版权。2026-10-03 GitHub API 显示 25,663 stars。当前固定版本实际包含 49 个角色、74 个技能；旧简介中的 72 是旧计数。

这是 Claude Code 的开发配置模板，不是可直接放入 Godot 的游戏插件。我们保留完整 `.claude` 来源快照供按需阅读，使用 `tools/studio.py` 将其任务审查和证据门槛适配到 Codex。快照放在 `third_party`，带 `.gdignore`，不加入游戏资源、不自动加载 Claude 设置或执行其 hooks。49 个角色定义可用，不代表 49 个进程同时运行。

## 每轮只完成一条状态链

1. 读取 `CURRENT_SPEC.md`、最新反馈、任务队列、质量门槛和锁定资产约束。
2. `python tools/studio.py brief --chain book` 生成当前状态链的分工、来源和检查范围。按需读指定角色的技术职责，不整包灌入上下文。
3. 先确定能捕捉原问题的检查，再实现该链；检查游戏逻辑、世界物件、界面/输入、声音反馈之间的边界。
4. `python tools/studio.py run --chain book --godot <Godot可执行文件>` 运行映射的真实 Godot 测试，保存独立用户数据、日志、当前源码指纹与原尺寸截图。
5. 实际窗口检查正常操作、可见 ×、Esc、错误操作、快速点击、重复进入、存档恢复、失焦、中英排版和适配。书页、纸张和交付声音要实际听，Dummy 音频测试不能证明音效质量。
6. `python tools/studio.py gate --chain book --evidence <本次evidence.json>` 核对证据。没有实机记录、截图、完整检查或存在阻断问题时返回 `NOT_COMPLETE` 和退出码 2；绝不把自动化 PASS 填成玩家验收。实机记录须由真正执行检查的人填写，程序不会自动生成通过结论。
7. 形成阶段报告，附截图/状态说明和仍未解决的问题。通过后进入队列下一条链；最后回归、打包并发布到 GitHub main。

`roles` 列出所有来源角色；`verify` 检查固定快照、哈希、角色、技能和映射。尚未映射测试的链不能用其他测试冒充验证。`tools/check.ps1` 已接入适配器校验及证据门槛回归；GitHub Actions 只验证这个接入，不宣称完整游戏实机通过。

## Solmere 对来源模板的明确适配

| 来源流程 | 本工程采用方式 |
|---|---|
| `/dev-story` → `/code-review` → `/story-done` | 一条真实交互链 → 针对相关代码审查 → 当前版本证据验收；不会虚构 Codex 原生斜杠命令。 |
| 分层角色 | 按链使用 Godot/GDScript、UI/UX、叙事、QA、音效等职责。当前为单代理顺序执行；新增代理仍须符合本会话授权和资源限制。 |
| `test-evidence-review` | 检查测试是否覆盖故障，区分缺失、失败、未知和过期；空测试、旧截图不能关闭任务。 |
| 资产审计/美术指导 | 优先保留用户认可的早间框架与当前有效美术；不得因安装模板重新设计场景。 |
| 自动化模式 | 用户已经授权的修改、测试和 main 发布继续执行，不引入逐文件许可弹窗；实际工具权限仍遵守。 |
| 引擎规则 | 本工程使用 `scripts/rebuild`、`data/rebuild`、`tests`；不搬迁到模板的 `src`，不引入 Unity/Unreal/C# 依赖。 |

审查参考职责和门槛不能代替审美、真实操作或玩家反馈。来源中的要求若与用户最新明确指令冲突，以用户要求为准；不写入全局 Codex memory。

## 当前起点

当前链仍是书本的打开、翻页、明确关闭、再次进入。已有独立 GPU 输入检查，但完整原生窗口、失焦、中英和目标分辨率验收尚未完成。三封信资料仍是作者模拟数据，没有被这里标记为已实现或实测 30 分钟。
