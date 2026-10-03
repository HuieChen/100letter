extends Control
## Local source inspection. Configure never grants evidence; only input can do so.
## 1600 x 900 design canvas. No scenery, author-answer list, or timer costs.
signal closed
signal cue(name:String)

const Art = preload("res://scripts/rebuild/physical_art.gd")
const DESIGN := Vector2(1600, 900)
const PAPER := Rect2(315, 164, 970, 568)
const PHOTO := Rect2(390,175,820,560)
const CLOSE := Rect2(1302, 105, 126, 54)
const OPEN := Rect2(1232, 679, 57, 57)
const OLD_PLATE := Rect2(483, 316, 236, 154)
const NEW_PLATE := Rect2(457, 285, 344, 212)
const INK := Color("34454b")
const SOFT := Color("73736b")
const TEAL := Color("427e86")
const CREAM := Color("eee7d3")
const PUBLIC_IDS := ["street_renaming", "ceramic_17", "moran_entry", "mira_absent",
	"telescope_checkout", "telescope_returned", "shuttle_timetable", "trusted_handoff_rule",
	"current_3c_resident", "june_current_mailpoint", "old_music_photo", "sea_watch_roster",
	"case04_manual_hold", "ledger_hv_repeat", "helena_rota", "procedure_codes", "ledger_returns"]

var clue_id := ""
var effective_clue_id := ""
var _core: Node
var _spec: Dictionary = {}
var _page := 0
var _photo_zoom := 1.0
var _read_rows: Array[int] = []
var _recorded := false
var _leaving := false
var _dragging := false
var _drag_origin := Vector2.ZERO
var _plate_offset := 0.0
var _plate_start := 0.0
var _focus_index := 0
var _hover := ""
var _status := ""
var _factor := 1.0
var _origin := Vector2.ZERO
var _font: Font
var _knock_wait := 0.0


func configure(core: Node, requested_clue: String) -> String:
	_core = core
	clue_id = requested_clue
	effective_clue_id = requested_clue
	_spec = {}
	_page = 0
	_photo_zoom = 1.0
	_read_rows.clear()
	_recorded = false
	_leaving = false
	_dragging = false
	_plate_offset = 0.0
	_focus_index = 0
	_knock_wait = 0.0
	_status = ""
	var error := _source_error(requested_clue)
	if not error.is_empty():
		_status = error
		queue_redraw()
		return error
	if requested_clue == "telescope_checkout" and _minute() >= 905:
		effective_clue_id = "telescope_returned"
	_spec = _make_spec(effective_clue_id)
	_recorded = bool(_core.call("has_evidence", effective_clue_id))
	if _recorded: _status = "这处记录已经在册中，可以再看。"
	queue_redraw()
	return ""


func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_font = load("res://assets/fonts/SolmereSans.ttf") as Font
	resized.connect(_layout)
	_layout()
	grab_focus()
	set_process(true)


func _layout() -> void:
	_factor = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	if _factor <= 0: _factor = 1.0
	_origin = (size - DESIGN * _factor) * 0.5
	queue_redraw()


func _source_error(id: String) -> String:
	if not is_instance_valid(_core) or not _core.has_method("observe"): return "资料尚未准备好。"
	if id not in PUBLIC_IDS: return "这项资料需要在对应人物或实物处查看。"
	var data: Dictionary = _core.call("clue_data", id)
	var state: Dictionary = _core.get("state")
	if data.is_empty() or state.is_empty(): return "没有找到这份公开资料。"
	if not state.get("failure", {}).is_empty() or not state.get("ending", {}).is_empty(): return "当前不能继续观察。"
	if not state.get("active_operation", {}).is_empty(): return "先放下正在使用的工具。"
	if data.get("location", "") != state.get("location", ""): return "需走到资料所在地点。"
	if _minute() < int(data.get("validity_time", {}).get("available_after_minute", 0)): return "这份记录还没有填写。"
	if id in ["case04_manual_hold", "helena_rota", "procedure_codes", "ledger_returns"]:
		if not bool(state.cases.case04.available): return "旧账簿还没有进入这次工作。"
	if id == "ledger_hv_repeat":
		if str(state.cases.case04.disposition).is_empty(): return "先处理手中的旧档邮件。"
		if not bool(_core.call("has_evidence", "case04_archive_mark")) and not bool(_core.call("has_evidence", "case04_manual_hold")):
			return "先查看与这封旧件相关的标记。"
	return ""


