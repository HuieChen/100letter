extends Control
## Authored postal rooms and standalone layout review; host owns campaign state.
signal room_changed(index: int)
signal close_requested

const DESIGN := Vector2(1920, 1080)
const SOURCE := preload("res://assets/authoring/post_office_20261019/room_pair.jpg")
const LocalMotion := preload("res://scripts/rebuild/scene_local_motion.gd")
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
	var _motion: Tween
	var _hover_amount := 0.0:
		set(value): _hover_amount = value; queue_redraw()
	var _press_amount := 0.0:
		set(value): _press_amount = value; queue_redraw()
	func _ready() -> void:
		flat = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_entered.connect(_animate)
		mouse_exited.connect(_animate)
		focus_entered.connect(_animate)
		focus_exited.connect(_animate)
		button_down.connect(_animate)
		button_up.connect(_animate)

	func _animate() -> void:
		if _motion != null and _motion.is_valid(): _motion.kill()
		_motion = create_tween().set_parallel(true)
		_motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_motion.tween_property(self,"_hover_amount",1.0 if not disabled and (is_hovered() or has_focus()) else 0.0,0.14)
		_motion.tween_property(self,"_press_amount",1.0 if not disabled and button_pressed else 0.0,0.07)

	func _stroke(points: PackedVector2Array, color: Color, width: float) -> void:
		draw_polyline(points,color,width,true)
		# Rounded ink ends and joins, rather than a double-outline chevron.
		for point: Vector2 in points: draw_circle(point,width*0.5,color,true,-1,true)

	func _draw() -> void:
		var center := size * 0.5 + Vector2(float(direction)*3.0*_hover_amount,2.0*_press_amount)
		var drawn_scale := 1.0 + 0.035*_hover_amount - 0.12*_press_amount
		draw_set_transform(center,0.0,Vector2.ONE*drawn_scale)
		var ink := Color("fff2d7").lerp(Color("fffbed"),_hover_amount)
		if disabled: ink.a = 0.55
		var strokes: Array[PackedVector2Array] = []
		if is_close:
			strokes.append(PackedVector2Array([Vector2(-9,-9),Vector2(9,9)]))
			strokes.append(PackedVector2Array([Vector2(9,-9),Vector2(-9,9)]))
		else:
			strokes.append(PackedVector2Array([Vector2(-21*direction,1),Vector2(-4*direction,-0.5),Vector2(18*direction,0)]))
			strokes.append(PackedVector2Array([Vector2(1*direction,-16),Vector2(18*direction,0),Vector2(0*direction,16)]))
		for points: PackedVector2Array in strokes:
			var shadow := PackedVector2Array()
			for point: Vector2 in points: shadow.append(point+Vector2(0,2))
			_stroke(shadow,Color(0.22,0.28,0.22,0.24)*Color(1,1,1,ink.a),7.0)
		for points: PackedVector2Array in strokes: _stroke(points,ink,6.0)
		if has_focus() and not disabled:
			_stroke(PackedVector2Array([Vector2(-6,27),Vector2(6,27)]),ink,2.0)

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
	LocalMotion.attach_room(node)
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
