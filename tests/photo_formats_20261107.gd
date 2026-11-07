extends SceneTree
const Camera=preload("res://scripts/ui/field_camera.gd")
const Host=preload("res://scripts/rebuild/final_playable.gd")
var failures:Array[String]=[]
var checks:=0
var out:="user://qa/formats/"
func _initialize():
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func run():
	root.unfocusable=true;Engine.max_fps=60
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
	DirAccess.make_dir_recursive_absolute(out)
	var v:=SubViewport.new();v.size=Vector2i(1600,900);v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(v)
	var source:=Image.create(1600,900,false,Image.FORMAT_RGB8);source.fill(Color("619fae"));source.fill_rect(Rect2i(600,200,400,500),Color("e7bf64"))
	for lang:String in ["zh","en"]:
		var camera:=Camera.new();camera.locale=lang;camera.save_directory="user://qa/formats_"+str(Time.get_ticks_usec());camera.album_directory=camera.save_directory+"/album";camera.capture_provider=func():return source.duplicate()
		v.add_child(camera);camera.size=Vector2(1600,900)
		for expected:bool in [true,false]:
			var key:=InputEventKey.new();key.keycode=KEY_R;key.physical_keycode=KEY_R;key.pressed=true
			v.push_input(key,true);await process_frame
			key=key.duplicate();key.pressed=false;v.push_input(key,true);await process_frame
			check(camera.instant_format==expected,"R keyboard event switches paper")
		for instant:bool in [true,false]:
			camera._format_button.pressed.emit();check(camera.instant_format==instant,"format button switches")
			await RenderingServer.frame_post_draw;v.get_texture().get_image().save_png(out+lang+str(instant)+"_finder.png")
			await camera.take_photo()
			var captured:=Image.load_from_file(camera.last_photo_path)
			check((captured.get_width()==captured.get_height())==instant,"capture matches frame")
			check((camera._review_paper.size.x<camera._review_paper.size.y)==instant,"paper orientation matches capture")
			camera._caption_editor.text="海风 / Sea breeze";var exported:String=await camera.export_current_photo()
			var print_image:=Image.load_from_file(exported)
			check((print_image.get_width()<print_image.get_height())==instant,"export keeps selected paper")
			check(Camera.caption_for(camera.last_photo_path)=="海风 / Sea breeze","both styles persist note")
			check(camera._review_paper.get_rect().encloses(camera._caption_editor.get_rect()),"note inside paper")
			await RenderingServer.frame_post_draw;v.get_texture().get_image().save_png(out+lang+str(instant)+"_review.png")
			camera._leave_review()
		camera.queue_free();await process_frame
	var game:=Host.new();game.allow_display_changes=false;v.add_child(game);game.size=Vector2(1600,900);game.core.new_game();game.core.state.location="community_center";game._world();game._resident_conversation("community",0)
	await create_timer(.5).timeout;await RenderingServer.frame_post_draw;v.get_texture().get_image().save_png(out+"community.png")
	check(game.modal._right_portrait.size.x==448,"community portrait reduced")
	game._close();game._settings_page(false);await create_timer(.5).timeout;await RenderingServer.frame_post_draw;v.get_texture().get_image().save_png(out+"settings.png")
	game._close();game.process_mode=Node.PROCESS_MODE_DISABLED;game.sound.shutdown()
	# Match the host's orderly shutdown: the audio thread releases stopped
	# playback references before the fixture frees its owner and exits.
	var shutdown_started:=Time.get_ticks_msec()
	while game.sound.has_pending_playbacks() and Time.get_ticks_msec()-shutdown_started<1000:await process_frame
	game.queue_free();await process_frame;v.queue_free();await process_frame
	FileAccess.open(out+"formats.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
	print("PHOTO_FORMATS ",checks," / ",failures.size());quit(0 if failures.is_empty() else 1)
