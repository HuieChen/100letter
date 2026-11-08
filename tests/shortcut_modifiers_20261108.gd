extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var checks:=0
var failures:Array[String]=[]
func _initialize():
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr(label)
func key(code:Key,modifier:String=""):
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
		event.ctrl_pressed=modifier=="ctrl";event.alt_pressed=modifier=="alt";event.meta_pressed=modifier=="meta";event.shift_pressed=modifier=="shift"
		Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
func settle(seconds:float=.1):await create_timer(seconds).timeout
func run():
	root.unfocusable=true;root.size=Vector2i(1600,900);Engine.max_fps=60
	game=Host.new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
	game.core.new_game();game._post_office_room();await settle()
	for language:String in ["zh","en"]:
		game.preferences.values.language=language
		for modifier:String in ["ctrl","alt","meta"]:
			for code:Key in [KEY_M,KEY_J,KEY_B,KEY_C,KEY_ESCAPE,KEY_F11]:
				root.gui_release_focus();var mode:String=game.preferences.values.display_mode
				await key(code,modifier)
				check(not is_instance_valid(game.modal),language+" "+modifier+" shortcut does not open a game panel "+str(code))
				check(game.preferences.values.display_mode==mode,language+" modified F11 never changes display preferences "+str(code))
		await key(KEY_C);await settle();var camera:Control=game.modal
		check(camera!=null and camera.get_script()==preload("res://scripts/ui/field_camera.gd"),language+" plain C still opens camera")
		for modifier:String in ["ctrl","alt","meta"]:
			root.gui_release_focus();var count:int=camera.gallery_paths.size();var instant:bool=camera.instant_format
			await key(KEY_C,modifier)
			check(not camera.capture_busy and camera.gallery_paths.size()==count,language+" "+modifier+" C cannot accidentally capture")
			await key(KEY_R,modifier)
			check(camera.instant_format==instant,language+" "+modifier+" R cannot change paper format")
			await key(KEY_ESCAPE,modifier)
			check(game.modal==camera and not camera._closing,language+" modified Escape does not dismiss camera")
		await key(KEY_R);check(camera.instant_format,language+" plain R still switches format")
		await key(KEY_ESCAPE);check(not is_instance_valid(game.modal),language+" plain Escape still closes camera")
		root.gui_release_focus();await key(KEY_B,"shift")
		check(is_instance_valid(game.modal),language+" Shift still permits game shortcuts")
		game._close();game.core.state.location="post_office";game._world();await settle()
		game.walker.foot=Vector2(game._street_road.world.size.x*.376,game.walker.foot.y);await settle()
		for modifier:String in ["ctrl","alt","meta"]:
			root.gui_release_focus();await key(KEY_E,modifier);await settle(.2)
			check(game.view=="world" and not game._street_road._entering,language+" "+modifier+" E does not enter a door")
		await key(KEY_E);await settle(1.2)
		check(game.view=="post_office_room",language+" plain E still completes door entry")
	game.sound.shutdown();await settle(.5);game.queue_free();await process_frame
	print("SHORTCUT_MODIFIERS ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
