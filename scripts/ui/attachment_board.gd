class_name AttachmentBoard
extends Control
## The photograph is an independent vector prop. Its arrangement is provisional
## until the player physically puts the envelope through the outgoing slot.

signal decided(with_photo: bool)
signal dismissed
signal cue(kind: String)

const CANVAS := Vector2(1100, 570)
const INK := Color("#304e50")
const MUTED := Color("#728a80")
const PAPER := Color("#fff8e5")
const CREAM := Color("#f7efd9")
const TEAL := Color("#5f9084")
const LINE := Color("#c5c9ad")
const CORAL := Color("#bd785f")
const ENVELOPE_START := Vector2(273, 379)
const PHOTO_START := Vector2(548, 218)
const DRAWER_PHOTO := Vector2(882, 384)
const OUTGOING := Rect2(763, 121, 289, 119)
const DRAWER := Rect2(732, 289, 303, 205)
const CLOSE := Rect2(1029, 10, 48, 44)
const PHOTO_SIZE := Vector2(254, 176)
const ENVELOPE_SIZE := Vector2(366, 206)

var photo_text: String = "We said we’d come back every summer."
var stage: int = 0
var reversed: bool = false
var with_photo: bool = true
var _photo_position := PHOTO_START
var _envelope_position := ENVELOPE_START
var _pointer := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _drag_kind: String = ""
var _message: String = ""
var _finishing: bool = false
var _completion_sent: bool = false
var _finish_elapsed: float = 0.0
var _handoff_from := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	set_process(true)


func configure(caption: String = "We said we’d come back every summer.") -> void:
	photo_text = caption
	stage = 0
	reversed = false
	with_photo = true
	_photo_position = PHOTO_START
	_envelope_position = ENVELOPE_START
	_drag_kind = ""
	_message = ""
	_finishing = false
	_completion_sent = false
	_finish_elapsed = 0.0
	set_process(true)
	queue_redraw()


func _scale_factor() -> float:
	return maxf(0.01, minf(size.x / CANVAS.x, size.y / CANVAS.y))


func _canvas_origin() -> Vector2:
	return (size - CANVAS * _scale_factor()) * 0.5


func _to_canvas(point: Vector2) -> Vector2:
	return (point - _canvas_origin()) / _scale_factor()


func _canvas_transform() -> void:
	draw_set_transform(_canvas_origin(), 0.0, Vector2.ONE * _scale_factor())


