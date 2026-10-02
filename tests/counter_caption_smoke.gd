extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game=Host.new();root.add_child(game);game.size=Vector2(1600,900)
	game.core.save_path="user://qa/counter-caption-"+str(Time.get_ticks_usec())+".json";game.core.new_game();game._counter();await process_frame
	var desk:Control=game._desk_surface
	_check(not desk.caption_suppressed,"default desk hints begin visible")
	game._say("主管去整理后面的邮架了。桌上邮件箱里留着第一封。")
	_check(desk.caption_suppressed and game.status.visible,"host feedback suppresses overlapping desk caption")
	for down:bool in [true,false]:
		var e:=InputEventMouseButton.new();e.position=Vector2(810,642);e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await process_frame
	_check(desk.latch_open,"actual pointer still opens the latch during feedback")
	_check(desk._message_left>0 and desk.caption_suppressed,"new tool hint is retained without drawing through host text")
	await _shot("temporary_feedback")
	game._footer_timer.start(0.10);await create_timer(0.2).timeout
	_check(not game.status.visible and not desk.caption_suppressed,"actual timer restores one useful desk hint layer")
	_check(desk._message_left>0,"desk hint has remaining display time after host feedback")
	await _shot("desk_hint_restored")
	game._say("再核对一下。 ");game._say("")
	_check(not desk.caption_suppressed and not game.status.visible,"clearing feedback restores desk hint immediately")
	_check(game.core.state.minute==540,"caption coordination never advances game clock")
	var report:={"checks":checks,"failures":failures,"scope":"Isolated GPU host plus real latch input and actual caption timer; no gameplay route or human acceptance claim.","host_sha256":FileAccess.get_sha256("res://scripts/rebuild/final_playable.gd"),"desk_sha256":FileAccess.get_sha256("res://scripts/rebuild/postal_desk.gd")}
	var out:=FileAccess.open("res://test-results/counter_caption_results.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t"));out.close()
	print("COUNTER CAPTION: %d checks, %d failures"%[checks,failures.size()]);game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
func _shot(name:String)->void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-results/counter_caption")
	_check(root.get_texture().get_image().save_png("res://test-results/counter_caption/"+name+".png")==OK,"capture "+name)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
