# Final v1 独立状态接口

本层实现最终制作包中的案件、时间、保管权和恢复规则，以及用户最新明确覆盖的[开封与察觉规则](USER_RULE_OVERRIDES.md)。已提供独立宿主、档案册与物件台接口；模型测试不等于完整流程或参考游戏体验验收。

## 文件与边界

- `scripts/rebuild/final_case_state.gd`：`FinalCaseState extends Node`，唯一业务状态为 `state`；不引用旧 `GameSession`。
- `data/rebuild/final_cases.json`：五封最终正文逐字保留于作者数据，23 条外部线索。正文来源为原包 `04_VERTICAL_SLICE/CASE_BIBLE_FINAL.md`。
- `scripts/rebuild/mail_physics_state.gd`：独立物件模型；核心直接复用它的初始化和完整快照校验，不复制另一套物件阶段规则。
- `tests/final_case_state_smoke.gd`：状态与物件公共 API 联动、显式时间边界、损坏存档和恢复检查。每次使用隔离 QA 存档路径。

当前存档默认 `user://final_v2/progress.json`。原 final_v1 和更早存档不加载、不猜测迁移、不覆盖；旧 `opened` 布尔无法证明实际重开次数。信件 ID 沿用 `case01`–`case05` 只是稳定标识，不能据此把旧 Nora/18:00 规则当作同一存档内容。

## 给交互层的接口

| 行为 | 方法 | 约束 |
|---|---|---|
| 新班次 | `new_game()` | 09:00，无实时倒计时；只放出 Case01 |
| 取出实物 | `take_case(id)` | 邮局保管物只能在邮局取；已交付物不能取回 |
| 观察正反面 | `inspect_envelope(id, side)` | 不扣时，不授予正文；只处理在手未处置信件 |
| 保存无工具观察 | `accept_inspection(id, snapshot)` | 完整模型校验与合法观察重放，只允许翻面、视野、完整信封移动；不能增加破口、材料状态或正文权限 |
| 查看开封余量 | `remaining_openings()` / `can_open(id)` | 整班共三次；已真正破开的本轮可继续抽出与展开 |
| 提交真实破口 | `accept_opening_breach(id, snapshot)` | 活动开封中，模型首个有效破口立即提交；序号幂等，禁止历史倒退或跳号 |
| 场景资料/当面答复 | `observe(clue_id)` | 检查地点、实际时点及知情者在场；首次来源/时刻保留 |
| 人物相遇 | `meet(npc_id)` | 记录实际地点、时刻及已知姓名 |
| 旅行 | `travel(destination, previewed_minutes)` | 调用者必须先明确预览 15 或 30 分钟；确认后调用一次 |
| 长帮助/检索 | `perform_time_event(kind, unique_id)` | `long_help`/`kitchen_help` 30 分钟，`records_retrieval` 15 分钟；稳定编号防重复扣时 |
| 找到旧档案件 | `discover_archive_box()` | 先查明 June 当前合法收信点，再在邮局发现实物箱 |
| 登记受托交付 | `agree_handoff(arrival, route_confirmed, no_signature_required)` | 已看规则、与尘缘在场确认；约定到达早于 17:30 |
| 明确等候回执 | `wait_for_handoff()` | 仅邮局、未到回执；推进到约定到达一次并结算察觉。UI 须先显示剩余分钟；阅读不触发 |
| 查看处置前提 | `can_dispose(id, action, target, note)` | 返回空串表示可尝试；错误串不提交动作 |
| 实际处置 | `dispose(id, action, target, note)` | 错投可纠正；迟到未送仍保留邮袋，回邮局才登记 |
| 正式处理单 | `record_resolution(id, result)` / `resolution_view(id)` | 实际处置后回邮局盖章；玩家判断与真实去向分开保存 |
| 档案草稿 | `record_archive_draft(claims, sources)` | `hv_person`/`desk`/`formal_code`，只可引用已观察来源；错猜仍是未确认草稿 |
| 收工 | `end_shift()` | 五件都有去向或合法未决记录；事实重建与伦理去向分开 |

除明确返回布尔的存档方法外，业务动作返回 `String`：空串成功，非空串为未成立原因。状态改变发出 `changed`。自动存档失败通过 `save_failed(message)` 和 `last_save_error` 告知；UI 必须显示该问题，不应把动作完成当作磁盘已保存。

