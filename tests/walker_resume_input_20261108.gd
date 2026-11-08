extends SceneTree
## GPU regression with routed engine key events and simulated focus notifications.
## Run with isolated APPDATA/LOCALAPPDATA and -- --final-save=user://qa/.../state.json.
## This is not desktop keyboard injection or a human Alt-Tab acceptance test.
const Walker = preload("res://scripts/rebuild/final_walker.gd")
const Host = preload("res://scripts/rebuild/final_playable.gd")
const DIRECTIONS = {KEY_W:Vector2.UP, KEY_A:Vector2.LEFT, KEY_S:Vector2.DOWN, KEY_D:Vector2.RIGHT,
	KEY_UP:Vector2.UP, KEY_LEFT:Vector2.LEFT, KEY_DOWN:Vector2.DOWN, KEY_RIGHT:Vector2.RIGHT}
var walker:Control
var game:Control
var checks:=0
var failures:Array[String]=[]
var callbacks:=0
var out:="user://qa/walker-resume-20261108/"
var source_hashes:Dictionary={}

func _initialize()->void:
	var isolated:=false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--final-save=user://qa/"):isolated=true
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	if not isolated:push_error("Isolated --final-save=user://qa/... is required");quit(1);return
	_run.call_deferred()

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func key(code:Key,down:bool,echo:bool=false)->void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;event.echo=echo
	Input.parse_input_event(event);Input.flush_buffered_events()

func tap(code:Key)->void:key(code,true);key(code,false)

func release_keys()->void:
	for code:Key in DIRECTIONS:key(code,false)
	key(KEY_SHIFT,false)

func advance(seconds:float=.25)->void:
	for index:int in ceili(seconds*120.0):walker._process(1.0/120.0)

func fresh()->void:
	release_keys();walker.manual_enabled=false
	walker.configure(null,Rect2(40,100,1900,600),Vector2(900,400))
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	walker.manual_enabled=true

func settle(seconds:float=.08)->void:
	await create_timer(seconds).timeout;await process_frame

func _run()->void:
	check(DisplayServer.get_name()!="headless","GPU backend is active")
	root.unfocusable=true;root.size=Vector2i(1600,900);Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(out)
	var files:Array[String]=["res://assets/authoring/cast_20261105/courier_idle.png","res://assets/faefever_v2/characters/courier_walk_regions.json"]
	for index:int in 5:
		files.append("res://assets/authoring/courier_20261030/clean_edges/walk_%d.png"%index)
	for path:String in files:source_hashes[path]=FileAccess.get_sha256(path)
	walker=Walker.new();root.add_child(walker)
	# Normal Window policy is needed for the focus-in branch. The native window
	# remains offscreen; only notifications and engine events are simulated.
	root.unfocusable=false
	_test_keys_and_resume()
	_test_click_and_shift()
	_test_focus_and_cycles()
	release_keys();walker.queue_free();await process_frame
	root.unfocusable=true
	await _test_host_modals()
	for path:String in source_hashes:
		check(not str(source_hashes[path]).is_empty() and FileAccess.get_sha256(path)==source_hashes[path],"original source stays unchanged: "+path.get_file())
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"source_hashes":source_hashes,"method":"Hidden GPU; routed synthetic engine keys, simulated native focus notifications; isolated save and preferences."},"  "))
	print("WALKER_RESUME_INPUT ",checks," checks / ",failures.size()," failures; receipt=",ProjectSettings.globalize_path(out+"receipt.json"))
	quit(0 if failures.is_empty() else 1)

func _test_keys_and_resume()->void:
	fresh();var start:Vector2=walker.foot
	key(KEY_D,true);advance()
	check(walker.foot.x>start.x+10 and walker.velocity.x>0,"fresh D moves with normal acceleration")
	key(KEY_D,false);advance(.4);start=walker.foot;advance(.2)
	check(walker.foot==start and walker.velocity==Vector2.ZERO,"released movement brakes and stays still")
	for code:Key in DIRECTIONS:
		fresh();walker.manual_enabled=false;key(code,true);advance(.1);start=walker.foot
		walker.manual_enabled=true;advance(.25)
		check(walker.foot==start and walker.velocity==Vector2.ZERO,"held modal key stays stopped after resume: "+OS.get_keycode_string(code))
		key(code,true,true);advance(.1)
		check(walker.foot==start,"repeat event does not unlock held key: "+OS.get_keycode_string(code))
		# Deliberately no frame between release and repress.
		key(code,false);key(code,true);advance(.2)
		check((walker.foot-start).dot(DIRECTIONS[code])>5,"same-frame release/repress restores direction: "+OS.get_keycode_string(code))
	fresh();walker.manual_enabled=false;key(KEY_A,true);key(KEY_S,true);walker.manual_enabled=true
	start=walker.foot;key(KEY_D,true);advance()
	check(walker.foot.x>start.x+10 and walker.foot.y==start.y,"fresh D works while held A and S remain individually blocked")
	key(KEY_D,false);walker.cancel();start=walker.foot;key(KEY_A,false);key(KEY_A,true);advance()
	check(walker.foot.x<start.x-10 and walker.foot.y==start.y,"releasing A unlocks only A, not the still-held S")
	fresh();walker.manual_enabled=false;key(KEY_D,true);walker.manual_enabled=true
	start=walker.foot;key(KEY_RIGHT,true);advance()
	check(walker.foot.x>start.x+10,"fresh arrow alias works even while physical D is blocked")
	# If another input handler consumes release, per-frame polling still recovers.
	fresh();walker.manual_enabled=false;key(KEY_D,true);walker.manual_enabled=true
	walker.set_process_input(false);key(KEY_D,false);advance(.02);key(KEY_D,true);start=walker.foot;advance()
	check(walker.foot.x>start.x+10,"polling observes a release even without the walker input callback")
	walker.set_process_input(true)

