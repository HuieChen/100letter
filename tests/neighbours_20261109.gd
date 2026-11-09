extends SceneTree
var out:=""
func _initialize():
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
	run.call_deferred()
func run():
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game=load("res://scripts/rebuild/final_playable.gd").new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900);game.core.new_game()
	var failures:Array=[]
	for spec:Array in [["chess_stall","Naonao"],["food_truck","FoodTruckGuest"]]:
		game.core.state.location="chess_stall" if spec[0]=="chess_stall" else "community_center"
		game._world(spec[0]);await create_timer(.6).timeout
		var figure=game._street_road.world.get_node_or_null(spec[1])
		if figure==null:failures.append("Missing "+spec[1])
		else:
			if absf(figure.position.y+figure.size.y-850)>1:failures.append("Foot anchor "+spec[1])
			if figure.size.y>320:failures.append("Oversized "+spec[1])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+spec[0]+".png")
	game.sound.shutdown();game.queue_free();await process_frame;await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":6,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
