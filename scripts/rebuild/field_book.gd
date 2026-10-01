class_name FinalFieldBook
extends Control
## Physical notebook UI. Author-only catalog/case_data are deliberately never read.
signal closed

const CANVAS := Vector2(1600, 900)
const FONT = preload("res://assets/fonts/SolmereSans.ttf")
const HAND = preload("res://assets/fonts/Caveat.ttf")
const Art = preload("res://scripts/rebuild/physical_art.gd")
const BOOK_RECT := Rect2(30,52,1540,798)
const INK := Color("#303238")
const MUTED := Color("#6B7376")
const TEAL := Color("#397C82")
const PAPER := Color("#F9F5EC")
const SHADE := Color("#E6E1CB")
const SECTIONS := ["人物", "见闻", "信件", "推断"]
const PAGE_SIZE := 6
const PLACE_NAMES := {"post_office": "邮局", "community_center": "社区中心", "residential": "居民楼", "bus_stop": "公交站", "lookout": "观景台", "chess_stall": "棋摊", "tarot_shop": "塔罗店"}
const SOURCE_NAMES := {"community_notice": "市政通知", "residential_wall": "旧瓷牌", "public_resident_note": "住户公示", "mira_home": "Mira 门口", "equipment_checkout_sheet": "器材借还簿", "public_bus_timetable": "站点时刻表", "local_service_guide": "本地邮件服务规则", "physical_label": "修复后的转寄标签", "current_resident_list": "现行住户表", "public_volunteer_roster": "志愿者收信登记", "case04_envelope_back": "旧件背面", "community_archive_photo": "历年活动照片", "current_volunteer_board": "现行志愿者公告", "old_desk_ledger": "旧值台账簿", "old_shift_rota": "旧值班表", "official_procedure_guide": "正式处置规则"}
const FIELD_LABELS := {"recipient": "收件人", "address": "地址", "return": "回信地址", "sender": "寄件人", "date": "日期", "service_mark": "服务标记", "counter_note": "柜台附记", "status": "类别", "back": "背面", "archive_mark": "档案标记", "original_address": "原地址", "forwarding_recipient": "转寄姓名", "forwarding_destination": "转寄地点", "forwarding_valid_from": "起始日期", "forwarding_valid_until": "终止日期"}

var core: Node
var section := 0
var page := 0
var selected_id := ""
var selected_sources: Array[String] = []
var draft_claims: Dictionary = {}
var notice := ""
var _canvas: Control
var _view: Dictionary = {}
var _items: Array = []
var _closed := false
var _turn: Tween
var _turn_surface: Control
var _turn_progress := 1.0


func configure(next_core: Node) -> void:
	core = next_core
	_closed = false
	visible = true
	_view = core.dossier_view() if is_instance_valid(core) else {"known_people": {}, "observations": [], "draft": {}, "confirmed": {}}
	draft_claims = _view.draft.get("claims", {}).duplicate(true)
	selected_sources.clear()
	for id: String in _view.draft.get("sources", []): selected_sources.append(id)
	_rebuild()


func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	if _canvas == null: _rebuild()
	_layout()


func _layout() -> void:
	if _canvas == null: return
	var factor := maxf(0.01, minf(size.x / CANVAS.x, size.y / CANVAS.y))
	_canvas.position = (size - CANVAS * factor) * 0.5
	_canvas.scale = Vector2.ONE * factor
	queue_redraw()


func _draw() -> void:
	var factor := maxf(0.01, minf(size.x / CANVAS.x, size.y / CANVAS.y))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.11, 0.13, 0.16))
	draw_set_transform((size - CANVAS * factor) * 0.5, 0, Vector2.ONE * factor)
	# Blank painted material only. Text, identity permissions and navigation remain live controls.
	Art.paint(self,"handbook_open",BOOK_RECT)
	draw_set_transform(Vector2.ZERO)


