extends SceneTree
var game:Control
var view:SubViewport
var checks:=0
var failures:Array[String]=[]
var out:=""
var quit_mode:=""
func _initialize()->void:
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
		if arg.begins_with("--qa-quit-mode="):quit_mode=arg.trim_prefix("--qa-quit-mode=")
	create_timer(50).timeout.connect(func():push_error("Exit test timed out");quit(1))
	run.call_deferred()
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures.append(why);push_error(why)
func click(button:Button)->void:
	var point:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;view.push_input(motion,true)
	await process_frame
	for held:bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=held
		view.push_input(event,true);await process_frame
	await create_timer(.3).timeout
func key(code:Key)->void:
	for held:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=held
		view.push_input(event,true);await process_frame
	await create_timer(.25).timeout
func receipt()->void:
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"quit_mode":quit_mode},"  "))
	print("TITLE_EXIT_CHECKS ",checks," / ",failures.size()," mode=",quit_mode)
func run()->void:
	DirAccess.make_dir_recursive_absolute(out)
	root.unfocusable=true
	view=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scripts/rebuild/final_playable.gd").new();game.allow_display_changes=false;view.add_child(game);game.size=Vector2(1600,900)
	await create_timer(.5).timeout
	if not quit_mode.is_empty():
		if quit_mode=="play":
			await click(game.stage.get_node("NewShift"));await key(KEY_ESCAPE)
			await click(game.modal.get_node("PaperSheet/SheetAction_1"))
			await click(game.modal.get_node("SettingsQuitGame"))
		else:await click(game.stage.get_node("QuitGame"))
		check(game.modal.has_meta("quit_confirmation"),"real quit control opens confirmation")
		receipt()
		# Process must terminate through the real save/audio shutdown path, not test quit().
		print("REAL_QUIT_ACTION")
		await click(game.modal.get_node("PaperSheet/SheetAction_1"))
		return
	for language:String in ["zh","en"]:
		game.preferences.values.language=language;game._title();await create_timer(.4).timeout
		var exit_button:Button=game.stage.get_node("QuitGame")
		check(exit_button.text==("退出游戏" if language=="zh" else "Quit game"),language+" title quit label")
		await click(exit_button)
		check(game.modal.has_meta("quit_confirmation"),language+" title quit opens confirmation")
		check(view.gui_get_focus_owner()==game.modal.get_node("PaperSheet/SheetAction_0"),"safe cancel receives default focus")
		await key(KEY_ESCAPE)
		check(not is_instance_valid(game.modal) and game.view=="title","Esc cancels title quit")
		check(view.gui_get_focus_owner()==exit_button,"cancel returns focus to quit entry")
		await key(KEY_ESCAPE)
		check(game.modal.has_meta("quit_confirmation"),"Esc on title opens quit confirmation")
		await click(game.modal.get_node("PaperSheet/CloseSheet"))
		check(not is_instance_valid(game.modal),"X cancels quit")
	check(not game.core.has_save(),"canceled title quit does not create campaign progress")
	await click(game.stage.get_node("NewShift"))
	check(game.view=="post_office_room","Start still enters game")
	await key(KEY_ESCAPE)
	check(game.modal.has_node("PaperSheet/SheetAction_3"),"pause provides four actions including quit")
	await click(game.modal.get_node("PaperSheet/SheetAction_3"));await key(KEY_ESCAPE)
	check(game.modal.has_node("PaperSheet/SheetAction_3") and view.gui_get_focus_owner()==game.modal.get_node("PaperSheet/SheetAction_3"),"cancel returns to pause quit action")
	var save_path:String=game.core.save_path
	var sentinel_path:=save_path+".blocked"
	var file:=FileAccess.open(sentinel_path,FileAccess.WRITE);file.store_string("keep original");file.close()
	game.core.save_path=sentinel_path+"/save.json"
	await click(game.modal.get_node("PaperSheet/SheetAction_2"))
	check(game.view=="post_office_room" and is_instance_valid(game.modal),"failed save keeps play/pause instead of returning to title")
	await click(game.modal.get_node("PaperSheet/SheetAction_3"))
	await click(game.modal.get_node("PaperSheet/SheetAction_1"))
	check(not game._window_close_pending and game.can_process(),"failed save keeps game alive after explicit quit")
	check(game.has_node("SaveFailureNotice"),"failed quit reports progress save failure")
	check(FileAccess.get_file_as_string(sentinel_path)=="keep original","blocked parent file preserved")
	game.core.save_path=save_path
	await key(KEY_ESCAPE)
	await click(game.modal.get_node("PaperSheet/SheetAction_2"))
	check(game.view=="title" and game.core.has_save(),"successful save returns to title")
	await click(game.stage.get_node("ContinueShift"))
	check(game.view=="post_office_room","Continue restores the saved scene")
	for language:String in ["zh","en"]:
		game.preferences.values.language=language
		game._settings_page(false);await create_timer(.4).timeout
		check(game.modal.has_node("SettingsReturnTitle"),language+" in-game settings has direct title entry")
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(out+language+"_settings_exit.png")
		await click(game.modal.get_node("SettingsQuitGame"));await key(KEY_ESCAPE)
		check(game.modal.has_node("SettingsReturnTitle") and view.gui_get_focus_owner()==game.modal.get_node("SettingsQuitGame"),"cancel returns to Settings quit entry")
		await click(game.modal.get_node("SettingsReturnTitle"))
		check(game.view=="title" and not is_instance_valid(game.modal),language+" actual Settings button saves and returns to cover")
		await click(game.stage.get_node("OpenSettings"))
		check(not game.modal.has_node("SettingsReturnTitle") and game.modal.has_node("SettingsQuitGame"),"title Settings offers quit without redundant return")
		await key(KEY_ESCAPE);await click(game.stage.get_node("ContinueShift"))
	await key(KEY_ESCAPE)
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(out+"pause_exit.png")
	await click(game.modal.get_node("PaperSheet/SheetAction_3"))
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(out+"quit_confirmation.png")
	receipt()
	game.sound.shutdown();game.queue_free();await process_frame;view.queue_free();await process_frame
	await create_timer(.2).timeout
	quit(0 if failures.is_empty() else 1)
