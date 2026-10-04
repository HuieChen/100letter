class_name PostalResolutionSlip
extends Control
## UI-only. The host supplies already-seen facts and validates every submitted action.
signal submitted(result: Dictionary)
signal closed(draft: Dictionary)
signal cue(name: String)

const Art = preload("res://scripts/rebuild/physical_art.gd")
const CANVAS := Vector2(1600, 900)
const FONT = preload("res://assets/fonts/SolmereSans.ttf")
const INK := Color("4f3847")
const MUTED := Color("697575")
const PAPER := Color("faf5e8")
const TEAL := Color("49745b")
const SEAL_INK := Color("9f5146")
const DOCUMENT := Rect2(534, 42, 578, 783)
const SEAL_HOME := Rect2(1208, 620, 104, 158)
const SEAL_AREA := Rect2(939, 690, 110, 106)
const REVIEW_AREA := Rect2(576, 762, 320, 39)
const WORDS := {
	"zh": {"title":"邮件处置单", "desk":"SOLMERE POST  /  DESK B", "facts":"已见记录", "determination":"我的事实判断", "disposition":"这件邮件的去向", "note":"依据／给下一班的说明", "empty":"尚未提供现场记录。", "review":"复核填写内容 →", "edit":"← 返回修改", "close":"收起", "seal":"拿起邮局章", "fact_note":"这些记录只说明你实际见过什么。", "draft_hint":"填写自己的判断和去向，再复核纸面。", "review_hint":"核对纸面。拿起右侧唯一的邮局章，拖到留出的盖章位置后松开。", "keyboard_hint":"方向键移章 · Enter 落章 · Esc 放回", "target":"邮局章", "missing_field":"请先填写：", "missing_action":"请先选定这件邮件的去向。", "missing_note":"这个去向需要留下简短说明。", "misplaced":"章放回原处。请落在纸面右下方的留章位置。", "pressed":"已盖章，等待工作记录。", "review_first":"先填写并复核这张处置单。", "reference":"来源："},
	"en": {"title":"Postal Resolution Slip", "desk":"SOLMERE POST  /  DESK B", "facts":"Observed record", "determination":"My factual determination", "disposition":"Disposition of this item", "note":"Basis / note for the next shift", "empty":"No observed records supplied yet.", "review":"Review this slip →", "edit":"← Amend this slip", "close":"Put away", "seal":"Pick up desk seal", "fact_note":"These records describe only what you have seen.", "draft_hint":"Enter your determination and disposition, then review the slip.", "review_hint":"Check the slip. Pick up the one desk seal on the right, drag it to the reserved area, and release.", "keyboard_hint":"Arrow keys move seal · Enter stamps · Esc returns it", "target":"Desk seal", "missing_field":"Complete this field: ", "missing_action":"Select a disposition for this item.", "missing_note":"Leave a brief note for this disposition.", "misplaced":"The seal is back in its place. Lower it into the reserved area at the bottom right.", "pressed":"Stamped; awaiting the work record.", "review_first":"Complete and review this slip first.", "reference":"Source: "}
}

var _payload: Dictionary = {}
var _draft: Dictionary = {"determination": {}, "disposition": "", "note": ""}
var _locale := "zh"
var _canvas: Control
var _fields: Dictionary = {}
var _choices: Array[Button] = []
var _note: TextEdit
var _review_button: Button
var _seal_button: Button
var _notice: Label
var _reviewing := false
var _holding := false
var _pressing := false
var _stamped := false
var _closed := false
var _stamp_at := SEAL_HOME.get_center()
var _stamp_press := 0.0
var _press_tween: Tween
var _factor := 1.0
var _origin := Vector2.ZERO
var _generation := 0


