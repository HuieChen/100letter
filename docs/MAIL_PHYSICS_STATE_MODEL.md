# 最终包邮件物态模型：接口与验证边界

2026-10-01。实现为 [mail_physics_state.gd](../scripts/rebuild/mail_physics_state.gd)，独立于旧版 Main、GameSession 和旧物理 UI。新 [MailWorkbench](../scripts/rebuild/mail_workbench.gd) 已用实际输入接入本模型与 FinalCaseState；宿主功能仍在独立回归。模型本身不持有时钟、NPC 信任、职业可靠性、邮件保管权，也不写游戏存档。

依据：Case Bible（本地历史资料，未随公开源码发布）、外部检查（本地历史资料，未随公开源码发布）、修复操作（本地历史资料，未随公开源码发布）、架构（本地历史资料，未随公开源码发布）。参考动作未核验部分继续见项目的 `REFERENCE_INTERACTION_BREAKDOWN.md`、`REFERENCE_AUDIO_MOTION_BREAKDOWN.md`；这里不把几何算法当成原作操作证据。

## 公共接口

所有返回 String 的方法以空字符串表示接受，非空为稳定的错误 ID。`visible_crease` 是产生真实纸面损伤的接触结果；它与普通拒绝不同，调用后仍应同步物态。不得把所有非空返回都当作“什么也没发生”。

| 接口 | 职责 |
| --- | --- |
| `setup(case_id)` | 创建 case01–case05 的初始物态；不授予调查线索 |
| `begin_operation(mode)` | 进入 `repair_exterior`、`open` 或 `reseal`，只切换操作上下文 |
| `inspect_face(face)`、`set_inspection(zoom, pan)` | 翻正反面、1–3 倍观察；不公开私人正文 |
| `select_tool(tool)`、`return_tool()`、`tool_contact(position)` | 持用抽象工具、归还、实际接触物件；仅选工具不改变材料 |
| `object_rect(id)`、`begin_drag(id, position)`、`drag_to(position)`、`release_drag()` | 有抓取偏移的实际物件移动；接触、位置、顺序守卫在同一模型 |
| `rotate_held(quarter_turns)` | 只旋转已拿起的外标签碎片；不会代选正确角度 |
| `cancel_operation()` | 清工具、抓取和当前模式；保留破封、半抽出、折叠姿态、痕迹与已读历史 |
| `export_state()`、`restore_state(snapshot)` | 深拷贝 JSON 可存快照；载入验证原子化，拒绝非法跨字段状态，不改旧有效状态 |
| `visible_label_field_ids()` | 修复后背面可见的 5 个字段 ID，不返回推断结论 |
| `body_is_currently_visible()` | 当前页在桌上且有折页打开时为真；不是永久已读标记 |

`changed(snapshot)` 用于呈现/核心同步，不是逐帧自动保存命令。`operation_completed(mode, snapshot)` 只在实际步骤到达完成边界时发出。输入适配层应先在失焦/普通退出时取消捕获，再把稳定物态交给核心的取消/明确保存边界；不得通过还原操作前快照擦掉痕迹。架构禁止拖拽中途自动存盘，本模型没有文件 I/O。

## 三条物理链

**Case03 授权外修：** 放到垫板 → 看正反面 → 接触翘起标签 → 拿起、旋转并对齐 → 盖保护片 → 工具接触压合 → 对齐外折痕 → 翻面复查。只在 case03 接受该模式，完成不设置 `opened`、`body_exposed` 或 `privacy_violation`。原有封口保持关闭。修复后 UI 应从 `case_data("case03").envelope.recovered_fields` 取以下文字：

`original_address`、`forwarding_recipient`、`forwarding_destination`、`forwarding_valid_from`、`forwarding_valid_until`。

不硬编码“已过期”答案。日期 `2024-07-20` 和 `2025-07-19` 属于新 catalog 明确标注的补充默认，不声称为上游包提供的精确日期。当前模型是一张可旋转翘起标签，不冒称已实现旧版六碎片拼图或多层纸纤维仿真。

**开封：** 取得有足够空间的工位 → 拿工具 → 顺序接触 9 个封线区间 → 归还工具 → 抓纸边抽出 → 分别拖开两个折页 → 最后一折松手。封线完成不自动抽纸或显示全文。连续沿已工作封线的小步采样不会重复误计损伤；跳到远处未工作段不被当作完成。只有最后的明确释放产生 `open` 完成事件。

**折回封合：** 按折线分别折回 → 纸张实际拖入开口并释放 → 封舌拖合并释放 → 封合工具实际接触。半抽出但尚未展开也可以重新装回；该分支保留越界历史，不凭空授予正文知识。按按钮选择模式或工具不能替代这些步骤。

## 快照与历史

`version = 2` 增加真实开封次数。版本 1 只有历史布尔值，无法知道同封重开多少次，因此拒绝自动导入，不猜测次数；核心使用独立新存档槽保留旧记录。内部阶段、坐标与摘要一并保存，核心不应裁掉未知内部字段。字段数量、类型、有限数值、范围、几何可达性和关键状态关系均验证。

