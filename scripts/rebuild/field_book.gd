class_name FinalFieldBook
extends Control
## Physical notebook UI. Author-only catalog/case_data are deliberately never read.
signal closed
signal cue(kind: String)

const CANVAS := Vector2(1600, 900)
const FONT = preload("res://assets/fonts/SolmereSans.ttf")
const HAND = preload("res://assets/fonts/Caveat.ttf")
const Art = preload("res://scripts/rebuild/physical_art.gd")
const BOOK_RECT := Rect2(30,52,1540,798)
# Insets follow the opaque paper silhouette, not the outer leather cover.
# Every live record is clipped to one leaf; the gutter is never a text column.
const LEFT_SAFE := Rect2(178,154,548,566)
const RIGHT_SAFE := Rect2(865,154,548,566)
const TAB_SIZE := Vector2(136,54)
const TAB_CENTERS := [285.0,465.0,1035.0,1235.0]
const INK := Color("#303238")
const MUTED := Color("#6B7376")
const TEAL := Color("#397C82")
const PAPER := Color("#F9F5EC")
const SHADE := Color("#E6E1CB")
const SECTIONS := ["人物", "见闻", "信件", "推断"]
const SECTIONS_EN := ["People", "Sources", "Letters", "Draft"]
const PAGE_SIZE := 6
const PORTRAITS := {"chenyuan":"CHAR_chenyuan","mira_vale":"CHAR_mira","june_arlen":"CHAR_june","elsie_moran":"CHAR_elsie","community_clerk":"CHAR_clerk"}
const PLACE_NAMES := {"post_office": "邮局", "community_center": "社区中心", "residential": "居民楼", "bus_stop": "公交站", "lookout": "观景台", "chess_stall": "棋摊", "tarot_shop": "塔罗店"}
const SOURCE_NAMES := {"community_notice": "市政通知", "residential_wall": "旧瓷牌", "public_resident_note": "住户公示", "mira_home": "Mira 门口", "equipment_checkout_sheet": "器材借还簿", "public_bus_timetable": "站点时刻表", "local_service_guide": "本地邮件服务规则", "physical_label": "修复后的转寄标签", "current_resident_list": "现行住户表", "public_volunteer_roster": "志愿者收信登记", "case04_envelope_back": "旧件背面", "community_archive_photo": "历年活动照片", "current_volunteer_board": "现行志愿者公告", "old_desk_ledger": "旧值台账簿", "old_shift_rota": "旧值班表", "official_procedure_guide": "正式处置规则"}
const FIELD_LABELS := {"recipient": "收件人", "address": "地址", "return": "回信地址", "sender": "寄件人", "date": "日期", "service_mark": "服务标记", "counter_note": "柜台附记", "status": "类别", "back": "背面", "archive_mark": "档案标记", "original_address": "原地址", "forwarding_recipient": "转寄姓名", "forwarding_destination": "转寄地点", "forwarding_valid_from": "起始日期", "forwarding_valid_until": "终止日期"}

var core: Node
var locale := "zh"
var section := 0
var page := 0
var selected_id := ""
var selected_sources: Array[String] = []
var draft_claims: Dictionary = {}
var notice := ""
var _canvas: Control
var _left_page: Control
var _right_page: Control
var _view: Dictionary = {}
var _items: Array = []
var _closed := false
var _turn: Tween
var _turn_surface: Control
var _turn_progress := 1.0


