extends SceneTree
const Walker=preload("res://scripts/rebuild/final_walker.gd")
var checks:=0
var failures:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run()->void:
	DirAccess.make_dir_recursive_absolute("res://test-results/courier_inbetweens_20261101")
	var viewport:=SubViewport.new();viewport.size=Vector2i(520,760);viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var w=Walker.new();viewport.add_child(w);w.set_process(false)
	w.actor_height=704;w.foot=Vector2(210,740);w._turn_position=0
	var images:Array[Image]=[]
	for state in [0,1,2]:
		w._eye_state=state;w._walk_time=.125;w.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image();images.append(image)
		image.save_png("res://test-results/courier_inbetweens_20261101/blink_%d.png"%state)
	for index in [1,2]:
		var changed:=0;var outside:=0
		for y in range(760):
			for x in range(520):
				if images[0].get_pixel(x,y)!=images[index].get_pixel(x,y):
					changed+=1
					if not Rect2i(245,185,115,115).has_point(Vector2i(x,y)):outside+=1
		check(changed>200,"Eye state %d visibly changes"%index)
		check(outside==0,"Blink changes only the bounded eye painting")
		check(images[0].get_pixel(300,400)==images[index].get_pixel(300,400),"Body pixels remain unchanged")
	viewport.queue_free();await process_frame
	print("COURIER_BLINK_RENDER %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