func _minute() -> int:
	var state: Dictionary = _core.get("state") if is_instance_valid(_core) else {}
	return int(state.get("minute", 540))


func _make_spec(id: String) -> Dictionary:
	# The visible content is the source itself, never clue_data.text/supports.
	match id:
		"ceramic_17": return {"kind": "plate", "title": "墙上的两层门牌", "subtitle": "住宅入口"}
		"mira_absent": return {"kind": "door", "title": "门边的名牌", "subtitle": "住宅入口"}
		"street_renaming": return _paper("街名更动公告", "海堤重建后的地址登记", "原街名                         现街名", ["Old Quay Lane     →     Bay Steps"])
		"moran_entry": return _paper("住户联系页", "Bay Steps · 入口公示", "住户                            通信地址", ["E. Moran                  9 Bay Steps"])
		"telescope_checkout", "telescope_returned":
			var returned := id == "telescope_returned"
			return _paper("设备借还单", "社区中心 · 折叠望远镜", "借用人 / 用途地点 / 归还登记", ["Mira Vale  ·  folding telescope", "活动地点：Lookout", "归还：15:05" if returned else "归还：________"], [0, 1, 2])
		"shuttle_timetable":
			# Explicit supplemental design approved for this slice, not an old route.
			return _paper("上山电车时刻表", "本站 → 观景台  /  仅上行", "每日发车时间", ["09:00—17:00  每半小时一班", "整点、半点发车  ·  单程 15 分钟", "末班 17:00 发车 / 17:15 抵达"], [0, 1, 2])
		"trusted_handoff_rule": return _paper("本地递送业务手册", "受托转交条款", "适用条件", ["可交由可信的本地转交人携带。", "须确认对方路线适合此次递送。", "收件服务不得要求收件人本人签名。"], [0, 1, 2])
		"current_3c_resident": return _paper("现行住户页", "Rose Court", "房号                            当前登记", ["3C                          新住户已登记"], [0])
		"june_current_mailpoint": return _paper("志愿者通信登记", "社区中心 · 现行登记", "姓名 / 值勤 / 批准收信地点", ["June Arlen  ·  Observatory volunteer", "批准收信格：Community Center"], [0, 1])
		"old_music_photo": return {"kind":"photo","title":"夏日音乐夜的合影","subtitle":"社区公告窗 · 留存照片","rows":["Summer music night","Mira Vale  /  June Arlen","另有其他活动参与者"],"required":[0,1]}
		"sea_watch_roster": return _paper("Sea Watch Weekend", "本期志愿者名册", "参与者", ["Mira Vale", "June Arlen"], [0, 1])
		"case04_manual_hold": return _paper("未结件旧账簿", "Desk B · 原始栏位", "收件人 / 原地址 / 处置记号", ["June Arlen  ·  Rose Court 3C", "20 JUL 2020                 HOLD — HV"], [0, 1])
		"ledger_hv_repeat": return _paper("未结件旧账簿", "Desk B · 相邻登记页", "登记条目                         手写记号", ["June Arlen / Rose Court 3C     HV / HOLD", "另一未结条目                    HV / HOLD", "后续未结条目                    HV / HOLD"], [0, 1])
		"helena_rota": return _paper("旧值勤分配表", "职员登记", "姓名                            工位", ["Helena Voss                   Desk B"])
		"procedure_codes": return _paper("正式处置分类", "邮务业务手册", "记录类别", ["RETURN  ·  退回", "UNKNOWN  ·  收件信息待核", "DAMAGED  ·  邮件受损"], [0, 1, 2])
		"ledger_returns": return _paper("退回工位登记页", "旧账簿 · 去向栏", "旧件条目                         去向 / 原因", ["June Arlen / Rose Court 3C    Desk B / review", "另一未结条目                   Desk B / review"], [0, 1])
	return {}


