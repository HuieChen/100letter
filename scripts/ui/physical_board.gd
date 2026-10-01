class_name PhysicalBoard
extends Control
## Paper operations share one small drawing/input surface. No operation advances
## from elapsed time alone: every stage needs a held pointer or a placed object.

signal completed(mode: String, result: Dictionary)
signal dismissed
signal progress(data: Dictionary)
signal cue(kind: String)

const CANVAS := Vector2(1180, 610)
const INK := Color("#304e50")
const MUTED := Color("#7c9088")
const TEAL := Color("#5b9187")
const CREAM := Color("#faf2dd")
const PAPER := Color("#fff9e9")
const CORAL := Color("#bf735f")
const LINE := Color("#cbd0b9")
const SHADOW := Color(0.20, 0.31, 0.30, 0.10)
const CLOSE := Rect2(1094, 10, 58, 42)
const PAGE_TARGET := Vector2(796, 323)
const EDGE_TARGET := Vector2(982, 323)
const TAPE_TARGET := Vector2(796, 466)
const STAMP_TARGET := Vector2(798, 454)

var mode: String = ""
var letter: Dictionary = {}
var stage: int = 0
var _pieces: Array[Dictionary] = []
var _selected: int = -1
var _dragging: bool = false
var _drag_offset := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _pointer := Vector2.ZERO
var _moving := Vector2.ZERO
var _hover: int = -1
var _tool: String = ""
var _path := PackedVector2Array()
var _path_length: float = 0.0
var _trace_distance: float = 0.0
var _mistakes: int = 0
var _tears: Array[Vector2] = []
var _off_path: bool = false
var _stamp_hold: float = 0.0
var _alignment_error: float = 0.0
var _records: Array[Dictionary] = []
var _match_serial: String = ""
var _match_date: String = ""
var _matched_row: int = -1
var _message: String = ""
var _finishing: bool = false
var _completion_sent: bool = false
var _finish_delay: float = 0.0
var _finish_result: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	set_process(true)
	queue_redraw()


func configure(next_mode: String, next_letter: Dictionary, existing: Dictionary = {}) -> void:
	mode = next_mode
	letter = next_letter.duplicate(true)
	stage = int(existing.get("stage", 0))
	_mistakes = int(existing.get("mistakes", 0))
	_tool = str(existing.get("tool", ""))
	_alignment_error = float(existing.get("alignment_error", 0.0))
	_pieces.clear()
	_tears.clear()
	_records.clear()
	_dragging = false
	_selected = -1
	_finishing = false
	_completion_sent = false
	_finish_delay = 0.0
	set_process(true)
	_matched_row = -1
	_message = ""
	_stamp_hold = 0.0
	if mode == "fragments":
		_setup_fragments(existing)
	elif mode == "open":
		_setup_open(existing)
	elif mode == "restore":
		stage = clampi(stage, 0, 3)
		_moving = _restore_start(stage)
	elif mode == "archive":
		for raw: Variant in letter.get("records", []):
			if raw is Dictionary:
				_records.append(raw)
		_match_serial = str(letter.get("match_serial", ""))
		_match_date = str(letter.get("match_date", ""))
		_moving = Vector2(1000, 228)
	if existing.has("moving"):
		_moving = _read_vector(existing["moving"], _moving)
	if mode == "fragments" and not _pieces.is_empty():
		var already_joined: bool = true
		for piece: Dictionary in _pieces:
			already_joined = already_joined and bool(piece["locked"])
		if already_joined:
			_finish({"address": "Rose Court 302", "pieces": 6})
	queue_redraw()


func _setup_fragments(existing: Dictionary) -> void:
	var starts: Array[Vector2] = [Vector2(130, 189), Vector2(348, 207), Vector2(154, 386), Vector2(350, 393), Vector2(551, 506), Vector2(904, 510)]
	var rotations: Array[int] = [0, 1, 3, 2, 1, 0]
	var saved: Array = existing.get("pieces", [])
	for index: int in range(6):
		var column: int = index % 3
		var row: int = index / 3
		var target := Vector2(665 + column * 160, 226 + row * 130)
		var part := {"position": starts[index], "target": target, "turn": rotations[index], "locked": false, "polygon": _piece_polygon(column, row)}
		if index < saved.size() and saved[index] is Dictionary:
			var entry: Dictionary = saved[index]
			part["position"] = _read_vector(entry.get("position", []), starts[index])
			part["turn"] = int(entry.get("turn", rotations[index])) % 4
			part["locked"] = bool(entry.get("locked", false))
			if bool(part["locked"]):
				part["position"] = target
				part["turn"] = 0
		_pieces.append(part)


