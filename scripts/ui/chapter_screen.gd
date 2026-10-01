class_name ChapterScreen
extends Control
## Painted chapter bookends. Scenery comes from a complete environment image;
## the original building is fitted in full above it, with no crop or colour overlay.
## Code draws only typography, quiet reading paper, and the failure letter prop.

signal primary_requested
signal secondary_requested
signal details_requested

const CANVAS := Vector2(1600, 900)
const Courier = preload("res://scripts/ui/courier_actor.gd")
const ENVIRONMENT = preload("res://assets/generated/environments/post_office.png")
const POST_OFFICE = preload("res://assets/display_user/post_office_exterior_USER_20261001_LOCKED.jpg.png")
const INK := Color("#294f4e")
const SOFT := Color("#718980")
const FADED := Color("#aeb9aa")
const PAPER := Color("#f3efdf")
const WARM := Color("#f8f1dc")
const LINE := Color("#c9d0bd")
const CORAL := Color("#b77761")

var mode: String = "title"
var art: Texture2D
var info: Dictionary = {}
var story_view: RichTextLabel
var primary_button: Button
var secondary_button: Button
var details_button: Button
var _content: Control
var _elapsed: float = 0.0
var _paper_textures: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout_content)
	if _content == null:
		_rebuild()
	set_process(true)
	_layout_content()


func configure(next_mode: String, next_art: Texture2D, next_info: Dictionary) -> void:
	mode = next_mode
	art = POST_OFFICE if next_mode == "ending" or next_art == null else next_art
	info = next_info.duplicate(true)
	_elapsed = 0.0
	_rebuild()
	_layout_content()
	queue_redraw()


func _scale_factor() -> float:
	return maxf(0.01, minf(size.x / CANVAS.x, size.y / CANVAS.y))


func _origin() -> Vector2:
	return (size - CANVAS * _scale_factor()) * 0.5


func _layout_content() -> void:
	if is_instance_valid(_content):
		_content.position = _origin()
		_content.scale = Vector2.ONE * _scale_factor()
	queue_redraw()


func _rebuild() -> void:
	if is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.size = CANVAS
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	story_view = null
	primary_button = null
	secondary_button = null
	details_button = null
	match mode:
		"ending": _build_ending()
		"failure": _build_failure()
		_: _build_title()


func _label(value: String, rect: Rect2, font_size: int, color: Color = INK) -> Label:
	var node := Label.new()
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.text = value
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_constant_override("line_spacing", 9)
	_content.add_child(node)
	return node


func _text_button(value: String, rect: Rect2, callback: Callable, font_size: int = 25, enabled: bool = true) -> Button:
	var node := Button.new()
	node.text = value
	node.position = rect.position
	node.size = rect.size
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.flat = true
	node.disabled = not enabled
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", CORAL)
	node.add_theme_color_override("font_pressed_color", CORAL)
	node.add_theme_color_override("font_disabled_color", FADED)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		node.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = CORAL
	focus.border_width_bottom = 1
	node.add_theme_stylebox_override("focus", focus)
	_content.add_child(node)
	node.pressed.connect(callback)
	return node


func _build_title() -> void:
	_label("CHAPTER 01   /   夏日", Rect2(104,137,560,36), 17, SOFT)
	var title_value: String = str(info.get("title","一百信"))
	_label(title_value, Rect2(91,213,630,140), 104 if title_value.length() <= 5 else 61)
	_label(str(info.get("subtitle","SOLMERE POST")),Rect2(105,378,535,38),21,SOFT)
	_label("把今天交给一封信",Rect2(104,447,547,56),27)
	primary_button = _text_button("开始这一天  →",Rect2(104,594,420,64),func() -> void: primary_requested.emit(),27)
	secondary_button = _text_button("继续工作  →",Rect2(105,681,420,60),func() -> void: secondary_requested.emit(),25,bool(info.get("can_continue",false)))
	details_button = _text_button("制作 / 操作",Rect2(106,786,300,44),func() -> void: details_requested.emit(),18)
	_label("SOLMERE  ·  SUMMER",Rect2(1084,827,370,34),16,SOFT)


