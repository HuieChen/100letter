extends Control
## Standalone manifest-painted courier; no legacy illustration dependencies.
## Scene-local foot coordinates. The walk bounds constrain the feet, not the
## texture rectangle. Callback ownership changes whenever walk_to/cancel runs.

signal arrived
signal footstep
signal foot_position_changed(at: Vector2)

const PhysicalArt = preload("res://scripts/rebuild/physical_art.gd")
const WALK_GEOMETRY := "res://assets/faefever_v2/characters/courier_walk_regions.json"
var _frame_geometry: Dictionary = {}
var _poses: Dictionary = {}
var _walk_keys: Array[String] = []
var _frame_ends: Array[float] = []
var _cycle_seconds: float = 0.0
var _idle_time: float = 0.0

var max_speed: float = 200.0
var acceleration: float = 1100.0
var deceleration: float = 1400.0
var actor_height: float = 156.0
var foot := Vector2.ZERO:
	set(value):
		if foot.is_equal_approx(value): return
		foot=value
		foot_position_changed.emit(foot)
var target := Vector2.ZERO
var velocity := Vector2.ZERO
var walk_bounds := Rect2()
var walking: bool = false
var manual_enabled: bool = false:
	set(value):
		manual_enabled = value
		if not value: cancel()
		set_process(true)
var _texture: Texture2D
var _pending_action: Callable = Callable()
var _command: int = 0
var _walk_time: float = 0.0
var _step_distance: float = 0.0
var _motion_blend: float = 0.0
var _pose_mix: float = 0.0
var _settle_time: float = 1.0
var _settle_phase: float = 0.0
var _was_in_motion: bool = false
var _facing: float = 1.0
var _manual_active: bool = false
var _fast_held: bool = false
var _window_focused: bool = true
var _breathing: float = 0.0
var _gesture_name: String = ""
var _gesture_time: float = 0.0
var _gesture_duration: float = 1.0


func _ready() -> void:
	# A pointer-only Window may never acquire focus. Do not treat it as focused
	# until its real Window says so, or poll another application's held keys.
	_window_focused = get_window().has_focus()
	if FileAccess.file_exists(WALK_GEOMETRY):
		var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(WALK_GEOMETRY))
		if data is Dictionary:
			for frame:Dictionary in data.get("frames",[]):
				var key := str(frame.key)
				_frame_geometry[key] = frame
				_walk_keys.append(key)
				_cycle_seconds += maxf(float(frame.get("duration_seconds",0.125)),0.001)
				_frame_ends.append(_cycle_seconds)
			if data.get("idle") is Dictionary:
				_frame_geometry["CHAR_courier"] = data.idle
				for frame:Dictionary in data.get("frames",[]):
					if frame.get("source_frame")==data.idle.get("source_frame"):
						_idle_time=float(frame.get("timestamp_seconds",0.0))
	_walk_time=_idle_time
	# Warm the source's complete ordered cycle before the first visible step.
	# Drawing never decodes a new bitmap while the actor is already moving.
	_poses["CHAR_courier"]=PhysicalArt.texture("CHAR_courier")
	var idle_image:=Image.new()
	if idle_image.load("res://assets/authoring/courier_20261030/clean_edges/idle.png")==OK:
		_poses["CHAR_courier"]=ImageTexture.create_from_image(idle_image)
		_frame_geometry["CHAR_courier"]={"reference_height_px":idle_image.get_height(),"foot_anchor_px":[idle_image.get_width()*0.52,idle_image.get_height()]}
	for key:String in _walk_keys:
		_poses[key]=PhysicalArt.texture(key)
	for index in range(_walk_keys.size()):
		var pixels:=Image.new()
		if pixels.load("res://assets/authoring/courier_20261030/clean_edges/walk_%d.png"%index)==OK:
			var key:String=_walk_keys[index]
			_poses[key]=ImageTexture.create_from_image(pixels)
			_frame_geometry[key]={"reference_height_px":pixels.get_height(),"foot_anchor_px":[pixels.get_width()*0.5,pixels.get_height()]}
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func configure(texture: Texture2D, bounds: Rect2, initial_foot: Vector2) -> void:
	cancel()
	_texture = texture
	walk_bounds = bounds.abs()
	foot = _bounded(initial_foot)
	target = foot
	_walk_time = _idle_time
	_motion_blend = 0.0
	_facing = 1.0
	set_process(true)
	queue_redraw()


func walk_to(destination: Vector2, action: Callable = Callable()) -> void:
	if is_queued_for_deletion():
		return
	if not walking and not _manual_active:
		_walk_time=_idle_time
		_step_distance=0.0
	_command += 1
	_manual_active = false
	_gesture_name = ""
	_pending_action = action
	target = _bounded(destination)
	walking = true
	set_process(true)
	queue_redraw()