func _piece_polygon(column: int, row: int) -> PackedVector2Array:
	# Adjacent pieces use the same torn edge in reverse, so their silhouettes
	# genuinely join. Edge details remain useful when the label is rotated.
	var points := PackedVector2Array()
	var top := _horizontal_edge(row > 0)
	var right := _vertical_edge(column < 2)
	var bottom := _horizontal_edge(row < 1)
	var left := _vertical_edge(column > 0)
	for point: Vector2 in top:
		points.append(point - Vector2(80, 65))
	for i: int in range(1, right.size()):
		points.append(right[i] + Vector2(80, -65))
	for i: int in range(bottom.size() - 2, -1, -1):
		points.append(bottom[i] + Vector2(-80, 65))
	for i: int in range(left.size() - 2, 0, -1):
		points.append(left[i] - Vector2(80, 65))
	return points


func _horizontal_edge(torn: bool) -> PackedVector2Array:
	if torn:
		return PackedVector2Array([Vector2(0, 0), Vector2(34, 3), Vector2(60, -10), Vector2(94, 7), Vector2(122, -5), Vector2(160, 0)])
	return PackedVector2Array([Vector2(0, 0), Vector2(47, -2), Vector2(105, 2), Vector2(160, 0)])


func _vertical_edge(torn: bool) -> PackedVector2Array:
	if torn:
		return PackedVector2Array([Vector2(0, 0), Vector2(-5, 29), Vector2(10, 57), Vector2(-7, 94), Vector2(0, 130)])
	return PackedVector2Array([Vector2(0, 0), Vector2(2, 39), Vector2(-2, 83), Vector2(0, 130)])


func _setup_open(existing: Dictionary) -> void:
	_path.clear()
	_path_length = 0.0
	for index: int in range(51):
		var t: float = float(index) / 50.0
		_path.append(Vector2(155 + 820 * t, 269 - sin(t * PI) * 29 + sin(t * TAU) * 9))
		if index > 0:
			_path_length += _path[index].distance_to(_path[index - 1])
	_trace_distance = clampf(float(existing.get("trace_distance", 0.0)), 0.0, _path_length)
	for raw: Variant in existing.get("tears", []):
		_tears.append(_read_vector(raw, Vector2.ZERO))
	stage = clampi(stage, 0, 1)
	_moving = Vector2(520, 294)


func _scale_factor() -> float:
	return maxf(0.01, minf(size.x / CANVAS.x, size.y / CANVAS.y))


func _canvas_origin() -> Vector2:
	return (size - CANVAS * _scale_factor()) * 0.5


func _to_canvas(point: Vector2) -> Vector2:
	return (point - _canvas_origin()) / _scale_factor()


func _canvas_transform() -> void:
	draw_set_transform(_canvas_origin(), 0.0, Vector2.ONE * _scale_factor())


func _font() -> Font:
	return get_theme_font("font")


func _text(at: Vector2, text: String, font_size: int = 20, color: Color = INK, width: float = -1.0) -> void:
	draw_string(_font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)


func _wrapped(at: Vector2, text: String, width: float, font_size: int = 18, color: Color = INK) -> void:
	draw_multiline_string(_font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, 4, color)


func _paper(rect: Rect2, color: Color = PAPER) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), SHADOW)
	draw_rect(rect, color)
	draw_rect(rect, LINE, false, 1.2)