func configure(next_core: Node, language: String = "") -> void:
	core = next_core
	if not language.is_empty(): locale = "en" if language.begins_with("en") else "zh"
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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.11, 0.13, 0.52))
	draw_set_transform((size - CANVAS * factor) * 0.5, 0, Vector2.ONE * factor)
	# Blank painted material only. Text, identity permissions and navigation remain live controls.
	var material := Art.texture("handbook_open")
	if material != null:
		# Separate upright index slips tuck behind the unchanged painted book.
		for index: int in _available_sections():
			Art.paint(self,"book_index_tab",painted_tab_rect(index))
		var cut := 58.0
		var ratio := BOOK_RECT.size / material.get_size()
		draw_texture_rect_region(material, Rect2(BOOK_RECT.position + Vector2(0,cut)*ratio, Vector2(material.get_width(),material.get_height()-cut)*ratio), Rect2(0,cut,material.get_width(),material.get_height()-cut))
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
	_left_page = _leaf("LeftPaperSafeArea", LEFT_SAFE)
	_right_page = _leaf("RightPaperSafeArea", RIGHT_SAFE)
	if is_instance_valid(core): _view = core.dossier_view()
	if _view.is_empty(): _view = {"known_people": {}, "observations": [], "draft": {}, "confirmed": {}}
	var close := _button("Close", "×", Rect2(173,109,56,56), _close, 38)
	close.position = Vector2(1464,16)
	close.size = Vector2(96,66)
	close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.add_theme_stylebox_override("normal", _tab_style(false))
	close.add_theme_stylebox_override("hover", _tab_style(true))
	close.add_theme_stylebox_override("pressed", _tab_style(true))
	var available := _available_sections()
	if not available.is_empty() and section not in available:
		section = int(available[0]); page = 0; selected_id = ""
	if not available.is_empty(): _label(_section_name(section), Rect2(285,183,430,35), 27)
	_label(_t("随身记录", "Field notes"), Rect2(846,176,420,36), 24, MUTED)
	for index: int in available:
		var tab := _button("Tab" + str(index), _section_name(index), Rect2(), _select_section.bind(index), 16 if locale == "en" else 18)
		tab.position = tab_rect(index).position
		tab.size = TAB_SIZE
		tab.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.add_theme_color_override("font_color", TEAL if index == section else INK)
		for state: String in ["normal","hover","pressed","focus"]:
			tab.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		tab.add_theme_color_override("font_hover_color", TEAL)
		
		tab.mouse_entered.connect(tab.queue_redraw)
		tab.mouse_exited.connect(tab.queue_redraw)
		tab.tooltip_text = ""
	_items = _section_items()
	page = clampi(page, 0, maxi(0, ceili(float(_items.size()) / page_size()) - 1))
	if section == 3:
		_draw_draft()
	else:
		_draw_index()
		match section:
			0: _draw_person()
			1: _draw_evidence()
			2: _draw_letter()
	var pages := maxi(1, ceili(float(_items.size()) / page_size()))
	if section != 3:
		var previous := _button("PreviousPage", "", Rect2(256,642,118,88), _flip.bind(-1), 38)
		# The illustrated folded corners are outside the text-column transform.
		# Place hit areas on those visible paper corners, not on empty page space.
		previous.position = Vector2(105,692)
		previous.size = Vector2(160,104)
		previous.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		previous.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		previous.disabled = page == 0
		previous.mouse_default_cursor_shape = Control.CURSOR_ARROW if previous.disabled else Control.CURSOR_POINTING_HAND
		var next := _button("NextPage", "", Rect2(1210,642,118,88), _flip.bind(1), 38)
		next.position = Vector2(1335,692)
		next.size = Vector2(160,104)
		next.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		next.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		next.disabled = page + 1 >= pages
		next.mouse_default_cursor_shape = Control.CURSOR_ARROW if next.disabled else Control.CURSOR_POINTING_HAND
	var folio := _label("%d  /  %d" % [page+1, pages], Rect2(686,702,210,32), 18, MUTED)
	folio.name = "LeafNumber"
	folio.position = Vector2(675,746)
	folio.size = Vector2(110,28)
	if not notice.is_empty(): _label(notice, Rect2(855,650,420,42), 18, TEAL)
	_turn_surface = Control.new()
	_turn_surface.name = "TurningLeaf"
	_turn_surface.size = CANVAS
	_turn_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_surface.draw.connect(_draw_turning_leaf)
	_canvas.add_child(_turn_surface)
	_layout()
	queue_redraw()


