extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var camera:Control
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/host_album_quit/"
var exported:=false
var timed_out:=false
var force_failure:=false
func _initialize():
	var isolated:=false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--final-save=user://qa/"):isolated=true
		if arg=="--force-export-failure":force_failure=true
	if not isolated:push_error("QA-only --final-save required");quit(1);return
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr(label)
func run():
	root.unfocusable=true;auto_accept_quit=false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(out)
	game=Host.new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
	game.core.new_game();game._post_office_room()
	await process_frame
	var directory:String=game._photo_directory();DirAccess.make_dir_recursive_absolute(directory)
	var source:=directory.path_join("DearSomewhere_close.png")
	var pixels:=Image.create(640,360,false,Image.FORMAT_RGB8);pixels.fill(Color("579ba9"));pixels.save_png(source)
	game._bag_photo_album(source);camera=game.modal;camera.album_directory=out+"album"
	camera._caption_editor.text="Close while saving / 保存时关闭"
	if force_failure:camera._caption_editor.text="Keep this note / 保留原文。\n".repeat(300)
	camera.album_saved.connect(func(_path:String):exported=true)
	root.tree_exiting.connect(final_receipt)
	camera.export_current_photo()
	check(camera._album_busy,"export begins before window close")
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(not game._window_close_pending,"host waits for export before disabling processing")
	await create_timer(8.0).timeout
	timed_out=true;failures.append("host did not finish requested window close");quit(1)
func final_receipt():
	check(not timed_out,"requested close finishes without another click")
	check(exported!=force_failure,"export completes with expected success/failure before application exit")
	if force_failure:
		check(camera.last_album_path.is_empty(),"failed export never announces a saved file")
		check(not camera._caption_editor.text.is_empty() and camera.checkpoint_for_quit(),"failed oversized export retains saved source note")
	else:check(not camera.last_album_path.is_empty() and FileAccess.file_exists(camera.last_album_path),"completed exported PNG exists at shutdown")
	check(game.get_node_or_null("SaveFailureNotice")==null,"pending export does not produce false save failure")
	check(game._window_close_pending,"actual host orderly quit path is used")
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"exported":exported,"method":"Engine WM_CLOSE_REQUEST sent twice during real GPU export; no OS input."},"  "))
	print("HOST_ALBUM_CLOSE ",checks," checks / ",failures.size()," failures")