func _paper(title: String, subtitle: String, heading: String, rows: Array, required: Array = [0]) -> Dictionary:
	return {"kind": "paper", "title": title, "subtitle": subtitle, "heading": heading, "rows": rows, "required": required}


func interaction_regions() -> Array[Dictionary]:
	var regions: Array[Dictionary] = [{"id": "close", "rect": CLOSE}]
	if _spec.is_empty() or _leaving: return regions
	match str(_spec.kind):
		"plate": regions.append({"id": "plate", "rect": _shift(NEW_PLATE, Vector2(_plate_offset, 0))})
		"door": regions.append({"id": "knock", "rect": Rect2(841,575,175,183)})
		"photo":
			regions.append({"id":"photo_flip","rect":Rect2(1028,663,163,55)})
			if _page==0:regions.append({"id":"photo","rect":_photo_rect()})
			else:
				for index:int in range(_spec.rows.size()):regions.append({"id":"row_%d"%index,"rect":_photo_row_rect(index)})
		"paper":
			if _page == 0: regions.append({"id": "open", "rect": OPEN})
			else:
				for index: int in range(_spec.rows.size()):
					regions.append({"id": "row_%d" % index, "rect": _row_rect(index)})
	return regions


func _row_rect(index: int) -> Rect2:
	return Rect2(384, 328 + index * 94, 834, 84)


func _photo_rect() -> Rect2:
	var dimensions:=PHOTO.size*_photo_zoom
	return Rect2(PHOTO.get_center()-dimensions*0.5,dimensions)

func _photo_row_rect(index:int) -> Rect2:
	return Rect2(453,280+index*118,690,96)

func get_observation_snapshot() -> Dictionary:
	return {"clue_id":effective_clue_id,"kind":str(_spec.get("kind","")),"photo_back":_page==1,"photo_zoom":_photo_zoom,"read_rows":_read_rows.duplicate(),"recorded":_recorded,"regions":interaction_regions()}
func _gui_input(event: InputEvent) -> void:
	if _leaving: return
	if event is InputEventMouseButton and event.pressed and _spec.get("kind","")=="photo":
		var point:Vector2=(event.position-_origin)/_factor
		if event.button_index==MOUSE_BUTTON_RIGHT and _photo_rect().has_point(point):
			_activate("photo_flip");accept_event();return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and _page==0 and _photo_rect().has_point(point):
			_photo_zoom=clampf(_photo_zoom+(0.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -0.1),1.0,1.25)
			queue_redraw();accept_event();return
	if event is InputEventMouseMotion:
		var point: Vector2 = (event.position - _origin) / _factor
		if _dragging:
			_plate_offset = clampf(_plate_start + point.x - _drag_origin.x, 0, 490)
		else:
			_hover = _region_at(point)
		queue_redraw()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = (event.position - _origin) / _factor
		if event.pressed:
			grab_focus()
			var id := _region_at(point)
			if id == "plate":
				_dragging = true
				_drag_origin = point
				_plate_start = _plate_offset
			elif not id.is_empty(): _activate(id)
		elif _dragging:
			_dragging = false
			if _plate_offset >= OLD_PLATE.end.x - NEW_PLATE.position.x + 12: _record()
		queue_redraw()
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_leave()
		elif event.keycode == KEY_F and _spec.get("kind","")=="photo":
			_activate("photo_flip")
		elif event.keycode in [KEY_PLUS,KEY_EQUAL,KEY_MINUS] and _spec.get("kind","")=="photo" and _page==0:
			_photo_zoom=clampf(_photo_zoom+(0.1 if event.keycode!=KEY_MINUS else -0.1),1.0,1.25)
		elif event.keycode == KEY_TAB:
			var regions := interaction_regions()
			_focus_index = posmod(_focus_index + (-1 if event.shift_pressed else 1), regions.size())
		elif event.keycode in [KEY_RIGHT, KEY_LEFT] and _spec.get("kind", "") == "plate":
			_plate_offset = clampf(_plate_offset + (95.0 if event.keycode == KEY_RIGHT else -95.0), 0, 490)
			if _plate_offset >= OLD_PLATE.end.x - NEW_PLATE.position.x + 12: _record()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			var regions := interaction_regions()
			_activate(str(regions[mini(_focus_index, regions.size() - 1)].id))
		else: return
		queue_redraw()
		accept_event()


