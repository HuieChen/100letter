class_name SceneProps
extends Control
## Independent scene props overlaid on unchanged location artwork. These are
## small physical silhouettes, with labels in hover tooltips rather than panels.

signal pressed

var kind: String = "notice"
var label_text: String = ""
var _hovered: bool = false
var _armed: bool = false

const PAPER := Color("#efe5c8")
const PAPER_LIGHT := Color("#fbf2db")
const INK := Color("#57746a")
const WOOD := Color("#b89666")
const LINE := Color("#b1b59b")
const CORAL := Color("#ba7c62")


func _ready() -> void:
	if size == Vector2.ZERO:
		size = Vector2(76, 80)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())
	queue_redraw()


func clue_marker(prop_kind: String, label: String) -> void:
	kind = prop_kind
	label_text = label
	tooltip_text = label
	queue_redraw()


func _draw() -> void:
	var factor: float = minf(size.x / 80.0, size.y / 84.0)
	var origin: Vector2 = (size - Vector2(80, 84) * factor) * 0.5
	if _hovered:
		origin.y -= 1.0
	draw_set_transform(origin, 0.0, Vector2.ONE * factor)
	match kind:
		"door": _draw_door()
		"nameplate", "plaque": _draw_nameplate()
		"envelope", "letter": _draw_envelope()
		"timetable", "clock": _draw_timetable()
		"photo": _draw_photo()
		"record", "archive", "book": _draw_record()
		"handwriting": _draw_handwriting()
		_: _draw_notice()
	draw_set_transform(Vector2.ZERO)


func _sheet(points: PackedVector2Array, color: Color = PAPER_LIGHT) -> void:
	var shadow := points.duplicate()
	for index: int in range(shadow.size()):
		shadow[index] += Vector2(2, 3)
	draw_colored_polygon(shadow, Color(0.21, 0.29, 0.23, 0.12))
	draw_colored_polygon(points, color)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, LINE, 0.9, true)


func _draw_notice() -> void:
	_sheet(PackedVector2Array([Vector2(16, 17), Vector2(66, 13), Vector2(69, 69), Vector2(19, 74)]), PAPER)
	_sheet(PackedVector2Array([Vector2(11, 10), Vector2(58, 14), Vector2(61, 64), Vector2(10, 62)]))
	draw_circle(Vector2(37, 14), 3.0, CORAL)
	draw_line(Vector2(21, 29), Vector2(48, 31), INK, 2.0, true)
	draw_line(Vector2(21, 38), Vector2(48, 40), LINE, 1.6, true)
	draw_line(Vector2(21, 46), Vector2(42, 48), LINE, 1.6, true)
	draw_colored_polygon(PackedVector2Array([Vector2(52, 56), Vector2(61, 64), Vector2(51, 64)]), Color("#dcd5b9"))


func _draw_nameplate() -> void:
	draw_rect(Rect2(6, 23, 67, 35), WOOD)
	draw_rect(Rect2(10, 27, 59, 27), Color("#d2c09a"))
	draw_circle(Vector2(14, 40), 1.5, INK)
	draw_circle(Vector2(65, 40), 1.5, INK)
	draw_line(Vector2(23, 37), Vector2(52, 37), INK, 3.0, true)
	draw_line(Vector2(25, 44), Vector2(45, 44), Color("#a18f6d"), 1.5, true)
	# A half-lifted old paper label makes its earlier use visible, not its answer.
	draw_colored_polygon(PackedVector2Array([Vector2(18, 51), Vector2(49, 51), Vector2(45, 63), Vector2(17, 58)]), PAPER)
	draw_line(Vector2(21, 54), Vector2(40, 55), LINE, 1.0, true)


func _draw_envelope() -> void:
	_sheet(PackedVector2Array([Vector2(6, 27), Vector2(71, 21), Vector2(75, 62), Vector2(10, 69)]))
	draw_polyline(PackedVector2Array([Vector2(7, 28), Vector2(43, 45), Vector2(71, 22)]), LINE, 1.2, true)
	draw_polyline(PackedVector2Array([Vector2(11, 67), Vector2(32, 45), Vector2(45, 50), Vector2(55, 42), Vector2(74, 61)]), LINE, 0.9, true)
	draw_rect(Rect2(60, 30, 9, 11), Color("#77968a"))