func configure(payload: Dictionary) -> String:
	var error := _validate_payload(payload)
	if not error.is_empty(): return error
	_generation += 1
	if _press_tween != null: _press_tween.kill()
	_payload = payload.duplicate(true)
	_locale = str(payload.get("locale", "zh"))
	_draft = {"determination": {}, "disposition": "", "note": ""}
	var supplied: Dictionary = payload.get("draft", {})
	var values: Dictionary = supplied.get("determination", {})
	for field: Dictionary in payload.determination_fields:
		_draft.determination[str(field.id)] = str(values.get(str(field.id), field.get("value", ""))).left(80)
	_draft.disposition = str(supplied.get("disposition", payload.get("default_disposition", "")))
	if not _action_exists(_draft.disposition): _draft.disposition = ""
	_draft.note = str(supplied.get("note", "")).left(500)
	_reviewing = false
	_holding = false
	_pressing = false
	_stamped = false
	_closed = false
	_stamp_press = 0.0
	_stamp_at = SEAL_HOME.get_center()
	visible = true
	_build()
	return ""


func _validate_payload(payload: Dictionary) -> String:
	if str(payload.get("case_id", "")).is_empty(): return "missing_case_id"
	for key: String in ["known_facts", "determination_fields", "dispositions"]:
		if not payload.get(key) is Array: return "invalid_" + key
	if payload.dispositions.is_empty() or payload.dispositions.size() > 9: return "invalid_disposition_count"
	if payload.determination_fields.size() > 8: return "too_many_determination_fields"
	for key: String in ["determination_fields", "dispositions"]:
		var ids: Array[String] = []
		for item: Variant in payload[key]:
			if not item is Dictionary or str(item.get("id", "")).is_empty() or str(item.get("label", "")).is_empty(): return "invalid_" + key + "_entry"
			if str(item.id) in ids: return "duplicate_" + key + "_id"
			ids.append(str(item.id))
	for fact: Variant in payload.known_facts:
		if not fact is Dictionary or not fact.get("text") is String: return "invalid_fact"
	if not payload.get("draft", {}) is Dictionary: return "invalid_draft"
	if not payload.get("draft", {}).get("determination", {}) is Dictionary: return "invalid_draft_fields"
	if str(payload.get("locale", "zh")) not in WORDS: return "unsupported_locale"
	return ""


func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	_factor = maxf(0.01, minf(size.x / CANVAS.x, size.y / CANVAS.y))
	_origin = (size - CANVAS * _factor) * 0.5
	if is_instance_valid(_canvas):
		_canvas.scale = Vector2.ONE * _factor
		_canvas.position = _origin
	queue_redraw()


func _t(key: String) -> String:
	return str(WORDS[_locale].get(key, key))


