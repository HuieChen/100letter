extends Node2D
## Isolated native World2D. Fixed-step impulses, mass, inertia, drag, contacts and bounds.
const Lemon=preload("res://scripts/ui/floating_lemon.gd")
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
		var body:=Lemon.new();body.radius=spec.radius;body.position=spec.center;body.mass=spec.mass;body.gravity_scale=0.0
		body.linear_damp_mode=RigidBody2D.DAMP_MODE_REPLACE;body.linear_damp=2.6
		body.angular_damp_mode=RigidBody2D.DAMP_MODE_REPLACE;body.angular_damp=3.2
		body.center_of_mass_mode=RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM;body.center_of_mass=Vector2(3,-2)
		body.continuous_cd=RigidBody2D.CCD_MODE_CAST_SHAPE;body.contact_monitor=true;body.max_contacts_reported=4
		var material:=PhysicsMaterial.new();material.bounce=0.12;material.friction=0.1;body.physics_material_override=material
		var collision:=CollisionShape2D.new();var shape:=CircleShape2D.new();shape.radius=body.radius;collision.shape=shape;body.add_child(collision)
		# Full small slice has all original paper-paint components; nothing cut off during drift.
		for key:String in ["settings_lemon_rind","settings_lemon_flesh","settings_lemon_segments"]:
			var sprite:=Sprite2D.new();sprite.texture=Art.texture(key);sprite.region_enabled=true;sprite.region_rect=Rect2(1568,704,240,240)
			sprite.scale=Vector2.ONE*(body.radius/110.0);sprite.offset=Vector2(-1,-2)
			var shader:=ShaderMaterial.new();shader.shader=LemonMatte
			# Opaque texels of the unchanged PDF pigment plates; not generated paint.
			var pigment_pixel:=Vector2(1710.5,784.5) if key=="settings_lemon_segments" else Vector2(1686.5,822.5)
			shader.set_shader_parameter("pigment_uv",pigment_pixel/Vector2(sprite.texture.get_size()))
			sprite.material=shader;body.add_child(sprite);body.register_visual(sprite)
		body.body_entered.connect(func(_other:Node):contacts+=1)
		add_child(body);bodies.append(body)
	# Overscan bounds preserve the supplied clipped top-left composition, without teleport reset.
	for rect:Rect2 in [Rect2(-210,-205,2030,20),Rect2(-210,1090,2030,20),Rect2(-230,-205,20,1315),Rect2(1820,-205,20,1315)]:
		var wall:=StaticBody2D.new();wall.position=rect.get_center();var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=rect.size;collision.shape=shape;wall.add_child(collision);add_child(wall)
func water_touch(point:Vector2,strength:float=1.0)->void:
	waves.append({"point":point,"age":0.0,"strength":clampf(strength,0.1,1.0),"hits":0})
	if waves.size()>16:waves.pop_front()
func hit_lemon(point:Vector2)->int:
	for i:int in bodies.size():
		if point.distance_to(bodies[i].position)<=bodies[i].radius:return i
	return -1
func water_swipe(from:Vector2,to:Vector2,speed:float,dragging:bool=false)->void:
	var travel:=minf(from.distance_to(to),180.0)
	if travel<=0.0001:return
	var direction:Vector2=(to-from).normalized()
	for body:RigidBody2D in bodies:
		var edge:float=maxf(0.0,body.position.distance_to(to)-body.radius)
		if edge>120.0:continue
		var strength:float=clampf(speed/1100.0,0.0,1.0)*pow(1.0-edge/120.0,2.0)
		body.sleeping=false
		body.apply_impulse(direction*strength*(travel/12.0)*(1.2 if dragging else 0.7),(to-body.position).limit_length(body.radius))
func press_lemon(index:int,point:Vector2)->bool:
	if index<0 or index>=bodies.size():return false
	var body:=bodies[index]
	if not bool(body.call("begin_press",point)):return false
	lemon_press_changed.emit(index,true,point,float(body.get("press_depth")))
	contact_audio.emit(point,0.25)
	return true
func release_lemon(index:int)->bool:
	if index<0 or index>=bodies.size():return false
	var body:=bodies[index];var before:Dictionary=body.call("press_snapshot")
	if not bool(body.call("end_press")):return false
	lemon_press_changed.emit(index,false,before.point,float(before.depth))
	contact_audio.emit(before.point,0.18)
	return true
func release_all_presses()->void:
	for i:int in bodies.size():release_lemon(i)
func tap_lemon(index:int,point:Vector2)->void:
	# Backward-compatible synthetic tap, without consuming another held press.
	if press_lemon(index,point):release_lemon(index)
func _physics_process(delta:float)->void:
	elapsed+=delta
	for wave:Dictionary in waves:
		wave.age+=delta;var front:float=wave.age*164.0
		for i:int in bodies.size():
			if int(wave.hits)&(1<<i):continue
			var body:=bodies[i];var from:Vector2=body.position-wave.point
			var edge:=maxf(0.0,from.length()-body.radius)
			if edge>420.0 or front<edge:continue
			wave.hits=int(wave.hits)|(1<<i)
			var energy:float=wave.strength*pow(1.0-edge/420.0,2.0)
			var outward:=from.normalized();body.sleeping=false
			# Apply pressure at the near edge. Native mass/inertia and the slightly eccentric
			# center of mass determine translation and turn; no prescribed wobble animation.
			body.apply_impulse(outward*24.0*energy,-outward*body.radius*0.82)
			if energy>0.25:contact_audio.emit(body.position,energy*0.3)
	while not waves.is_empty() and waves[0].age>3.0:waves.pop_front()
func restore_state(saved:Dictionary)->void:
	for i:int in mini(bodies.size(),saved.get("bodies",[]).size()):
		var data:Dictionary=saved.bodies[i];bodies[i].position=data.position;bodies[i].rotation=data.rotation;bodies[i].linear_velocity=data.velocity;bodies[i].angular_velocity=data.spin
		bodies[i].call("restore_press_state",data.get("press",{}))
	waves=saved.get("wave_state",[]).duplicate(true);elapsed=saved.get("time",0.0);contacts=saved.get("contacts",0)
func snapshot()->Dictionary:
	var state:Array=[]
	var active_presses:=0
	for body:RigidBody2D in bodies:
		var press:Dictionary=body.call("press_snapshot")
		if press.pressed:active_presses+=1
		state.append({"position":body.position,"velocity":body.linear_velocity,"rotation":body.rotation,"spin":body.angular_velocity,"mass":body.mass,"radius":body.radius,"press":press})
	return {"engine":"GodotPhysics2D","bodies":state,"contacts":contacts,"waves":waves.size(),"wave_state":waves.duplicate(true),"time":elapsed,"active_presses":active_presses}
