class_name DeductionBoard
extends Control
## Records the player's arrangement of independent evidence. This surface does
## not know or mark correct role mappings; factual confirmation belongs later.

signal recorded(claims: Dictionary)
signal dismissed
signal cue(kind: String)
signal changed(claims: Dictionary)

const CANVAS := Vector2(1100, 570)
const ORDER: Array[String] = ["old_nameplate", "event_archive", "handwriting_sample", "old_photo"]
const ROLES: Array[String] = ["address", "date", "sender"]
const ROLE_LABELS: Array[String] = ["旧住址记录", "寄出那一天", "寄件笔迹"]
const TITLES := {"old_nameplate": "旧门牌底册", "event_archive": "同日活动名册", "handwriting_sample": "有署名的活动卡", "old_photo": "观景台旧照片"}
const CARD_SIZE := Vector2(225, 168)
const CLOSE := Rect2(1035, 7, 47, 43)
const SEAL := Vector2(1002, 532)
const DETAIL_RECT := Rect2(216, 121, 669, 356)
const DETAIL_CLOSE := Rect2(830, 124, 49, 42)
const INK := Color("#31514f")
const MUTED := Color("#768a7f")
const PAPER := Color("#fff9e8")
const CREAM := Color("#f4eedb")
const LINE := Color("#c1c9b2")
const TEAL := Color("#6b9487")
const STAMP := Color("#a87b60")

var clues: Dictionary = {}
var claims: Dictionary = {}
var _cards: Array[Dictionary] = []
var _selected: int = -1
var _dragging: bool = false
var _drag_offset := Vector2.ZERO
var _source_role: String = ""
var _pointer := Vector2.ZERO
var _detail_id: String = ""
var _detail_view: RichTextLabel
var _hand_font: Font
var _message: String = ""
var _committing: bool = false
var _commit_elapsed: float = 0.0
var _sent: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	resized.connect(_layout_detail)
	set_process(true)


func configure(available_clues: Dictionary, known_ids: Array, previous: Dictionary = {}) -> void:
	clues = available_clues.duplicate(true)
	claims = {}
	_cards.clear()
	_selected = -1
	_dragging = false
	_detail_id = ""
	_committing = false
	_commit_elapsed = 0.0
	_sent = false
	_message = ""
	if ResourceLoader.exists("res://assets/fonts/Caveat.ttf"):
		_hand_font = load("res://assets/fonts/Caveat.ttf")
	else:
		_hand_font = get_theme_font("font")
	for id: String in ORDER:
		if id in known_ids and clues.get(id, {}) is Dictionary and not Dictionary(clues.get(id, {})).is_empty():
			var home := Vector2(149 + _cards.size() * 262, 414)
			_cards.append({"id": id, "home": home, "position": home})
	for role: String in ROLES:
		var id: String = str(previous.get(role, ""))
		var index: int = _find_card(id)
		if index >= 0 and not id in claims.values():
			claims[role] = id
			_cards[index]["position"] = _slot_center(role)
	if is_instance_valid(_detail_view):
		_detail_view.hide()
	set_process(true)
	queue_redraw()


func _scale_factor() -> float:
	return maxf(0.01, minf(size.x / CANVAS.x, size.y / CANVAS.y))


func _origin() -> Vector2:
	return (size - CANVAS * _scale_factor()) * 0.5


func _to_canvas(point: Vector2) -> Vector2:
	return (point - _origin()) / _scale_factor()


func _canvas_transform() -> void:
	draw_set_transform(_origin(), 0.0, Vector2.ONE * _scale_factor())