func _rebuild() -> void:
	if _turn != null: _turn.kill()
	_turn_progress = 1.0
	if _canvas != null:
		remove_child(_canvas)
		_canvas.queue_free()
	_canvas = Control.new()
	_canvas.name = "BookCanvas"
	_canvas.size = CANVAS
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	if is_instance_valid(core): _view = core.dossier_view()
	if _view.is_empty(): _view = {"known_people": {}, "observations": [], "draft": {}, "confirmed": {}}
	var close := _button("Close", "×", Rect2(173,109,56,56), _close, 38)
	close.position = Vector2(151,81)
	close.size = Vector2(52,52)
	_label("Solmere / Local Exceptions", Rect2(286,148,430,40), 28, TEAL, HAND)
	_label(SECTIONS[section], Rect2(285,183,430,35), 27)
	_label("随身记录", Rect2(846,176,420,36), 24, MUTED)
	for index: int in range(SECTIONS.size()):
		var tab := _button("Tab" + str(index), SECTIONS[index], Rect2(), _select_section.bind(index), 20)
		tab.position = Vector2([213,390,999,1191][index],66)
		tab.size = Vector2(82,46)
		tab.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		tab.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		
		tab.mouse_entered.connect(tab.queue_redraw)
		tab.mouse_exited.connect(tab.queue_redraw)
		tab.tooltip_text = "翻到" + SECTIONS[index]
	_items = _section_items()
	page = clampi(page, 0, maxi(0, ceili(float(_items.size()) / PAGE_SIZE) - 1))
	if section == 3:
		_draw_draft()
	else:
		_draw_index()
		match section:
			0: _draw_person()
			1: _draw_evidence()
			2: _draw_letter()
	var pages := maxi(1, ceili(float(_items.size()) / PAGE_SIZE))
	if section != 3:
		var previous := _button("PreviousPage", "‹", Rect2(286,680,62,47), _flip.bind(-1), 38)
		previous.disabled = page == 0
		var next := _button("NextPage", "›", Rect2(1240,680,62,47), _flip.bind(1), 38)
		next.disabled = page + 1 >= pages
	_label("%d  /  %d" % [page+1, pages], Rect2(686,702,210,32), 18, MUTED)
	if not notice.is_empty(): _label(notice, Rect2(855,650,420,42), 18, TEAL)
	_turn_surface = Control.new()
	_turn_surface.name = "TurningLeaf"
	_turn_surface.size = CANVAS
	_turn_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_surface.draw.connect(_draw_turning_leaf)
	_canvas.add_child(_turn_surface)
	_layout()
	queue_redraw()


func _section_items() -> Array:
	if section == 0: return _view.known_people.keys()
	if section == 1: return _view.observations.map(func(fact: Dictionary) -> String: return str(fact.id))
	if section == 2:
		var result: Array = []
		if is_instance_valid(core):
			for id: String in ["case01", "case02", "case03", "case04", "case05"]:
				var item: Dictionary = core.case_view(id)
				if not item.is_empty() and (not item.front.is_empty() or not item.back.is_empty() or not item.body.is_empty()): result.append(id)
		return result
	return []


func _draw_index() -> void:
	if _items.is_empty():
		_label(["还没有记下谁的姓名。", "这里等着第一条亲眼看到的记录。", "先亲手查看一封信。"] [section], Rect2(289,263,410,120), 24, MUTED)
		return
	if selected_id not in _items: selected_id = str(_items[page*PAGE_SIZE])
	for index: int in range(page * PAGE_SIZE, mini(_items.size(), (page+1)*PAGE_SIZE)):
		var id := str(_items[index])
		var text := _item_label(id)
		var mark := "— " if id == selected_id else "   "
		_button("Entry" + str(index), mark + text, Rect2(278,249+(index%PAGE_SIZE)*61,448,53), _select_item.bind(id), 22)
	_label("点击条目翻看；边签可直接换章。", Rect2(290,636,420,30), 17, MUTED)


func _item_label(id: String) -> String:
	if section == 0: return core.known_person_label(id)
	if section == 1:
		var fact := _fact(id)
		return ("✓ " if id in selected_sources else "") + _source_name(str(fact.source)) + " · " + _clock(int(fact.observed_minute))
	var item: Dictionary = core.case_view(id)
	var recipient := str(item.front.get("recipient", "未记录正面"))
	return "信件 " + id.right(2) + "  /  " + recipient


