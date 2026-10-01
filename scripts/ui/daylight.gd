class_name Daylight
extends Control
## A quiet summer stage, kept separate from the original artwork.
## environment: opaque backdrop; overlay: local translucent light/shadow shapes.
## The clock is supplied by GameSession. A tween only eases a supplied change;
## waiting, reading, and finishing that tween never advance the game minute.

const TRANSITION_SECONDS = 0.55
const OVERLAY_ALPHA_LIMIT = 0.16
const HOURS = [540.0, 720.0, 960.0, 1080.0, 1200.0]
const COLORS = [
	{
		"base": Color("f5f2e7"), "sky": Color("e9f1e9"),
		"sea": Color("badbd6"), "sand": Color("f6ecd9"), "sun": Color("fff5d7"),
		"sunlight": Color(1.0, 0.88, 0.65, 0.09),
		"window_light": Color(1.0, 0.90, 0.70, 0.12),
		"shadow": Color(0.50, 0.46, 0.63, 0.075)
	},
	{
		"base": Color("f7f3e5"), "sky": Color("edf4eb"),
		"sea": Color("b3d9d3"), "sand": Color("f8edd5"), "sun": Color("fff9e4"),
		"sunlight": Color(1.0, 0.92, 0.72, 0.055),
		"window_light": Color(1.0, 0.94, 0.78, 0.085),
		"shadow": Color(0.49, 0.47, 0.62, 0.06)
	},
	{
		"base": Color("f6eddb"), "sky": Color("f2eedf"),
		"sea": Color("bcd9cf"), "sand": Color("f3e4cd"), "sun": Color("ffedc6"),
		"sunlight": Color(1.0, 0.84, 0.60, 0.12),
		"window_light": Color(1.0, 0.87, 0.65, 0.135),
		"shadow": Color(0.51, 0.45, 0.62, 0.10)
	},
	{
		"base": Color("f5e3cf"), "sky": Color("f1e2d7"),
		"sea": Color("c5d8ce"), "sand": Color("efdbc2"), "sun": Color("ffdfb5"),
		"sunlight": Color(1.0, 0.79, 0.57, 0.14),
		"window_light": Color(1.0, 0.83, 0.63, 0.14),
		"shadow": Color(0.52, 0.44, 0.61, 0.125)
	},
	{
		"base": Color("eee5d9"), "sky": Color("eae7e3"),
		"sea": Color("c0d1d1"), "sand": Color("eadcc9"), "sun": Color("f6e4d0"),
		"sunlight": Color(1.0, 0.83, 0.65, 0.075),
		"window_light": Color(1.0, 0.86, 0.71, 0.095),
		"shadow": Color(0.50, 0.45, 0.60, 0.105)
	}
]

var mode: String = "environment":
	set(value):
		mode = "overlay" if value == "overlay" else "environment"
		queue_redraw()
var indoors: bool = false:
	set(value):
		indoors = value
		queue_redraw()
var minute: int:
	get:
		return _minute
	set(value):
		apply_minute(value, is_inside_tree())
var display_minute: float:
	get:
		return _display_minute

var _minute = 540
var _display_minute = 540.0
var _transition: Tween

func _init(initial_mode: String = "environment") -> void:
	mode = initial_mode
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()

func apply_minute(value: int, animate: bool = true) -> void:
	_minute = maxi(0, value)
	if is_instance_valid(_transition):
		_transition.kill()
	if animate and is_inside_tree() and not is_equal_approx(_display_minute, float(_minute)):
		_transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_transition.tween_method(_show_minute, _display_minute, float(_minute), TRANSITION_SECONDS)
	else:
		_show_minute(float(_minute))

func _show_minute(value: float) -> void:
	_display_minute = value
	queue_redraw()

static func period(value: int) -> String:
	if value < 720:
		return "晨光"
	if value < 960:
		return "午后"
	if value < 1050:
		return "斜阳"
	if value < 1140:
		return "日落"
	return "晚风"

