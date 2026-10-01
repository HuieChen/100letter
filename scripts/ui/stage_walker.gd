class_name StageWalker
extends Control
## Scene-local foot coordinates. The walk bounds constrain the feet, not the
## texture rectangle. Callback ownership changes whenever walk_to/cancel runs.

signal arrived
signal footstep
signal foot_position_changed(at: Vector2)

const Actor = preload("res://scripts/ui/courier_actor.gd")

var max_speed: float = 200.0
var acceleration: float = 720.0
var deceleration: float = 930.0
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
var _walk_phase: float = 0.0
var _step_distance: float = 0.0
var _motion_blend: float = 0.0
var _facing: float = 1.0
var _manual_active: bool = false
var _window_focused: bool = true
var _breathing: float = 0.0
var _gesture_name: String = ""
var _gesture_time: float = 0.0
var _gesture_duration: float = 1.0


func _ready() -> void:
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
	_walk_phase = 0.0
	_motion_blend = 0.0
	_facing = 1.0
	set_process(true)
	queue_redraw()


func walk_to(destination: Vector2, action: Callable = Callable()) -> void:
	if is_queued_for_deletion():
		return
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
		_window_focused = false
		if _manual_active: cancel()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true
		set_process(true)


func _manual_direction() -> Vector2:
	if not manual_enabled or not _window_focused: return Vector2.ZERO
	var x: float = float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var y: float = float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
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
	# A simple elliptical ground contact is independent of both artwork paths.
	draw_set_transform(foot + Vector2(0, 3), 0.0, Vector2(1.0, 0.25) * actor_height / 156.0)
	draw_circle(Vector2.ZERO, 21.0, Color(0.20, 0.32, 0.29, 0.12))
	draw_set_transform(Vector2.ZERO)
	if _texture != null:
		# Entire supplied texture; no region/crop, mirroring, limb deformation,
		# bobbing or palette edits. Locked reference sheets are not passed here.
		draw_texture_rect(_texture, _actor_rect(), false)
	else:
		Actor.draw_actor(self, foot, _walk_phase, _motion_blend, _facing, actor_height, _gesture_name, _gesture_time / _gesture_duration, _breathing)


func _process(delta: float) -> void:
	_breathing += delta
	if not _gesture_name.is_empty():
		_gesture_time += delta
		if _gesture_time >= _gesture_duration: _gesture_name = ""
	var manual: Vector2 = _manual_direction()
	if manual.length_squared() > 0.0 and not _manual_active:
		_command += 1
		_pending_action = Callable()
		walking = false
		_manual_active = true
		_gesture_name = ""
	var remaining: float = clampf(delta, 0.0, 0.25)
	while remaining > 0.00001:
		var step: float = minf(remaining, 1.0 / 60.0)
		if _manual_active:
			_advance_manual(manual,step)
		elif walking:
			_advance(step)
		var desired_blend: float = clampf(velocity.length() / maxf(max_speed, 1.0), 0.0, 1.0) if walking or _manual_active else 0.0
		_motion_blend = move_toward(_motion_blend, desired_blend, step * 7.0)
		if _motion_blend < 0.02 and not walking:
			_motion_blend = 0.0
		remaining -= step
	queue_redraw()
	if not walking and _motion_blend == 0.0 and not manual_enabled and _texture != null and _gesture_name.is_empty():
		set_process(false)


func _advance_manual(direction: Vector2, delta: float) -> void:
	var desired: Vector2 = direction * max_speed
	velocity = velocity.move_toward(desired, (acceleration if not direction.is_zero_approx() else deceleration) * delta)
	var previous: Vector2 = foot
	var proposed: Vector2 = foot + velocity * delta
	foot = _bounded(proposed)
	if not is_equal_approx(proposed.x, foot.x): velocity.x = 0.0
	if not is_equal_approx(proposed.y, foot.y): velocity.y = 0.0
	target = foot
	var travelled: float = foot.distance_to(previous)
	_advance_phase(travelled)
	if absf(direction.x) > 0.1: _facing = signf(direction.x)
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
	var desired_speed: float = minf(max_speed, sqrt(2.0 * deceleration * distance))
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


func _advance_phase(travelled: float) -> void:
	_walk_phase = fposmod(_walk_phase + travelled / 142.0 * TAU, TAU)
	_step_distance += travelled
	while _step_distance >= 71.0:
		_step_distance -= 71.0
		footstep.emit()


func _reach_target() -> void:
	var completed_command: int = _command
	var action: Callable = _pending_action
	foot = target
	velocity = Vector2.ZERO
	walking = false
	_pending_action = Callable()
	arrived.emit()
	# A signal listener may open another screen, cancel, or choose another target.
	# In those cases the former hotspot action no longer belongs to this walk.
	if completed_command == _command and not is_queued_for_deletion() and action.is_valid():
		action.call()