func _region_at(point: Vector2) -> String:
	for region: Dictionary in interaction_regions():
		if (region.rect as Rect2).has_point(point): return str(region.id)
	return ""


func _activate(id: String) -> void:
	if id == "close":
		_leave()
	elif id == "photo_flip":
		_page=1-_page;_photo_zoom=1.0;_focus_index=1;cue.emit("paper")
		_status="照片背面的题注可以逐行核对。" if _page==1 else "滚轮拿近看；右键或 F 翻看照片背面。"
	elif id=="photo":
		_photo_zoom=1.25 if is_equal_approx(_photo_zoom,1.0) else 1.0
	elif id == "open":
		_page = 1;cue.emit("paper")
		_focus_index = 1
		_status = "点读纸上的条目；Tab 切换，Enter 阅读。"
	elif id == "knock" and _knock_wait <= 0 and not _recorded:
		_knock_wait = 0.45
		_status = "叩了叩门。"
	elif id.begins_with("row_"):
		var index := int(id.trim_prefix("row_"))
		if index not in _read_rows: _read_rows.append(index)
		var all_read := true
		for required: int in _spec.get("required", []):
			if required not in _read_rows: all_read = false
		_status = "已看过这一栏。"
		if all_read: _record()
	queue_redraw()


func _process(delta: float) -> void:
	if _knock_wait > 0 and not _leaving:
		_knock_wait -= delta
		if _knock_wait <= 0:
			_record()
			if _recorded: _status = "等了一会儿，没有人应门。"
			queue_redraw()


func _record() -> void:
	if _recorded or _leaving or _spec.is_empty(): return
	if _spec.get("kind","")=="photo" and Art.texture("old_music_photo")==null:
		_status="照片图像尚未装入，暂时不能核对参与者。";return
	var error := _source_error(effective_clue_id)
	if error.is_empty(): error = str(_core.call("observe", effective_clue_id))
	if not error.is_empty():
		_status = error
		return
	_recorded = true
	_status = "已将这处原始记录记入册中。"
	queue_redraw()


func _leave() -> void:
	if _leaving: return
	_leaving = true
	_dragging = false
	_knock_wait = 0.0
	release_focus()
	closed.emit()


func _draw() -> void:
	if not _font: return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.14, 0.15, 0.72))
	draw_set_transform(_origin, 0, Vector2.ONE * _factor)
	_text(str(_spec.get("subtitle", "现场资料")), Vector2(318, 130), 22, Color("e9e4d6"))
	_text("×", CLOSE.position + Vector2(38, 39), 36, Color("e9e4d6"))
	if not _spec.is_empty():
		match str(_spec.kind):
			"plate": _draw_plate()
			"door": _draw_door()
			"paper": _draw_paper()
			"photo": _draw_photo()
	var regions := interaction_regions()
	for index: int in range(regions.size()):
		var rect: Rect2 = regions[index].rect
		if str(regions[index].id) == _hover or (has_focus() and index == _focus_index):
			draw_line(rect.position + Vector2(5, rect.size.y - 3), rect.end - Vector2(5, 3), Color("aca799"), 2)
	draw_set_transform(Vector2.ZERO)