func _draw_timetable() -> void:
	_sheet(PackedVector2Array([Vector2(15, 9), Vector2(63, 9), Vector2(63, 76), Vector2(15, 76)]))
	draw_rect(Rect2(14, 9, 50, 10), INK)
	draw_circle(Vector2(39, 36), 12, Color("#dce1c8"))
	draw_arc(Vector2(39, 36), 11, 0, TAU, 24, INK, 1.2, true)
	draw_line(Vector2(39, 36), Vector2(39, 28), INK, 1.4, true)
	draw_line(Vector2(39, 36), Vector2(44, 39), INK, 1.4, true)
	for y: float in [56.0, 63.0, 70.0]:
		draw_line(Vector2(23, y), Vector2(32, y), INK, 1.5, true)
		draw_line(Vector2(40, y), Vector2(55, y), LINE, 1.5, true)


func _draw_door() -> void:
	draw_rect(Rect2(17, 8, 49, 69), Color("#8d9c7d"))
	draw_rect(Rect2(23, 12, 35, 65), WOOD)
	draw_rect(Rect2(28, 18, 24, 23), Color("#a3baaa"))
	draw_line(Vector2(40, 18), Vector2(40, 41), Color("#dddfc4"), 1.5, true)
	draw_line(Vector2(28, 30), Vector2(52, 30), Color("#dddfc4"), 1.5, true)
	draw_circle(Vector2(51, 53), 2.2, INK)
	draw_line(Vector2(14, 78), Vector2(69, 78), Color("#a0ae92"), 3.0, true)


func _draw_photo() -> void:
	_sheet(PackedVector2Array([Vector2(7, 18), Vector2(66, 13), Vector2(73, 68), Vector2(13, 74)]))
	draw_colored_polygon(PackedVector2Array([Vector2(14, 24), Vector2(61, 20), Vector2(66, 57), Vector2(19, 63)]), Color("#a7c2ae"))
	draw_colored_polygon(PackedVector2Array([Vector2(17, 45), Vector2(64, 39), Vector2(66, 57), Vector2(19, 63)]), Color("#7f9d90"))
	draw_circle(Vector2(35, 39), 4.0, INK)
	draw_circle(Vector2(47, 39), 4.0, CORAL)
	draw_line(Vector2(35, 42), Vector2(35, 54), INK, 6.0, true)
	draw_line(Vector2(47, 42), Vector2(47, 54), CORAL, 6.0, true)


func _draw_record() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(9, 20), Vector2(29, 14), Vector2(40, 18), Vector2(63, 11), Vector2(69, 66), Vector2(44, 73), Vector2(31, 67), Vector2(12, 73)]), Color("#c0c9ab"))
	draw_colored_polygon(PackedVector2Array([Vector2(14, 23), Vector2(31, 18), Vector2(40, 23), Vector2(60, 17), Vector2(64, 62), Vector2(44, 67), Vector2(31, 62), Vector2(17, 67)]), PAPER_LIGHT)
	draw_line(Vector2(39, 23), Vector2(44, 66), LINE, 1.1, true)
	for offset: float in [0.0, 8.0, 16.0]:
		draw_line(Vector2(20, 34 + offset), Vector2(33, 31 + offset), LINE, 1.1, true)
		draw_line(Vector2(46, 31 + offset), Vector2(56, 28 + offset), LINE, 1.1, true)


func _draw_handwriting() -> void:
	_draw_notice()
	var line := PackedVector2Array([Vector2(18, 46), Vector2(23, 36), Vector2(26, 46), Vector2(30, 36), Vector2(32, 45), Vector2(36, 42), Vector2(38, 45), Vector2(43, 40), Vector2(42, 53)])
	draw_polyline(line, CORAL, 1.4, true)
	draw_line(Vector2(51, 57), Vector2(65, 25), Color("#bd9664"), 4.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(48, 64), Vector2(50, 54), Vector2(54, 57)]), INK)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_armed = true
			grab_focus()
		else:
			var should_activate: bool = _armed and Rect2(Vector2.ZERO, size).has_point(event.position)
			_armed = false
			if should_activate:
				pressed.emit()
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]:
		pressed.emit()
		accept_event()