func _draw() -> void:
	_canvas_transform()
	draw_rect(Rect2(Vector2.ZERO, CANVAS), CREAM)
	draw_line(Vector2(28, 69), Vector2(1152, 69), LINE, 1.2)
	_text(Vector2(1110, 39), "×", 29, MUTED)
	if mode == "fragments":
		_draw_fragments()
	elif mode == "open":
		_draw_open()
	elif mode == "restore":
		_draw_restore()
	elif mode == "archive":
		_draw_archive()
	if not _message.is_empty():
		_wrapped(Vector2(40, 583), _message, 1095, 18, CORAL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_fragments() -> void:
	_text(Vector2(32, 39), "水损标签  /  顺着纸边、邮戳与枝叶拼接", 23)
	_text(Vector2(40, 104), "拖动碎片。选中后按 R 或右键旋转；靠近时轻轻放下。", 19, MUTED)
	draw_rect(Rect2(574, 144, 502, 279), Color(0.34, 0.57, 0.53, 0.05))
	draw_rect(Rect2(574, 144, 502, 279), LINE, false, 1.0)
	_text(Vector2(718, 134), "把纸片放在这张衬纸上", 17, MUTED)
	for index: int in range(_pieces.size()):
		if index != _selected:
			_draw_piece(index)
	if _selected >= 0:
		_draw_piece(_selected)
	_canvas_transform()


func _draw_piece(index: int) -> void:
	var piece: Dictionary = _pieces[index]
	var at: Vector2 = piece["position"]
	var angle: float = float(piece["turn"]) * PI * 0.5
	draw_set_transform(_canvas_origin() + at * _scale_factor(), angle, Vector2.ONE * _scale_factor())
	var polygon: PackedVector2Array = piece["polygon"]
	var shadow_points := PackedVector2Array()
	for point: Vector2 in polygon:
		shadow_points.append(point + Vector2(3, 4))
	draw_colored_polygon(shadow_points, SHADOW)
	draw_colored_polygon(polygon, Color("#eee4c9") if index == 3 else PAPER)
	var outline := polygon.duplicate()
	outline.append(outline[0])
	draw_polyline(outline, Color("#b5bb9f"), 1.2, true)
	var labels: Array[String] = ["Rose", "Court", "302", "转寄标签", "SOLMERE", "17 · V"]
	_text(Vector2(-66, 16), labels[index], 32 if index < 3 else 19, INK)
	# A continuous stem crosses the lower row; stamp arcs cross the upper row.
	if index >= 3:
		draw_line(Vector2(-80, 35), Vector2(80, 35), TEAL, 2.0)
		for x: float in [-42.0, 20.0, 55.0]:
			draw_line(Vector2(x, 35), Vector2(x + 15, 23), TEAL, 1.5)
			draw_line(Vector2(x + 15, 35), Vector2(x + 26, 47), TEAL, 1.5)
	else:
		draw_line(Vector2(-80, -37), Vector2(80, -37), Color(0.73, 0.43, 0.33, 0.40), 2.0)
		draw_line(Vector2(-80, -30), Vector2(80, -30), Color(0.73, 0.43, 0.33, 0.25), 1.0)
	if index == _selected and not bool(piece["locked"]):
		draw_circle(Vector2(57, 43), 3.0, TEAL)
	_canvas_transform()


func _draw_open() -> void:
	_text(Vector2(32, 39), "拆封桌  /  取出一封尚未抵达的信", 23)
	if stage == 0:
		_draw_tool(Rect2(42, 98, 280, 86), "safe", "圆头纸舟", "慢一些 · 容错较宽")
		_draw_tool(Rect2(340, 98, 280, 86), "quick", "细线飞梭", "快一些 · 更易留下裂痕")
		_text(Vector2(649, 124), "选择一种虚构拆封工具", 18, MUTED)
		_text(Vector2(649, 157), "从圆点按住，慢慢沿弯曲虚线移动。", 18, MUTED)
		_paper(Rect2(102, 215, 942, 300), Color("#ece2c9"))
		draw_line(Vector2(104, 511), Vector2(573, 316), LINE, 1.5)
		draw_line(Vector2(1042, 511), Vector2(573, 316), LINE, 1.5)
		for index: int in range(0, _path.size() - 1, 2):
			draw_line(_path[index], _path[index + 1], MUTED, 2.5, true)
		if _trace_distance > 1.0:
			var shown := PackedVector2Array([_path[0]])
			var distance: float = 0.0
			for index: int in range(1, _path.size()):
				distance += _path[index].distance_to(_path[index - 1])
				if distance < _trace_distance:
					shown.append(_path[index])
			shown.append(_point_on_path(_trace_distance))
			draw_polyline(shown, TEAL, 4.0, true)
		draw_circle(_point_on_path(_trace_distance), 8.0, CORAL if _off_path else TEAL)
		draw_arc(_point_on_path(_trace_distance), 14.0, 0, TAU, 24, Color(0.36, 0.57, 0.53, 0.25), 1.5)
		for tear: Vector2 in _tears:
			draw_line(tear + Vector2(-4, 4), tear + Vector2(5, 15), CORAL, 2.0)
		_text(Vector2(230, 429), "SOLMERE  ·  异常邮件", 28, Color("#879382"))
		_text(Vector2(345, 554), "可以放手。再次按住圆点，就能接着操作。", 18, MUTED)
	else:
		_text(Vector2(42, 111), "封口已经松开。捏住内页，向上拖出并展开。", 20, MUTED)
		_paper(Rect2(247, 325, 674, 191), Color("#e8dcc1"))
		var pull: float = clampf(294 - _moving.y, 0.0, 170.0)
		_paper(Rect2(_moving - Vector2(153, 65), Vector2(306, 178 + pull)))
		draw_line(_moving + Vector2(-131, 9), _moving + Vector2(128, 9), LINE, 1.0)
		_text(_moving + Vector2(-119, -17), "轻轻展开", 21, TEAL)
		for row: int in range(4):
			draw_line(_moving + Vector2(-118, 40 + row * 23), _moving + Vector2(90 - row * 7, 40 + row * 23), LINE, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(247, 350), Vector2(584, 442), Vector2(921, 350), Vector2(921, 517), Vector2(247, 517)]), Color("#efe4cd"))
		draw_polyline(PackedVector2Array([Vector2(247, 350), Vector2(584, 442), Vector2(921, 350)]), LINE, 1.5, true)
		_text(Vector2(444, 559), "↑  内页需要亲手取出", 18, MUTED)


