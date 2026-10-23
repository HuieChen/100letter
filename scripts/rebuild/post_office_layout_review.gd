extends Control
## Authored postal rooms and standalone layout review; host owns campaign state.
signal room_changed(index: int)
signal close_requested

const DESIGN := Vector2(1920, 1080)
const SOURCE := preload("res://assets/authoring/post_office_20261019/room_pair.jpg")
const REGIONS := [Rect2(0, 0, 1914, 1080), Rect2(1926, 0, 1914, 1080)]
var room_index := 0
var transitioning := false
var navigation_allowed: Callable
var canvas: Control
var image: TextureRect
var previous_image: TextureRect
var next_arrow: Button
var previous_arrow: Button
var close_button: Button
var _transition: Tween
var _textures: Array[Texture2D] = []

class SceneArrow extends Button:
	var direction := 1
	var is_close := false
	func _ready() -> void:
		flat = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var center := size * 0.5 + Vector2(0, 2 if button_pressed else 0)
		var ink := Color("476b64") if is_hovered() or has_focus() else Color("59796b")
		var points: PackedVector2Array
		if is_close:
			points = PackedVector2Array([center + Vector2(-9,-9), center + Vector2(9,9)])
			draw_polyline(points, Color("fff6dd"), 9.0, true)
			draw_polyline(points, ink, 4.0, true)
			points = PackedVector2Array([center + Vector2(9,-9), center + Vector2(-9,9)])
		else:
			points = PackedVector2Array([center + Vector2(-11 * direction,-22), center + Vector2(12 * direction,0), center + Vector2(-11 * direction,22)])
		draw_polyline(points, Color("fff6dd"), 11.0 if not is_close else 9.0, true)
		draw_polyline(points, ink, 5.0 if not is_close else 4.0, true)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for region: Rect2 in REGIONS:
		var texture := AtlasTexture.new()
		texture.atlas = SOURCE
		texture.region = region
		texture.filter_clip = true
		_textures.append(texture)
	canvas = Control.new()
	canvas.name = "RoomCanvas"
	canvas.size = DESIGN
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	previous_image = _image_node("PreviousRoom")
	image = _image_node("AuthoredRoom")
	room_index = clampi(room_index, 0, 1)
	image.texture = _textures[room_index]
	next_arrow = _arrow("ToWorkroom", Vector2(1810, 492), 1)
	previous_arrow = _arrow("ToCounter", Vector2(34, 492), -1)
	next_arrow.visible = room_index == 0
	previous_arrow.visible = room_index == 1
	next_arrow.pressed.connect(func(): show_room(1))
	previous_arrow.pressed.connect(func(): show_room(0))
	close_button = _arrow("CloseReview", Vector2(1844, 24), 1)
	close_button.size = Vector2(52,52)
	close_button.is_close = true
	close_button.pressed.connect(_request_close)
	resized.connect(_layout)
	_layout()
	# The standalone review scene owns its close path; component QA can observe it.
	if get_tree().current_scene == self:
		get_window().title = "Dear Somewhere · 邮局场景"
		close_requested.connect(func(): get_tree().quit())

func _image_node(node_name: String) -> TextureRect:
	var node := TextureRect.new()
	node.name = node_name
	node.size = DESIGN
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(node)
	return node

func _arrow(node_name: String, at: Vector2, direction: int) -> SceneArrow:
	var node := SceneArrow.new()
	node.name = node_name
	node.position = at
	node.size = Vector2(76,96)
	node.direction = direction
	canvas.add_child(node)
	return node

func _layout() -> void:
	if not is_instance_valid(canvas): return
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - DESIGN * factor) * 0.5

func show_room(index: int) -> void:
	if transitioning or index == room_index or index < 0 or index > 1: return
	if navigation_allowed.is_valid() and not navigation_allowed.call(): return
	transitioning = true
	next_arrow.disabled = true
	previous_arrow.disabled = true
	previous_image.texture = image.texture
	image.texture = _textures[index]
	image.modulate.a = 0.0
	room_index = index
	_transition = create_tween()
	_transition.tween_property(image, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_callback(func():
		previous_image.texture = null
		transitioning = false
		next_arrow.disabled = false
		previous_arrow.disabled = false
		next_arrow.visible = room_index == 0
		previous_arrow.visible = room_index == 1
		room_changed.emit(room_index))

func _request_close() -> void:
	if _transition != null: _transition.kill()
	transitioning = false
	close_requested.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_request_close()

func _exit_tree() -> void:
	if _transition != null: _transition.kill()