func _draw_paper() -> void:
	
	Art.paint(self,"service_paper",PAPER)
	
	_text(str(_spec.title), Vector2(388, 242), 35, INK)
	if _page == 0:
		_text(str(_spec.subtitle), Vector2(389, 287), 24, SOFT)
		draw_line(Vector2(391, 323), Vector2(1124, 323), Color("c9baa4"), 1)
		_text("现场留存", Vector2(391, 374), 24, SOFT)
		
		Art.paint(self,"paper_corner",Rect2(1236,683,49,49))
	else:
		_text(str(_spec.heading), Vector2(391, 298), 22, SOFT)
		for index: int in range(_spec.rows.size()):
			var rect := _row_rect(index)
			_text(str(_spec.rows[index]), rect.position + Vector2(12, 42), 27, INK, 795)
			draw_line(rect.position + Vector2(10, rect.size.y), rect.end, Color("d4c9b8"), 1)
			if index in _read_rows:
				draw_line(rect.position + Vector2(-17, 33), rect.position + Vector2(-11, 39), SOFT, 1.5)
				draw_line(rect.position + Vector2(-11, 39), rect.position + Vector2(-2, 23), SOFT, 1.5)
		if effective_clue_id == "shuttle_timetable":
			_text("站钟  " + str(_core.call("time_text")), Vector2(958, 689), 23, SOFT)
		else:
			_text("1", Vector2(1205, 696), 21, SOFT)


func _draw_photo() -> void:
	if _page==0:
		Art.paint(self,"old_music_photo",_photo_rect(),Color.WHITE,true)
	else:
		Art.paint(self,"service_paper",PHOTO)
		_text("照片背面的题注",Vector2(454,245),27,SOFT)
		for index:int in range(_spec.rows.size()):
			var rect:=_photo_row_rect(index)
			_text(str(_spec.rows[index]),rect.position+Vector2(8,51),28,INK,670)
			if index in _read_rows:draw_line(rect.position+Vector2(8,71),rect.position+Vector2(620,71),Color("b4b9aa"),1)
	_text("翻到正面 ↶" if _page==1 else "翻看背面 ↷",Vector2(1034,700),21,INK if _page==1 else Color("f7efdb"))
func _draw_plate() -> void:
	Art.paint(self,"wall_closeup",PAPER)
	_text("门牌固定在同一处墙面",Vector2(381,236),29,INK)
	Art.paint(self,"wall_plate_old",OLD_PLATE)
	_text("17",OLD_PLATE.position+Vector2(61,108),75,TEAL)
	var plate:=_shift(NEW_PLATE,Vector2(_plate_offset,0))
	Art.paint(self,"wall_plate_new",plate)
	_text("9",plate.position+Vector2(144,105),66,INK)
	_text("BAY STEPS",plate.position+Vector2(63,161),28,INK)
	_text("现牌边缘可移动",Vector2(478,566),22,SOFT)

func _draw_door() -> void:
	# The same generated left door, magnified without repainting its architecture.
	Art.paint(self,"door_closeup",Rect2(514,40,570,1040))
	_text("Mira",Vector2(730,399),25,INK)
	_text("Vale",Vector2(731,430),25,INK)

func _text(value: String, at: Vector2, font_size: int, color: Color, width: float = -1) -> void:
	if width < 0:
		draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		return
	var current := ""
	var line := 0
	for character: String in value:
		if character == "\n" or _font.get_string_size(current + character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			draw_string(_font, at + Vector2(0, line * (font_size + 7)), current, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			current = ""
			line += 1
		if character != "\n": current += character
	draw_string(_font, at + Vector2(0, line * (font_size + 7)), current, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _shift(rect: Rect2, offset: Vector2) -> Rect2:
	return Rect2(rect.position + offset, rect.size)
