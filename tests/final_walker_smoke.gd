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
	var original_unfocusable:bool=root.unfocusable
	root.unfocusable=false
	walker = Walker.new()
	root.add_child(walker)
	_check(walker._window_focused==root.has_focus(), "initial keyboard focus comes from the actual Window")
	_check(walker._poses.size()==6 and walker._walk_keys.size()==5 and not walker._poses.values().has(null), "all five latest video poses and matching idle are warm before first step")
	_check(walker._walk_keys==["CHAR_courier_walk_0","CHAR_courier_walk_1","CHAR_courier_walk_2","CHAR_courier_walk_3","CHAR_courier_walk_4"], "complete latest authored cycle is ordered without obsolete frames")
	_check(is_equal_approx(walker._cycle_seconds,0.625) and is_equal_approx(walker._idle_time,0.25),"original8fps period and idle2 timing loaded")
	for index:int in range(5):
		_check(walker._frame_for_time(float(index)*0.125+0.00001)==index and walker._frame_for_time(float(index)*0.125+0.1249)==index,"original125ms frame duration "+str(index))
	_check(walker._frame_for_time(0.625)==0 and walker._frame_for_time(1.0)==3,"timestamp selection wraps through exact source duration")
	var idle_geometry:Dictionary=walker._frame_geometry["CHAR_courier"]
	for key:String in walker._walk_keys:
		var geometry:Dictionary=walker._frame_geometry[key]
		_check(geometry.foot_anchor_px==idle_geometry.foot_anchor_px and geometry.reference_height_px==idle_geometry.reference_height_px, "idle and walk share the actual source-stage anchor: "+key)
	walker.arrived.connect(func() -> void: arrivals += 1)
	walker.footstep.connect(func() -> void: footsteps += 1)
	walker.configure(null, Rect2(40, 170, 900, 230), Vector2(120, 300))
	_check(walker._frame_for_time(walker._walk_time)==2,"start pose matches static original idle without a first-frame jump")
	var timing_start:float=walker._walk_time
	walker._advance_phase(25.0)
	_check(is_equal_approx(walker._walk_time,fposmod(timing_start+0.125,0.625)),"25worldpx at200px/s advances exactly one original frame")
	walker.cancel()
	walker.walk_to(Vector2(480, 300), func() -> void: callbacks.append("first"))
	_check(callbacks.is_empty() and walker.walking, "hotspot action waits for approach rather than firing on click")
	walker._process(1.0 / 60.0)
	var first_speed: float = walker.velocity.length()
	walker._process(1.0 / 60.0)
	_check(first_speed > 0.0 and walker.velocity.length() > first_speed and walker.velocity.length() < walker.max_speed, "actor accelerates into its walk")
	_finish_walk()
	_check(footsteps >= 2 and footsteps <= 3, "walking emits one conservative grounded contact per source cycle from actual travelled distance")
	var settled_steps: int = footsteps
	_check(callbacks == ["first"] and arrivals == 1, "arrival runs the pending action once")
	_check(walker.foot.distance_to(Vector2(480, 300)) < 0.01 and walker.velocity.length() < 0.02, "feet settle at target with no residual movement")
	walker._process(1.0)
	_check(footsteps == settled_steps, "standing still emits no phantom footsteps")
	_check(callbacks.size() == 1 and arrivals == 1, "extra frames cannot repeat a completed callback")
	walker.walk_to(Vector2(900, 350), func() -> void: callbacks.append("stale"))
	for index: int in range(12):
		walker._process(1.0 / 60.0)
	var momentum:Vector2=walker.velocity
	var phase:float=walker._walk_time
	walker.walk_to(Vector2(180, 330), func() -> void: callbacks.append("replacement"))
	_check(walker.velocity==momentum and is_equal_approx(walker._walk_time,phase),"retarget preserves actual momentum and animation timing before braking")
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
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	walker.walk_to(Vector2(800,300),func():callbacks.append("unfocused_stale"))
	walker._process(0.1)
	_check(walker.walking and walker.velocity.length()>0.0, "focusable pointer approach starts before focus loss")
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var focus_foot:Vector2=walker.foot
	walker._process(1.0)
	_check(not walker.walking and walker.foot==focus_foot and not "unfocused_stale" in callbacks,"losing focus cancels click movement and stale action")
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	_test_manual()
	_test_cadence_and_arrival()
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
	root.unfocusable=original_unfocusable
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


func _test_cadence_and_arrival() -> void:
	var trajectories:Array[Vector2]=[]
	for rate:float in [30.0,60.0,144.0]:
		walker.configure(null,Rect2(40,170,900,230),Vector2(120,300))
		walker.walk_to(Vector2(900,300))
		var poses:Dictionary={}
		for tick:int in range(int(rate)):
			walker._process(1.0/rate)
			poses[walker._frame_for_time(walker._walk_time)]=true
		trajectories.append(walker.foot)
		_check(poses.size()==5,"real movement visits all latest source poses at"+str(rate)+"fps")
		var last_speed:float=0.0
		for tick:int in range(int(rate)*8):
			last_speed=walker.velocity.length()
			walker._process(1.0/rate)
			if not walker.walking:break
		_check(not walker.walking and last_speed<20.0,"arrival eases below20px/s before the final1px settle at"+str(rate)+"fps")
		_check(walker._frame_for_time(walker._walk_time)==2,"arrival restores the exact original idle2 at"+str(rate)+"fps")
	_check(trajectories[0].distance_to(trajectories[1])<1.5 and trajectories[1].distance_to(trajectories[2])<1.5,"30/60/144fps movement agrees within1.5worldpx after one second")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS " + label)
	else:
		failures.append(label)
		push_error("FAIL " + label)