func _draw_tool(rect: Rect2, tool_id: String, name_text: String, description: String) -> void:
	_paper(rect, Color("#dfe9db") if _tool == tool_id else PAPER)
	_text(rect.position + Vector2(18, 31), name_text, 22)
	_text(rect.position + Vector2(18, 64), description, 17, MUTED)


func _draw_restore() -> void:
	_text(Vector2(32, 39), "修复桌  /  让纸张重新合拢", 23)
	var directions: Array[String] = ["① 对齐折痕：把信纸拖到右侧的半透明轮廓。", "② 补回边缘：把窄纸边放回信纸右侧的缺口。", "③ 封合：把修复带横放在纸页下方的折缝上。", "③ 封合：拿起修复印，在修复带上按住片刻，再松手。"]
	_text(Vector2(42, 105), directions[stage], 20, MUTED)
	var target := Rect2(PAGE_TARGET - Vector2(168, 165), Vector2(336, 330))
	draw_rect(target, Color(0.34, 0.56, 0.51, 0.08))
	draw_rect(target, LINE, false, 1.5)
	for y: float in [253.0, 395.0]:
		draw_dashed_line(Vector2(637, y), Vector2(955, y), MUTED, 1.0, 7.0)
	if stage == 0:
		_draw_restore_page(_moving, false)
	else:
		_draw_restore_page(PAGE_TARGET, true)
		var edge_rect := Rect2(EDGE_TARGET - Vector2(20, 153), Vector2(40, 306))
		if stage == 1:
			draw_rect(edge_rect, Color(0.34, 0.56, 0.51, 0.09))
			_draw_edge(_moving)
		else:
			_draw_edge(EDGE_TARGET)
			draw_dashed_line(TAPE_TARGET - Vector2(96, 0), TAPE_TARGET + Vector2(96, 0), MUTED, 1.5, 5.0)
			if stage == 2:
				_draw_tape(_moving)
			else:
				_draw_tape(TAPE_TARGET)
				_draw_stamp(_moving)
				if _dragging and _moving.distance_to(STAMP_TARGET) < 46.0:
					draw_arc(STAMP_TARGET, 50, -PI / 2, -PI / 2 + TAU * minf(_stamp_hold / 0.55, 1.0), 30, TEAL, 3.0)
	if stage < 3:
		_text(Vector2(65, 517), "材料托盘", 19, MUTED)
	_text(Vector2(600, 552), "折痕对齐  →  纸边复位  →  修复带与印记", 17, MUTED)


