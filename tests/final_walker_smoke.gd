extends SceneTree
## Run: Godot --headless --path . --script res://tests/final_walker_smoke.gd
## Covers the independent final walker: callback ownership, genuine keyboard input and no legacy art dependency.

const Walker = preload("res://scripts/rebuild/final_walker.gd")
var walker: Control
var callbacks: Array[String] = []
var arrivals: int = 0
var footsteps: int = 0
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	walker = Walker.new()
	root.add_child(walker)
	walker.arrived.connect(func() -> void: arrivals += 1)
	walker.footstep.connect(func() -> void: footsteps += 1)
	walker.configure(null, Rect2(40, 170, 900, 230), Vector2(120, 300))
	walker.walk_to(Vector2(480, 300), func() -> void: callbacks.append("first"))
	_check(callbacks.is_empty() and walker.walking, "hotspot action waits for approach rather than firing on click")
	walker._process(1.0 / 60.0)
	var first_speed: float = walker.velocity.length()
	walker._process(1.0 / 60.0)
	_check(first_speed > 0.0 and walker.velocity.length() > first_speed and walker.velocity.length() < walker.max_speed, "actor accelerates into its walk")
	_finish_walk()
	_check(footsteps >= 4 and footsteps <= 6, "walking emits spaced foot contacts from actual travelled distance")
	var settled_steps: int = footsteps
	_check(callbacks == ["first"] and arrivals == 1, "arrival runs the pending action once")
	_check(walker.foot.distance_to(Vector2(480, 300)) < 0.01 and walker.velocity.length() < 0.02, "feet settle at target with no residual movement")
	walker._process(1.0)
	_check(footsteps == settled_steps, "standing still emits no phantom footsteps")
	_check(callbacks.size() == 1 and arrivals == 1, "extra frames cannot repeat a completed callback")
	walker.walk_to(Vector2(900, 350), func() -> void: callbacks.append("stale"))
	for index: int in range(12):
		walker._process(1.0 / 60.0)
	walker.walk_to(Vector2(180, 330), func() -> void: callbacks.append("replacement"))
	_finish_walk()
	_check(not "stale" in callbacks and callbacks[-1] == "replacement", "a new destination invalidates the earlier hotspot callback")
	_check(walker._facing < 0.0, "the courier faces its return journey")
	walker.walk_to(Vector2(700, 300), func() -> void: callbacks.append("cancelled"))
	walker._process(0.1)
	walker.cancel()
	var stopped: Vector2 = walker.foot
	for index: int in range(60):
		walker._process(1.0 / 60.0)
	_check(walker.foot == stopped and not "cancelled" in callbacks, "cancel stops feet and invalidates callbacks when a modal opens")
	walker.walk_to(Vector2(-300, 900), func() -> void: callbacks.append("bounded"))
	_finish_walk()
	_check(walker.foot == Vector2(40, 400), "click targets clamp to the walkable foot area")
	walker.walk_to(walker.foot, func() -> void: callbacks.append("nearby"))
	_check(not "nearby" in callbacks, "even a nearby hotspot callback waits for the processing boundary")
	walker._process(1.0 / 60.0)
	_check(callbacks[-1] == "nearby", "a nearby hotspot remains usable without a fake journey")
	var cancel_on_arrival: Callable = func() -> void: walker.cancel()
	walker.arrived.connect(cancel_on_arrival)
	walker.walk_to(Vector2(70, 400), func() -> void: callbacks.append("screen_closed"))
	_finish_walk()
	_check(not "screen_closed" in callbacks, "closing the screen from arrived cancels the former action safely")
	walker.arrived.disconnect(cancel_on_arrival)
	_test_manual()
	var reference := Image.create_empty(24, 48, false, Image.FORMAT_RGBA8)
	reference.fill(Color("#548679"))
	var original_pixels: PackedByteArray = reference.get_data().duplicate()
	var texture := ImageTexture.create_from_image(reference)
	walker.configure(texture, Rect2(40, 170, 900, 230), Vector2(330, 300))
	var texture_rect: Rect2 = walker._actor_rect()
	_check(is_equal_approx(texture_rect.size.x / texture_rect.size.y, 0.5), "optional whole texture keeps its original aspect ratio")
	walker.walk_to(Vector2(100, 300))
	_finish_walk()
	_check(reference.get_data() == original_pixels and walker._texture == texture, "whole texture source pixels remain unchanged after walking")
	_check(not FileAccess.get_file_as_string("res://scripts/rebuild/final_walker.gd").contains("courier_actor"), "final movement class does not import the retired artwork renderer")
	print("FINAL WALKER SMOKE: %d checks, %d failures" % [checks, failures.size()])
	walker.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _test_manual() -> void:
	walker.configure(null,Rect2(40,170,900,230),Vector2(120,300))
	_key(KEY_D,true)
	walker._process(0.2)
	_check(walker.foot == Vector2(120,300), "manual input is disabled by default outside the scene")
	walker.manual_enabled=true
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	walker.walk_to(Vector2(790,300),func() -> void: callbacks.append("manual_stale"))
	for index in range(45): walker._process(1.0/60.0)
	_check(walker.foot.x > 205 and not walker.walking and walker._manual_active, "held D drives actual acceleration and interrupts click travel")
	_key(KEY_D,false)
	for index in range(45): walker._process(1.0/60.0)
	var settled: Vector2=walker.foot
	_check(walker.velocity.length() < 0.02 and not "manual_stale" in callbacks, "key release brakes smoothly and never fires a stale hotspot")
	_key(KEY_W,true)
	for index in range(180): walker._process(1.0/60.0)
	_key(KEY_W,false)
	_check(walker.foot.y == 170 and walker.foot.x == settled.x, "W moves through depth but clamps feet at the walk boundary")
	walker.manual_enabled=false
	settled=walker.foot
	_key(KEY_D,true)
	for index in range(20): walker._process(1.0/60.0)
	_check(walker.foot == settled, "opening a modal disables keyboard movement even if a key remains held")
	walker.manual_enabled=true
	walker._process(0.2)
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	settled=walker.foot
	for index in range(30): walker._process(1.0/60.0)
	_check(walker.foot == settled and walker.velocity == Vector2.ZERO, "losing window focus immediately stops manual movement")
	_key(KEY_D,false)
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	walker.manual_enabled=false
	walker.face_towards(walker.foot+Vector2(-100,0))
	_check(walker._facing < 0, "dialogue can face the nearby person without changing foot position")
	walker.gesture("handoff")
	walker._process(0.5)
	_check(walker._gesture_name == "handoff" and walker.foot == settled, "handoff lifecycle remains grounded (visual pose requires a manifest asset)")
	walker._process(2.0)
	_check(walker._gesture_name.is_empty(), "gesture returns to breathing idle without looping the handoff")


func _finish_walk() -> void:
	for index: int in range(1200):
		walker._process(1.0 / 60.0)
		if not walker.walking:
			break
	_check(not walker.walking, "journey converges without overshoot or a stuck target")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS " + label)
	else:
		failures.append(label)
		push_error("FAIL " + label)
