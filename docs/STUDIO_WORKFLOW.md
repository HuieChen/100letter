# Solmere 工作室制作流程

来源：[Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)，固定 MIT 提交 `b21fa0f7f289fc3e726cf36fb12b9bc1e7a51e4d`，实际49个角色、74个技能。主管/专业职责、设计→实现→反向审查→交接和七阶段结构现已落为本工程的配置、故事与可执行命令。

当前执行是 **sequential_role_passes**：按具名职责顺序执行，产生各自检查记录。没有启动49个并发代理，也不能把顺序审查说成独立多代理验证。来源 hooks、模型、权限与批准提示不自动运行；用户此前已授权修改和 main 发布。

## 项目结构

- `project.yaml`：JSON语法的合法YAML，固定Godot入口/布局、七阶段、责任父级与修改范围。
- `design/`：游戏制作锚点、实物交互合同；之后叙事/美术/音效按需落在对应部门。
- `production/epics/`：八条有序故事，每条只有一个实施责任，写明验收、参考需求、输入、依赖与审查职责。
- `production/studio-board.json`：当前唯一故事和未解决问题；现有实现不会自动变成已验收。
- `scripts/rebuild`、`scripts/ui`、`data/rebuild`、`assets`、`tests`、`tools`：保持现有游戏真实文件位置与旧存档。
- `docs/architecture/STUDIO_BOUNDARIES.md`：玩法、UI、物理状态、声音与制作管线的边界。

## 实际操作

```text
python tools/studio.py status
python tools/studio.py ready --chain book
python tools/studio.py dispatch --chain book
python tools/studio.py impact --path scripts/rebuild/final_playable.gd
python tools/studio.py run --chain book --godot <已安装的Godot路径>
python tools/studio.py finish --chain book --evidence <当前相对路径> --review <职责记录相对路径> ...
python tools/studio.py handoff --chain book --evidence <当前相对路径> --review <职责记录相对路径> ...
```

`dispatch`真正写出角色任务、技术参考、输入指纹、责任边界和具名输出路径。职责要读自己的源定义技术部分并检查实际代码/画面，不执行定义中的外部设置。UI程序员实施；UX检查真实动作与首次玩家；美术指导检查认可素材内的纸边和视觉层次；Godot职责查输入/锚点/生命周期；QA-lead反向找错；sound-designer试听触发与层次。producer登记顺序、交接和跨部门影响。

审查记录必须包含 `role / chain / execution / basis / observed / criterion_results / artifacts / verdict / findings`。所有验收项须被具名职责用当前证据覆盖。`PASS / REWORK / NOT_ASSESSED`严格区分；缺试听、实机或新手观察不能写PASS。程序校验完整性，不证明报告文字就是事实。

`finish`不修改状态。缺角色记录、漏验收项、错误/过期输入、改变的证据或缺原生检查会返回`NOT_COMPLETE`，退出码2。`handoff`运行同一检查，仅全部满足后保存完成凭证、更新当前故事；失败不推进。后续改了运行时源码，依赖的旧完成凭证失效。`impact`列出共享改动影响的故事和职责，由实施者实际回测；不自动发消息或拦截所有编辑。

`bag/map/npc/walk`映射现有完整核心输入检查，明确是共享核心套件而非单链专属或原生玩家测试。三信没有映射成熟测试，仍不能拿旧五案套件替代。缺原生操作、试听、首次玩家清晰度证据时不关闭故事。质量门槛不因工作室结构增加而降低。

## 本轮使用情况

源码指纹仅统一Git正常转换的CRLF/LF，跨Windows/Linux不误判过期；任何内容变化仍会使审查过期，适配器逻辑也计入审查输入。截图、日志与其他证据仍按原始字节校验，保留目录禁用Git文本转换。

实际从档案开始生成六份具名职责任务，执行当前引擎输入检查，记录源码审查、排版截图观察和尚未执行的实机/试听项。详情见 `docs/testing/STUDIO_PRODUCTION_20261003.md`。本轮未修改运行时或重画素材；制作管线测试与游戏测试分别记录。CI检查来源完整性、制作结构和证据拒绝逻辑，不宣称最终游戏验收。