func _draw_restore_page(at: Vector2, settled: bool) -> void:
	_paper(Rect2(at - Vector2(168, 165), Vector2(336, 330)))
	for offset: float in [-70.0, 72.0]:
		draw_line(at + Vector2(-150, offset), at + Vector2(150, offset), LINE, 1.2)
	_text(at + Vector2(-134, -113), "SOLMERE POST", 20, TEAL)
	for row: int in range(5):
		draw_line(at + Vector2(-134, -42 + row * 22), at + Vector2(90 - row * 4, -42 + row * 22), LINE, 2.0)
	if settled and _mistakes > 1:
		draw_line(at + Vector2(110, 126), at + Vector2(128, 142), CORAL, 1.2)


func _draw_edge(at: Vector2) -> void:
	var points := PackedVector2Array([Vector2(-18, -153), Vector2(20, -153), Vector2(20, 153), Vector2(-18, 153), Vector2(-9, 108), Vector2(-21, 63), Vector2(-7, 13), Vector2(-22, -49), Vector2(-9, -101)])
	for index: int in range(points.size()):
		points[index] += at
	draw_colored_polygon(points, Color("#f6eccf"))
	points.append(points[0])
	draw_polyline(points, LINE, 1.2, true)


func _draw_tape(at: Vector2) -> void:
	draw_rect(Rect2(at - Vector2(97, 20), Vector2(194, 40)), Color("#d4dfbc"))
	draw_rect(Rect2(at - Vector2(97, 20), Vector2(194, 40)), Color("#abb998"), false, 1.0)
	_text(at + Vector2(-59, 7), "修  复  带", 18, Color("#6f8467"))


func _draw_stamp(at: Vector2) -> void:
	draw_circle(at + Vector2(3, 6), 43, SHADOW)
	draw_circle(at, 42, Color("#c97d63"))
	draw_arc(at, 33, 0, TAU, 40, PAPER, 1.5)
	_text(at + Vector2(-21, 8), "邮修", 21, PAPER)


func _draw_archive() -> void:
	_text(Vector2(32, 39), "旧异常件清单  /  核对编号与日期", 23)
	_text(Vector2(42, 100), "把今日旧信的记录章拖到对应行。编号、日期需要同时相符。", 19, MUTED)
	_paper(Rect2(42, 124, 729, 424))
	_text(Vector2(62, 151), "邮件编号", 17, TEAL)
	_text(Vector2(338, 151), "登记日期", 17, TEAL)
	_text(Vector2(547, 151), "原记录", 17, TEAL)
	var count: int = mini(_records.size(), 11)
	for index: int in range(count):
		var rect := _archive_row_rect(index)
		if index % 2 == 0:
			draw_rect(rect, Color(0.35, 0.56, 0.52, 0.045))
		if index == _matched_row:
			draw_rect(rect, Color(0.35, 0.56, 0.52, 0.13))
		var record: Dictionary = _records[index]
		_text(rect.position + Vector2(15, 24), _record_serial(record), 19)
		_text(rect.position + Vector2(291, 24), str(record.get("date", "")), 19)
		_text(rect.position + Vector2(500, 24), str(record.get("status", "")), 18, CORAL)
		if index == _matched_row:
			_text(rect.position + Vector2(632, 24), "对应", 17, TEAL)
	_text(Vector2(825, 151), "今日收到的旧信", 20)
	if _matched_row < 0:
		_paper(Rect2(_moving - Vector2(154, 59), Vector2(308, 118)), Color("#e5ead8"))
		_text(_moving + Vector2(-132, -18), "案件 04 · 旧件记录章", 18, TEAL)
		_text(_moving + Vector2(-132, 16), _match_serial, 21)
		_text(_moving + Vector2(-132, 45), _match_date, 19, MUTED)
	_wrapped(Vector2(818, 382), "HOLD  暂扣\nRETURN  退回\nDELAY  延迟", 303, 20, MUTED)


