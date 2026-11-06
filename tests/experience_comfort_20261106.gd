extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Core=preload("res://scripts/rebuild/final_case_state.gd")
var game:Control
var view:SubViewport
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/experience_comfort/"
var observations:Dictionary={}
func _initialize():
	var isolated:=false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--final-save=user://qa/"):isolated=true
	if not isolated:
		push_error("Pass --final-save=user://qa/<unique-run>/state.json to protect player saves")
		quit(1);return
	run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func settle(seconds:float=.2)->void:await create_timer(seconds).timeout;await process_frame
func key(code:Key,unicode_value:int=0)->void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.unicode=unicode_value;e.pressed=true;view.push_input(e,true)
	e=e.duplicate();e.pressed=false;view.push_input(e,true)
	await process_frame
func click(control:Control)->void:
	var p:=control.get_global_rect().get_center()
	var m:=InputEventMouseMotion.new();m.position=p;m.global_position=p;view.push_input(m,true)
	for down:bool in [true,false]:
		var e:=InputEventMouseButton.new();e.position=p;e.global_position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;view.push_input(e,true)
	await process_frame
func capture(name:String)->void:
	await RenderingServer.frame_post_draw;view.get_texture().get_image().save_png(out+name+".png")
func run()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(out)
	root.unfocusable=true;Engine.max_fps=60
	view=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);view.notify_mouse_entered()
	game=Host.new();game.allow_display_changes=false
	game.preferences_path="user://qa/experience-flow/"+str(Time.get_ticks_usec())+"/preferences.json"
	view.add_child(game);game.size=Vector2(1600,900)
	game.preferences.set_value("language","zh")
	game.core.new_game();game.core.save_game();game._post_office_room()
	await settle()
	for locale:String in ["zh","en"]:
		game.preferences.set_value("language",locale)
		game._post_office_room();await settle()
		var minute:int=game.core.state.minute
		await key(KEY_M);await settle(.1)
		check(is_instance_valid(game.modal) and game.modal.name=="MapInspection",locale+" M opens map")
		check(game.modal.z_index>=100,locale+" map is above all world actor layers")
		await click(game.modal.find_child("Map_residential",true,false))
		check(game.busy,locale+" map choice locks duplicate input during scene change")
		check(game.has_node("SceneTransition"),locale+" map choice has a short visual transition")
		await key(KEY_B);await key(KEY_ESCAPE)
		check(not is_instance_valid(game.modal),locale+" fast Bag key cannot interrupt arrival")
		await settle(.75)
		check(not game.busy and game.view=="world",locale+" arrival fully restores world controls")
		check(game.core.state.location=="residential",locale+" map reaches chosen location")
		check(game.core.state.minute==minute,locale+" exploration preserves current no-time-charge behavior")
		var restored:=Core.new();restored.save_path=game.core.save_path;root.add_child(restored)
		check(restored.load_game() and restored.state.location=="residential",locale+" arrival immediately survives save/reload")
		restored.queue_free()
		if is_instance_valid(game.modal):game._close()
		var at:Vector2=game.walker.foot
		game.walker.walk_to(at+Vector2(400,0))
		await settle(.08)
		await key(KEY_C);await settle(.08)
		check(is_instance_valid(game.modal) and game.modal.get_script().resource_path.ends_with("field_camera.gd"),locale+" C opens camera")
		var camera_at:Vector2=game.walker.foot
		await settle(.35)
		check(game.walker.foot.distance_to(camera_at)<.05,locale+" camera cancels pending walk without hiding the courier")
		check(game.walker.visible,locale+" camera preserves the live character in the photographed scene")
		await key(KEY_ESCAPE);await settle()
		check(not is_instance_valid(game.modal),locale+" camera Escape returns to world")
		await key(KEY_B);await settle()
		check(game.modal.z_index>=100,locale+" bag is above foreground world layers")
		for i:int in 10:
			await key(KEY_TAB)
			var focused:=view.gui_get_focus_owner()
			check(focused!=null and game.modal.is_ancestor_of(focused),locale+" Tab stays inside Bag "+str(i))
		await key(KEY_ESCAPE);await settle()
		check(not is_instance_valid(game.modal),locale+" Bag Escape has no extra pause layer")
		await key(KEY_ESCAPE);await settle()
		check(is_instance_valid(game.modal),locale+" world Escape opens pause")
		await click(game.modal.find_child("SheetAction_1",true,false));await settle(.4)
		check(is_instance_valid(game.modal) and game.modal.has_node("SettingsWater"),locale+" pause opens settings")
		await key(KEY_ESCAPE);await settle(.3)
		check(is_instance_valid(game.modal) and game.modal.find_child("SheetAction_0",true,false)!=null,locale+" settings Escape returns to pause")
		await click(game.modal.find_child("SheetAction_0",true,false));await settle()
		check(not is_instance_valid(game.modal),locale+" pause Resume returns once to the same scene")
		await capture("world_"+locale)
	observations.final_location=game.core.state.location
	game.sound.shutdown();await settle(.5);game.queue_free();await process_frame;view.queue_free();await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"method":"Real viewport pointer and key events through production Host; isolated state, both locales. Does not claim human aesthetic acceptance."},"  "))
	print("EXPERIENCE_FLOW ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
