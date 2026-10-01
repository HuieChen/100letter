extends SceneTree
## Visual fixture, not an end-to-end playthrough. Travel uses public core actions.
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.title="Solmere generated-world visual QA"
	game=Host.new();root.add_child(game);game.size=Vector2(1600,900)
	game.core.save_path="user://qa/world-visual-"+str(Time.get_ticks_usec())+".json"
	game.core.new_game()
	await _shot("title")
	for location in ["post_office","community_center","residential","bus_stop","lookout","chess_stall","tarot_shop"]:
		if location!=game.core.state.location:_check(game.core.travel(location,game._walk_cost(str(game.core.state.location),location)).is_empty(),"legitimate travel "+location)
		game._world()
		await process_frame;await process_frame
		_check(game.stage.find_child("WorldArtwork",true,false).texture!=null,"new background present "+location)
		_check(game.walker.actor_height>=330,"courier remains prominent "+location)
		await _shot(location)
		if location=="post_office":
			var minute:int=game.core.state.minute
			game._map();await process_frame
			await _shot("town_map")
			await _click("Map_residential")
			await _shot("map_preview")
			_check(game.core.state.minute==minute,"map preview has no time cost")
			game._close()
		if location in ["lookout","chess_stall"]:
			var prior_minute:int=game.core.state.minute
			var evidence_count:int=game.core.state.evidence.size()
			await _click("LookTelescopeCase" if location=="lookout" else "LookChessboard")
			for i in range(500):
				if is_instance_valid(game.modal):break
				await process_frame
			_check(is_instance_valid(game.modal),"real scenery click walks into an observation "+location)
			_check(game.core.state.minute==prior_minute and game.core.state.evidence.size()==evidence_count,"scenery inspection neither spends reading time nor invents proof "+location)
			await _shot(location+"_observation")
			await _click("AdvanceDialogue")
			_check(not is_instance_valid(game.modal) and game.walker.manual_enabled,"observation returns to walking "+location)
	print("FINAL WORLD VISUAL PROBE: %d checks, %d failures"%[checks,failures.size()])
	game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
func _click(name:String)->void:
	var c:Control=game.find_child(name,true,false);_check(c!=null,"input target "+name)
	if c==null:return
	var point:=c.get_global_rect().get_center()
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
		root.push_input(e,true);await process_frame
func _shot(name:String)->void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results/formal_world_v2"))
	root.get_texture().get_image().save_png("res://test-results/formal_world_v2/"+name+".png")
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