func _gui_input(event: InputEvent) -> void:
	if _finishing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_save_progress()
			dismissed.emit()
			accept_event()
		elif event.keycode == KEY_R and mode == "fragments":
			_rotate_selected()
			accept_event()
		return
	if event is InputEventMouseMotion:
		_pointer = _to_canvas(event.position)
		_handle_motion()
		queue_redraw()
	elif event is InputEventMouseButton:
		_pointer = _to_canvas(event.position)
		if event.pressed:
			grab_focus()
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and mode == "fragments":
			_selected = _piece_at(_pointer)
			_rotate_selected()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and CLOSE.has_point(_pointer):
				_save_progress()
				dismissed.emit()
				accept_event()
				return
			if event.pressed:
				_handle_press()
			else:
				_handle_release()
			accept_event()
		queue_redraw()


func _handle_press() -> void:
	if not (mode == "open" and stage == 0 and _mistakes >= 3):
		_message = ""
	if mode == "fragments":
		_selected = _piece_at(_pointer)
		if _selected >= 0 and not bool(_pieces[_selected]["locked"]):
			_begin_drag(_pieces[_selected]["position"])
	elif mode == "open":
		if stage == 0:
			if _trace_distance < 1.0:
				if Rect2(42, 98, 280, 86).has_point(_pointer):
					_tool = "safe"
					cue.emit("tool")
					_save_progress()
				elif Rect2(340, 98, 280, 86).has_point(_pointer):
					_tool = "quick"
					cue.emit("tool")
					_save_progress()
			if _tool.is_empty():
				return
			if _pointer.distance_to(_point_on_path(_trace_distance)) < _tolerance() + 6.0:
				_dragging = true
				_off_path = false
				cue.emit("tool")
		elif Rect2(_moving - Vector2(153, 65), Vector2(306, 150)).has_point(_pointer):
			_begin_drag(_moving)
	elif mode == "restore":
		if _restore_hit_rect().has_point(_pointer):
			_begin_drag(_moving)
			_stamp_hold = 0.0
	elif mode == "archive":
		if Rect2(_moving - Vector2(154, 59), Vector2(308, 118)).has_point(_pointer):
			_begin_drag(_moving)


func _begin_drag(at: Vector2) -> void:
	_dragging = true
	_drag_offset = _pointer - at
	_drag_origin = at
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	cue.emit("paper")


func _handle_motion() -> void:
	if not _dragging:
		if mode == "fragments":
			_hover = _piece_at(_pointer)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover >= 0 else Control.CURSOR_ARROW
		elif mode == "restore":
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _restore_hit_rect().has_point(_pointer) else Control.CURSOR_ARROW
		elif mode == "archive":
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if Rect2(_moving - Vector2(154, 59), Vector2(308, 118)).has_point(_pointer) else Control.CURSOR_ARROW
		return
	var candidate: Vector2 = _pointer - _drag_offset
	if mode == "fragments" and _selected >= 0:
		_pieces[_selected]["position"] = Vector2(clampf(candidate.x, 90, 1090), clampf(candidate.y, 162, 526))
	elif mode == "open" and stage == 1:
		_moving = Vector2(clampf(candidate.x, 335, 756), clampf(candidate.y, 117, 310))
	elif mode == "restore":
		var margin: Vector2 = Vector2(168, 166) if stage == 0 else Vector2(45, 70)
		_moving = Vector2(clampf(candidate.x, margin.x, 1135), clampf(candidate.y, 143, 535))
	elif mode == "archive":
		_moving = Vector2(clampf(candidate.x, 60, 1025), clampf(candidate.y, 150, 540))


func _handle_release() -> void:
	if not _dragging:
		return
	_dragging = false
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	cue.emit("paper")
	if mode == "fragments" and _selected >= 0:
		_try_snap_piece(_selected)
	elif mode == "open":
		if stage == 1 and _moving.y <= 145.0:
			_finish({"tool": _tool, "mistakes": _mistakes, "trace_quality": clampf(1.0 - _mistakes * (0.07 if _tool == "safe" else 0.15), 0.1, 1.0)})
	elif mode == "restore":
		_release_restore()
	elif mode == "archive":
		_release_archive()
	_save_progress()