func _build_ending() -> void:
	_label(str(info.get("time", "傍晚")) + "   /   SOLMERE", Rect2(88, 88, 700, 40), 18, SOFT)
	_label("灯还亮着", Rect2(82, 155, 760, 104), 62)
	_label("有些信迟到了。\n有些信，从来没有被允许抵达。", Rect2(88, 277, 780, 99), 25, SOFT)
	_label("这一日的回声", Rect2(993, 95, 450, 44), 22)
	story_view = RichTextLabel.new()
	story_view.position = Vector2(992, 156)
	story_view.size = Vector2(474, 490)
	story_view.text = str(info.get("story", info.get("summary", "")))
	story_view.bbcode_enabled = false
	story_view.scroll_active = true
	story_view.scroll_following = false
	story_view.selection_enabled = true
	story_view.add_theme_color_override("default_color", INK)
	story_view.add_theme_font_size_override("normal_font_size", 22)
	story_view.add_theme_constant_override("line_separation", 11)
	story_view.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	story_view.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_content.add_child(story_view)
	primary_button = _text_button("收好这一日  →", Rect2(992, 718, 427, 57), func() -> void: primary_requested.emit(), 25)
	secondary_button = _text_button("再走一遍", Rect2(994, 791, 220, 46), func() -> void: secondary_requested.emit(), 19)
	details_button = _text_button("今日足迹", Rect2(1263, 791, 225, 46), func() -> void: details_requested.emit(), 19)
	_label("明天，小镇仍会有人等信。", Rect2(90, 816, 710, 44), 19, SOFT)


func _build_failure() -> void:
	_label("信件停在了这里", Rect2(946, 123, 512, 43), 18, SOFT)
	_label("这封信没能\n继续上路", Rect2(938, 193, 557, 157), 51)
	var cause: String = str(info.get("message", info.get("cause", "纸边的裂痕已经穿过了文字。你停下了手里的工具。")))
	_label(cause, Rect2(946, 400, 531, 114), 24)
	_label("工作记录还留在：" + str(info.get("checkpoint_label", "拆封前")), Rect2(946, 539, 527, 79), 19, SOFT)
	primary_button = _text_button(str(info.get("primary_label", "从拆封前继续")) + "  →", Rect2(946, 657, 548, 62), func() -> void: primary_requested.emit(), 25)
	secondary_button = _text_button("回到标题", Rect2(948, 756, 323, 49), func() -> void: secondary_requested.emit(), 20)
	_label("这次的裂痕，不必成为最后一次处理。", Rect2(94, 786, 748, 48), 22, SOFT)


func _fit_rect(area: Rect2) -> Rect2:
	if art == null or art.get_width() == 0 or art.get_height() == 0:
		return Rect2()
	var factor: float = minf(area.size.x / float(art.get_width()), area.size.y / float(art.get_height()))
	var dimensions: Vector2 = art.get_size() * factor
	return Rect2(area.position + (area.size - dimensions) * 0.5, dimensions)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	draw_set_transform(_origin(), 0.0, Vector2.ONE * _scale_factor())
	if mode == "title":
		_draw_title_stage()
	elif mode == "ending":
		_draw_ending_stage()
	elif mode == "failure":
		_draw_torn_letter(Vector2(463, 449))
		draw_line(Vector2(949, 727), Vector2(1435, 727), LINE, 1.0)
	draw_set_transform(Vector2.ZERO)


func _paper_gradient(rect: Rect2, colors: PackedColorArray, stops: PackedFloat32Array, vertical: bool = false) -> void:
	# Reading surfaces only. All trees, hills, pavement and shadows belong to
	# the painted environment texture, never to generated geometry.
	var key: String = str(rect)
	if not _paper_textures.has(key):
		var gradient := Gradient.new()
		gradient.colors = colors
		gradient.offsets = stops
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 16 if vertical else 256
		texture.height = 256 if vertical else 16
		texture.fill_from = Vector2.ZERO
		texture.fill_to = Vector2(0, 1) if vertical else Vector2(1, 0)
		_paper_textures[key] = texture
	draw_texture_rect(_paper_textures[key], rect, false)


func _draw_environment() -> void:
	draw_texture_rect(ENVIRONMENT, Rect2(Vector2.ZERO, CANVAS), false)


