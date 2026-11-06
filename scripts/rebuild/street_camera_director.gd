extends Node2D
## Consume Phantom Camera's real damped transform without applying a root
## Camera2D transform to the authored Control canvas or the HUD.
const Phantom = preload("res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_2d.gd")
const ANCHOR_X := 650.0
var phantom: Node2D
var target: Node2D
var scroll := 0.0
var limit := 0.0
var _last_foot := 0.0
var _initialized := false

func _ready() -> void:
	name = "StreetCameraDirector"
	top_level = true
	global_position = Vector2.ZERO
	target = Node2D.new()
	target.name = "CourierFramingTarget"
	add_child(target)
	phantom = Phantom.new()
	phantom.name = "PhantomStreetFollow"
	phantom.follow_mode = Phantom.FollowMode.GLUED
	phantom.follow_target = target
	phantom.follow_damping = true
	phantom.follow_damping_value = Vector2(0.18, 0.1)
	phantom.tween_on_load = false
	add_child(phantom)
	# The road steps the camera after courier movement, exactly once per frame.
	phantom.set_process(false)
	phantom.set_physics_process(false)

func frame_foot(at: float, world_width: float) -> void:
	limit = maxf(0.0, world_width - 1600.0)
	target.position = Vector2(clampf(at - ANCHOR_X, 0.0, limit), 0.0)
	# Map arrivals and saved positions must be framed before the scene reveal,
	# instead of taking the player on an unwanted pan across the entire town.
	if not _initialized or absf(at - _last_foot) > 450.0:
		phantom.teleport_position()
		scroll = target.position.x
	_initialized = true
	_last_foot = at

func advance(delta: float, enabled: bool = true) -> float:
	if not _initialized or not enabled:
		return scroll
	phantom.process_logic(minf(maxf(delta, 0.0), 0.05))
	scroll = clampf(phantom.get_transform_output().origin.x, 0.0, limit)
	return scroll

func snapshot() -> Dictionary:
	return {"driver":"PhantomCamera2D", "version":"0.11.0.3", "scroll":scroll, "target":target.position.x, "limit":limit, "damping":phantom.follow_damping_value.x}