func _piece_at(point: Vector2) -> int:
	if _selected >= 0:
		var selected: Dictionary = _pieces[_selected]
		var local: Vector2 = (point - Vector2(selected["position"])).rotated(-float(selected["turn"]) * PI * 0.5)
		if Geometry2D.is_point_in_polygon(local, selected["polygon"]):
			return _selected
	for index: int in range(_pieces.size() - 1, -1, -1):
		var part: Dictionary = _pieces[index]
		var local: Vector2 = (point - Vector2(part["position"])).rotated(-float(part["turn"]) * PI * 0.5)
		if Geometry2D.is_point_in_polygon(local, part["polygon"]):
			return index
	return -1


func _rotate_selected() -> void:
	if _selected >= 0 and not bool(_pieces[_selected]["locked"]):
		_pieces[_selected]["turn"] = (int(_pieces[_selected]["turn"]) + 1) % 4
		cue.emit("paper")
		_save_progress()
		queue_redraw()


func _try_snap_piece(index: int) -> bool:
	var piece: Dictionary = _pieces[index]
	var position_value: Vector2 = piece["position"]
	var target: Vector2 = piece["target"]
	if int(piece["turn"]) != 0 or position_value.distance_to(target) > 23.0:
		return false
	piece["position"] = target
	piece["locked"] = true
	cue.emit("snap")
	var all_joined: bool = true
	for part: Dictionary in _pieces:
		all_joined = all_joined and bool(part["locked"])
	if all_joined:
		_message = "Rose Court 302。旧标签上的地址终于连成了一行。"
		_finish({"address": "Rose Court 302", "pieces": 6}, 1.2)
	return true


func _process(delta: float) -> void:
	if _finishing:
		if _completion_sent:
			return
		_finish_delay -= delta
		if _finish_delay <= 0.0:
			_completion_sent = true
			set_process(false)
			completed.emit(mode, _finish_result)
		return
	if _dragging and mode == "open" and stage == 0:
		_advance_trace(delta)
		queue_redraw()
	elif _dragging and mode == "restore" and stage == 3:
		if _moving.distance_to(STAMP_TARGET) < 46.0:
			_stamp_hold += delta
		else:
			_stamp_hold = 0.0
		queue_redraw()


func _advance_trace(delta: float) -> void:
	var nearest := _nearest_path(_pointer)
	var near_distance: float = nearest.x
	var along: float = nearest.y
	var allowed_ahead: float = 120.0 if _tool == "safe" else 172.0
	var invalid: bool = near_distance > _tolerance() or along > _trace_distance + allowed_ahead or along < _trace_distance - 40.0
	if invalid:
		if not _off_path:
			_mistakes += 1
			_tears.append(_point_on_path(_trace_distance))
			if _mistakes >= 6:
				_message = "再沿错误边线划下去会损坏这封信。停一停，重新找到封线上的圆点。"
			elif _mistakes >= 3:
				_message = "纸边正在起毛，放慢一点。可以松手，再从圆点接着走。"
			cue.emit("tool")
		_off_path = true
		return
	_off_path = false
	var speed: float = 195.0 if _tool == "safe" else 450.0
	_trace_distance += minf(maxf(0.0, along - _trace_distance), speed * delta)
	if _trace_distance >= _path_length - 6.0:
		_trace_distance = _path_length
		stage = 1
		_dragging = false
		_moving = Vector2(520, 294)
		cue.emit("snap")
		_save_progress()


func _tolerance() -> float:
	return 34.0 if _tool == "safe" else 15.0


func _point_on_path(distance_value: float) -> Vector2:
	var remaining: float = distance_value
	for index: int in range(1, _path.size()):
		var segment: float = _path[index].distance_to(_path[index - 1])
		if remaining <= segment:
			return _path[index - 1].lerp(_path[index], clampf(remaining / segment, 0.0, 1.0))
		remaining -= segment
	return _path[_path.size() - 1] if not _path.is_empty() else Vector2.ZERO


