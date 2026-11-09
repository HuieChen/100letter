extends SceneTree
var game:Control
var view:SubViewport
var checks:=0
var failures:Array[String]=[]
var out:=""
var cues:Array[String]=[]
func _initialize()->void:
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
	create_timer(60).timeout.connect(func():push_error("map test timeout");quit(1))
	run.call_deferred()
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures.append(why);push_error(why)
func click(button:Control)->void:
	var at:=button.get_global_rect().get_center()
	var move:=InputEventMouseMotion.new();move.position=at;view.push_input(move,true);await process_frame
	for held:bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=held;view.push_input(event,true);await process_frame
	await create_timer(.1).timeout
func run()->void:
	DirAccess.make_dir_recursive_absolute(out);root.unfocusable=true
	view=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scripts/rebuild/final_playable.gd").new();game.allow_display_changes=false;view.add_child(game);game.size=Vector2(1600,900)
	await create_timer(.8).timeout;game.core.new_game();game._world();await create_timer(.5).timeout
	game.sound.cue_played.connect(func(kind:String,_sample:String):cues.append(kind))
	game._map();await create_timer(.4).timeout
	var map:Control
	for child in game.modal.get_children():
		if child.has_method("install_pet_regions"):map=child
	var location:String=game.core.state.location
	await click(map.get_node("Pet_Paw"));check(cues.count("dog")==1,"paw emits dog")
	await click(map.get_node("Pet_FountainDog"));check(cues.count("dog")==1,"shared cooldown blocks overlap")
	await create_timer(1.7).timeout
	await click(map.get_node("Pet_FountainDog"));check(cues.count("dog")==2,"fountain emits same dog")
	await click(map.get_node("Pet_BookCat"));check(cues.count("cat")==1,"book cat emits existing cat")
	check(is_instance_valid(game.modal) and game.core.state.location==location,"pet clicks do not travel or close map")
	check(game.sound.POOLS.cat==["cat_meow_cc0.mp3"],"same original bookstore cat sample")
	check(game.sound._stream("puppy_bark_cc0.wav").get_length()>1.0,"dog sample decoded")
	game.sound.set_muted(true);await create_timer(1.7).timeout;await click(map.get_node("Pet_Paw"));check(cues.count("dog")==2,"mute blocks dog")
	game.sound.set_muted(false);game.sound.set_volumes(.75,0.0,.85);await create_timer(1.7).timeout;await click(map.get_node("Pet_Paw"));check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(game.sound.SFX_BUS))<=-60.0,"effects volume zero silences dog bus")
	game.sound.set_volumes(.75,.85,.85)
	for locale:String in ["zh","en"]:
		game.preferences.values.language=locale
		map._hovered_destination=map.get_node("Map_grocery");map._keyboard_navigation=false
		await create_timer(.3).timeout;await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(out+locale+"_map.png")
		check(map._caption.size.x>=map._caption.get_minimum_size().x,"caption fits "+locale)
	await click(map.get_node("Map_grocery"));await create_timer(.8).timeout
	check(game.core.state.location=="community_center","building still travels")
	game.queue_free();await process_frame;await process_frame;view.queue_free();await process_frame;await process_frame
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	quit(0 if failures.is_empty() else 1)