func _available_sections() -> Array[int]:
	var result: Array[int] = []
	if not _view.get("known_people", {}).is_empty(): result.append(0)
	if not _view.get("observations", []).is_empty(): result.append(1)
	if is_instance_valid(core):
		for id: String in core.CASE_IDS:
			var item: Dictionary = core.case_view(id)
			if not item.is_empty() and (not item.front.is_empty() or not item.back.is_empty() or not item.body.is_empty()):
				result.append(2); break
	if not _fact("case04_archive_mark").is_empty() or not _fact("case04_manual_hold").is_empty() or not _fact("ledger_hv_repeat").is_empty(): result.append(3)
	return result


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


func page_size() -> int:
	return 1 if section == 0 else PAGE_SIZE


func _draw_index() -> void:
	if _items.is_empty():
		return
	if section == 0:
		selected_id = str(_items[page])
		return
	if selected_id not in _items: selected_id = str(_items[page*PAGE_SIZE])
	for index: int in range(page * PAGE_SIZE, mini(_items.size(), (page+1)*PAGE_SIZE)):
		var id := str(_items[index])
		var text := _item_label(id)
		var mark := "— " if id == selected_id else "   "
		_button("Entry" + str(index), mark + text, Rect2(278,249+(index%PAGE_SIZE)*61,448,53), _select_item.bind(id), 22)


func _item_label(id: String) -> String:
	if section == 0: return _person_name(id)
	if section == 1:
		var fact := _fact(id)
		return ("✓ " if id in selected_sources else "") + _source_name(str(fact.source)) + " · " + _clock(int(fact.observed_minute))
	var item: Dictionary = core.case_view(id)
	var recipient := str(item.front.get("recipient", _t("未记录正面", "Front not recorded")))
	return _t("信件 ", "Letter ") + id.right(2) + "  /  " + recipient


func _draw_person() -> void:
	if selected_id not in _view.known_people:
		return
	_label(_person_name(selected_id), Rect2(848,244,420,47), 29)
	var encounters: Dictionary = core.get("state").get("encounters", {})
	var encountered := encounters.has(selected_id)
	var portrait_rect := Rect2(322,263,316,326)
	# Only an encountered resident receives their generated gameplay portrait.
	if PORTRAITS.has(selected_id) and encountered:
		var portrait := TextureRect.new()
		portrait.name = "KnownPortrait"
		var source := Art.texture(str(PORTRAITS[selected_id]))
		var used := source.get_image().get_used_rect()
		var sketch := AtlasTexture.new()
		sketch.atlas = source
		sketch.region = Rect2(used.position, Vector2(used.size.x, used.size.y * 0.56))
		sketch.filter_clip = true
		portrait.texture = sketch
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(portrait, portrait_rect)
		var signature := _label(_person_name(selected_id), Rect2(345,605,300,40), 24, MUTED)
		signature.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_label(_t("未留肖像", "No portrait recorded") if encountered else _t("尚未见面", "Not yet met"), Rect2(348,376,260,72), 23, MUTED)
	var lines: Array[String] = []
	if encountered:
		var entry: Dictionary = encounters[selected_id]
		lines.append(_t("首次交谈\n", "First conversation\n") + _place_name(str(entry.location)) + " · " + _clock(int(entry.minute)))
	else: lines.append(_t("名字来自已查看的邮件或公开记录。", "Name found in examined mail or a public record."))
	for fact: Dictionary in _view.observations:
		if str(fact.source) == selected_id or str(fact.text).contains(core.known_person_label(selected_id)):
			lines.append(_source_name(str(fact.source)) + " · " + _clock(int(fact.observed_minute)) + "\n" + str(fact.text))
	_reading("PersonNotes", "\n\n".join(lines), Rect2(849,310,425,323), 21)


