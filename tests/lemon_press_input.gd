extends SceneTree
## Native rigid-body press/release plus fixed-step buoyancy, with real source sprites.
const Surface=preload("res://scripts/ui/coastal_physics.gd")
var world:Node2D
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _fresh()->void:
	if is_instance_valid(world):world.queue_free();await process_frame;await process_frame
	world=Surface.new();root.add_child(world);await physics_frame;await process_frame
func _step(frames:int,index:int=1)->Dictionary:
	var min_depth:=100.0;var max_depth:= -100.0;var max_spin:=0.0
	for _i:int in frames:
		await physics_frame;await process_frame
		var press:Dictionary=world.snapshot().bodies[index].press
		min_depth=minf(min_depth,float(press.depth));max_depth=maxf(max_depth,float(press.depth))
		max_spin=maxf(max_spin,absf(world.bodies[index].angular_velocity))
	return {"min_depth":min_depth,"max_depth":max_depth,"max_spin":max_spin}
func _run()->void:
	root.unfocusable=true;await _fresh()
	var body:RigidBody2D=world.bodies[1]
	var plates:Array[Sprite2D]=[]
	for child:Node in body.get_children():
		if child is Sprite2D:plates.append(child)
	var source_texture:Texture2D=plates[0].texture;var source_material:Material=plates[0].material
	var source_scale:=plates[0].scale;var start:Vector2=body.position
	_check(world.press_lemon(1,start),"direct down begins the press state")
	_check(world.snapshot().active_presses==1,"held press is visible to input safety code")
	_check(not world.press_lemon(1,start),"repeat down cannot stack another pressure impulse")
	_check(world.snapshot().bodies[1].press.press_count==1,"repeat down preserves press generation")
	_check(not world.press_lemon(-1,start),"invalid negative target is safely rejected")
	_check(not world.release_lemon(99),"invalid release target is safely rejected")
	await _step(12)
	var held:Dictionary=world.snapshot().bodies[1].press
	_check(held.depth>3.0 and held.depth<=6.0,"held fruit sinks a small readable distance")
	_check(body.scale==Vector2.ONE,"visual press does not scale the native rigid body")
	var collision:CollisionShape2D=body.get_child(0)
	_check(collision.shape.radius==body.radius and collision.scale==Vector2.ONE,"native collision size stays unchanged")
	_check(plates[0].position.y>2.0,"source artwork actually moves into the water")
	_check(plates[0].scale.x/source_scale.x>=0.96 and plates[0].scale.x/source_scale.x<1.0,"apparent press scale is bounded below four percent")
	_check(plates[0].material==source_material,"clean matte material remains intact while pressing")
	_check(plates[0].texture==source_texture,"unchanged original source texture remains selected")
	_check(world.release_lemon(1),"mouse up releases the held fruit")
	_check(world.snapshot().active_presses==0,"release removes every held input flag")
	_check(not world.release_lemon(1),"duplicate up does not apply another recoil impulse")
	var rebound:Dictionary=await _step(32)
	var center_spin:float=rebound.max_spin
	_check(rebound.min_depth< -0.005 and rebound.min_depth>= -0.8,"release produces one small spring rebound")
	await _step(52)
	var settled:Dictionary=world.snapshot().bodies[1].press
	_check(absf(settled.depth)<0.01 and absf(settled.velocity)<0.06,"spring settles without a periodic wobble")
	_check(body.linear_velocity.length()<0.2,"native press momentum also settles under water drag")
	await _fresh();body=world.bodies[1]
	world.press_lemon(1,body.position+Vector2(body.radius*0.82,0));await _step(12)
	world.release_lemon(1);var right:Dictionary=await _step(4);var right_spin:float=body.angular_velocity
	_check(right.max_spin>center_spin*2.0+0.005,"edge press gives meaningfully more native torque than centre")
	await _fresh();body=world.bodies[1]
	world.press_lemon(1,body.position-Vector2(body.radius*0.82,0));await _step(12)
	world.release_lemon(1);await _step(4)
	_check(body.angular_velocity*right_spin<0.0,"opposite edges reverse the native turn direction")
	await _fresh()
	world.press_lemon(0,world.bodies[0].position);world.press_lemon(1,world.bodies[1].position)
	var both:Dictionary=world.snapshot()
	_check(both.bodies[1].press.target>both.bodies[0].press.target,"heavier slice has greater buoyant resistance")
	_check(both.active_presses==2,"both physical presses are tracked independently")
	world.release_all_presses()
	_check(world.snapshot().active_presses==0,"close or focus-loss cleanup releases all held input")
	world.press_lemon(1,world.bodies[1].position)
	world.tap_lemon(1,world.bodies[1].position)
	_check(world.snapshot().bodies[1].press.pressed,"legacy synthetic tap cannot consume a held press")
	await _step(12);var before:Dictionary=world.snapshot()
	await _fresh();world.restore_state(before)
	var restored:Dictionary=world.snapshot()
	_check(restored.active_presses==0,"UI rebuild safely releases the old pointer capture")
	_check(absf(restored.bodies[1].press.depth-before.bodies[1].press.depth)<0.001,"rebuild preserves physical spring displacement")
	_check(restored.bodies[1].position.distance_to(before.bodies[1].position)<0.001,"rebuild preserves actual rigid-body position")
	_check(restored.bodies[1].press.press_count==before.bodies[1].press.press_count,"rebuild does not invent another button press")
	await _fresh();body=world.bodies[1]
	for _i:int in 100:world.tap_lemon(1,body.position+Vector2(body.radius*0.8,0))
	var burst:Dictionary=await _step(18);var press:Dictionary=world.snapshot().bodies[1].press
	_check(burst.max_depth<=6.0 and burst.min_depth>= -0.8,"rapid taps preserve bounded submergence and rebound")
	_check(press.scale_factor>=0.96 and press.scale_factor<=1.0,"rapid taps cannot distort the painted fruit")
	_check(body.linear_velocity.length()<=55.01,"rapid pressure cannot launch fruit across the UI")
	_check(absf(body.angular_velocity)<=0.1301,"rapid edge presses retain native angular safety bound")
	world.queue_free();await process_frame;await process_frame
	print("LEMON PRESS INPUT: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