static func ambient_at(value: int) -> Color:
	# Runtime light is shared by background, supplied buildings and painted actors.
	# Source image pixels stay intact. Clock changes, never reading time, drive it.
	var hours=[540.0,720.0,960.0,1080.0,1200.0]
	var tints=[Color("fffaf0"),Color("ffffff"),Color("fff1dc"),Color("f5d5c1"),Color("b6c2da")]
	if value<=hours[0]: return tints[0]
	for index in range(hours.size()-1):
		if value<=hours[index+1]:
			var blend: float=smoothstep(hours[index],hours[index+1],float(value))
			return tints[index].lerp(tints[index+1],blend)
	return tints[-1]

static func palette_at(value: float) -> Dictionary:
	if value <= HOURS[0]:
		return COLORS[0].duplicate()
	if value >= HOURS[-1]:
		return COLORS[-1].duplicate()
	for index in range(HOURS.size() - 1):
		if value <= HOURS[index + 1]:
			var blend = clampf((value - HOURS[index]) / (HOURS[index + 1] - HOURS[index]), 0.0, 1.0)
			# Zero slope at each stop keeps palette boundaries visually continuous.
			blend = blend * blend * (3.0 - 2.0 * blend)
			var palette: Dictionary = {}
			for key in COLORS[index]:
				palette[key] = COLORS[index][key].lerp(COLORS[index + 1][key], blend)
			return palette
	return COLORS[-1].duplicate()

static func overlay_shapes_at(value: float, extent: Vector2, inside: bool = false) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	if extent.x <= 0.0 or extent.y <= 0.0:
		return layers
	var palette = palette_at(value)
	var phase = clampf((value - 540.0) / 540.0, 0.0, 1.0)
	if inside:
		# Two panes, with the mullion left as untouched negative space. The light
		# belongs on a blank wall/worktop behind the desk, never on the locked art.
		var cast = Vector2(0.20 + phase * 0.16, 0.52)
		for offset in [0.0, 0.165]:
			var left = Vector2(0.045 + offset, 0.105)
			var right = Vector2(0.19 + offset, 0.105)
			layers.append({"points": _scaled([left, right, right + cast, left + cast], extent), "color": palette.window_light})
	else:
		# One broad light patch; no animated particles, stripes, or answer glows.
		var drift = phase * 0.055
		layers.append({"points": _scaled([
			Vector2(0.69 + drift, 0.11), Vector2(0.91 + drift, 0.11),
			Vector2(0.56, 0.69), Vector2(0.17, 0.64)
		], extent), "color": palette.sunlight})
	# A restrained lavender cast sits below the light patch, so their alpha does
	# not stack. Its length responds to the supplied game time, not real time.
	var shadow_cast = Vector2(lerpf(0.10, -0.16, phase), 0.055 + phase * 0.02)
	var a = Vector2(0.22, 0.835)
	var b = Vector2(0.74, 0.835)
	layers.append({"points": _scaled([a, b, b + shadow_cast, a + shadow_cast], extent), "color": palette.shadow})
	return layers

static func _scaled(points: Array, extent: Vector2) -> PackedVector2Array:
	var scaled = PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(point * extent)
	return scaled

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if mode == "overlay":
		for layer in overlay_shapes_at(_display_minute, size, indoors):
			draw_colored_polygon(layer.points, layer.color)
		return
	var palette = palette_at(_display_minute)
	draw_rect(Rect2(Vector2.ZERO, size), palette.base)
	if indoors:
		# Interior mode leaves the stage calm. A separate overlay can supply the
		# window shape wherever the current workspace has room for it.
		draw_rect(Rect2(Vector2(0, size.y * 0.83), Vector2(size.x, size.y * 0.17)), palette.sand)
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.59)), palette.sky)
	# A single level sea and shore keeps the building as the visual focus.
	draw_rect(Rect2(Vector2(0, size.y * 0.59), Vector2(size.x, size.y * 0.16)), palette.sea)
	draw_rect(Rect2(Vector2(0, size.y * 0.75), Vector2(size.x, size.y * 0.25)), palette.sand)
	var phase = clampf((_display_minute - 540.0) / 540.0, 0.0, 1.0)
	var sun = Vector2(lerpf(0.765, 0.89, phase), 0.33 - sin(phase * PI) * 0.08 + phase * 0.20)
	draw_circle(sun * size, minf(size.x, size.y) * 0.036, palette.sun)
