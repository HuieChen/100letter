extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _fresh()->Node2D:
	if is_instance_valid(game):game.queue_free();await process_frame;await process_frame
	game=Host.new();game.allow_display_changes=false;game.preferences_path="user://qa/coastal-physics/"+str(Time.get_ticks_usec())+".json";root.add_child(game);game.size=Vector2(1600,900);game._settings_page();await physics_frame;await process_frame
	return game.modal.surface
func _step(seconds:float)->void:
	var until:=Time.get_ticks_msec()+int(seconds*1000.0)
	while Time.get_ticks_msec()<until:await physics_frame
func _run()->void:
	root.unfocusable=true;root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900)
	var world:Node2D=await _fresh()
	_check(world.bodies.size()==2,"two actual native rigid bodies")
	_check(world.get_viewport().world_2d!=root.world_2d,"settings physics isolated from gameplay space")
	for body:RigidBody2D in world.bodies:
		_check(body.get_children().any(func(child:Node):return child is CollisionShape2D and child.shape is CircleShape2D),"real circle collision geometry")
		_check(body.gravity_scale==0 and body.linear_damp>0,"surface plane has water drag instead of falling")
	var start:Vector2=world.bodies[1].position
	world.water_touch(start-Vector2(256,0));await _step(0.35)
	_check(world.bodies[1].position.distance_to(start)<0.1,"no instantaneous shove before the wave arrives")
	await _step(1.2)
	_check(world.bodies[1].position.x>start.x+1,"arriving near wave pushes the slice away")
	_check(absf(world.bodies[1].rotation)<0.12,"turn is small and damped, not a constant wobble")
	await _step(2.4)
	_check(world.bodies[1].linear_velocity.length()<0.2,"water drag settles motion without teleporting home")
	_check(world.bodies[1].position.x>start.x+1,"settled body retains its actual displaced position")
	world=await _fresh();start=world.bodies[1].position
	world.water_touch(Vector2(1900,50));await _step(1.8)
	_check(world.bodies[1].position.distance_to(start)<0.1,"distant water does not falsely shove the slice")
	world=await _fresh();var big_start:Vector2=world.bodies[0].position;var small_start:Vector2=world.bodies[1].position
	world.water_touch(big_start+Vector2(182,0));world.water_touch(small_start+Vector2(112,0));await _step(0.7)
	var big_move:float=world.bodies[0].position.distance_to(big_start);var small_move:float=world.bodies[1].position.distance_to(small_start)
	_check(big_move>0.5 and small_move>big_move*1.6,"equal near impacts move the lighter slice farther")
	_check(world.bodies[0].position.x<big_start.x and world.bodies[1].position.x<small_start.x,"opposite-side touches reverse push direction")
	world=await _fresh();start=world.bodies[1].position
	for i:int in 100:world.water_touch(start-Vector2(100,20))
	_check(world.waves.size()==16,"rapid taps retain a bounded physical wave queue")
	await _step(0.6)
	_check(world.bodies[1].linear_velocity.length()<=55.01,"rapid taps cannot launch fruit across the screen")
	_check(world.bodies[1].position.distance_to(start)<35,"burst displacement stays small")
	var before:Dictionary=world.snapshot();game.modal._build();await physics_frame
	_check(game.modal.surface.bodies[1].position.distance_to(before.bodies[1].position)<1.5,"UI language rebuild preserves the moving physical object")
	world=await _fresh();world.bodies[0].position=Vector2(1300,685);world.bodies[1].position=Vector2(1558,685);world.bodies[1].linear_velocity=Vector2(-40,0)
	await _step(0.65)
	_check(world.contacts>0,"native solver reports actual lemon collision contacts")
	_check(world.bodies[0].position.distance_to(world.bodies[1].position)>=250,"circle collision prevents fruit overlap")
	world=await _fresh();world.bodies[1].position=Vector2(1717,685);world.bodies[1].linear_velocity=Vector2(55,0)
	await _step(0.8)
	_check(world.bodies[1].position.x<1730,"native boundary collision contains the body")
	game.queue_free();await process_frame;await process_frame
	print("COASTAL PHYSICS: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