func cancel() -> void:
	_command += 1
	_pending_action = Callable()
	velocity = Vector2.ZERO
	walking = false
	_motion_blend = 0.0
	_manual_active = false
	_step_distance = 0.0
	_walk_time = _idle_time
	target = foot
	queue_redraw()


func face_towards(point: Vector2) -> void:
	if absf(point.x - foot.x) > 1.0:
		_facing = signf(point.x - foot.x)
	queue_redraw()


func gesture(kind: String) -> void:
	if not kind in ["talk", "handoff", "inspect"]: return
	cancel()
	_gesture_name = kind
	_gesture_time = 0.0
	_gesture_duration = 1.4 if kind == "talk" else 2.1
	set_process(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_fast_held=false
		_window_focused = false
		# Native FLAG_NO_FOCUS still permits pointer input. A late focus-out event
		# must not discard an accepted mouse approach in a window which cannot own
		# focus; ordinary playable windows retain their focus-loss cancellation.
		if _manual_active or (walking and not get_window().unfocusable): cancel()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = not get_window().unfocusable
		set_process(true)


func _manual_direction() -> Vector2:
	if not manual_enabled or not _window_focused: return Vector2.ZERO
	var x: float = float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var y: float = float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	if walk_bounds.size.y <= 0.0: y = 0.0
	return Vector2(x, y).normalized() * Vector2(1.0, 0.58)


func _exit_tree() -> void:
	cancel()


func _bounded(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, walk_bounds.position.x, walk_bounds.end.x), clampf(point.y, walk_bounds.position.y, walk_bounds.end.y))


func _actor_rect() -> Rect2:
	if _texture == null or _texture.get_height() <= 0:
		return Rect2(foot - Vector2(actor_height * 0.25, actor_height), Vector2(actor_height * 0.5, actor_height))
	var dimensions: Vector2 = _texture.get_size() * actor_height / float(_texture.get_height())
	return Rect2(foot - Vector2(dimensions.x * 0.5, dimensions.y), dimensions)


func _draw() -> void:
	var blend:=smoothstep(0.0,1.0,_pose_mix)
	if blend<1.0: _draw_pose("CHAR_courier",1.0-blend)
	if blend>0.0 and not _walk_keys.is_empty():
		_draw_pose(_walk_keys[_frame_for_time(_walk_time)],blend)

func _draw_pose(key:String,opacity:float)->void:
	var art:Texture2D=_poses.get(key)
	if art==null:return
	var ratio:float=actor_height/art.get_height()
	var anchor:=Vector2(art.get_width()*0.44,art.get_height())
	if _frame_geometry.has(key):
		var geometry:Dictionary=_frame_geometry[key]
		ratio=actor_height/float(geometry.reference_height_px)
		anchor=Vector2(float(geometry.foot_anchor_px[0]),float(geometry.foot_anchor_px[1]))
	var dimensions:=art.get_size()*ratio
	var facing:float=-1.0 if _facing<0 else 1.0
	draw_set_transform(foot,0.0,Vector2(facing,1.0))
	draw_texture_rect(art,Rect2(-anchor*ratio,dimensions),false,Color(1,1,1,opacity))
	draw_set_transform(Vector2.ZERO)


func _process(delta: float) -> void:
	_breathing += delta
	if not _gesture_name.is_empty():
		_gesture_time += delta
		if _gesture_time >= _gesture_duration: _gesture_name = ""
	var manual: Vector2 = _manual_direction()
	if manual.length_squared() > 0.0 and not _manual_active:
		if not walking and _pose_mix<0.01:
			_walk_time=_idle_time
			_step_distance=0.0
		_command += 1
		_pending_action = Callable()
		walking = false
		_manual_active = true
		_gesture_name = ""
	var remaining: float = clampf(delta, 0.0, 0.25)
	while remaining > 0.00001:
		var step: float = minf(remaining, 1.0 / 120.0)
		if _manual_active:
			_advance_manual(manual,step)
		elif walking:
			_advance(step)
		var desired_blend: float = clampf(velocity.length() / maxf(max_speed, 1.0), 0.0, 1.0) if walking or _manual_active else 0.0
		_motion_blend = move_toward(_motion_blend, desired_blend, step * 7.0)
		if _motion_blend < 0.02 and not walking:
			_motion_blend = 0.0
		remaining -= step
	_update_idle_transition(delta)
	queue_redraw()
	if not walking and _motion_blend == 0.0 and not manual_enabled and _texture != null and _gesture_name.is_empty():
		set_process(false)