func _text(at: Vector2, value: String, font_size: int = 20, color: Color = INK, font_value: Font = null) -> void:
	draw_string(font_value if font_value != null else get_theme_font("font"), at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _slot_center(role: String) -> Vector2:
	return Vector2(209 + ROLES.find(role) * 338, 214)


func _slot_rect(role: String) -> Rect2:
	return Rect2(_slot_center(role) - Vector2(149, 92), Vector2(298, 184))


func _draw() -> void:
	_canvas_transform()
	draw_rect(Rect2(Vector2.ZERO, CANVAS), CREAM)
	_text(Vector2(27, 36), "把三份独立记录联系起来", 24)
	_text(Vector2(1048, 36), "×", 28, MUTED)
	_text(Vector2(29, 69), "记录推断，不会当场告诉你对错。双击记录，可阅读背面的完整原文。", 18, MUTED)
	for index: int in range(ROLES.size()):
		var role: String = ROLES[index]
		var rect: Rect2 = _slot_rect(role)
		_text(Vector2(rect.position.x + 15, 109), ROLE_LABELS[index], 19)
		draw_rect(rect, Color(0.40, 0.56, 0.46, 0.04))
		# Corners and a paper clip suggest a record mount, not a correctness box.
		for point: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
			var x_sign: float = 1.0 if point.x == rect.position.x else -1.0
			var y_sign: float = 1.0 if point.y == rect.position.y else -1.0
			draw_line(point, point + Vector2(18 * x_sign, 0), LINE, 1.2)
			draw_line(point, point + Vector2(0, 18 * y_sign), LINE, 1.2)
		if not claims.has(role):
			_text(rect.position + Vector2(74, 103), "放下一份记录", 18, Color("#9eaa96"))
		if _committing:
			_text(rect.position + Vector2(98, 177), "已 登 记", 14, STAMP)
	for index: int in range(_cards.size()):
		if index != _selected:
			_draw_card(index)
	if _selected >= 0:
		_draw_card(_selected)
	_canvas_transform()
	if _cards.is_empty():
		_text(Vector2(175, 419), "桌面上只会出现你亲眼找到的记录。先去现场看看。", 20, MUTED)
	_text(Vector2(29, 548), _message if not _message.is_empty() else "卡片可以换位；放回下方桌面，就能重新选择。", 17, MUTED)
	draw_circle(SEAL + Vector2(3, 4), 27, Color(0.25, 0.28, 0.20, 0.12))
	draw_circle(SEAL, 27, STAMP)
	draw_arc(SEAL, 21, 0, TAU, 32, PAPER, 1.1, true)
	_text(SEAL + Vector2(-16, 7), "登记", 16, PAPER)
	_text(Vector2(846, 539), "登记推断", 19)
	if not _detail_id.is_empty():
		draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.18, 0.27, 0.23, 0.23))
		draw_rect(Rect2(DETAIL_RECT.position + Vector2(5, 6), DETAIL_RECT.size), Color(0.20, 0.26, 0.19, 0.12))
		draw_rect(DETAIL_RECT, PAPER)
		draw_rect(DETAIL_RECT, LINE, false, 1.1)
		_text(Vector2(239, 157), str(clues.get(_detail_id, {}).get("title", "记录背面")), 23)
		_text(Vector2(844, 153), "×", 26, MUTED)
		_text(Vector2(240, 461), "点击纸边或 ×，把记录放回桌上。", 16, MUTED)
	draw_set_transform(Vector2.ZERO)


func _draw_card(index: int) -> void:
	var card: Dictionary = _cards[index]
	var at: Vector2 = card["position"]
	var id: String = card["id"]
	draw_set_transform(_origin() + at * _scale_factor(), 0.0, Vector2.ONE * _scale_factor())
	var rect := Rect2(-CARD_SIZE * 0.5, CARD_SIZE)
	draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color(0.22, 0.29, 0.22, 0.11))
	draw_rect(rect, PAPER)
	draw_rect(rect, LINE, false, 1.0)
	_text(Vector2(-96, -58), str(TITLES.get(id, "记录")), 15, MUTED)
	draw_line(Vector2(-96, -47), Vector2(96, -47), Color("#d8ddc9"), 1.0)
	match id:
		"old_nameplate":
			_text(Vector2(-95, -18), "ROSE COURT", 20)
			_text(Vector2(-95, 13), "J. Arlen / June Arlen", 17)
			_text(Vector2(-94, 42), "2020 · 夏", 18)
			_text(Vector2(-94, 66), "姓名条与全名一同留在底册", 13, MUTED)
		"event_archive":
			_text(Vector2(-94, -15), "18 JUL 2020", 24)
			_text(Vector2(-94, 15), "Mira Vale · June Arlen", 15)
			_text(Vector2(-94, 40), "Summer Community Night", 13)
			_text(Vector2(-94, 65), "当时留下的原始活动名单", 13, MUTED)
		"handwriting_sample":
			_text(Vector2(-96, -9), "Mira Vale", 35, INK, _hand_font)
			_text(Vector2(-96, 29), "July 18, 2020", 29, INK, _hand_font)
			_text(Vector2(-94, 54), "M 高起笔并回勾", 13, MUTED)
			_text(Vector2(-94, 73), "July 的 y 尾笔很长", 13, MUTED)
		"old_photo":
			draw_rect(Rect2(-95, -36, 71, 55), Color("#aec6b7"))
			draw_rect(Rect2(-95, -13, 71, 32), Color("#809f8f"))
			draw_circle(Vector2(-72, -9), 4.0, INK)
			draw_circle(Vector2(-49, -9), 4.0, STAMP)
			draw_line(Vector2(-72, -4), Vector2(-72, 11), INK, 6, true)
			draw_line(Vector2(-49, -4), Vector2(-49, 11), STAMP, 6, true)
			_text(Vector2(-12, -15), "18 July", 17)
			_text(Vector2(-12, 10), "2020", 21)
			_text(Vector2(-94, 42), "We said we'd come back", 13)
			_text(Vector2(-94, 61), "every summer.", 13)
			_text(Vector2(15, 76), "背影无法辨认人脸", 11, MUTED)
	_canvas_transform()