`state.tutorial_first_case_completed` 在 Case01 真实处置后，回邮局盖好正式处理单时产生；只有它为真，Case02 / Case03 才可取。交付、退回和合法未决记录都支持完成第一封教学，但都仍须回柜台盖单；错投、单纯翻看或仅交出物件不能跳过。旧档箱发现也检查此门槛。UI 读取该标志引导流程，不可直接写它来解锁。

## 避免向玩家泄露作者答案

UI 使用 `case_view(id)`、`body_text(id)`、`known_person_label(id)` 和 `dossier_view()`。

`case_view` 只返回实际观察过的正反面、完成抽出及展开后已知的正文/附件。档案视图区分带来源/地点/时刻的 `observations`、玩家 `draft` 和收工后有来源支撑的 `confirmed`。未知人物标签为“尚未确认身份”。作者工具用 `case_data`、`clue_data`、`catalog`，这些包含完整原文和规则，不能直接绑定为玩家列表。

## 物件操作接线

1. 从 `case_state(id).physical` 初始化 `MailPhysicsState.restore_state(snapshot)`。
2. 调用核心 `begin_operation(id, mode)` 和模型 `begin_operation(mode)`，模式为 `repair_exterior`、`open`、`reseal`、`amend`。修改模式另用下节的安全选项配置模型。
3. 输入全部交给物件模型；`changed` 在 `opened_count` 增加时立即调用核心 `accept_opening_breach`，其余变化用于显示，不在拖动中自动写盘。`finish_operation` / `cancel_operation` 同样校验计数，不能绕过上限。
4. 模型 `operation_completed(mode, snapshot)` 后调用 `finish_operation(id, snapshot)`。正文必须已实际抽出并完整展开。Case03 外修永不自动授予私人正文或照片。
5. 明确退出时先调用模型 `cancel_operation()`，再把 `export_state()` 交给核心 `cancel_operation(snapshot)`。取消保留已发生的损伤、破封、半抽出/半折回和知情历史；只释放临时工具输入。
6. 操作明确结束/退出后方可 `save_game()`。活动工具模式下保存被拒绝。再次进入直接恢复完整快照。

工作可靠度、NPC 信任、隐私越界、被察觉拆痕是不同状态。细致打开仍可能越界；隐藏行为不会令 NPC 自动知情。用户新规覆盖原包：整班最多三次实际破封，含内部工作封；同封封回重开也再计。第三次允许、第四次阻止，封回不退次数。私人信开封后须真实折回、装回并封合才能交付；累计三次不同邮件在收件时被察觉拆痕，声望降至最低并触发可恢复失败。没有单次八次手滑即坏结局。

## 五案的最终区别

- Case01：Elsie Moran，旧街名、瓷质 17 与当前 Bay Steps 地址；可完全不拆投递。
- Case02：Mira Vale，17:30 前当面优先。设备单 `returned 15:05` 在 15:05 前不可见。委托先交给尘缘，约定到达事件发生后才变为 Mira 保管。诚实的迟到未送说明合法。
- Case03：June Arlen，获准外标签修复；原 Rose Court 3C 与旧 North Pier Hostel 转寄均须和当前资料核对。社区批准收信格可转递，无硬截止时间。
- Case04：June 本来就写在信封上；六年前旧件的处置为交付、归档复核、待核实。归档不是寄回 Mira；不强制集齐全部四条背景信息，不自动评分伦理选择。
- Case05：处理 Case04 后实际观察账簿重复 HV，才可从账簿夹袋拿内部封。已投出的旧信可用账簿记录比对，无需拿回实物。职员内部信可合法读，也可不读而归档；三个去向都合法。

## 存档与中途失败

保存信封格式为 `solmere-final-production-state` v2，包含原样 `payload_json` 和其 SHA256。状态另记 `rules_version`、全班 `opening_history` 与各封 `opened_count`。先写并校验 `.tmp`，保留上一份有效 `.bak`，再在同目录发布主文件。损坏主文件只从有效备份恢复，残留临时文件不当作进度。不同格式、版本、规则版本或 catalog 的文件禁止覆盖，须另选槽。

