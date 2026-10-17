extends RigidBody2D
## Native GodotPhysics2D rigid body; forces do not overwrite the transform each frame.
var radius:=94.0
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
func register_visual(sprite:Sprite2D)->void:
	_visuals.append({"sprite":sprite,"position":sprite.position,"scale":sprite.scale})
func begin_press(point:Vector2)->bool:
	if press_held:return false
	press_held=true;press_seconds=0.0;press_count+=1
	press_arm=(point-position).rotated(-rotation).limit_length(radius)
	press_edge=clampf(press_arm.length()/radius,0.0,1.0)
	# The broad/heavier slice has greater buoyant resistance; an edge press sinks
	# the small slice slightly farther and applies an actual off-centre impulse.
	press_target=(4.2+1.3*press_edge)*clampf(sqrt(1.25/mass),0.85,1.0)
	press_velocity=minf(press_velocity+24.0,46.0)
	sleeping=false
	apply_impulse(Vector2(0.0,2.0+3.0*press_edge),press_arm.rotated(rotation)*0.55)
	return true
func end_press()->bool:
	if not press_held:return false
	press_held=false;release_count+=1;press_target=0.0;sleeping=false
	var arm:=press_arm.rotated(rotation)
	var compression:=clampf(press_depth/5.5,0.0,1.0)
	var impulse:=Vector2(0.0,-(2.5+4.0*compression))
	if arm.length()>0.5:impulse-=arm.normalized()*press_edge*2.0
	apply_impulse(impulse,arm*0.65)
	return true
func press_snapshot()->Dictionary:
	return {"pressed":press_held,"depth":press_depth,"velocity":press_velocity,"target":press_target,
		"edge_ratio":press_edge,"held_seconds":press_seconds,"arm":press_arm,"point":position+press_arm.rotated(rotation),
		"scale_factor":1.0-clampf(press_depth,0.0,6.0)*0.006,"press_count":press_count,"release_count":release_count}
func restore_press_state(saved:Dictionary)->void:
	# A rebuilt UI cannot retain the old widget's pointer capture. Preserve the
	# physical displacement and spring velocity, then release safely without
	# synthesizing another native impulse or another button-down event.
	press_held=false;press_target=0.0
	press_depth=clampf(float(saved.get("depth",0.0)),-0.8,6.0)
	press_velocity=clampf(float(saved.get("velocity",0.0)),-65.0,65.0)
	press_edge=clampf(float(saved.get("edge_ratio",0.0)),0.0,1.0)
	press_seconds=float(saved.get("held_seconds",0.0));press_arm=saved.get("arm",Vector2.ZERO)
	press_count=int(saved.get("press_count",0));release_count=int(saved.get("release_count",0))
	_apply_visual_depth()
func _physics_process(delta:float)->void:
	if press_held:press_seconds+=delta
	# A damped buoyancy spring runs on the fixed physics clock. It is driven
	# only by actual press/release forces, with no periodic wobble or tween.
	var step:=minf(delta,0.05)
	press_velocity+=((press_target-press_depth)*180.0-press_velocity*18.5)*step
	press_depth+=press_velocity*step
	if press_depth>6.0:press_depth=6.0;press_velocity=minf(press_velocity,0.0)
	elif press_depth< -0.8:press_depth= -0.8;press_velocity=maxf(press_velocity,0.0)
	if not press_held and absf(press_depth)<0.001 and absf(press_velocity)<0.01:
		press_depth=0.0;press_velocity=0.0
	_apply_visual_depth()
func _apply_visual_depth()->void:
	var sink:=Vector2(0.0,press_depth).rotated(-rotation)
	var factor:=1.0-clampf(press_depth,0.0,6.0)*0.006
	for plate:Dictionary in _visuals:
		var sprite:Sprite2D=plate.sprite
		sprite.position=plate.position+sink
		sprite.scale=plate.scale*factor
func _integrate_forces(state:PhysicsDirectBodyState2D)->void:
	# Prevent accumulated rapid taps from making a floating slice fly across the UI.
	state.linear_velocity=state.linear_velocity.limit_length(55.0)
	state.angular_velocity=clampf(state.angular_velocity,-0.13,0.13)