func _draw_evidence() -> void:
	var fact := _fact(selected_id)
	if fact.is_empty():
		return
	_label(_source_name(str(fact.source)), Rect2(846,246,427,48), 28)
	_label(_place_name(str(fact.location)) + "  ·  " + _clock(int(fact.observed_minute)), Rect2(849,302,420,36), 20, MUTED)
	_reading("EvidenceText", str(fact.text), Rect2(850,358,420,195), 24)
	var publicness := str(fact.get("public_or_private", ""))
	_label({"public": _t("公开资料", "Public record"), "voluntary": _t("当面答复", "Spoken in person"), "physical": _t("亲手查看的物件", "Examined object")}.get(publicness, _t("观察记录", "Observation")), Rect2(851,572,420,32), 18, MUTED)
	_button("IncludeSource", "从草稿抽出这条来源" if selected_id in selected_sources else "把这条来源夹进推断页 →", Rect2(842,606,445,43), _toggle_source, 21)


func _draw_letter() -> void:
	if selected_id.is_empty() or not is_instance_valid(core): return
	var item: Dictionary = core.case_view(selected_id)
	if item.is_empty(): return
	_label(_t("信件 ", "Letter ") + selected_id.right(2), Rect2(848,246,422,48), 29)
	var lines: Array[String] = []
	for side: String in ["front", "back"]:
		if item[side].is_empty(): continue
		lines.append(_t("正面记录", "Envelope front") if side == "front" else _t("背面记录", "Envelope back"))
		for key: String in item[side]:
			var value: Variant = item[side][key]
			if value is Dictionary:
				for inner: String in value: lines.append(_field_name(inner) + _t("：", ": ") + str(value[inner]))
			elif not str(value).is_empty(): lines.append(_field_name(key) + _t("：", ": ") + str(value))
		lines.append("")
	if not item.body.is_empty(): lines.append(_t("已读正文\n\n", "Read letter\n\n") + str(item.body))
	else: lines.append(_t("正文没有记录。", "No letter text recorded."))
	if not str(item.attachment).is_empty(): lines.append(_t("已见附件：", "Examined enclosure: ") + str(item.attachment))
	_reading("LetterText", "\n".join(lines), Rect2(849,303,425,332), 22)


func _draw_draft() -> void:
	var has_archive_source := not _fact("case04_archive_mark").is_empty() or not _fact("case04_manual_hold").is_empty() or not _fact("ledger_hv_repeat").is_empty()
	if not has_archive_source:
		return
	_label("夹入的来源", Rect2(288,251,415,40), 26)
	var lines: Array[String] = []
	for id: String in selected_sources:
		var fact := _fact(id)
		if not fact.is_empty(): lines.append("— " + _source_name(str(fact.source)) + "\n    " + _place_name(str(fact.location)) + " · " + _clock(int(fact.observed_minute)))
	_reading("DraftSources", "\n\n".join(lines) if not lines.is_empty() else _t("尚未夹入来源。", "No sources attached."), Rect2(290,305,420,285), 22)
	if not _view.confirmed.is_empty():
		_label("收工归档 · 已确认", Rect2(850,256,425,48), 28)
		var confirmed: String = _t("经手者：", "Signed by: ") + _person_name(str(_view.confirmed.get("hv_person", ""))) + _t("\n\n岗位：", "\n\nDesk: ") + str(_view.confirmed.get("desk", "")).replace("desk_b", "Desk B") + _t("\n\n正式处置码：", "\n\nOfficial code: ") + (_t("是", "Yes") if _view.confirmed.get("formal_code", true) else _t("否", "No"))
		_reading("ConfirmedRecord", confirmed, Rect2(850,324,420,269), 25)
		_label("来源核对记录。\n邮件去向仍保留在原回执上。", Rect2(850,611,425,59), 20, MUTED)
		return
	_label(_t("待核对", "Provisional"), Rect2(290,600,418,66), 19, MUTED)
	_label("HV 的署名 / 经手者", Rect2(850,246,425,35), 23)
	var person := OptionButton.new()
	person.name = "PersonSelect"
	person.add_item(_t("尚未确定", "Undetermined"))
	person.set_item_metadata(0, "")
	for id: String in _view.known_people:
		person.add_item(_person_name(id))
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
	desk.placeholder_text = _t("尚未记录", "Not recorded")
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
	for text: String in [_t("尚未确定", "Undetermined"), _t("是正式处置码", "Official code"), _t("不是正式处置码", "Not an official code")]: code.add_item(text)
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
	notice = _t("已记录 · 待核对", "Recorded · provisional") if error.is_empty() else error
	_rebuild()


