extends Node2D
## Native floating slices driven by measured water accelerations and currents.
const Lemon=preload("res://scripts/ui/settings_float.gd")
const Art=preload("res://scripts/rebuild/physical_art.gd")
const LemonMatte=preload("res://scripts/ui/lemon_white_matte.gdshader")
signal contact_audio(point:Vector2,strength:float)
signal lemon_press_changed(index:int,held:bool,point:Vector2,depth:float)
var bodies:Array[RigidBody2D]=[]
var waves:Array[Dictionary]=[]
var elapsed:=0.0
var contacts:=0

func _ready()->void:
	for spec:Dictionary in [{"center":Vector2(145,65),"radius":162.0,"mass":3.3},{"center":Vector2(1406,685),"radius":92.0,"mass":1.25}]:
		var body:=Lemon.new();body.radius=spec.radius;body.position=spec.center;body.home=spec.center;body.mass=spec.mass;body.gravity_scale=0.0
		body.can_sleep=false
		body.linear_damp_mode=RigidBody2D.DAMP_MODE_REPLACE;body.linear_damp=2.8
		body.angular_damp_mode=RigidBody2D.DAMP_MODE_REPLACE;body.angular_damp=4.0
		body.center_of_mass_mode=RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM;body.center_of_mass=Vector2(3,-2)
		body.continuous_cd=RigidBody2D.CCD_MODE_CAST_SHAPE;body.contact_monitor=true;body.max_contacts_reported=4
		var material:=PhysicsMaterial.new();material.bounce=0.08;material.friction=0.1;body.physics_material_override=material
		var collision:=CollisionShape2D.new();var shape:=CircleShape2D.new();shape.radius=body.radius;collision.shape=shape;body.add_child(collision)
		# Preserve the exact original crop, scale, plate order, offsets and matte pigment samples.
		for key:String in ["settings_lemon_rind","settings_lemon_flesh","settings_lemon_segments"]:
			var sprite:=Sprite2D.new();sprite.texture=Art.texture(key);sprite.region_enabled=true;sprite.region_rect=Rect2(1568,704,240,240)
			sprite.scale=Vector2.ONE*(body.radius/110.0);sprite.offset=Vector2(-1,-2)
			var shader:=ShaderMaterial.new();shader.shader=LemonMatte
			var pigment_pixel:=Vector2(1710.5,784.5) if key=="settings_lemon_segments" else Vector2(1686.5,822.5)
			shader.set_shader_parameter("pigment_uv",pigment_pixel/Vector2(sprite.texture.get_size()))
			sprite.material=shader;body.add_child(sprite);body.register_visual(sprite)
		body.body_entered.connect(func(_other:Node):contacts+=1)
		add_child(body);bodies.append(body)

func set_water_forces(accelerations:Array[Vector2])->void:
	# Entries are accelerations in world px/s²; each body multiplies by its native mass.
	for i:int in bodies.size():
		bodies[i].call("set_water_acceleration",accelerations[i] if i<accelerations.size() else Vector2.ZERO)

func set_water_currents(velocities:Array[Vector2])->void:
	# Entries are local water velocities in world px/s, sampled outside each slice.
	for i:int in bodies.size():
		bodies[i].call("set_water_current",velocities[i] if i<velocities.size() else Vector2.ZERO)

func water_touch(point:Vector2,strength:float=1.0)->void:
	# Retain interaction metadata. Actual wave travel and pressure belong to the field solver.
	waves.append({"point":point,"age":0.0,"strength":clampf(strength,0.1,1.0),"hits":0})
	if waves.size()>12:waves.pop_front()

func hit_lemon(point:Vector2)->int:
	for i:int in bodies.size():
		var body:=bodies[i]
		if point.distance_to(body.position+Vector2(0,float(body.get("press_depth"))))<=body.radius:return i
	return -1

func water_swipe(_from:Vector2,_to:Vector2,_speed:float,_dragging:bool=false)->void:
	# The host inserts the stroke into the fluid. Do not apply a second shortcut impulse here.
	pass

func press_lemon(index:int,point:Vector2)->bool:
	if index<0 or index>=bodies.size():return false
	var body:=bodies[index]
	if not bool(body.call("begin_press",point)):return false
	lemon_press_changed.emit(index,true,point,float(body.get("press_depth")))
	contact_audio.emit(point,0.18)
	return true

func release_lemon(index:int)->bool:
	if index<0 or index>=bodies.size():return false
	var body:=bodies[index];var before:Dictionary=body.call("press_snapshot")
	if not bool(body.call("end_press")):return false
	lemon_press_changed.emit(index,false,before.point,float(before.depth))
	contact_audio.emit(before.point,0.12)
	return true

func release_all_presses()->void:
	for i:int in bodies.size():release_lemon(i)

func tap_lemon(index:int,point:Vector2)->void:
	if press_lemon(index,point):release_lemon(index)

func _physics_process(delta:float)->void:
	elapsed+=delta
	for wave:Dictionary in waves:
		wave.age+=delta
	while not waves.is_empty() and waves[0].age>1.7:waves.pop_front()

func restore_state(saved:Dictionary)->void:
	for i:int in mini(bodies.size(),saved.get("bodies",[]).size()):
		var data:Dictionary=saved.bodies[i];var body:=bodies[i]
		var home:Vector2=body.get("home")
		var saved_position:Vector2=data.get("position",home)
		body.position=home+(saved_position-home).limit_length(8.0)
		body.rotation=clampf(float(data.get("rotation",0.0)),-0.0349,0.0349)
		var velocity:Vector2=data.get("velocity",Vector2.ZERO)
		body.linear_velocity=velocity.limit_length(9.0);body.angular_velocity=clampf(float(data.get("spin",0.0)),-0.035,0.035)
		body.call("restore_water_state",data)
		body.call("restore_press_state",data.get("press",{}))
	waves.clear()
	elapsed=float(saved.get("time",0.0));contacts=int(saved.get("contacts",0))

func snapshot()->Dictionary:
	var state:Array=[]
	var active_presses:=0
	for body:RigidBody2D in bodies:
		var press:Dictionary=body.call("press_snapshot")
		if press.pressed:active_presses+=1
		state.append({"position":body.position,"velocity":body.linear_velocity,"rotation":body.rotation,"spin":body.angular_velocity,"mass":body.mass,"radius":body.radius,"press":press,"home":body.get("home"),"fluid_acceleration":body.get("fluid_acceleration"),"fluid_current":body.get("fluid_current")})
	return {"engine":"GodotPhysics2D","motion":"water_coupled_pool_20261105","bodies":state,"contacts":contacts,"waves":waves.size(),"wave_state":waves.duplicate(true),"time":elapsed,"active_presses":active_presses}