| 字段 | 含义 |
| --- | --- |
| `tampering_started` | 首次实际破坏接触；即使只误伤纸而封口未打开也为真 |
| `opened` / `opened_history` | 实际封线首次破口的历史，不随封回消失 |
| `opened_count` | 每轮第一个有效破口递增，同封封回再开也计；仅选工具、未碰纸取消、封线外误伤不计 |
| `privacy_violation` | case01–04 实际动手破坏私人邮件的历史；case05 内部工作件例外 |
| `body_exposed` | 曾展开到足以出现内容；取消、折回后仍保留 |
| `body_unfolded` / `unfolded` | 曾完整抽出并展开，在最终释放时提交的历史 |
| `open_cycle_completed` | 当前这一轮开封是否已提交；与历史已读分开，支持第二次重开中断 |
| `folded`、`inserted`、`resealed` / `restored` | 当前折好、装回、封合状态，不代表“没拆过” |
| `tamper_trace`、`permanent_damage`、`irreversible_damage` | 材料状态与不可擦除的损伤底线，不是道德分 |
| `completion_serial` | 完成边界计数；选择模式、取消和载入不会递增 |

普通误触不触发游戏终局，`damage_failure` 固定为 false；严重失职累计、发现痕迹及工作后果由核心另行处理。按用户新规则，整班最多三次实际开封，case05 内部合法件也占次数，但不产生顾客隐私违规。适配器在第一次有效破口的 `changed` 信号里即时调用 `accept_opening_breach`，不等抽纸或全文完成；核心阻止第四轮，已破开的当前物件仍可继续抽出、阅读、封回。

当前每轮首次破口痕迹 0.25、错误纸接触增量 1、压合质量算法和容差均为待调校工程默认，不是参考游戏复刻数据，不向玩家展示百分比。错误接触频率与连续笔划手感仍须真人调校。

桌面逻辑范围为 1180×630；开封允许信封原点最大 `(220,260)`，自由纸页原点最大 `(860,325)`，保留完整 120 像素折页拖动行程。检查时可以把完整信封移到更右侧，但模型会在真正破封前要求移回可用工位，不自动搬动物件。缩放/平移的坐标变换及视觉裁切属于后续 UI 适配职责。

## 运行证据与五轮审查

Godot **4.7.2.stable.official.ed1daf0bf** 实际执行 [mail_physics_state_smoke.gd](../tests/mail_physics_state_smoke.gd)：**607 个断言、0 失败**。结果及源/测试/契约 SHA256 在 mail_physics_state_results.json（本地历史资料，未随公开源码发布）。新增同封三轮、取消与 JSON 重载计数、合法内部件也计数、旧版本与伪造次数拒绝。当前 v2 引擎输出保留于执行工具记录，较早的工作区日志是 503 断言历史，不能混作最新版证据。

[mail_workbench_input_smoke.gd](../tests/mail_workbench_input_smoke.gd) 独立 GPU 输入回归为 **70 个断言、0 失败**，报告 mail_workbench_input_results.json（本地历史资料，未随公开源码发布），日志为工作区 `work/mail_workbench_v2_gpu.log`。包含真实 `Input.parse_input_event`、首次破口立即计数、取消读档、第三次内部件允许、第四次工具前阻止与安全退出失败重试。新教学前置通过真实检查/封回 case01 后调用合法待核实处置建立，再测试 case03；没有赋值解锁字段。它不是 OS 原生鼠标操作或真人试玩。均隔离 APPDATA；引擎仍输出系统根证书存储读取错误，测试无网络请求，不能把整份日志称为无错误。

| 审查轮次 | 本次结果与边界 |
| --- | --- |
| A 功能 | 公共模型方法与独立工作台真实输入驱动正反面/缩放、Case03 外修、私人开封、内部件例外、未读回装和完整封回；未直接改内部解谜标志或人工发完成信号。 |
| B 参考保真 | 对齐最终包的物态分步及授权界限；几何、容差与工具流程细节标为设计默认。缺少参考完整连续操作/音频核验，仍 `NEEDS_REFERENCE_REVIEW`。 |
| C 逻辑与死锁 | 修复右侧抽纸不可达、完整折页拖动终点出界、错误纸接触漏记越界、末折到位未松手不能继续、半抽出回装错误跳桌面。验证取消与 JSON 重载、当前姿态/历史分离、重复完成防护、非法快照原子拒绝。 |
| D 美术/UI/音频 | 独立工作台 GPU 截图已检查基本可读性与物件遮挡；放大坐标、Esc、模拟失焦、存档失败已测。键盘独立完成、真实触感、音频听测和整体参考风格仍未通过。 |
| E 交付 | 新工作台接入新宿主回归中；未导出新成品、未替代旧版交付。49 条整体契约不因局部用例通过而整体标为完成，真人试玩数为 0。 |

跨层示例轨迹可参考测试中的 `_repair_case03`、`_open_to_folded_page` 和 `_reseal_page`。这些辅助函数只调用公共接触/拖拽/释放 API；它们是模型测试轨迹，不是生产界面的自动解题函数。