func _toggle_source() -> void:
	if selected_id in selected_sources: selected_sources.erase(selected_id)
	else: selected_sources.append(selected_id)
	notice = ""
	_rebuild()


func _select_section(index: int) -> void:
	section = index
	page = 0
	selected_id = ""
	notice = ""
	_rebuild()
	_turn_page()


func _select_item(id: String) -> void:
	cue.emit("paper")
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
	cue.emit("flip")
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
	if SOURCE_NAMES.has(id): return _ui_text(SOURCE_NAMES[id])
	return _person_name(id) if is_instance_valid(core) else _t("未确认来源", "Unconfirmed source")


func _place_name(id: String) -> String:
	return _ui_text(str(PLACE_NAMES.get(id, "地点未记录")))


func _t(zh: String, en: String) -> String:
	return en if locale == "en" else zh


func _section_name(index: int) -> String:
	return str(SECTIONS_EN[index] if locale == "en" else SECTIONS[index])


func tab_rect(index: int) -> Rect2:
	return painted_tab_rect(index)


func painted_tab_rect(index: int) -> Rect2:
	return Rect2(TAB_CENTERS[index]-68.0,59.0,136.0,54.0)


func _person_name(id: String) -> String:
	var observed: String = core.known_person_label(id) if is_instance_valid(core) else ""
	return "Chenyuan" if locale == "en" and observed == "尘缘" else observed


func _field_name(id: String) -> String:
	var english := {"recipient":"To", "address":"Address", "return":"Return address", "sender":"From", "date":"Date", "service_mark":"Postal mark", "counter_note":"Counter note", "status":"Mail status", "back":"Back", "archive_mark":"Archive mark", "original_address":"Original address", "forwarding_recipient":"Forward to", "forwarding_destination":"Forwarding address", "forwarding_valid_from":"Valid from", "forwarding_valid_until":"Valid until"}
	return str(english.get(id, id) if locale == "en" else FIELD_LABELS.get(id, id))


func _ui_text(value: String) -> String:
	if locale != "en": return value
	# Localize headings, never the verbatim source quotes or the player's writing.
	var translations := {
		"人物":"People", "见闻":"Sources", "信件":"Letters", "推断":"Draft", "随身记录":"Field notes",
		"邮局":"Post office", "社区中心":"Community centre", "居民楼":"Sea Steps", "公交站":"Tram stop", "观景台":"Lookout", "棋摊":"Chess stall", "塔罗店":"Tower house", "地点未记录":"Place not recorded",
		"市政通知":"Town notice", "旧瓷牌":"Old ceramic sign", "住户公示":"Resident notice", "Mira 门口":"Mira's door", "器材借还簿":"Equipment register", "站点时刻表":"Tram timetable", "本地邮件服务规则":"Postal regulations", "修复后的转寄标签":"Recovered forwarding label", "现行住户表":"Resident register", "志愿者收信登记":"Volunteer mail register", "旧件背面":"Old envelope back", "历年活动照片":"Community photograph", "现行志愿者公告":"Volunteer notice", "旧值台账簿":"Old desk ledger", "旧值班表":"Old duty roster", "正式处置规则":"Handling regulations",
		"从草稿抽出这条来源":"Remove source from draft", "把这条来源夹进推断页 →":"Attach source to draft", "夹入的来源":"Attached sources", "收工归档 · 已确认":"Filed · verified", "来源核对记录。\n邮件去向仍保留在原回执上。":"Source verification record.\nOriginal receipts retain each delivery.", "HV 的署名 / 经手者":"HV signature / handler", "值台 / 岗位（照记录填写）":"Desk / assignment", "HV 是否为正式处置码":"Is HV an official code?", "写入暂定记录":"Record provisional finding"
	}
	return str(translations.get(value, value))