func _nearest_path(point: Vector2) -> Vector2:
	var best_distance: float = INF
	var best_along: float = 0.0
	var traversed: float = 0.0
	for index: int in range(1, _path.size()):
		var start: Vector2 = _path[index - 1]
		var finish: Vector2 = _path[index]
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(point, start, finish)
		var distance_value: float = point.distance_to(nearest)
		if distance_value < best_distance:
			best_distance = distance_value
			best_along = traversed + start.distance_to(nearest)
		traversed += start.distance_to(finish)
	return Vector2(best_distance, best_along)


func _restore_start(next_stage: int) -> Vector2:
	var starts: Array[Vector2] = [Vector2(250, 322), Vector2(272, 320), Vector2(255, 298), Vector2(256, 318)]
	return starts[clampi(next_stage, 0, 3)]


func _restore_hit_rect() -> Rect2:
	var dimensions: Array[Vector2] = [Vector2(336, 330), Vector2(65, 312), Vector2(194, 55), Vector2(90, 90)]
	return Rect2(_moving - dimensions[stage] * 0.5, dimensions[stage])


func _release_restore() -> void:
	var targets: Array[Vector2] = [PAGE_TARGET, EDGE_TARGET, TAPE_TARGET, STAMP_TARGET]
	var tolerance: float = 30.0 if stage == 0 else 38.0
	if stage == 3:
		tolerance = 46.0
	var error: float = _moving.distance_to(targets[stage])
	if error < tolerance:
		if stage == 3:
			if _stamp_hold >= 0.55:
				cue.emit("stamp")
				_moving = STAMP_TARGET
				_finish({"quality": clampf(0.99 - _mistakes * 0.055 - _alignment_error * 0.001, 0.3, 0.99), "misalignments": _mistakes}, 0.7)
			else:
				_message = "让修复印在纸上停留一会儿，等外圈落稳再松手。"
				_moving = _restore_start(stage)
		else:
			_alignment_error += error
			stage += 1
			_moving = _restore_start(stage)
			cue.emit("snap")
	else:
		if _moving.distance_to(_drag_origin) > 30.0:
			_mistakes += 1
		_message = "还没有贴合。沿着折痕或纸边再调整一点。"
		_moving = _restore_start(stage)


func _archive_row_rect(index: int) -> Rect2:
	return Rect2(47, 163 + index * 34, 719, 34)


func _record_serial(record: Dictionary) -> String:
	return str(record.get("serial", record.get("number", record.get("id", ""))))


func _release_archive() -> void:
	for index: int in range(mini(_records.size(), 11)):
		if _archive_row_rect(index).has_point(_pointer):
			var record: Dictionary = _records[index]
			if _record_serial(record) == _match_serial and str(record.get("date", "")) == _match_date:
				_matched_row = index
				cue.emit("stamp")
				_message = "同一枚编号，同一天邮戳。旧信在清单里留下了一个人为决定。"
				_finish({"serial": _match_serial, "date": _match_date, "record": record.duplicate(true)}, 1.2)
				return
			_message = "编号与日期还没有同时对应。再比一眼。"
			break
	_moving = Vector2(1000, 228)


func _save_progress() -> void:
	var data := {"mode": mode, "stage": stage, "mistakes": _mistakes, "tool": _tool, "trace_distance": _trace_distance, "alignment_error": _alignment_error, "moving": [_moving.x, _moving.y]}
	var parts: Array[Dictionary] = []
	for piece: Dictionary in _pieces:
		var position_value: Vector2 = piece["position"]
		parts.append({"position": [position_value.x, position_value.y], "turn": piece["turn"], "locked": piece["locked"]})
	data["pieces"] = parts
	var marks: Array = []
	for tear: Vector2 in _tears:
		marks.append([tear.x, tear.y])
	data["tears"] = marks
	progress.emit(data)


func _finish(result: Dictionary, delay: float = 0.35) -> void:
	if _finishing:
		return
	_finishing = true
	_finish_result = result
	_finish_delay = delay
	_dragging = false
	queue_redraw()


func _read_vector(raw: Variant, fallback: Vector2) -> Vector2:
	if raw is Array and raw.size() == 2:
		return Vector2(float(raw[0]), float(raw[1]))
	if raw is Vector2:
		return raw
	return fallback