func _draw_person() -> void:
	if selected_id not in _view.known_people:
		_label("未知的姓名留空。\n记录从相遇或实际看到的纸面开始。", Rect2(850,271,410,130), 25, MUTED)
		return
	_label(core.known_person_label(selected_id), Rect2(848,244,420,47), 29)
	var encounters: Dictionary = core.get("state").get("encounters", {})
	var encountered := encounters.has(selected_id)
	var portrait_rect := Rect2(875,308,165,279)
	# Only an encountered resident receives their generated gameplay portrait.
	if selected_id == "chenyuan" and encountered:
		var portrait := TextureRect.new()
		portrait.name = "KnownPortrait"
		portrait.texture = Art.texture("CHAR_chenyuan")
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(portrait, portrait_rect)
	else:
		_label("未留肖像" if encountered else "尚未见面", Rect2(871,340,180,72), 23, MUTED)
	var lines: Array[String] = []
	if encountered:
		var entry: Dictionary = encounters[selected_id]
		lines.append("首次交谈\n" + _place_name(str(entry.location)) + " · " + _clock(int(entry.minute)))
	else: lines.append("名字来自已查看的邮件或公开记录。")
	for fact: Dictionary in _view.observations:
		if str(fact.source) == selected_id or str(fact.text).contains(core.known_person_label(selected_id)):
			lines.append("见闻：" + _source_name(str(fact.source)) + "\n" + _place_name(str(fact.location)) + " · " + _clock(int(fact.observed_minute)))
	_reading("PersonNotes", "\n\n".join(lines), Rect2(1057,303,222,288), 21)
	_label("名字与肖像只按已经取得的记录出现。", Rect2(851,610,425,35), 17, MUTED)


func _draw_evidence() -> void:
	var fact := _fact(selected_id)
	if fact.is_empty():
		_label("保留原话，也保留它来自哪里。", Rect2(850,274,420,90), 26, MUTED)
		return
	_label(_source_name(str(fact.source)), Rect2(846,246,427,48), 28)
	_label(_place_name(str(fact.location)) + "  ·  " + _clock(int(fact.observed_minute)), Rect2(849,302,420,36), 20, MUTED)
	_reading("EvidenceText", str(fact.text), Rect2(850,358,420,195), 24)
	var publicness := str(fact.get("public_or_private", ""))
	_label({"public": "公开资料", "voluntary": "当面答复", "physical": "亲手查看的物件"}.get(publicness, "观察记录"), Rect2(851,572,420,32), 18, MUTED)
	_button("IncludeSource", "从草稿抽出这条来源" if selected_id in selected_sources else "把这条来源夹进推断页 →", Rect2(842,606,445,43), _toggle_source, 21)


func _draw_letter() -> void:
	if selected_id.is_empty() or not is_instance_valid(core): return
	var item: Dictionary = core.case_view(selected_id)
	if item.is_empty(): return
	_label("信件 " + selected_id.right(2), Rect2(848,246,422,48), 29)
	var lines: Array[String] = []
	for side: String in ["front", "back"]:
		if item[side].is_empty(): continue
		lines.append("正面记录" if side == "front" else "背面记录")
		for key: String in item[side]:
			var value: Variant = item[side][key]
			if value is Dictionary:
				for inner: String in value: lines.append(str(FIELD_LABELS.get(inner, inner)) + "：" + str(value[inner]))
			elif not str(value).is_empty(): lines.append(str(FIELD_LABELS.get(key, key)) + "：" + str(value))
		lines.append("")
	if not item.body.is_empty(): lines.append("已读正文\n\n" + str(item.body))
	else: lines.append("正文没有记录。")
	if not str(item.attachment).is_empty(): lines.append("已见附件：" + str(item.attachment))
	_reading("LetterText", "\n".join(lines), Rect2(849,303,425,332), 22)


