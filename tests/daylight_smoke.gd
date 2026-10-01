extends SceneTree
## Tests the stage's color/geometry contract; does not advance gameplay time.
const Light = preload("res://scripts/ui/daylight.gd")
var checks = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(Light.ambient_at(720) == Color.WHITE, "noon leaves the painted world at its original colors")
	_check(Light.ambient_at(1080).b < Light.ambient_at(1080).r, "sunset warms the world rather than imposing a dark screen")
	_check(Light.ambient_at(1440) == Light.ambient_at(1200) and Light.ambient_at(0) == Light.ambient_at(540), "world color temperature safely clamps outside the working day")
	var ambient_step: float = 0.0
	var minimum_channel: float = 1.0
	for clock_minute in range(540, 1441):
		var tint: Color = Light.ambient_at(clock_minute)
		ambient_step = maxf(ambient_step, _distance(tint, Light.ambient_at(clock_minute + 1)))
		minimum_channel = minf(minimum_channel, minf(tint.r, minf(tint.g, tint.b)))
	_check(ambient_step < 0.004 and minimum_channel > 0.7, "world tint changes gradually and retains readable evening brightness")
	for boundary in [540.0, 720.0, 960.0, 1080.0, 1200.0]:
		var before = Light.palette_at(boundary - 0.01)
		var after = Light.palette_at(boundary + 0.01)
		var step = 0.0
		for key in before:
			step = maxf(step, _distance(before[key], after[key]))
		_check(step < 0.0001, "palette is continuous at minute %d" % boundary)
	var step = 0.0
	var maximum_alpha = 0.0
	var contrast = INF
	for minute in range(540, 1441):
		var colors = Light.palette_at(minute)
		var next = Light.palette_at(minute + 1)
		for key in colors:
			step = maxf(step, _distance(colors[key], next[key]))
		for key in ["sunlight", "window_light", "shadow"]:
			maximum_alpha = maxf(maximum_alpha, colors[key].a)
		for key in ["base", "sky", "sea", "sand"]:
			contrast = minf(contrast, (colors[key].srgb_to_linear().get_luminance() + 0.05) / (Color("294b4b").srgb_to_linear().get_luminance() + 0.05))
	_check(step < 0.004, "each game-minute color change stays gradual")
	_check(maximum_alpha <= 0.16, "every overlay alpha stays within 0.16")
	_check(contrast >= 5.5, "dark teal text remains readable on all evening stage colors")
	_check(Light.palette_at(1440) == Light.palette_at(1200), "late gameplay keeps a bright evening palette")
	_check(Light.palette_at(0) == Light.palette_at(540), "early time safely clamps to morning")
	_check(Light.palette_at(1080).base.get_luminance() >= 0.85, "sunset retains a light cream workspace")
	_check(Light.period(540) == "晨光" and Light.period(720) == "午后" and Light.period(1000) == "斜阳" and Light.period(1080) == "日落" and Light.period(1200) == "晚风", "period labels progress through the working day")
	for indoors in [false, true]:
		for minute in [540, 720, 960, 1080, 1440]:
			var shapes = Light.overlay_shapes_at(minute, Vector2(1600, 900), indoors)
			var small = Light.overlay_shapes_at(minute, Vector2(800, 450), indoors)
			var valid = shapes.size() == (3 if indoors else 2)
			for index in range(shapes.size()):
				valid = valid and shapes[index].color.a <= 0.16
				for point_index in range(shapes[index].points.size()):
					var point: Vector2 = shapes[index].points[point_index]
					valid = valid and point.x >= 0 and point.y >= 0 and point.x <= 1600 and point.y <= 900 and (point * 0.5).is_equal_approx(small[index].points[point_index])
			_check(valid, "minimal translucent geometry fits both canvas sizes at %d indoors=%s" % [minute, indoors])
	_check(Light.overlay_shapes_at(540, Vector2.ZERO).is_empty(), "zero-size layout has no invalid polygons")
	var environment = Light.new()
	environment.size = Vector2(1600, 900)
	environment.minute = 720
	root.add_child(environment)
	var overlay = Light.new("overlay")
	overlay.indoors = true
	overlay.size = Vector2(840, 480)
	overlay.minute = 720
	root.add_child(overlay)
	await process_frame
	_check(environment.mode == "environment" and overlay.mode == "overlay", "both modes enter the scene tree")
	_check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE and environment.mouse_filter == Control.MOUSE_FILTER_IGNORE, "lighting cannot block interactions")
	_check(overlay.modulate == Color.WHITE and environment.modulate == Color.WHITE, "lighting does not color-modulate whole nodes or artwork")
	await create_timer(0.06).timeout
	_check(overlay.minute == 720 and is_equal_approx(overlay.display_minute, 720), "reading time leaves the clock and daylight unchanged")
	overlay.apply_minute(1080)
	_check(overlay.minute == 1080 and overlay.display_minute < 1080, "a supplied time change starts smooth visual interpolation")
	await create_timer(Light.TRANSITION_SECONDS + 0.05).timeout
	_check(overlay.minute == 1080 and is_equal_approx(overlay.display_minute, 1080), "interpolation settles without advancing game time")
	overlay.minute = 1200
	await create_timer(0.05).timeout
	overlay.apply_minute(540, false)
	await create_timer(Light.TRANSITION_SECONDS + 0.05).timeout
	_check(overlay.minute == 540 and is_equal_approx(overlay.display_minute, 540), "loading a checkpoint cancels the stale visual target")
	environment.queue_free()
	overlay.queue_free()
	await process_frame
	print("DAYLIGHT SMOKE: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _distance(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), maxf(absf(a.b - b.b), absf(a.a - b.a)))

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS " + label)
	else:
		failures.append(label)
		push_error("FAIL " + label)
