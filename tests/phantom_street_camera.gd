extends SceneTree
const Director=preload("res://scripts/rebuild/street_camera_director.gd")
const Road=preload("res://scripts/rebuild/coastal_road.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr(label)
func run():
	root.unfocusable=true
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var driver=Director.new();root.add_child(driver)
	driver.frame_foot(2000,10000)
	check(driver.phantom.get_script().resource_path.begins_with("res://addons/phantom_camera/"),"upstream PhantomCamera2D is the active solver")
	check(is_equal_approx(driver.scroll,1350),"first arrival aligns synchronously")
	var last:float=driver.scroll
	for frame:int in 120:
		driver.frame_foot(2000+(frame+1)*200.0/60,10000)
		var now:float=driver.advance(1.0/60)
		check(now>=last and now<=driver.target.position.x,"forward tracking remains monotone and does not overshoot "+str(frame))
		last=now
	check(driver.target.position.x-driver.scroll>5 and driver.target.position.x-driver.scroll<45,"cinematic tracking has bounded gentle lag")
	var frozen:float=driver.scroll
	for frame:int in 30:driver.advance(1.0/60,false)
	check(driver.scroll==frozen,"photo and modal framing freezes without residual drift")
	for frame:int in 90:driver.advance(1.0/60)
	check(absf(driver.scroll-driver.target.position.x)<.02,"stop settles accurately onto authored framing")
	driver.frame_foot(9900,10000)
	check(driver.scroll==8400,"teleport clamps to right panorama edge immediately")
	driver.frame_foot(100,10000)
	check(driver.scroll==0,"teleport clamps to left panorama edge immediately")
	driver.queue_free();await process_frame
	# Integration: original canvas and pointer coordinate conversion stay together.
	var road=Road.new();road.district="community";root.add_child(road);road.size=Vector2(1600,900)
	road.courier.set_process(false);road.set_process(false)
	road.courier.foot=Vector2(4000,872)
	check(absf(road.world.position.x+road.courier.foot.x-650)<.01,"road arrival frames exact courier landmark")
	check(road.world.scale==Vector2.ONE and road.art.scale==Vector2.ONE,"art scale and painted hit geometry remain intact")
	road.courier.foot.x+=10;road._process(1.0/60)
	check(road.camera_director.scroll>3350 and road.camera_director.scroll<3360,"real road uses damped Phantom result")
	var offset:float=road.world.position.x
	road.can_walk=func():return false
	for frame:int in 30:road._process(1.0/60)
	check(road.world.position.x==offset,"real road honors modal freeze")
	var out:="user://qa/phantom_street_camera/"+str(Time.get_ticks_usec())+"/"
	DirAccess.make_dir_recursive_absolute(out)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"arrival.png")
	road.can_walk=Callable()
	for frame:int in 120:
		road.courier._advance_manual(Vector2.RIGHT,1.0/60)
		road._process(1.0/60)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"tracking.png")
	check(road.camera_director.scroll>3350,"rendered walking advances panorama")
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"camera":road.camera_director.snapshot()},"  "))
	road.queue_free();await process_frame
	print("PHANTOM_STREET_CAMERA ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
