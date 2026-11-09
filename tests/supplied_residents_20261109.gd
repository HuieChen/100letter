extends SceneTree
var out:=""
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
	run.call_deferred()
func run():
	DirAccess.make_dir_recursive_absolute(out);root.unfocusable=true
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game=load("res://scripts/rebuild/final_playable.gd").new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900);game.core.new_game()
	for locale:String in ["zh","en"]:
		game.preferences.set_value("language",locale)
		for spec:Array in [["community_center","food_truck","FoodTruckGuest","hoodie_guest.png",Rect2(1514,155,380,771)],["tarot_shop","tarot_shop","TarotGuest","tarot_guest.png",Rect2(2151,165,309,750)]]:
			game.core.state.location=spec[0];game._world(spec[1]);await create_timer(.6).timeout
			var figure=game._street_road.world.get_node_or_null(spec[2])
			check(figure!=null,"figure present "+spec[2])
			if figure==null:continue
			check(absf(figure.position.y+figure.size.y-850)<.1,"feet on authored ground")
			check(is_equal_approx(figure.size.y,305.0),"matching neighbour scale")
			check(figure.texture.region==spec[4],"exact subject atlas")
			var original:=Image.load_from_file("res://assets/authoring/neighbours_20261109/"+spec[3]);original.generate_mipmaps()
			check(original.get_data()==figure.texture.atlas.get_image().get_data(),"unchanged source pixels")
			check(figure.mouse_filter==Control.MOUSE_FILTER_IGNORE,"no blocked walking input")
			check(figure.z_index<game.walker.z_index,"courier passes in front")
			check(game._street_road.world.get_node_or_null("Resident_chef")!=null if spec[0]=="community_center" else game._street_road.world.get_node_or_null("FoodTruckGuest")==null,"correct street roles")
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(out+locale+"_"+spec[1]+".png")==OK,"scene screenshot")
	game.sound.shutdown();await create_timer(.6).timeout;game.queue_free();await process_frame;await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("SUPPLIED_RESIDENTS ",checks," / ",failures.size());quit(0 if failures.is_empty() else 1)