func _gui_input(event: InputEvent) -> void:
	if _committing:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if not _detail_id.is_empty():
			_close_detail()
		else:
			dismissed.emit()
		accept_event()
	elif event is InputEventMouseMotion:
		_pointer = _to_canvas(event.position)
		if _dragging and _selected >= 0:
			var point: Vector2 = _pointer - _drag_offset
			_cards[_selected]["position"] = Vector2(clampf(point.x, 119, 981), clampf(point.y, 166, 421))
		else:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _card_at(_pointer) >= 0 or _pointer.distance_to(SEAL) < 35.0 else Control.CURSOR_ARROW
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer = _to_canvas(event.position)
		if event.pressed:
			grab_focus()
			_handle_press(event.double_click)
		else:
			_release_card()
		accept_event()
		queue_redraw()


func _handle_press(double_click: bool) -> void:
	if not _detail_id.is_empty():
		_close_detail()
		return
	if CLOSE.has_point(_pointer):
		dismissed.emit()
		return
	if _pointer.distance_to(SEAL) <= 33.0 or Rect2(837, 509, 129, 47).has_point(_pointer):
		_stamp()
		return
	_selected = _card_at(_pointer)
	if _selected < 0:
		return
	var card: Dictionary = _cards[_selected]
	if double_click:
		_open_detail(str(card["id"]))
		return
	_dragging = true
	_drag_offset = _pointer - Vector2(card["position"])
	_source_role = _role_for(str(card["id"]))
	_message = ""
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	cue.emit("paper")


func _release_card() -> void:
	if not _dragging or _selected < 0:
		return
	_dragging = false
	var card: Dictionary = _cards[_selected]
	var id: String = card["id"]
	var destination: String = ""
	for role: String in ROLES:
		if Vector2(card["position"]).distance_to(_slot_center(role)) <= 63.0:
			destination = role
			break
	if not destination.is_empty():
		var previous_id: String = str(claims.get(destination, ""))
		if not _source_role.is_empty():
			claims.erase(_source_role)
		claims[destination] = id
		card["position"] = _slot_center(destination)
		if not previous_id.is_empty() and previous_id != id:
			var previous_index: int = _find_card(previous_id)
			if previous_index >= 0:
				if not _source_role.is_empty() and _source_role != destination:
					claims[_source_role] = previous_id
					_cards[previous_index]["position"] = _slot_center(_source_role)
				else:
					_cards[previous_index]["position"] = _cards[previous_index]["home"]
		cue.emit("paper")
	elif Vector2(card["position"]).y >= 337.0:
		if not _source_role.is_empty():
			claims.erase(_source_role)
		card["position"] = card["home"]
	else:
		card["position"] = _slot_center(_source_role) if not _source_role.is_empty() else card["home"]
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	changed.emit(claims.duplicate(true))


func _stamp() -> void:
	if claims.size() != 3:
		_message = "先放下三份不同的记录，再把推断登记下来。"
		return
	for role: String in ROLES:
		if not claims.has(role):
			return
	_committing = true
	_commit_elapsed = 0.0
	cue.emit("stamp")
	queue_redraw()


func _process(delta: float) -> void:
	if not _committing or _sent:
		return
	_commit_elapsed += delta
	if _commit_elapsed >= 0.35:
		_sent = true
		set_process(false)
		recorded.emit(claims.duplicate(true))


func _role_for(id: String) -> String:
	for role: String in ROLES:
		if claims.get(role, "") == id:
			return role
	return ""


func _find_card(id: String) -> int:
	for index: int in range(_cards.size()):
		if _cards[index]["id"] == id:
			return index
	return -1


func _card_at(point: Vector2) -> int:
	if _selected >= 0 and Rect2(Vector2(_cards[_selected]["position"]) - CARD_SIZE * 0.5, CARD_SIZE).has_point(point):
		return _selected
	for index: int in range(_cards.size() - 1, -1, -1):
		if Rect2(Vector2(_cards[index]["position"]) - CARD_SIZE * 0.5, CARD_SIZE).has_point(point):
			return index
	return -1


func _open_detail(id: String) -> void:
	_detail_id = id
	_dragging = false
	if not is_instance_valid(_detail_view):
		_detail_view = RichTextLabel.new()
		_detail_view.bbcode_enabled = false
		_detail_view.scroll_active = true
		_detail_view.selection_enabled = true
		_detail_view.add_theme_font_size_override("normal_font_size", 21)
		_detail_view.add_theme_color_override("default_color", INK)
		_detail_view.add_theme_constant_override("line_separation", 8)
		_detail_view.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		_detail_view.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		add_child(_detail_view)
	var entry: Dictionary = clues.get(id, {})
	_detail_view.text = str(entry.get("source", "")) + "\n\n" + str(entry.get("text", ""))
	_detail_view.show()
	_detail_view.scroll_to_line(0)
	_layout_detail()
	cue.emit("flip")
	queue_redraw()


func _close_detail() -> void:
	_detail_id = ""
	if is_instance_valid(_detail_view):
		_detail_view.hide()
	queue_redraw()


func _layout_detail() -> void:
	if is_instance_valid(_detail_view):
		_detail_view.position = _origin() + Vector2(241, 179) * _scale_factor()
		_detail_view.size = Vector2(615, 255)
		_detail_view.scale = Vector2.ONE * _scale_factor()
