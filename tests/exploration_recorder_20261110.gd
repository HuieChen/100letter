extends SceneTree
var out:=""
var checks:=0
var failures:Array=[]
func _initialize():
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func run():
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game=load("res://scripts/rebuild/final_playable.gd").new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
	game.core.new_game();game.core.state.location="community_center";game._world()
	game.walker.foot=Vector2(1400,872);game.walker.target=game.walker.foot
	await create_timer(.7).timeout
	var base_effects:=AudioServer.get_bus_effect_count(AudioServer.get_bus_index("SolmereAmbience"))
	var baseline_buses:=AudioServer.bus_count
	game._recorder();await create_timer(.5).timeout
	var recorder=game.modal;var field=game._street_road.field_sound
	check(recorder.name=="FieldRecorder" and game.sound.recorder_focus,"Recorder accessible and sound focus entered")
	check(game.walker.manual_enabled,"Recorder permits walking during monitoring")
	check(game.sound.music.stream_paused and game.sound._music_gain==0.0,"Guitar fully silent after recorder entry fade")
	check(field.sources.any(func(item):return item.id=="fountain") and field.sources.any(func(item):return item.id=="market"),"Community has local fountain and market sound sources")
	var source:Dictionary=field.sources[0]
	recorder.aim_point=game._street_road.world.get_global_transform()*source.at
	await create_timer(.8).timeout
	var towards:float=source.gain
	recorder.aim_point=Vector2(1580,640);await create_timer(.8).timeout
	check(source.gain<towards*.65,"Aiming away audibly attenuates the same world voice")
	recorder.aim_point=game._street_road.world.get_global_transform()*source.at
	source.player.play();await create_timer(.3).timeout
	recorder.library.get_parent().show();recorder.toggle_recording()
	check(not recorder.library.get_parent().visible,"Recording hides library, preserves scene")
	var metered_peak:=0.0
	for i in 25:
		await create_timer(.1).timeout
		metered_peak=maxf(metered_peak,recorder.levels.length())
		if i==10:
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"recorder_recording.png")
	check(recorder.recording and recorder.elapsed>2.0,"Recording advances without a fixed progress gate")
	check(metered_peak>.00001,"Meter reflects samples over the recorded interval, including silent gaps")
	check(recorder.stop_recording(),"Stop saves recording")
	var first:String=recorder.last_path
	check(FileAccess.file_exists(first),"WAV created")
	var wav:=AudioStreamWAV.load_from_file(first)
	check(wav!=null and wav.get_length()>2.0 and wav.get_length()<3.4,"Saved WAV duration tracks actual interval")
	check(wav.data.size()>10000 and wav.stereo,"Actual stereo PCM retained")
	var audio_peak:=0
	for sample in range(0,wav.data.size()-1,2):audio_peak=maxi(audio_peak,absi(wav.data.decode_s16(sample)))
	check(audio_peak>0 and audio_peak<32767,"Saved PCM contains real non-clipped sound")
	wav.save_to_wav(out+"recorded_environment.wav")
	recorder.title_edit.text="树边 / Trees";check(recorder._save_name(),"Recording name saved")
	recorder.toggle_playback();await create_timer(.25).timeout
	check(recorder.playback.playing and game.sound.recorder_playback,"Playback works and ducks current ambience")
	recorder.toggle_recording();check(not recorder.playback.playing and not game.sound.recorder_playback,"New recording stops replay, prevents feedback")
	await create_timer(.6).timeout
	recorder._focus_lost();check(not recorder.recording and recorder.last_path!=first,"Focus loss stops and saves current clip")
	var before:Vector2=game.walker.foot
	recorder.toggle_recording()
	var key:=InputEventKey.new();key.keycode=KEY_RIGHT;key.physical_keycode=KEY_RIGHT;key.pressed=true
	recorder.record_button.grab_focus();Input.parse_input_event(key);Input.flush_buffered_events();await create_timer(.4).timeout
	key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
	check(game.walker.foot.x>before.x+5.0 and recorder.recording,"Arrow keys move courier while recording continues")
	recorder.stop_recording()
	var ground:=InputEventMouseButton.new();ground.button_index=MOUSE_BUTTON_LEFT;ground.pressed=true;ground.position=Vector2(1100,872)
	recorder._aim_input(ground);await create_timer(.25).timeout
	check(game.walker.walking,"Recorder surface forwards ground clicks")
	ground.button_index=MOUSE_BUTTON_RIGHT;recorder._aim_input(ground);check(not game.walker.walking,"Right click still cancels walking while recording tool is open")
	recorder._toggle_library();await create_timer(.1).timeout
	check(not game.walker.manual_enabled,"Library pauses walking for safe naming")
	recorder._toggle_library();await create_timer(.1).timeout
	check(game.walker.manual_enabled,"Leaving library restores walking")
	var good_directory:String=recorder.directory
	var blocked_path:=out+"not_a_directory";FileAccess.open(blocked_path,FileAccess.WRITE).store_string("test")
	recorder.directory=blocked_path
	recorder.toggle_recording();await create_timer(.6).timeout
	check(not recorder.stop_recording() and recorder.pending_audio!=null,"Write failure retains exact captured audio")
	check(not recorder.checkpoint_for_quit(),"Unsaved recording prevents silent exit")
	recorder.directory=good_directory;check(recorder.checkpoint_for_quit(),"Retry persists retained recording")
	recorder.visual_hint.button_pressed=true;recorder.library.get_parent().hide()
	var visible_panels:=0
	for child:Node in recorder._page.get_children():
		if child is Panel and child.visible:visible_panels+=1
	check(visible_panels==0,"No opaque panel remains during field monitoring")
	var clear:=Rect2(400,170,800,600)
	for control:Control in [recorder.record_button,recorder.play_button,recorder.clock_label,recorder.status,recorder.visual_hint,recorder.library_button]:check(not clear.intersects(control.get_rect()),"Recorder controls leave central scene clear: "+str(control.name))
	await create_timer(.15).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"recorder_zh.png")
	recorder.library.get_parent().show();await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"recorder_library.png")
	recorder.request_close();await process_frame;await process_frame
	check(not game.sound.recorder_focus and not game.sound.recorder_playback,"Closing restores sound modes")
	await create_timer(.35).timeout
	check(not game.sound.music.stream_paused and game.sound._music_gain>0.0,"Closing smoothly resumes the same guitar")
	check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("SolmereAmbience"))==base_effects,"Recorder effects removed without affecting existing bus")
	game.preferences.values.language="en";game._recorder();await process_frame
	recorder=game.modal;check(first in recorder.paths,"Library persists across reopen")
	check(recorder._metadata(first).name=="树边 / Trees","Saved recording title survives reopen")
	check(recorder.play_button.text=="P  Play","English labels")
	for pixels:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=pixels;await process_frame;await RenderingServer.frame_post_draw
		check(recorder.get_rect().encloses(recorder.record_button.get_rect()),"Record control fits "+str(pixels))
		root.get_texture().get_image().save_png(out+"recorder_en_"+str(pixels.x)+".png")
	recorder.request_close();await process_frame;await process_frame
	check(AudioServer.bus_count==baseline_buses,"Repeated recorder use does not grow buses")
	game._street_road.field_sound.shutdown();game.sound.shutdown();await create_timer(.3).timeout
	game.queue_free();await process_frame;await process_frame;await create_timer(.5).timeout
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"audio_driver":AudioServer.get_driver_name(),"recording":first}))
	quit(0 if failures.is_empty() else 1)