已实现两段有依据的规则升级：本日 `openings-and-detection-v1` 到 `tutorial-and-openings-v2`，从真实 Case01 处置回填教学进度，或对后续仍全新未动的班次施加新锁；不推测越序进行中的教学完成。后者到 `tutorial-openings-amendments-v3` 时，物态 v2 的开封次数逐项保留，新增改写/附件字段按旧版没有这些操作的确定原始基线初始化；不虚构改写历史或目击阅读反应。两段均处理有效检查点和委托前快照。读取保留原文件字节，显式保存才发布升级后的内容。不是旧 final_v1 存档迁移。

每封实物都经过完整模型校验；同时检查可用性、保管权、去向、阅读历史、隐私记录、证据来源和有界恢复点。仅校验和正确不代表业务状态有效。

`report_loss(id, recorded, note)` 表示已发生的实际遗失事件，不是 UI 的“制造失败”按钮。三次不同未登记严重遗失触发职业中止；这是明确列出的可调初值。单次错投、合法待核实、迟到或伦理选择不触发中止。

`can_resume_failure()` / `resume_checkpoint()` 恢复最新严重事件之前，保留此前班次的时间、旅行和已发生记录。检查点不嵌套自身，失败及恢复点均可跨重启。普通取消物件操作不调用此回退入口。

新失败类型 `repeated_detected_tampering` 的阈值为 3；字段含 `case_id`、`count`、`threshold`、`message`。第 3 次强制 `work_reliability <= -3`，对应最低声望档。直接交付恢复交付前；延迟委托保存真实 `pre_handoff`，到达后触发失败时恢复交给尘缘之前，撤回此后至回执到达的行动。开封与已知事实保留到该检查点，邮件重新由玩家保管，可改做合法待核实。宿主须在交付及推进时间的动作后优先检查 `state.failure`。

待到达的受托回执不能被提前收工跳过。`end_shift` 在此时返回原因；宿主可在邮局显示 `arrival_minute - minute` 分钟的明确等待动作，调用 `wait_for_handoff`。这个动作可能收到第 3 次拆痕察觉回执，所以同样须优先显示失败。

## 已声明的设计初值

原包未给出的精确日历、替换门牌号、拆痕阈值、可靠度区间及重复严重失职阈值均列在 catalog `implementation_defaults`。它们不是对参考游戏的测量值。没有继承旧版公交时刻，也没有按“处理几封信”强制跳到下午。

具体路线所需 15/30 分钟、人物现场动画和输入层、班车预览以及参考体验须由后续场景层实现和实测。本状态层通过不代表这些 UI 已完成。

## 有限改写与附件 API

用户已确认保留此前五案，新锁定方向文档补充系统表现。`data/rebuild/player_amendments.json` 是独立的获准变体表，原 `final_cases.json` 正文及最终包不改。只有旧 Case02 的挽留动机句、Case04 的离开句可擦除或放入唯一获准替换条；Case03 只有原灯塔照片可取放。无任意文字输入。

| 接口 | 接线约束 |
|---|---|
| `amendment_options(id)` | 仅仍在玩家手中、实际拆开取出并完整展开的受支持邮件返回 `slots` / `attachment`；给模型 `configure_amendments`。只含原句、有限选项与语义预览，不含未来人物反应。 |
| `begin_operation(id, "amend")` | 与既有操作相同；模型必须经过实际擦除区段、替换条落位或照片落区。`operation_completed` 再交 `finish_operation`。 |
| `source_body_text(id)` / `body_text(id)` | 前者是玩家已经读过的原稿记录，后者是已确认改动后的现稿。尚未读过都为空。部分擦除只保存物理覆盖区段，不能把它当作完整新句；工作台按 mask 绘制。 |
| `pending_recipient_readings(person_id)` | 仅在场、已遇见该 NPC，且存在实际收到但未目击阅读的回执时返回邮件 ID；无远程反应。 |
| `witness_recipient_reading(id)` | 宿主实际播放在场阅读时调用一次，成功后用 `recipient_feedback(id)` 显示反应。重复调用不重复扣分或改变故事。 |

`state.cases[id].alterations` 保存原文 SHA256、已确认的 `edit_key/option_id`、照片是否随信、连续变更历史及阅读回执。物态 v3 保存部分擦除 mask、替换条与照片的位置；原句不写入物态。取消保留实际材料变化，普通 `accept_inspection` 不能注入修改。照片取出后仍是桌面上的同一件物体，放回保留曾移动历史；没有复制附件。