func _update_idle_transition(delta:float)->void:
	var moving:=velocity.length()>3.0 or walking or (_manual_active and not _manual_direction().is_zero_approx())
	if moving:
		_settle_time=0.0
		_was_in_motion=true
		_pose_mix=move_toward(_pose_mix,1.0,delta/0.22)
		return
	if _was_in_motion:
		_settle_phase=_walk_time
		_was_in_motion=false
		_settle_time=0.0
	_settle_time+=delta
	# Finish the gait on the existing planted-foot source pose before turning.
	# No invented artwork: only timing/order of the supplied poses changes.
	if _pose_mix>0.01 and _settle_time<0.26 and _cycle_seconds>0.0:
		var planted:=0.3125
		var distance:=fposmod(planted-_settle_phase+_cycle_seconds*0.5,_cycle_seconds)-_cycle_seconds*0.5
		_walk_time=fposmod(_settle_phase+distance*smoothstep(0.0,0.26,_settle_time),_cycle_seconds)
	if _settle_time>0.48:
		_pose_mix=move_toward(_pose_mix,0.0,delta/0.42)


func _input(event:InputEvent)->void:
	if event is InputEventKey and (event.keycode==KEY_SHIFT or event.physical_keycode==KEY_SHIFT):
		_fast_held=event.pressed

func _advance_manual(direction: Vector2, delta: float) -> void:
	var fast := _fast_held or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SHIFT)
	var desired: Vector2 = direction * max_speed * (1.65 if fast else 1.0)
	velocity = velocity.move_toward(desired, (acceleration if not direction.is_zero_approx() else deceleration) * delta)
	var previous: Vector2 = foot
	var proposed: Vector2 = foot + velocity * delta
	foot = _bounded(proposed)
	if not is_equal_approx(proposed.x, foot.x): velocity.x = 0.0
	if not is_equal_approx(proposed.y, foot.y): velocity.y = 0.0
	target = foot
	var travelled: float = foot.distance_to(previous)
	_advance_phase(travelled)
	# Reversing input first brakes the current momentum. Turning the painted
	# pose immediately would make it face backwards while still travelling.
	if absf(velocity.x) > 0.02:
		_facing = signf(velocity.x)
	elif absf(direction.x) > 0.1:
		_facing = signf(direction.x)
	if direction.is_zero_approx() and velocity.length() < 0.02:
		velocity = Vector2.ZERO
		_manual_active = false


func _advance(delta: float) -> void:
	var difference: Vector2 = target - foot
	var distance: float = difference.length()
	if distance <= 1.0:
		_reach_target()
		return
	var direction: Vector2 = difference / distance
	# Approach gently in the last few pixels; the previous square-root-only
	# brake still travelled about66px/s before snapping to a stationary pose.
	var desired_speed: float = minf(max_speed, minf(sqrt(2.0 * deceleration * distance), distance * 8.0))
	var desired_velocity: Vector2 = direction * desired_speed
	var rate: float = deceleration if desired_speed < velocity.length() else acceleration
	velocity = velocity.move_toward(desired_velocity, rate * delta)
	var motion: Vector2 = velocity * delta
	if motion.dot(difference) >= difference.length_squared():
		_reach_target()
		return
	var previous: Vector2 = foot
	foot = _bounded(foot + motion)
	var travelled: float = foot.distance_to(previous)
	if travelled > 0.001:
		_advance_phase(travelled)
	if absf(velocity.x) > 8.0:
		_facing = signf(velocity.x)


func _frame_for_time(seconds: float) -> int:
	if _frame_ends.is_empty() or _cycle_seconds<=0.0:return 0
	var at:float=fposmod(seconds,_cycle_seconds)
	for index:int in range(_frame_ends.size()):
		if at<_frame_ends[index]-0.0000001:return index
	return 0


func _advance_phase(travelled: float) -> void:
	if travelled<=0.0 or _cycle_seconds<=0.0:return
	# At the established game speed the clip runs in its exact source cadence.
	# Acceleration/braking slow the cycle with actual foot travel, not frame rate.
	# This world-distance calibration belongs to gameplay, not the source video.
	_walk_time = fposmod(_walk_time + 0.65 * travelled / maxf(max_speed,1.0),_cycle_seconds)
	_step_distance += travelled
	# One conservative contact on the narrow, grounded source pose per cycle.
	# The silent source does not substantiate a second synthesized footfall.
	var contact_distance:float=maxf(max_speed,1.0)*_cycle_seconds/0.65
	while _step_distance >= contact_distance:
		_step_distance -= contact_distance
		footstep.emit()


func _reach_target() -> void:
	var completed_command: int = _command
	var action: Callable = _pending_action
	foot = target
	velocity = Vector2.ZERO
	walking = false
	# Keep the last visible foot pose through the settle/fade, rather than
	# switching animation frames at the same instant movement stops.
	_pending_action = Callable()
	arrived.emit()
	# A signal listener may open another screen, cancel, or choose another target.
	# In those cases the former hotspot action no longer belongs to this walk.
	if completed_command == _command and not is_queued_for_deletion() and action.is_valid():
		action.call()