func _text(at: Vector2, value: String, font_size: int = 20, color: Color = INK) -> void:
	draw_string(get_theme_font("font"), at, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw() -> void:
	_canvas_transform()
	draw_rect(Rect2(Vector2.ZERO, CANVAS), CREAM)
	_text(Vector2(29, 38), "一张照片，要去哪里", 24)
	_text(Vector2(1044, 40), "×", 28, MUTED)
	draw_line(Vector2(27, 64), Vector2(1074, 64), LINE, 1.0)
	if stage == 0:
		_text(Vector2(34, 99), "双击照片可看背面。把它放进左侧信封，或放入右侧抽屉。", 19, MUTED)
	else:
		_text(Vector2(34, 99), "照片还可以换放。捏住信封下沿，把信送进右上方的出件口。", 19, MUTED)
	_draw_drawer()
	if stage > 0:
		_draw_outgoing()
	else:
		_text(Vector2(797, 195), "先为照片选一个位置", 18, MUTED)
	_text(Vector2(123, 221), "放进信封 · 一起抵达", 20, INK)
	_text(Vector2(764, 271), "放入抽屉 · 留在这里", 20, INK)
	# The separate prop remains visible in the drawer when the letter leaves.
	if stage > 0 and not with_photo and _drag_kind != "photo":
		_draw_photo(_photo_position, 0.74)
	_draw_envelope()
	if _drag_kind == "photo":
		_draw_photo(_photo_position, 1.0)
	elif stage == 0:
		_draw_photo(_photo_position, 1.0)
	if not _message.is_empty():
		_text(Vector2(35, 532), _message, 18, CORAL)
	else:
		_text(Vector2(35, 532), "出件口合上后，照片的去处也会随这封信一起记入今天的记录。", 18, MUTED)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_drawer() -> void:
	draw_rect(Rect2(DRAWER.position + Vector2(4, 6), DRAWER.size), Color(0.2, 0.3, 0.25, 0.09))
	draw_rect(DRAWER, Color("#d7ddc7"))
	draw_rect(Rect2(DRAWER.position + Vector2(12, 13), DRAWER.size - Vector2(24, 26)), Color("#c2ceb7"))
	draw_rect(DRAWER, LINE, false, 1.5)
	draw_rect(Rect2(DRAWER.position + Vector2(0, 173), Vector2(DRAWER.size.x, 32)), Color("#b9c8b0"))
	draw_line(Vector2(846, 478), Vector2(921, 478), MUTED, 4.0, true)


func _draw_outgoing() -> void:
	draw_rect(OUTGOING, Color("#dce5d1"))
	draw_rect(OUTGOING, LINE, false, 1.0)
	_text(OUTGOING.position + Vector2(75, 34), "今日出件口", 21, INK)
	draw_rect(Rect2(OUTGOING.position + Vector2(22, 62), Vector2(245, 25)), INK)
	draw_line(OUTGOING.position + Vector2(22, 88), OUTGOING.position + Vector2(267, 88), TEAL, 3.0)
	_text(OUTGOING.position + Vector2(61, 112), "把信封送到这里", 17, MUTED)


func _draw_envelope() -> void:
	var scale_value: float = 1.0
	if _finishing:
		scale_value = lerpf(1.0, 0.22, clampf(_finish_elapsed / 0.5, 0.0, 1.0))
	draw_set_transform(_canvas_origin() + _envelope_position * _scale_factor(), 0.0, Vector2.ONE * _scale_factor() * scale_value)
	var bounds := Rect2(-ENVELOPE_SIZE * 0.5, ENVELOPE_SIZE)
	draw_rect(Rect2(bounds.position + Vector2(4, 6), bounds.size), Color(0.2, 0.3, 0.25, 0.12))
	draw_rect(bounds, Color("#eee0c0"))
	draw_rect(bounds, LINE, false, 1.0)
	draw_polyline(PackedVector2Array([Vector2(-181, -101), Vector2(0, -143), Vector2(181, -101)]), Color("#b9b997"), 1.5, true)
	_canvas_transform()
	if stage > 0 and with_photo and _drag_kind != "photo":
		_draw_photo(_envelope_position + Vector2(0, -50) * scale_value, 0.74 * scale_value)
	# The front fold partly covers the photograph without obscuring its scene.
	draw_set_transform(_canvas_origin() + _envelope_position * _scale_factor(), 0.0, Vector2.ONE * _scale_factor() * scale_value)
	draw_colored_polygon(PackedVector2Array([Vector2(-183, -48), Vector2(0, 5), Vector2(183, -48), Vector2(183, 103), Vector2(-183, 103)]), PAPER)
	draw_polyline(PackedVector2Array([Vector2(-183, -48), Vector2(0, 5), Vector2(183, -48)]), LINE, 1.5, true)
	_text(Vector2(-146, 51), "正文仍在信封里", 20, INK)
	_text(Vector2(-147, 85), "按住这条下沿，把信拿起来", 16, MUTED)
	_canvas_transform()


func _draw_photo(at: Vector2, factor: float) -> void:
	draw_set_transform(_canvas_origin() + at * _scale_factor(), 0.0, Vector2.ONE * _scale_factor() * factor)
	var bounds := Rect2(-PHOTO_SIZE * 0.5, PHOTO_SIZE)
	draw_rect(Rect2(bounds.position + Vector2(3, 5), bounds.size), Color(0.2, 0.3, 0.25, 0.13))
	draw_rect(bounds, PAPER)
	draw_rect(bounds, LINE, false, 1.0)
	if reversed:
		_text(Vector2(-111, -55), "18 July 2020", 17, MUTED)
		# Break lines using the actual inherited font so the supplied caption
		# remains legible within the small paper prop.
		var lines: PackedStringArray = _caption_lines(photo_text, 219.0, 17)
		var y: float = -13.0
		for line: String in lines:
			_text(Vector2(-110, y), line, 17, INK)
			y += 23.0
		_text(Vector2(-110, 73), "照片背面", 14, MUTED)
	else:
		draw_rect(Rect2(-112, -73, 224, 128), Color("#a8c7bc"))
		draw_rect(Rect2(-112, -27, 224, 82), Color("#719d94"))
		draw_colored_polygon(PackedVector2Array([Vector2(-112, 10), Vector2(-38, -4), Vector2(112, 9), Vector2(112, 55), Vector2(-112, 55)]), Color("#cfccb0"))
		draw_line(Vector2(-110, -23), Vector2(110, -23), Color("#d8dfc6"), 1.0)
		# Two tiny, back-facing, geometric silhouettes; no borrowed artwork.
		_draw_silhouette(Vector2(-25, 14), Color("#4c7470"), Color("#53675f"))
		_draw_silhouette(Vector2(27, 15), Color("#af7e68"), Color("#506960"))
		draw_line(Vector2(-67, 36), Vector2(74, 36), Color("#66786b"), 3.0)
		_text(Vector2(-104, 77), "Lookout · 18 July 2020", 15, MUTED)
	_canvas_transform()


func _draw_silhouette(at: Vector2, coat: Color, hair: Color) -> void:
	draw_circle(at + Vector2(0, -24), 9.0, hair)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-7, -16), at + Vector2(7, -16), at + Vector2(13, 17), at + Vector2(-13, 17)]), coat)
	draw_line(at + Vector2(-6, 17), at + Vector2(-7, 31), hair, 4.0)
	draw_line(at + Vector2(6, 17), at + Vector2(7, 31), hair, 4.0)


