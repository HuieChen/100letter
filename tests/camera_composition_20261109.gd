extends SceneTree
var game:Control
var view:SubViewport
var checks:=0
var failures:Array[String]=[]
var out:=""
func _initialize()->void:
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
	create_timer(65).timeout.connect(func():push_error("Camera composition timed out");quit(1))
	run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func key(code:Key,held:bool)->void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=held;view.push_input(e,true);await process_frame
func mouse(at:Vector2,held:bool,button:MouseButton=MOUSE_BUTTON_LEFT)->void:
	var e:=InputEventMouseButton.new();e.position=at;e.button_index=button;e.pressed=held;view.push_input(e,true);await process_frame
func move(at:Vector2,delta:Vector2)->void:
	var e:=InputEventMouseMotion.new();e.position=at;e.relative=delta;view.push_input(e,true);await process_frame
func frame(label:String)->void:
	await RenderingServer.frame_post_draw;view.get_texture().get_image().save_png(out+label+".png")
func run()->void:
	DirAccess.make_dir_recursive_absolute(out);root.unfocusable=true
	view=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scripts/rebuild/final_playable.gd").new();game.allow_display_changes=false;view.add_child(game);game.size=Vector2(1600,900)
	await create_timer(.4).timeout
	game.core.new_game();game.core.state.location="post_office";game._world("bookstore");await create_timer(.5).timeout
	var world:Control=game._street_road.world
	var original:=world.position
	var player:Vector2=game.walker.foot
	game._camera();await create_timer(.3).timeout
	var camera:Control=game.modal
	await frame("camera_before")
	await move(Vector2(600,400),Vector2.ZERO);await mouse(Vector2(600,400),true)
	await move(Vector2(760,400),Vector2(160,0));await mouse(Vector2(760,400),false)
	check(world.position.x>original.x+140,"drag pans painted scene")
	check(game.walker.foot==player,"drag does not walk player")
	var after_drag:=world.position
	await key(KEY_RIGHT,true);await create_timer(.25).timeout;await key(KEY_RIGHT,false)
	check(world.position.x<after_drag.x-45,"held arrow pans continuously")
	var released:=world.position;await create_timer(.15).timeout
	check(world.position.is_equal_approx(released),"release stops camera without drift")
	await mouse(Vector2(700,400),true,MOUSE_BUTTON_WHEEL_UP)
	check(world.scale.x>1.0,"wheel zooms around frame center")
	var zoomed:=world.position
	await key(KEY_DOWN,true);await create_timer(.15).timeout;await key(KEY_DOWN,false)
	check(world.position.y<zoomed.y,"vertical framing works after zoom")
	camera._toggle_format();check(camera.instant_format,"instant format remains switchable")
	camera._toggle_format()
	await frame("camera_after_pan")
	var composed:=world.position
	await key(KEY_C,true);await key(KEY_C,false)
	await create_timer(3.2).timeout
	check(not camera.last_photo_path.is_empty() and FileAccess.file_exists(camera.last_photo_path),"real C shutter saves panned photo")
	check(world.position.is_equal_approx(composed),"exposure and print preserve composed view")
	var photo:=Image.load_from_file(camera.last_photo_path)
	check(photo!=null and photo.get_width()==1600 and photo.get_height()==900,"landscape capture retains full viewport")
	photo.save_png(out+"captured_pan.png")
	await key(KEY_LEFT,true);await create_timer(.15).timeout;await key(KEY_LEFT,false)
	check(world.position.is_equal_approx(composed),"review navigation cannot move world")
	camera.request_close();await process_frame
	await key(KEY_RIGHT,true);camera.get_window().focus_exited.emit();await create_timer(.12).timeout
	check(camera._held_pan.is_empty(),"focus loss clears held movement")
	await key(KEY_RIGHT,false)
	game._photo_composition.pan(Vector2(100000,100000))
	check(world.position==Vector2.ZERO,"top-left bound prevents empty scene")
	game._photo_composition.pan(Vector2(-100000,-100000))
	check((world.position+world.size*world.scale).is_equal_approx(Vector2(1600,900)),"bottom-right bound prevents empty scene")
	camera.reset_provider.call();check(world.position==original and world.scale==Vector2.ONE,"reset restores opening composition")
	camera.zoom_provider.call(.3);camera.request_close();await process_frame
	check(world.position.is_equal_approx(original) and world.scale==Vector2.ONE,"close restores walking camera")
	check(not game._street_road.photo_composition_active and game.walker.manual_enabled,"walking restored after camera closes")
	game._post_office_room();await create_timer(.25).timeout;game._camera();await process_frame
	check(game._photo_composition.target==game.stage,"indoor scene also supports framing")
	game.modal.zoom_provider.call(.2);check(game.stage.scale.x>1,"indoor zoom works")
	game._close();check(game.stage.position==Vector2.ZERO and game.stage.scale==Vector2.ONE,"indoor camera restores UI stage")
	game.queue_free();await process_frame;await process_frame;view.queue_free();await process_frame;await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("CAMERA_COMPOSITION ",checks," / ",failures.size());quit(0 if failures.is_empty() else 1)