static func _clock(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]


func _reading_font() -> Font:
	var result := FontVariation.new()
	result.base_font = ThemeDB.fallback_font
	result.fallbacks = [FONT]
	return result


func _label(text: String, rect: Rect2, font_size: int, color: Color = INK, font: Font = FONT) -> Label:
	var label := Label.new()
	label.text = _ui_text(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", _reading_font() if font == FONT else font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, rect)
	return label


func _reading(node_name: String, text: String, rect: Rect2, font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.name = node_name
	label.text = text
	var reading_font := _reading_font()
	label.add_theme_font_override("normal_font", reading_font)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", INK)
	label.scroll_active = true
	label.selection_enabled = true
	_place(label, rect)
	return label


func _button(node_name: String, text: String, rect: Rect2, callback: Callable, font_size: int = 22) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = _ui_text(text)
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", _reading_font())
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
	control.add_theme_font_override("font", _reading_font())
	control.add_theme_font_size_override("font_size", 23)
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_placeholder_color", MUTED)
	control.add_theme_stylebox_override("normal", _line_style(Color("#B5AB94")))
	control.add_theme_stylebox_override("focus", _line_style(TEAL))
	control.add_theme_stylebox_override("hover", _line_style(TEAL))
	control.add_theme_stylebox_override("pressed", _line_style(TEAL))
	if control is OptionButton:
		var popup: PopupMenu = control.get_popup()
		popup.add_theme_font_override("font", _reading_font())
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
	var at := Vector2(800+(rect.position.x-800)*1.13,450+(rect.position.y-450)*1.19)
	var dimensions := rect.size * Vector2(1.13,1.19)
	# Navigation lives on the physical page corners/tabs. Body writing stays in
	# independent, clipped leaf containers with explicit minimum readable size.
	if str(control.name) in ["Close", "PreviousPage", "NextPage"] or str(control.name).begins_with("Tab") or rect.position.y >= 700:
		control.position = at; control.size = dimensions
		_canvas.add_child(control)
		return
	var safe := LEFT_SAFE if rect.get_center().x < 800 else RIGHT_SAFE
	var parent := _left_page if rect.get_center().x < 800 else _right_page
	at.x = maxf(safe.position.x, at.x)
	at.y = maxf(safe.position.y, at.y)
	dimensions.x = minf(dimensions.x, safe.end.x - at.x)
	dimensions.y = minf(dimensions.y, safe.end.y - at.y)
	control.position = at - safe.position
	control.size = dimensions
	control.clip_contents = true
	parent.add_child(control)
	# Stable normalized anchors keep the writing attached to its own leaf.
	control.set_anchor(SIDE_LEFT, control.position.x / parent.size.x)
	control.set_anchor(SIDE_RIGHT, (control.position.x + control.size.x) / parent.size.x)
	control.set_anchor(SIDE_TOP, control.position.y / parent.size.y)
	control.set_anchor(SIDE_BOTTOM, (control.position.y + control.size.y) / parent.size.y)
	control.set_meta("paper_leaf", "left" if parent == _left_page else "right")


func _leaf(node_name: String, rect: Rect2) -> Control:
	var leaf := Control.new()
	leaf.name = node_name
	leaf.position = rect.position
	leaf.size = rect.size
	leaf.clip_contents = true
	leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(leaf)
	return leaf


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _closed: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _closed: return
	_closed = true
	hide()
	cue.emit("paper")
	closed.emit()
