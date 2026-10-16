extends SceneTree
## Own-game GPU fixture: whole 1920x1080 scenes and all six cutout poses.
## Pose samples are controlled drawing states, not a native mouse playthrough.
const Host=preload("res://scripts/rebuild/final_playable.gd")
const Art=preload("res://scripts/rebuild/physical_art.gd")
const OUT="res://test-results/video-character-20261016/visual/"
var game:Control
var checks:=0
var failures:Array[String]=[]
var images:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true
	root.size=Vector2i(1920,1080)
	root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.title="Courier cutout GPU review fixture"
	game=Host.new();root.add_child(game);game.size=Vector2(1600,900)
	game.core.save_path="user://qa/courier-visual-20261016/progress.json"
	game.core.new_game()
	for location:String in ["post_office","community_center","bus_stop","lookout","residential","chess_stall","tarot_shop"]:
		if game.core.state.location!=location:
			_check(game.core.travel(location,game._walk_cost(str(game.core.state.location),location)).is_empty(),"valid existing route "+location)
		game._world()
		await process_frame;await process_frame
		_check(game.walker._walk_keys.size()==6,"complete original animation in "+location)
		_check(game.walker._frame_geometry["CHAR_courier"].foot_anchor_px==[128.0,298.0],"matching idle foot anchor in "+location)
		await _shot("world_"+location)
		if location=="community_center":
			game.walker.set_process(false)
			game.walker._motion_blend=1.0
			for i:int in range(6):
				game.walker._walk_phase=(float(i)+0.001)/6.0*TAU
				game.walker.queue_redraw()
				await _shot("pose_"+str(i))
			game.walker._facing=-1.0;game.walker.queue_redraw()
			await _shot("facing_left")
	var report:={"suite":"courier_visual","checks":checks,"failures":failures,"screenshots":images,"scope":"Actual own-game GPU rendering at 1920x1080; explicit pose samples for boundary/scale review, not native input or player FPS proof."}
	var file:=FileAccess.open(OUT+"result.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	game.queue_free();await process_frame;await process_frame
	print("COURIER VISUAL: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _shot(name:String)->void:
	await process_frame
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path:=OUT+name+".png"
	var image:=root.get_texture().get_image()
	_check(image.get_size()==Vector2i(1920,1080),"full-size current GPU frame "+name)
	_check(image.save_png(path)==OK,"write current GPU frame "+name)
	images.append(path)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