func _draw_draft() -> void:
	var has_archive_source := not _fact("case04_archive_mark").is_empty() or not _fact("case04_manual_hold").is_empty() or not _fact("ledger_hv_repeat").is_empty()
	if not has_archive_source:
		_label("留给需要核对的记录", Rect2(288,260,415,55), 26)
		_label("先把亲眼看到的资料记下来。\n还没有档案痕迹需要在这里填写。", Rect2(289,338,413,130), 24, MUTED)
		_label("这一页暂时留白。", Rect2(850,286,420,70), 26, MUTED)
		return
	_label("夹入的来源", Rect2(288,251,415,40), 26)
	var lines: Array[String] = []
	for id: String in selected_sources:
		var fact := _fact(id)
		if not fact.is_empty(): lines.append("— " + _source_name(str(fact.source)) + "\n    " + _place_name(str(fact.location)) + " · " + _clock(int(fact.observed_minute)))
	_reading("DraftSources", "\n\n".join(lines) if not lines.is_empty() else "尚未夹入来源。\n\n在「见闻」中查看原记录，再选择要引用的条目。", Rect2(290,305,420,285), 22)
	if not _view.confirmed.is_empty():
		_label("收工归档 · 已确认", Rect2(850,256,425,48), 28)
		var confirmed: String = "经手者：" + str(core.known_person_label(str(_view.confirmed.get("hv_person", "")))) + "\n\n岗位：" + str(_view.confirmed.get("desk", "")).replace("desk_b", "Desk B") + "\n\n正式处置码：" + ("是" if _view.confirmed.get("formal_code", true) else "否")
		_reading("ConfirmedRecord", confirmed, Rect2(850,324,420,269), 25)
		_label("来源核对记录。\n邮件去向仍保留在原回执上。", Rect2(850,611,425,59), 20, MUTED)
		return
	_label("暂定记录可以改写。\n仅点「写入」后进入班次档案。", Rect2(290,600,418,66), 19, MUTED)
	_label("HV 的署名 / 经手者", Rect2(850,246,425,35), 23)
	var person := OptionButton.new()
	person.name = "PersonSelect"
	person.add_item("尚未确定")
	person.set_item_metadata(0, "")
	for id: String in _view.known_people:
		person.add_item(core.known_person_label(id))
		person.set_item_metadata(person.item_count-1, id)
		if draft_claims.get("hv_person") == id: person.select(person.item_count-1)
	person.item_selected.connect(func(index: int) -> void:
		var id := str(person.get_item_metadata(index))
		if id.is_empty(): draft_claims.erase("hv_person")
		else: draft_claims.hv_person = id)
	_style_input(person)
	_place(person, Rect2(847,288,424,43))
	_label("值台 / 岗位（照记录填写）", Rect2(850,352,425,35), 23)
	var desk := LineEdit.new()
	desk.name = "DeskEntry"
	desk.placeholder_text = "尚未记录"
	desk.text = str(draft_claims.get("desk", "")).replace("desk_b", "Desk B")
	desk.text_changed.connect(func(text: String) -> void:
		var value := text.strip_edges()
		if value.is_empty(): draft_claims.erase("desk")
		else: draft_claims.desk = value.to_lower().replace(" ", "_"))
	_style_input(desk)
	_place(desk, Rect2(847,391,424,43))
	_label("HV 是否为正式处置码", Rect2(850,455,425,35), 23)
	var code := OptionButton.new()
	code.name = "CodeSelect"
	for text: String in ["尚未确定", "是正式处置码", "不是正式处置码"]: code.add_item(text)
	if draft_claims.has("formal_code"): code.select(1 if draft_claims.formal_code else 2)
	code.item_selected.connect(func(index: int) -> void:
		if index == 0: draft_claims.erase("formal_code")
		else: draft_claims.formal_code = index == 1)
	_style_input(code)
	_place(code, Rect2(847,493,424,43))
	_button("RecordDraft", "写入暂定记录", Rect2(845,558,425,51), _record_draft, 24)


func _record_draft() -> void:
	if not is_instance_valid(core): return
	var error: String = core.record_archive_draft(draft_claims, selected_sources)
	notice = "已写入暂定记录；仍可重新查看来源、改写。" if error.is_empty() else error
	_rebuild()


func _toggle_source() -> void:
	if selected_id in selected_sources: selected_sources.erase(selected_id)
	else: selected_sources.append(selected_id)
	notice = "来源已夹入；到推断页填写并写入。" if selected_id in selected_sources else "已从这份草稿抽出。"
	_rebuild()