func _caption_lines(value: String, width: float, font_size: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var font_value: Font = get_theme_font("font")
	for paragraph: String in value.split("\n"):
		var current: String = ""
		var use_words: bool = " " in paragraph
		var tokens := PackedStringArray()
		if use_words:
			tokens = paragraph.split(" ", false)
		else:
			for character: String in paragraph:
				tokens.append(character)
		for token: String in tokens:
			var candidate: String = current + (" " if use_words and not current.is_empty() else "") + token
			if not current.is_empty() and font_value.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
				lines.append(current)
				current = token
			else:
				current = candidate
		lines.append(current)
	return lines


func _photo_factor() -> float:
	return 1.0 if stage == 0 or _drag_kind == "photo" else 0.74


func _photo_hit_rect() -> Rect2:
	var dimensions: Vector2 = PHOTO_SIZE * _photo_factor()
	return Rect2(_photo_position - dimensions * 0.5, dimensions)


func _delivery_zone() -> Rect2:
	return Rect2(_envelope_position - ENVELOPE_SIZE * 0.5, ENVELOPE_SIZE)


func _gui_input(event: InputEvent) -> void:
	if _finishing:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		dismissed.emit()
		accept_event()
	elif event is InputEventMouseMotion:
		_pointer = _to_canvas(event.position)
		_handle_motion()
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer = _to_canvas(event.position)
		if event.pressed:
			grab_focus()
			_handle_press(event.double_click)
		else:
			_handle_release()
		accept_event()
		queue_redraw()


func _handle_press(double_click: bool) -> void:
	if CLOSE.has_point(_pointer):
		dismissed.emit()
		return
	_message = ""
	if _photo_hit_rect().has_point(_pointer):
		if double_click:
			reversed = not reversed
			_drag_kind = ""
			cue.emit("flip")
		else:
			_drag_kind = "photo"
			_drag_offset = _pointer - _photo_position
			cue.emit("paper")
	elif stage > 0 and _delivery_zone().has_point(_pointer):
		_drag_kind = "envelope"
		_drag_offset = _pointer - _envelope_position
		cue.emit("paper")
	if not _drag_kind.is_empty():
		mouse_default_cursor_shape = Control.CURSOR_DRAG


func _handle_motion() -> void:
	if _drag_kind.is_empty():
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _photo_hit_rect().has_point(_pointer) or (stage > 0 and _delivery_zone().has_point(_pointer)) else Control.CURSOR_ARROW
		return
	var candidate: Vector2 = _pointer - _drag_offset
	if _drag_kind == "photo":
		_photo_position = Vector2(clampf(candidate.x, 135, 962), clampf(candidate.y, 185, 439))
	elif _drag_kind == "envelope":
		_envelope_position = Vector2(clampf(candidate.x, 193, 903), clampf(candidate.y, 218, 405))
		if with_photo:
			_photo_position = _envelope_position + Vector2(0, -50)


func _handle_release() -> void:
	if _drag_kind.is_empty():
		return
	var kind: String = _drag_kind
	_drag_kind = ""
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	if kind == "photo":
		if _delivery_zone().has_point(_photo_position):
			with_photo = true
			stage = 1
			_photo_position = _envelope_position + Vector2(0, -50)
			_message = "照片放进了信封。捏住下沿，送进出件口。"
			cue.emit("paper")
		elif DRAWER.has_point(_photo_position):
			with_photo = false
			stage = 1
			_photo_position = DRAWER_PHOTO
			_message = "照片留在了抽屉。正文还在信封里，等待你送出。"
			cue.emit("paper")
		else:
			_photo_position = PHOTO_START if stage == 0 else (_envelope_position + Vector2(0, -50) if with_photo else DRAWER_PHOTO)
			_message = "照片还没有放稳。选信封，或选抽屉。"
	elif kind == "envelope":
		if OUTGOING.has_point(_envelope_position):
			_finishing = true
			_handoff_from = _envelope_position
			_finish_elapsed = 0.0
			cue.emit("stamp")
		else:
			_envelope_position = ENVELOPE_START
			if with_photo:
				_photo_position = _envelope_position + Vector2(0, -50)
			_message = "信封仍在手边。送进右上方的出件口，才会离开。"


func _process(delta: float) -> void:
	if not _finishing or _completion_sent:
		return
	_finish_elapsed += delta
	var fraction: float = clampf(_finish_elapsed / 0.5, 0.0, 1.0)
	_envelope_position = _handoff_from.lerp(OUTGOING.get_center(), fraction)
	queue_redraw()
	if fraction >= 1.0:
		_completion_sent = true
		set_process(false)
		decided.emit(with_photo)
