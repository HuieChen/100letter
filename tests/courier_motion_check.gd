extends SceneTree
const Walker = preload("res://scripts/rebuild/final_walker.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var w = Walker.new()
	root.add_child(w)
	w.set_process(false)
	check(w._walk_keys.size() == 5 and w._poses.size() == 11, "Only original authored poses load")
	check(not FileAccess.get_file_as_string("res://scripts/rebuild/final_walker.gd").contains("courier_motion_20261031"), "Rejected generated frames are unreachable")
	check(w._turn_keys.size() == 7, "Five supplementary orientations plus authored endpoints")
	for key: String in w._walk_keys + w._turn_keys:
		check(w._poses.get(key) != null, "Pose is resident: " + key)
	var results := []
	for fps: float in [30.0, 60.0, 144.0]:
		w.actor_height = 295.0
		w.configure(null, Rect2(0, 872, 4000, 0), Vector2(100, 872))
		w.walk_to(Vector2(1200, 872))
		var poses := {}
		for i in range(int(fps * 2)):
			w._process(1.0 / fps)
			poses[w._frame_for_time(w._walk_time)] = true
		results.append(w.foot.x)
		check(poses.size() == 5, "Every gait pose visited at %s fps" % fps)
		check(w._pose_mix == 1.0, "Walking completes start orientation")
		w.walk_to(Vector2(200, 872))
		for i in range(int(fps * 6)): w._process(1.0 / fps)
		check(not w.walking and w.foot.distance_to(Vector2(200, 872)) < .01, "Reverse arrives")
		check(is_equal_approx(w._pose_mix, 0.0), "Stop finishes at authored front idle")
		var still: Vector2 = w.foot
		for i in range(int(fps)): w._process(1.0 / fps)
		check(w.foot == still, "Idle does not drift")
	check(absf(results[0] - results[2]) < 1.5, "30 and 144 fps travel agree")
	for fps: float in [30.0, 60.0, 144.0]:
		w.configure(null, Rect2(0, 872, 4000, 0), Vector2(100, 872))
		w._turn_position = 0.0
		w._pose_mix = 1.0
		w._was_in_motion = true
		var seen := {}
		var duration := 0.0
		while w._turn_position < 1.0 and duration < 1.0:
			w._update_idle_transition(1.0/fps)
			duration += 1.0/fps
			seen[roundi(w._turn_position*6.0)] = true
		check(duration <= .35, "Return finishes within350ms at %s fps" % fps)
		for pose in range(1,6): check(seen.has(pose), "Short turn retains intermediate %s at %s fps" % [pose,fps])
		check(w.foot == Vector2(100,872), "Short turn remains planted")
		w._turn_position = .5
		w.walking = true
		w._update_idle_transition(1.0/fps)
		check(w._turn_position < .5, "Restart reverses current turn without jumping to front")
		w.cancel()
	for pause: float in [.02, .08, .16, .30, .45]:
		w.walk_to(Vector2(500, 872))
		for i in range(30): w._process(1.0 / 60.0)
		w.cancel()
		w._process(pause)
		w.walk_to(Vector2(800, 872))
		for i in range(150): w._process(1.0 / 60.0)
		check(w._pose_mix >= 0.0 and w._pose_mix <= 1.0, "Quick restart remains bounded")
	var calls := [0]
	w.configure(null, Rect2(0, 872, 4000, 0), Vector2(100, 872))
	w.walk_to(Vector2(300, 872), func(): calls[0] += 1)
	for i in range(240): w._process(1.0 / 60.0)
	check(calls[0] == 1, "Arrival callback fires once")
	w.walk_to(Vector2(700, 872), func(): calls[0] += 1)
	w._process(.1)
	w._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var stopped: Vector2 = w.foot
	for i in range(90): w._process(1.0 / 60.0)
	check(w.foot == stopped and calls[0] == 1, "Focus loss cancels stale callback")
	w.configure(null, Rect2(0, 872, 4000, 0), Vector2(100, 872))
	for i in range(120): w._advance_manual(Vector2.RIGHT, 1.0 / 120.0)
	var ordinary: float = w.foot.x
	w.configure(null, Rect2(0, 872, 4000, 0), Vector2(100, 872))
	w._fast_held = true
	for i in range(120): w._advance_manual(Vector2.RIGHT, 1.0 / 120.0)
	var speed_ratio: float = (w.foot.x-100.0)/(ordinary-100.0)
	check(speed_ratio > 1.20 and speed_ratio < 1.36, "Shift is a gentle bounded increase")
	w._fast_held = false
	var last_speed: float = w.velocity.x
	var release_bounded := true
	for i in range(30):
		w._advance_manual(Vector2.RIGHT, 1.0/120.0)
		release_bounded = release_bounded and w.velocity.x <= last_speed + .001 and w.velocity.x >= w.max_speed - .001
		last_speed = w.velocity.x
	check(release_bounded and is_equal_approx(w.velocity.x,w.max_speed), "Release Shift while walking smoothly returns to normal speed")
	w._fast_held = true
	for i in range(30): w._advance_manual(Vector2.RIGHT, 1.0/120.0)
	w._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not w._fast_held and w._shift_blend == 0.0, "Focus loss clears Shift ramp")
	var time_before: float = w._walk_time
	w._advance_phase(125.0)
	check(absf(w._walk_time - time_before) < .0001, "One calibrated stride wraps once")
	w.queue_free()
	await process_frame
	print("COURIER_MOTION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