原稿→擦空→粘入指定替换条是本轮有限流程，不提供反复擦掉替换条或恢复原稿。改写不额外扣开封次数、不修改截止时间或路线、不自动损伤声望。实际纸面痕迹达到现有收件检测阈值时沿用既有处罚；反应只讨论对方收到的内容或看见的痕迹，不能凭空知道原稿。直接交付、委托实际到达、批准收信格均先生成待阅读记录；现场目击才释放文案。第三次察觉后的恢复保留交付前已修改的实物，不替玩家恢复原稿。

有限改写首次冻结证据为 2952 项 / 0 失败，其中该轮改写及恢复边界 1203 项。处理单接入后的当前结果见下节。测试用模型公开动作验证，不冒充 GUI、真人或参考手感验收。原 catalog SHA256 仍为 `11643fd4e3cd3073b290aec3088151906e14189799f49cd4c4c9a3f36cabbee4`。

## 正式处理单 API（规则 v4）

宿主真实印章操作完成后调用 `record_resolution(id, result)`。`result` 只接受四个键，组件另发的 `case_id` 须由宿主取出作第一个参数，不留在 result：

```gdscript
{
    "determination": {"recipient": "玩家填写的判断", "location": "玩家填写的现址", "status": "玩家填写的状态"},
    "disposition": "hold_for_verification", # 必须等于此件已执行 disposition
    "note": "玩家的处置说明",
    "stamped": true
}
```

判断三个字段均为非空文本，各最多 80 字符；说明最多 500 字符。允许未核实或错误判断，不补充作者答案、不把盖章等同于事实确认、不自动改变声望或时钟。核心仍只记录正式单；未盖章草稿由宿主的独立 `ResolutionDraftStore` 保存，不能通过草稿写入盖章状态。

动作仅允许在邮局、邮件已可用且真实处置后、无活动工具/失败/结束时调用。成功记录 `state.cases[id].resolution`，附上真实邮局登记分钟、地点及 `legacy_resolution:false`。完全相同的重复回调幂等，不重复记日志；不同内容不能覆盖已有正式单。`resolution_view` 返回副本。`stamped:true` 是实体 UI 操作结果的接口约定，不是脚本调用权限或防作弊凭证；UI 不可自动代盖。

收工仍要求五件已处置，另须全部完成处理单。委托尚未到达时，即使处理单已盖好仍须先明确等回执；察觉失败不会被盖章绕过。首封未盖单是有效可保存的中间状态，继续游戏后仍待盖单。

规则由 v3 升至 `user-2026-10-01-postal-resolution-v4`，保存 envelope 仍为 v2。已处置的旧 v3 邮件使用明确的 `legacy_resolution:true` 延续进度：`stamped:false`、`recorded_minute:-1`、空地点/判断/新说明，只保留旧的真实 disposition。它不是伪造过去盖过章或写过判断。旧结束状态、有效恢复点与委托前快照一并升级；读取不改原文件，显式保存才发布。

当前证据为 `test-results/final_case_state_results.json` / `final_case_state_smoke.log`：Godot 4.7.2，3135 项 / 0 失败，其中 54 项专门检查处理单边界；其他夹具也通过公开 API 完成首单后再取后续邮件。日志只有既有 Windows 系统证书库启动警告，无脚本错误。未触及正式存档。


## 宿主未盖章草稿

`resolution_draft_store.gd` 将 UI 草稿存入当前 `core.save_path` 旁的 `.drafts-v1.json`，不改变核心存档格式。仅允许收件人/地点/状态（各最多 80 字符）、实际处置 ID 和说明（最多 500 字符）；不允许 `stamped` 或作者答案字段。窗口关闭准备和返回封面先捕获正在填写的纸面，关闭组件也保存；续档仅恢复与当前真实处置一致、尚未正式盖章的草稿。

旁档采用校验和、临时文件发布及有效备份；未知版本保留原字节并阻止该次退出，纸面仍可编辑并重试。确认开始新班次会清空本班草稿及旧班次恢复副本，避免以后从损坏副本复活上班次文本。实际盖章仍唯一调用核心 `record_resolution`；草稿保存不解锁下一封、也不能收工。

当前局部验证：`test-results/final_resolution_draft_results.json`，实际 GPU 输入 42 项 / 0 失败、114 个键鼠事件。覆盖正在填写时保存、重建宿主续读、正常关闭、失败后重试、未知版本与伪盖章字段保护、损坏备份恢复。前置邮件由公开核心 API 建立；这不是完整五案玩家流程或 OS 窗口关闭测试。
