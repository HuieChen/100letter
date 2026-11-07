extends SceneTree
## Real GUI key input in an isolated save. No OS desktop control.
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/settings-continuity/"
func _initialize():
	var isolated:=false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--final-save=user://qa/"):isolated=true
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	if not isolated:push_error("Isolated QA save required");quit(1);return
	create_timer(90).timeout.connect(func():push_error("Settings continuity timed out");quit(1))
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func settle():await create_timer(.32).timeout
func key(code:Key,shift:bool=false):
	for down:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.shift_pressed=shift;event.pressed=down
		root.push_input(event,true);await process_frame
func shot(name:String):
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png")==OK,"screenshot "+name)
func open_from_pause():
	game.modal.get_node("PaperSheet/SheetAction_1").grab_focus();await key(KEY_ENTER);await settle()
func run():
	DirAccess.make_dir_recursive_absolute(out)
	root.unfocusable=true;root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game=Host.new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
	game.core.new_game();game.core.save_game();game._post_office_room()
	for locale:String in ["zh","en"]:
		root.size=Vector2i(1280,720) if locale=="zh" else Vector2i(1920,1080)
		game.preferences.set_value("language",locale);game._pause();await settle();await open_from_pause()
		var page=game.modal
		for id:String in ["language","display_mode","resolution","text_speed"]:
			var before:Dictionary=game.preferences.values.duplicate(true)
			page.controls[id].grab_focus();await key(KEY_ENTER);await settle()
			var popup:Control=page.get_node_or_null("SettingsDropdown")
			check(popup!=null,locale+" Enter opens "+id)
			if popup==null:quit(1);return
			for start:Control in [root.gui_get_focus_owner(),page.get_node("CloseSettings")]:
				for code:Key in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_TAB]:
					start.grab_focus();await key(code)
					var focus:=root.gui_get_focus_owner()
					check(focus!=null and (popup.is_ancestor_of(focus) or focus.name=="CloseSettings"),locale+" "+id+" nested navigation "+str(code)+" from "+str(start.name))
				start.grab_focus();await key(KEY_TAB,true)
				var reverse:=root.gui_get_focus_owner()
				check(reverse!=null and (popup.is_ancestor_of(reverse) or reverse.name=="CloseSettings"),locale+" "+id+" reverse Tab contained")
			check(game.preferences.values==before,locale+" navigation cannot alter covered values: "+id)
			if id=="resolution":await shot(locale+"_expanded")
			await key(KEY_ESCAPE)
			check(page.get_node_or_null("SettingsDropdown")==null and root.gui_get_focus_owner()==page.controls[id],locale+" Escape restores selector "+id)
			check(page.controls.master.focus_mode==Control.FOCUS_ALL,locale+" background controls reenabled")
		# A keyboard volume adjustment must still work and reach disk after closing.
		page.controls.music.grab_focus();var volume:float=game.preferences.values.music
		await key(KEY_LEFT)
		check(game.preferences.values.music<volume,locale+" slider responds after selector teardown")
		await key(KEY_ESCAPE);await settle()
		var focused:=root.gui_get_focus_owner()
		check(focused!=null and focused.name=="SheetAction_1",locale+" returns to Settings opener")
		check(not game.preferences.dirty,locale+" keyboard volume is saved before return")
		await shot(locale+"_pause_return")
		await open_from_pause();page=game.modal
		# Exercise deferred language rebuild followed by close in the same input turn.
		page.controls.language.grab_focus();await key(KEY_ENTER)
		page.find_child("Option_language_"+str(1 if locale=="zh" else 0),true,false).grab_focus()
		var event:=InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=true;root.push_input(event,true)
		event=InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=false;root.push_input(event,true)
		page.request_close();page.request_close();await settle()
		check(is_instance_valid(game.modal) and game.modal.get_node_or_null("PaperSheet")!=null,locale+" rapid language/close returns to pause once")
		focused=root.gui_get_focus_owner()
		check(focused is Button and focused.name=="SheetAction_1" and focused.text==game._tr("设置","Settings"),locale+" changed-language return focus and label agree")
		await key(KEY_ESCAPE);await settle()
		check(not is_instance_valid(game.modal),locale+" pause Escape returns to scene")
	game.sound.shutdown();game.queue_free();await process_frame;await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"GPU screenshots and engine-injected GUI input; isolated preferences and campaign saves."},"\t"))
	print("SETTINGS_CONTINUITY ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
