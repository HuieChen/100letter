extends RigidBody2D
## A physical slice carried by the measured water field, with a soft positional tether.
var radius:=94.0
var home:=Vector2.ZERO
var fluid_acceleration:=Vector2.ZERO
var fluid_current:=Vector2.ZERO
var _fluid_acceleration_target:=Vector2.ZERO
var _fluid_current_target:=Vector2.ZERO
var press_held:=false
var press_depth:=0.0
var press_velocity:=0.0
var press_target:=0.0
var press_edge:=0.0
var press_seconds:=0.0
var press_arm:=Vector2.ZERO
var press_count:=0
var release_count:=0
var _visuals:Array[Dictionary]=[]

func set_water_acceleration(value:Vector2)->void:
	_fluid_acceleration_target=value.limit_length(5.0) if value.is_finite() else Vector2.ZERO

func set_water_current(value:Vector2)->void:
	_fluid_current_target=value.limit_length(12.0) if value.is_finite() else Vector2.ZERO

func restore_water_state(saved:Dictionary)->void:
	set_water_acceleration(saved.get("fluid_acceleration",Vector2.ZERO))
	set_water_current(saved.get("fluid_current",Vector2.ZERO))
	fluid_acceleration=_fluid_acceleration_target;fluid_current=_fluid_current_target

func register_visual(sprite:Sprite2D)->void:
	_visuals.append({"sprite":sprite,"position":sprite.position,"scale":sprite.scale})

func begin_press(point:Vector2)->bool:
	if press_held:return false
	press_held=true;press_seconds=0.0;press_count+=1
	press_arm=(point-position).rotated(-rotation).limit_length(radius)
	press_edge=clampf(press_arm.length()/radius,0.0,1.0)
	press_target=2.6+0.4*press_edge
	press_velocity=minf(press_velocity+8.0,18.0)
	sleeping=false
	apply_impulse(Vector2(0.0,1.2+press_edge),press_arm.rotated(rotation)*0.3)
	return true

func end_press()->bool:
	if not press_held:return false
	press_held=false;release_count+=1;press_target=0.0;sleeping=false
	apply_impulse(Vector2(0.0,-1.2),press_arm.rotated(rotation)*0.25)
	return true

func press_snapshot()->Dictionary:
	return {"pressed":press_held,"depth":press_depth,"velocity":press_velocity,"target":press_target,
		"edge_ratio":press_edge,"held_seconds":press_seconds,"arm":press_arm,"point":position+press_arm.rotated(rotation),
		"scale_factor":1.0,"press_count":press_count,"release_count":release_count}

func restore_press_state(saved:Dictionary)->void:
	# A rebuilt settings page releases its old pointer capture while retaining a soft settle.
	press_held=false;press_target=0.0
	press_depth=clampf(float(saved.get("depth",0.0)),0.0,3.2)
	press_velocity=clampf(float(saved.get("velocity",0.0)),-24.0,24.0)
	press_edge=clampf(float(saved.get("edge_ratio",0.0)),0.0,1.0)
	press_seconds=float(saved.get("held_seconds",0.0));press_arm=saved.get("arm",Vector2.ZERO)
	press_count=int(saved.get("press_count",0));release_count=int(saved.get("release_count",0))
	_apply_visual_depth()

func _physics_process(delta:float)->void:
	if press_held:press_seconds+=delta
	# Near-critical damping returns the visual plate within half a second.
	var step:=minf(delta,0.0333333)
	press_velocity+=((press_target-press_depth)*400.0-press_velocity*38.0)*step
	press_depth+=press_velocity*step
	if press_depth>3.2:press_depth=3.2;press_velocity=minf(press_velocity,0.0)
	elif press_depth<0.0:press_depth=0.0;press_velocity=maxf(press_velocity,0.0)
	if not press_held and press_depth<0.005 and absf(press_velocity)<0.05:
		press_depth=0.0;press_velocity=0.0
	_apply_visual_depth()

func _apply_visual_depth()->void:
	var sink:=Vector2(0.0,press_depth).rotated(-rotation)
	for plate:Dictionary in _visuals:
		var sprite:Sprite2D=plate.sprite
		sprite.position=plate.position+sink
		# The authored circular slice stays rigid; press feedback never scales its artwork.
		sprite.scale=plate.scale

func _integrate_forces(state:PhysicsDirectBodyState2D)->void:
	# Inputs are measurements from the preceding solver step, never time-driven target poses.
	fluid_acceleration=fluid_acceleration.lerp(_fluid_acceleration_target,1.0-exp(-state.step/0.1))
	fluid_current=fluid_current.lerp(_fluid_current_target,1.0-exp(-state.step/0.16))
	var displacement:=state.transform.origin-home
	# Relative fluid drag and the home spring reach a quiet 2.2–5px equilibrium
	# for a 4–9px/s stream. Only real pressure/current changes move that equilibrium.
	var fluid_drag:Vector2=(fluid_current-state.linear_velocity)*2.2
	state.apply_central_force((fluid_drag+fluid_acceleration-displacement*4.0)*mass)
	# Restore physical spin from touches to the authored angle; no periodic tilt forcing.
	var inertia_value:=1.0/maxf(state.inverse_inertia,0.0000001)
	state.apply_torque(-state.transform.get_rotation()*inertia_value*5.0)
	var velocity:=state.linear_velocity.limit_length(9.0)
	# Saturate outward velocity, not position, so rapid input cannot launch a decoration.
	if displacement.length()>=8.0:
		var outward:=displacement.normalized()
		velocity-=outward*maxf(0.0,velocity.dot(outward))
	state.linear_velocity=velocity
	var angle:=state.transform.get_rotation()
	var spin:=clampf(state.angular_velocity,-0.035,0.035)
	if absf(angle)>=0.0349 and spin*angle>0.0:spin=0.0
	state.angular_velocity=spin