func _test_click_and_shift()->void:
	fresh();walker.manual_enabled=false;key(KEY_D,true);walker.manual_enabled=true
	var destination:Vector2=walker.foot+Vector2(-130,0)
	walker.walk_to(destination,func():callbacks+=1)
	advance(2.0)
	check(walker.foot==destination and callbacks==1 and not walker.walking,"blocked direction does not interrupt click arrival or its one callback")
	walker.walk_to(walker.foot+Vector2(-130,0),func():callbacks+=1)
	key(KEY_W,true);advance(.3)
	check(not walker.walking and walker._manual_active and callbacks==1,"fresh key still takes over click movement without its stale action")
	fresh();key(KEY_D,true);advance(.6);var normal_speed:float=walker.velocity.x
	key(KEY_SHIFT,true);advance(.4)
	check(walker.velocity.x>normal_speed*1.3,"Shift acceleration remains available during fresh movement")
	key(KEY_SHIFT,false);advance(.4)
	check(is_equal_approx(walker.velocity.x,normal_speed),"releasing Shift returns to normal walking speed")

func _test_focus_and_cycles()->void:
	fresh();key(KEY_D,true);advance(.2)
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var stopped:Vector2=walker.foot;advance(.2)
	check(walker.foot==stopped and walker.velocity==Vector2.ZERO,"focus-out cancels active keyboard movement")
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN);advance(.2)
	check(walker.foot==stopped,"focus return does not revive an old held D")
	key(KEY_W,true);advance(.2)
	check(walker.foot.y<stopped.y-5 and walker.foot.x==stopped.x,"fresh W moves while the focus-return D remains blocked")
	key(KEY_W,false);key(KEY_D,false);advance(.3);stopped=walker.foot
	key(KEY_D,true);advance(.2)
	check(walker.foot.x>stopped.x+5,"released D is reusable after focus return")
	fresh();walker.walk_to(walker.foot+Vector2(200,0),func():callbacks+=1);advance(.1)
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT);stopped=walker.foot
	walker._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN);advance(2.0)
	check(walker.foot==stopped and callbacks==1,"focus restoration does not resurrect a cancelled click callback")
	for cycle:int in 6:
		fresh();walker.manual_enabled=false;key(KEY_RIGHT,true);walker.manual_enabled=true;stopped=walker.foot;advance(.1)
		walker.manual_enabled=false;walker.manual_enabled=true;advance(.1)
		check(walker.foot==stopped,"repeated modal toggles keep the old key blocked: "+str(cycle))
		walker.manual_enabled=false;key(KEY_RIGHT,false);walker.manual_enabled=true;key(KEY_RIGHT,true);advance(.2)
		check(walker.foot.x>stopped.x+5,"release inside a later modal permits fresh movement: "+str(cycle))

func _test_host_modals()->void:
	game=Host.new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
	game.core.new_game();game._world();await settle()
	walker=game.walker;walker.foot=Vector2(1200,walker.foot.y);walker.cancel();walker._window_focused=true;root.gui_release_focus()
	for opener:Key in [KEY_ESCAPE,KEY_B]:
		tap(opener);await settle()
		check(is_instance_valid(game.modal),"world key opens tested modal: "+OS.get_keycode_string(opener))
		key(KEY_RIGHT,true);await settle(.1);var stopped:Vector2=walker.foot
		var scroll:float=game._street_road.camera_director.scroll
		tap(KEY_ESCAPE);await settle(.25)
		check(not is_instance_valid(game.modal) and walker.foot==stopped,"actual modal Escape resumes without its held arrow: "+OS.get_keycode_string(opener))
		check(absf(game._street_road.camera_director.scroll-scroll)<.05,"resuming a stationary courier keeps the settled camera: "+OS.get_keycode_string(opener))
		key(KEY_RIGHT,false);key(KEY_RIGHT,true);await settle(.2)
		check(walker.foot.x>stopped.x+5,"fresh arrow moves after actual modal closes: "+OS.get_keycode_string(opener))
		key(KEY_RIGHT,false);await settle(.8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"world_after_resume.png")
	game.sound.shutdown();await settle(.4);game.queue_free();await process_frame