func _build() -> void:
	if is_instance_valid(_canvas):
		remove_child(_canvas)
		_canvas.queue_free()
	_fields.clear()
	_choices.clear()
	_canvas = Control.new()
	_canvas.name = "ResolutionPaper"
	_canvas.size = CANVAS
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_label(_canvas, _t("desk"), Rect2(576,69,484,27), 17, TEAL)
	_label(_canvas, _t("title"), Rect2(576,103,488,49), 32)
	_label(_canvas, str(_payload.get("case_label", _payload.case_id)), Rect2(576,153,486,29), 17, MUTED)
	_button("Close", "×", Rect2(1375,66,159,43), request_close, 34)
	_label(_canvas, _t("facts"), Rect2(105,130,350,40), 25, Color("fff5df"))
	var facts_scroll := ScrollContainer.new()
	facts_scroll.name = "ObservedFacts"
	facts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(facts_scroll, _canvas, Rect2(100,178,366,542))
	var facts := VBoxContainer.new()
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_theme_constant_override("separation", 17)
	facts_scroll.add_child(facts)
	if _payload.known_facts.is_empty(): _evidence_note(facts, "", _t("empty"), "")
	for fact: Dictionary in _payload.known_facts:
		_evidence_note(facts, str(fact.get("label", "")), str(fact.text), str(fact.get("source", "")))
	_label(_canvas, _t("determination"), Rect2(576,199,485,34), 21)
	var field_scroll := ScrollContainer.new()
	field_scroll.name = "DeterminationFields"
	field_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(field_scroll, _canvas, Rect2(576,238,484,225))
	var field_stack := VBoxContainer.new()
	field_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_stack.add_theme_constant_override("separation", 8)
	field_scroll.add_child(field_stack)
	for field: Dictionary in _payload.determination_fields:
		var id := str(field.id)
		_flow_label(field_stack, str(field.label), 17, MUTED, 449)
		var input := LineEdit.new()
		input.name = "Field_" + id
		input.text = str(_draft.determination[id])
		input.max_length = 80
		input.custom_minimum_size = Vector2(449, 34)
		input.add_theme_font_override("font", FONT)
		input.add_theme_font_size_override("font_size", 21)
		input.add_theme_color_override("font_color", INK)
		input.add_theme_color_override("font_uneditable_color", INK)
		input.add_theme_stylebox_override("normal", _line_style(Color("c2c8bd")))
		input.add_theme_stylebox_override("read_only", _line_style(Color("c2c8bd")))
		input.add_theme_stylebox_override("focus", _line_style(TEAL))
		input.text_changed.connect(func(value: String): _draft.determination[id] = value)
		field_stack.add_child(input)
		_fields[id] = input
	_label(_canvas, _t("disposition"), Rect2(576,481,478,33), 21)
	var disposition_scroll := ScrollContainer.new()
	disposition_scroll.name = "DispositionChoices"
	disposition_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(disposition_scroll, _canvas, Rect2(576,516,484,94))
	var disposition_stack := VBoxContainer.new()
	disposition_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	disposition_stack.add_theme_constant_override("separation", 2)
	disposition_scroll.add_child(disposition_stack)
	for option: Dictionary in _payload.dispositions:
		var id := str(option.id)
		var b := _button("Disposition_" + id, "", Rect2(), _choose.bind(id), 19)
		_canvas.remove_child(b)
		disposition_stack.add_child(b)
		b.custom_minimum_size = Vector2(449, 27)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_choices.append(b)
	_label(_canvas, _t("note"), Rect2(576,620,478,30), 18, MUTED)
	_note = TextEdit.new()
	_note.name = "ResolutionNote"
	_note.text = str(_draft.note)
	_note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_note.add_theme_font_override("font", FONT)
	_note.add_theme_font_size_override("font_size", 19)
	_note.add_theme_color_override("font_color", INK)
	_note.add_theme_color_override("font_readonly_color", INK)
	_note.add_theme_stylebox_override("normal", _line_style(Color("c2c8bd")))
	_note.add_theme_stylebox_override("read_only", _line_style(Color("c2c8bd")))
	_note.add_theme_stylebox_override("focus", _line_style(TEAL))
	_place(_note, _canvas, Rect2(576,654,312,91))
	_note.text_changed.connect(func(): _draft.note = _note.text)
	_review_button = _button("ReviewSlip", _t("review"), REVIEW_AREA, _toggle_review, 20)
	_seal_button = _button("DeskSeal", "", SEAL_HOME, _keyboard_pick, 18)
	_seal_button.tooltip_text = _t("seal")
	_seal_button.gui_input.connect(_seal_input)
	_seal_button.focus_entered.connect(queue_redraw)
	_seal_button.focus_exited.connect(queue_redraw)
	_notice = _label(_canvas, _t("draft_hint"), Rect2(165,844,1270,43), 18, INK)
	_notice.hide()
	_notice.add_theme_color_override("font_outline_color", Color("f6f3df"))
	_notice.add_theme_constant_override("outline_size", 4)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sync()
	_layout()