func _draw_title_stage() -> void:
	_draw_environment()
	# The pale editorial margin leaves the original architecture and courier
	# entirely outside the text area. The background painting remains visible
	# through its soft outer edge; the user architecture is drawn afterwards.
	_paper_gradient(Rect2(0, 0, 839, 900),
		PackedColorArray([PAPER, PAPER, Color(PAPER, 0.93), Color(PAPER, 0.0)]),
		PackedFloat32Array([0.0, 0.70, 0.83, 1.0]))
	if art != null:
		draw_texture_rect(art, _fit_rect(Rect2(649, 95, 940, 664)), false)
	var factor := _scale_factor()
	Courier.draw_actor(self, _origin() + Vector2(859,777) * factor, 0.0, 0.0, 1.0, 177.0 * factor, "", 0.0, _elapsed)
	draw_set_transform(_origin(), 0.0, Vector2.ONE * factor)
	# These two quiet rules belong to the menu typography, not the scenery.
	draw_line(Vector2(106,549), Vector2(232,549), Color("aaa991"), 1.0, true)
	draw_circle(Vector2(237,549), 1.6, CORAL)
	draw_line(Vector2(106,667), Vector2(481,667), Color("d7d6bf"), 1.0, true)


func _draw_ending_stage() -> void:
	_draw_environment()
	_paper_gradient(Rect2(0, 0, 944, 441),
		PackedColorArray([PAPER, Color(PAPER, 0.97), Color(PAPER, 0.0)]),
		PackedFloat32Array([0.0, 0.76, 1.0]), true)
	_paper_gradient(Rect2(0, 769, 944, 131),
		PackedColorArray([Color(PAPER, 0.0), Color(PAPER, 0.96), PAPER]),
		PackedFloat32Array([0.0, 0.41, 1.0]), true)
	# A single sheet holds the readable, scrollable account. Its boundary is
	# separate from the full original building, so neither is clipped.
	draw_rect(Rect2(949, 62, 574, 800), Color(0.21, 0.28, 0.24, 0.10))
	draw_rect(Rect2(939, 52, 574, 800), Color(WARM, 0.98))
	if art != null:
		draw_texture_rect(art, _fit_rect(Rect2(28, 351, 884, 450)), false)
	var factor := _scale_factor()
	Courier.draw_actor(self, _origin() + Vector2(808,798) * factor, 0.0, 0.0, -1.0, 149.0 * factor, "", 0.0, _elapsed)
	draw_set_transform(_origin(), 0.0, Vector2.ONE * factor)
	draw_line(Vector2(994,783), Vector2(1434,783), LINE, 1.0)


func _draw_torn_letter(at: Vector2) -> void:
	var left := PackedVector2Array([Vector2(-235, -123), Vector2(-24, -123), Vector2(-5, -82), Vector2(-31, -47), Vector2(-12, -5), Vector2(-40, 38), Vector2(-18, 119), Vector2(-235, 119)])
	var right := PackedVector2Array([Vector2(37, -114), Vector2(247, -114), Vector2(247, 127), Vector2(42, 127), Vector2(22, 46), Vector2(50, 3), Vector2(32, -39), Vector2(58, -75)])
	for shape: PackedVector2Array in [left, right]:
		var shifted := PackedVector2Array()
		var shadow := PackedVector2Array()
		for point: Vector2 in shape:
			shifted.append(at + point)
			shadow.append(at + point + Vector2(6, 9))
		draw_colored_polygon(shadow, Color(0.27, 0.35, 0.29, 0.08))
		draw_colored_polygon(shifted, Color("#f2e8ce"))
		shifted.append(shifted[0])
		draw_polyline(shifted, Color("#c3c5ab"), 1.2, true)
	draw_line(at + Vector2(-213, -98), at + Vector2(-70, -11), Color("#c8c5a6"), 1.3, true)
	draw_line(at + Vector2(71, -14), at + Vector2(222, -91), Color("#c8c5a6"), 1.3, true)
	draw_rect(Rect2(at + Vector2(168, -85), Vector2(47, 52)), Color("#7d9d8d"))
	draw_string(get_theme_font("font"), at + Vector2(-197, 38), "SOLMERE", HORIZONTAL_ALIGNMENT_LEFT, 174, 21, SOFT)
	for y: float in [66.0, 78.0]:
		draw_line(at + Vector2(-196, y), at + Vector2(-73, y), Color("#c3c7ab"), 1.4, true)
	# One separated paper fibre makes the gap readable without adding spectacle.
	draw_line(at + Vector2(5, 39), at + Vector2(16, 65), Color("#d1c6a5"), 1.0, true)


func _process(delta: float) -> void:
	_elapsed += delta
	if mode in ["title", "ending"]:
		queue_redraw()
