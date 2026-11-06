extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Core=preload("res://scripts/rebuild/final_case_state.gd")
const Arrival=preload("res://scripts/rebuild/street_arrival.gd")
const Routes={"post_office":"post_office","chess_stall":"chess_stall","bookstore":"post_office","tarot_shop":"tarot_shop","record_store":"tarot_shop","statue":"tarot_shop","community_center":"community_center","residential":"residential","grocery":"community_center","market":"community_center","food_truck":"community_center","lookout":"lookout","bus_stop":"bus_stop"}
var game:Control
var view:SubViewport
var checks:=0
var failures:Array[String]=[]
var out:="user://qa/experience_routes/"
func _initialize():
	var isolated:=false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--final-save=user://qa/"):isolated=true
	if not isolated:
		push_error("Pass --final-save=user://qa/<unique-run>/state.json to protect player saves")
		quit(1);return
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func settle(t:float=.1):await create_timer(t).timeout;await process_frame
func click(control:Control):
	var point:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;view.push_input(motion,true)
	for down:bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;view.push_input(event,true)
	await process_frame
func wait_arrival():
	var deadline:=Time.get_ticks_msec()+3000
	while game.busy and Time.get_ticks_msec()<deadline:await process_frame
	await process_frame
func run():
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(out)
	root.unfocusable=true;Engine.max_fps=60
	view=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);view.notify_mouse_entered()
	game=Host.new();game.allow_display_changes=false;view.add_child(game);game.size=Vector2(1600,900)
	game.core.new_game();game.core.save_game();game._post_office_room();await settle()
	var minute:int=game.core.state.minute
	for destination:String in Routes:
		game._map();await settle(.04)
		var before:int=game.get_meta("completed_scene_changes",0)
		await click(game.modal.find_child("Map_"+destination,true,false))
		check(game.busy,destination+" locks scene change")
		game._visit_map_destination("tarot_shop")
		await wait_arrival()
		check(not game.busy,destination+" completes bounded transition")
		check(int(game.get_meta("completed_scene_changes",0))==before+1,destination+" accepts exactly one destination")
		check(game.core.state.location==Routes[destination],destination+" saves correct semantic district")
		check(game.sound.location_id==Routes[destination],destination+" selects matching audio district")
		var expected:float=game._street_road.world.size.x*.376 if destination=="post_office" else (12100.0 if destination=="food_truck" else float(Arrival.SOURCE_X[destination])*1.5-180.0)
		check(absf(game.walker.foot.x-expected)<.1,destination+" reaches its own painted landmark")
		check(game.core.state.minute==minute,destination+" has no invisible time penalty")
		var saved:=Core.new();saved.save_path=game.core.save_path;root.add_child(saved)
		check(saved.load_game() and saved.state.location==Routes[destination],destination+" reloads destination")
		saved.queue_free()
	game._post_office_room();await settle()
	await click(game.stage.get_node("PostOfficeExit"));await settle(.17)
	check(game.busy,"painted exit keeps door press before world transition")
	await wait_arrival();await settle(.12)
	check(game.view=="world" and game.core.state.location=="post_office","painted exit returns to its real outside door")
	await click(game._street_road.entry_hint);await settle(.17)
	check(game.busy,"E-entry button uses the same transition boundary")
	await wait_arrival()
	check(game.view=="post_office_room" and not game.busy,"door entry restores room controls")
	# A real rendered high-z foreground fixture catches modal occlusion, not just metadata.
	var foreground:=ColorRect.new();foreground.color=Color.MAGENTA;foreground.position=Vector2(500,300);foreground.size=Vector2(600,320);foreground.z_index=20;foreground.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.stage.add_child(foreground)
	game._bag_photos_visible=false;game._bag();await settle()
	await RenderingServer.frame_post_draw
	var frame:=view.get_texture().get_image();frame.save_png(out+"bag_layer.png")
	var paper:=game.modal.get_node("BagPaper") as Control
	var pixel:=frame.get_pixelv(Vector2i(paper.get_global_rect().position+Vector2(360,260)))
	check(pixel.g>.65,"real bag paper covers higher world foreground pixels")
	game._close();foreground.queue_free()
	# Refuse disk publication through a deliberately blocked QA-only target.
	var normal_path:String=game.core.save_path
	var blocked:=normal_path.get_base_dir()+"/blocked_directory";DirAccess.make_dir_recursive_absolute(blocked)
	game.core.save_path=blocked
	game._visit_map_destination("chess_stall");await wait_arrival()
	var notice:=game.get_node_or_null("SaveFailureNotice") as Control
	check(notice!=null and notice.z_index>100,"save failure remains visible over modal layers")
	check(game.core.state.location=="chess_stall" and not game.busy,"save failure retains live progress and controls")
	game.core.save_path=normal_path;game._save();await process_frame
	check(game.get_node_or_null("SaveFailureNotice")==null,"successful retry removes stale failure notice")
	var restored:=Core.new();restored.save_path=normal_path;root.add_child(restored)
	check(restored.load_game() and restored.state.location=="chess_stall","successful retry preserves latest progress")
	restored.queue_free()
	game.sound.shutdown();await settle(.5);game.queue_free();await process_frame;view.queue_free();await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"method":"13 real map button inputs, duplicate navigation, painted exit/entry, rendered foreground occlusion, QA-only disk failure/retry."},"  "))
	print("EXPERIENCE_ROUTES ",checks," checks / ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