func _evidence_note(parent: Node, caption: String, text: String, source: String) -> void:
	var paper := PanelContainer.new()
	paper.custom_minimum_size.x = 340
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff7e5")
	style.border_color = Color("bec9b5")
	style.border_width_bottom = 1
	style.content_margin_left = 17; style.content_margin_right = 17
	style.content_margin_top = 13; style.content_margin_bottom = 15
	var material:=StyleBoxTexture.new();material.texture=Art.texture("letter_paper");material.content_margin_left=18;material.content_margin_right=18;material.content_margin_top=13;material.content_margin_bottom=15
	paper.add_theme_stylebox_override("panel", material)
	parent.add_child(paper)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 7)
	paper.add_child(lines)
	if not caption.is_empty(): _flow_label(lines, caption, 16, TEAL)
	_flow_label(lines, text, 21, INK)
	if not source.is_empty(): _flow_label(lines, _t("reference") + source, 15, MUTED)

func _place(control: Control, parent: Node, rect: Rect2) -> void:
	parent.add_child(control)
	control.position = rect.position
	control.size = rect.size


func _label(parent: Node, text: String, rect: Rect2, points: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	_place(label, parent, rect)
	return label


func _flow_label(parent: Node, text: String, points: int, color: Color, width: float = 304) -> void:
	var label := _label(parent, text, Rect2(), points, color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = width


func _button(id: String, text: String, rect: Rect2, action: Callable, points: int = 21) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", points)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", TEAL)
	button.add_theme_color_override("font_pressed_color", TEAL)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _line_style(TEAL))
	button.add_theme_stylebox_override("focus", _line_style(TEAL))
	button.add_theme_stylebox_override("pressed", _line_style(TEAL))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	_place(button, _canvas, rect)
	return button


func _line_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.border_width_bottom = 1
	return style


func _action_exists(id: String) -> bool:
	for option: Dictionary in _payload.get("dispositions", []):
		if str(option.id) == id: return true
	return false


func _choose(id: String) -> void:
	if _reviewing or _stamped or _pressing: return
	_draft.disposition = id
	_sync()


func _sync() -> void:
	if not is_instance_valid(_canvas): return
	for input: LineEdit in _fields.values(): input.editable = not _reviewing and not _stamped
	_note.editable = not _reviewing and not _stamped
	for index: int in _choices.size():
		var option: Dictionary = _payload.dispositions[index]
		_choices[index].text = ("●  " if str(_draft.disposition) == str(option.id) else "○  ") + str(option.label)
		_choices[index].disabled = _reviewing or _stamped
	_review_button.text = _t("edit") if _reviewing else _t("review")
	_review_button.disabled = _stamped or _pressing
	queue_redraw()


func _validation_error() -> String:
	if str(_draft.note).length() > 500: return "说明请控制在 500 字以内。" if _locale == "zh" else "Keep the note within 500 characters."
	for field: Dictionary in _payload.determination_fields:
		if bool(field.get("required", true)) and str(_draft.determination.get(str(field.id), "")).strip_edges().is_empty(): return _t("missing_field") + str(field.label)
	if not _action_exists(str(_draft.disposition)): return _t("missing_action")
	for option: Dictionary in _payload.dispositions:
		if str(option.id) == str(_draft.disposition) and bool(option.get("requires_note", false)) and str(_draft.note).strip_edges().is_empty(): return _t("missing_note")
	return ""


func _toggle_review() -> void:
	if _pressing or _stamped: return
	_return_seal()
	if _reviewing:
		_reviewing = false
		_notice.text = _t("draft_hint")
	else:
		var error := _validation_error()
		if not error.is_empty(): _notice.text = error; _notice.show(); return
		_reviewing = true
		_notice.text = _t("review_hint")
	_notice.hide()
	_sync()
	cue.emit("paper")


func _seal_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pick_seal()
		_seal_button.accept_event()


func _keyboard_pick() -> void:
	# Mouse press is handled explicitly; Button's keyboard activation reaches here.
	if not _holding: _pick_seal()


