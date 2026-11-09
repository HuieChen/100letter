extends SceneTree
## Actual WM-close during the real camera's two-frame exposure.
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var camera:Control
var checks:=0
var failures:Array[String]=[]
var out:=""
var saved:Array[String]=[]
var timed_out:=false
var started:=Time.get_datetime_string_from_system(true)
func _initialize()->void:
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):
		push_error("QA-only --final-save required");quit(1);return
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	if out.is_empty():push_error("--qa-out required");quit(1);return
	run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run()->void:
	DirAccess.make_dir_recursive_absolute(out)
	root.unfocusable=true;auto_accept_quit=false
	game=Host.new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
	game.core.state.location="community_center";game._world();await process_frame
	game._camera();await process_frame;camera=game.modal
	camera.save_directory=out+"photos"
	camera.photo_saved.connect(func(path:String):saved.append(path))
	root.tree_exiting.connect(final_receipt)
	camera.shutter.pressed.emit()
	check(camera.capture_busy,"actual shutter accepted")
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(not game._window_close_pending,"repeated window close waits for exposure before disabling scene")
	await create_timer(8).timeout
	timed_out=true;failures.append("window close stalled after capture");quit(1)
func final_receipt()->void:
	check(not timed_out,"pending exposure releases requested close")
	check(saved.size()==1 and FileAccess.file_exists(saved[0]),"accepted photo exists exactly once at orderly application exit")
	check(game._window_close_pending,"actual host orderly shutdown completed")
	check(game.get_node_or_null("SaveFailureNotice")==null,"normal exposure produces no false save-failure message")
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"started_utc":started,"completed_utc":Time.get_datetime_string_from_system(true),"method":"Engine WM_CLOSE_REQUEST sent twice during real viewport exposure; offscreen GPU with isolated QA data, no OS input."},"  "))
	print("HOST_CAPTURE_CLOSE_COMPLETE ",checks," checks / ",failures.size()," failures")
