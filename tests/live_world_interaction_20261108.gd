extends SceneTree
## Isolated GPU regression for live Settings language and shutter/back persistence.
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var checks:=0
var failures:Array[String]=[]
var out:=""
var started:=Time.get_datetime_string_from_system(true)
func _initialize()->void:
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):
		push_error("QA-only --final-save required");quit(1);return
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	if out.is_empty():push_error("--qa-out required");quit(1);return
	root.unfocusable=true;root.gui_embed_subwindows=true
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run()->void:
	DirAccess.make_dir_recursive_absolute(out)
	game=Host.new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
	game.preferences.set_value("language","zh");game.core.state.location="post_office";game._world()
	await process_frame
	var road:Control=game._street_road
	game.walker.foot=Vector2(road.world.size.x*.376,game.walker.foot.y)
	await process_frame
	var road_id:int=road.get_instance_id();var courier_id:int=game.walker.get_instance_id();var foot:Vector2=game.walker.foot
	for index:int in [1,0]:
		game._settings_page(false);await create_timer(.35).timeout
		await click_named("Setting_language")
		check(game.modal.find_child("SettingsDropdown",true,false)!=null,"real language dropdown opens")
		await click_named("Option_language_"+str(index));await process_frame
		await click_named("CloseSettings");await create_timer(.25).timeout
		check(not is_instance_valid(game.modal),"settings returns to world")
		var locale:="en" if index==1 else "zh"
		check(game.preferences.values.language==locale,"clicked option applies "+locale)
		check(road.entry_hint.caption==("E  Enter" if index==1 else "E  进入"),"existing entry hint immediately uses "+locale)
		check(game.stage.find_child("AuthoredQuickbar",true,false).buttons.map.caption==("Map" if index==1 else "地图"),"quickbar and entry use same "+locale)
		check(game._street_road.get_instance_id()==road_id and game.walker.get_instance_id()==courier_id and game.walker.foot.distance_to(foot)<.01,"language keeps current street and courier position")
		check(game.walker.manual_enabled,"movement resumes after language settings")
	game._camera();await process_frame
	var camera:Control=game.modal
	var saved:Array[String]=[]
	camera.photo_saved.connect(func(path:String):saved.append(path))
	camera.shutter.pressed.emit()
	check(camera.capture_busy and not camera.checkpoint_for_quit(),"accepted shutter remains pending before exposure")
	key(KEY_ESCAPE)
	check(is_instance_valid(game.modal),"Back waits for accepted exposure")
	await create_timer(.6).timeout
	check(not is_instance_valid(game.modal),"Back closes after raw save without print animation delay")
	check(saved.size()==1 and FileAccess.file_exists(saved[0]),"accepted shutter writes exactly one photo before Back")
	if saved.size()==1:
		var pixels:=Image.load_from_file(saved[0]);check(pixels!=null and pixels.get_size()==Vector2i(1280,720),"saved photograph has actual viewport pixels")
	check(game.walker.manual_enabled and game.stage.find_child("AuthoredQuickbar",true,false).visible,"Back restores world movement and HUD")
	# Failed exposure must release the same queued close, not trap the player.
	game._camera();await process_frame
	camera=game.modal;camera.capture_provider=func():return null
	camera.shutter.pressed.emit();key(KEY_ESCAPE)
	await create_timer(.2).timeout
	check(not is_instance_valid(game.modal),"failed exposure releases queued Back")
	game.sound.shutdown();await create_timer(.35).timeout
	game.queue_free();await process_frame;await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"started_utc":started,"completed_utc":Time.get_datetime_string_from_system(true),"method":"Actual Host, Settings pointer events, shutter signal and viewport Escape; offscreen GPU and isolated QA data. Not OS-input or human acceptance."},"  "))
	print("LIVE_WORLD_INTERACTION_COMPLETE ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func click_named(node_name:String)->void:
	var control:Control=game.find_child(node_name,true,false)
	check(is_instance_valid(control),"visible control "+node_name)
	if not is_instance_valid(control):return
	var point:=control.get_global_rect().get_center()
	for down:bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true);await process_frame
func key(code:Key)->void:
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;root.push_input(event,true)