func _select_section(index: int) -> void:
	section = index
	page = 0
	selected_id = ""
	notice = ""
	_rebuild()
	_turn_page()


func _select_item(id: String) -> void:
	selected_id = id
	notice = ""
	_rebuild()


func _flip(direction: int) -> void:
	page += direction
	selected_id = ""
	notice = ""
	_rebuild()
	_turn_page()


func _turn_page() -> void:
	if not is_inside_tree(): return
	if _turn != null: _turn.kill()
	_turn_progress = 0.0
	_turn = create_tween()
	_turn.tween_method(_set_turn_progress, 0.0, 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_turn_progress(value: float) -> void:
	_turn_progress = value
	if is_instance_valid(_turn_surface): _turn_surface.queue_redraw()


func _draw_turning_leaf() -> void:
	if _turn_progress >= 1.0: return
	# Turn only a blank paper leaf around the bound gutter; the book and scene stay still.
	var width_scale := cos(_turn_progress * PI)
	_turn_surface.draw_set_transform(Vector2(790,76),0,Vector2(width_scale,1.0))
	var material:Texture2D=Art.texture("handbook_open")
	if material!=null:_turn_surface.draw_texture_rect_region(material,Rect2(0,0,640,730),Rect2(material.get_width()*0.5,material.get_height()*0.08,material.get_width()*0.46,material.get_height()*0.85),Color.WHITE)
	_turn_surface.draw_set_transform(Vector2.ZERO)


func _fact(id: String) -> Dictionary:
	for fact: Dictionary in _view.get("observations", []):
		if fact.id == id: return fact
	return {}


func _source_name(id: String) -> String:
	if SOURCE_NAMES.has(id): return SOURCE_NAMES[id]
	return core.known_person_label(id) if is_instance_valid(core) else "未确认来源"


func _place_name(id: String) -> String:
	return str(PLACE_NAMES.get(id, "地点未记录"))


static func _clock(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]


func _label(text: String, rect: Rect2, font_size: int, color: Color = INK, font: Font = FONT) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, rect)
	return label


func _reading(node_name: String, text: String, rect: Rect2, font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_override("normal_font", FONT)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", INK)
	label.scroll_active = true
	label.selection_enabled = true
	_place(label, rect)
	return label


func _button(node_name: String, text: String, rect: Rect2, callback: Callable, font_size: int = 22) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", TEAL)
	button.add_theme_color_override("font_disabled_color", Color("#ABA69C"))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _line_style(Color("#C8CAB5")))
	button.add_theme_stylebox_override("pressed", _line_style(TEAL))
	button.add_theme_stylebox_override("focus", _line_style(TEAL))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	_place(button, rect)
	return button


func _style_input(control: Control) -> void:
	control.add_theme_font_override("font", FONT)
	control.add_theme_font_size_override("font_size", 23)
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_placeholder_color", MUTED)
	control.add_theme_stylebox_override("normal", _line_style(Color("#B5AB94")))
	control.add_theme_stylebox_override("focus", _line_style(TEAL))
	control.add_theme_stylebox_override("hover", _line_style(TEAL))
	control.add_theme_stylebox_override("pressed", _line_style(TEAL))
	if control is OptionButton:
		var popup: PopupMenu = control.get_popup()
		popup.add_theme_font_override("font", FONT)
		popup.add_theme_font_size_override("font_size", 23)
		popup.add_theme_color_override("font_color", INK)
		popup.add_theme_stylebox_override("panel", _tab_style(false))


static func _line_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_width_bottom = 1
	style.border_color = color
	style.content_margin_left = 6
	return style


static func _tab_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#D5DDD0") if active else SHADE
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color("#877E70")
	style.content_margin_left = 11
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 4
	return style


func _place(control: Control, rect: Rect2) -> void:
	# Text follows the larger page geometry independently from the transparent painted base.
	control.position = Vector2(800+(rect.position.x-800)*1.13,450+(rect.position.y-450)*1.19)
	control.size = rect.size * Vector2(1.13,1.19)
	_canvas.add_child(control)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _closed: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _closed: return
	_closed = true
	hide()
	closed.emit()