func _pick_seal() -> void:
	if _closed or _stamped or _pressing: return
	if not _reviewing: _notice.text = _t("review_first"); return
	_holding = true
	_stamp_at = SEAL_HOME.get_center()
	_notice.text = _t("keyboard_hint")
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or _closed or _payload.is_empty(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _holding: _return_seal(); _notice.text = _t("review_hint")
			elif not _pressing: request_close()
		elif _holding and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER]:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER]: _drop_seal()
			else:
				var step := 20.0 if event.shift_pressed else 50.0
				_stamp_at += {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}[event.keycode] * step
				_stamp_at = _stamp_at.clamp(Vector2(45,80), Vector2(1550,820))
				queue_redraw()
			get_viewport().set_input_as_handled()
	elif _holding and event is InputEventMouseMotion:
		_stamp_at = (event.position - global_position - _origin) / _factor
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif _holding and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_stamp_at = (event.position - global_position - _origin) / _factor
		_drop_seal()
		get_viewport().set_input_as_handled()


func _return_seal() -> void:
	_holding = false
	_stamp_at = SEAL_HOME.get_center()
	queue_redraw()


func _drop_seal() -> void:
	if not _holding or _pressing or _stamped: return
	_holding = false
	if not SEAL_AREA.has_point(_stamp_at):
		_return_seal()
		_notice.text = _t("misplaced")
		return
	var error := _validation_error()
	if not error.is_empty(): _return_seal(); show_error(error); return
	_pressing = true
	_stamp_at = SEAL_AREA.get_center()
	_stamp_press = 0.0
	var generation := _generation
	cue.emit("stamp")
	_sync()
	_press_tween = create_tween()
	_press_tween.tween_method(func(value: float): _stamp_press = value; queue_redraw(), 0.0, 1.0, 0.09)
	_press_tween.tween_method(func(value: float): _stamp_press = value; queue_redraw(), 1.0, 0.0, 0.08)
	_press_tween.finished.connect(func():
		if generation != _generation or _closed: return
		_pressing = false
		_stamped = true
		_stamp_at = SEAL_HOME.get_center()
		_notice.text = _t("pressed")
		_sync()
		var result := export_draft()
		result["stamped"] = true
		submitted.emit(result))


func export_draft() -> Dictionary:
	var result := _draft.duplicate(true)
	result["case_id"] = str(_payload.get("case_id", ""))
	return result


func show_error(message: String) -> void:
	if _press_tween != null: _press_tween.kill()
	_generation += 1
	_pressing = false
	_closed = false
	_stamped = false
	_reviewing = false
	_stamp_press = 0.0
	_return_seal()
	if is_instance_valid(_notice): _notice.text = message
	_sync()


func request_close() -> void:
	if _closed or _pressing: return
	_closed = true
	_return_seal()
	closed.emit(export_draft())


func interaction_regions() -> Array:
	return [{"id":"seal", "rect":SEAL_HOME}, {"id":"stamp_area", "rect":SEAL_AREA}, {"id":"review", "rect":REVIEW_AREA}, {"id":"close", "rect":Rect2(1375,66,159,43)}]


func _draw() -> void:
	draw_set_transform(_origin,0,Vector2.ONE*_factor)
	Art.paint(self,"BG_workroom",Rect2(-640,-697,2880,1620))
	Art.paint(self,"resolution_slip",DOCUMENT)
	Art.paint(self,"pen",Rect2(1165,413,214,72),Color.WHITE,true)
	var center:=SEAL_AREA.get_center()
	if _stamped:Art.paint(self,"seal_mark",SEAL_AREA)
	else:draw_string(FONT,center+Vector2(-28,6),_t("target"),HORIZONTAL_ALIGNMENT_LEFT,76,16,MUTED)
	var dimensions:=Vector2(104,158)
	var at:=_stamp_at+Vector2(0,_stamp_press*4)
	if _holding or _pressing:at.y-=43
	Art.paint(self,"postal_seal",Rect2(at-dimensions*0.5,dimensions),Color.WHITE,true)
	if is_instance_valid(_seal_button) and _seal_button.has_focus() and not _holding:
		draw_line(SEAL_HOME.position+Vector2(17,158),SEAL_HOME.end-Vector2(17,0),TEAL,1.6,true)
	draw_set_transform(Vector2.ZERO)
