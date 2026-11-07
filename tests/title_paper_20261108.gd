extends SceneTree
var failures:Array[String]=[]
var checks:=0
var out:="user://qa/title_paper/"
var view:SubViewport
var game:Control
var cues:Array[String]=[]
func _initialize()->void:
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
	root.unfocusable=true
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
	run.call_deferred()
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures.append(why);push_error(why)
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(out+name+".png")
func mouse(position:Vector2,down:bool)->void:
	var event:=InputEventMouseButton.new();event.position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
	view.push_input(event,true)
	await process_frame
func move(position:Vector2)->void:
	var event:=InputEventMouseMotion.new();event.position=position
	view.push_input(event,true)
	await process_frame
func click(button:Button)->void:
	var point:=button.get_global_rect().get_center()
	await move(point);await mouse(point,true);await mouse(point,false)
	await create_timer(.35).timeout
func key(code:Key)->void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	view.push_input(event,true);await process_frame
	event=event.duplicate();event.pressed=false;view.push_input(event,true)
	await create_timer(.22).timeout
func run()->void:
	DirAccess.make_dir_recursive_absolute(out)
	view=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scripts/rebuild/final_playable.gd").new();game.allow_display_changes=false;view.add_child(game);game.size=Vector2(1600,900)
	game.sound.cue_played.connect(func(kind:String,_sample:String):cues.append(kind))
	await create_timer(.5).timeout
	check(game.stage.get_node("UserCoverArt").texture.get_size()==Vector2(7262,4085),"full original background resolution")
	check(game.stage.has_node("AuthoredTitle"),"separate authored logo")
	check(game.stage.get_node("ContinueShift").disabled,"no save disables Continue")
	check(game.stage.get_node("ContinueShift").focus_mode==Control.FOCUS_NONE,"keyboard skips unavailable Continue")
	check(game.sound.location_id=="title" and game.sound.ambience.playing,"cover ocean ambience playing")
	check(game.sound.ambience.bus==game.sound.AMBIENT_BUS,"ocean follows ambience setting")
	check(game.sound.music.volume_db < -60,"in-game guitar does not leak into cover")
	var capture:=AudioEffectCapture.new();capture.buffer_length=2.0
	var audio_bus:=AudioServer.get_bus_index(game.sound.AMBIENT_BUS)
	AudioServer.add_bus_effect(audio_bus,capture)
	await create_timer(.5).timeout
	var samples:=capture.get_buffer(capture.get_frames_available());var peak:=0.0
	for sample:Vector2 in samples:peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	check(peak>0.00001,"cover ambience emits actual nonzero audio samples")
	AudioServer.remove_bus_effect(audio_bus,AudioServer.get_bus_effect_count(audio_bus)-1)
	game.preferences.set_value("ambience",0.0)
	check(AudioServer.is_bus_mute(audio_bus),"zero ambience volume mutes cover ocean")
	game.preferences.set_value("ambience",.85)
	check(not AudioServer.is_bus_mute(audio_bus),"ambience slider restores ocean")
	await shot("no_save")
	var start:Button=game.stage.get_node("NewShift")
	await move(start.get_global_rect().get_center());await create_timer(.2).timeout
	check(start.art.scale.x>1.0,"hover gently lifts paper")
	check("title_hover" in cues,"hover produces quiet paper cue")
	await shot("hover")
	await mouse(start.get_global_rect().get_center(),true);await create_timer(.1).timeout
	await RenderingServer.frame_post_draw
	check(start.art.scale.x<1.0,"held paper compresses: held="+str(start._held)+" scale="+str(start.art.scale))
	await shot("pressed")
	await mouse(start.get_global_rect().get_center(),false);await create_timer(.5).timeout
	check(game.view=="post_office_room","Start opens playable post office")
	check(game.core.has_save(),"Start creates isolated save")
	game.core.state.location="bus_stop";game.core.save_game();game._title();await create_timer(.4).timeout
	check(not game.stage.get_node("ContinueShift").disabled,"saved journey enables Continue")
	await click(game.stage.get_node("ContinueShift"))
	check(game.view=="world" and game.core.state.location=="bus_stop","Continue restores saved location")
	game._title();await create_timer(.4).timeout
	var saved:=FileAccess.get_file_as_bytes(game.core.save_path)
	await click(game.stage.get_node("NewShift"))
	check(is_instance_valid(game.modal),"Start with save asks before replacing progress")
	check(saved==FileAccess.get_file_as_bytes(game.core.save_path),"confirmation leaves existing save intact")
	game._close();await create_timer(.2).timeout
	for language:String in ["zh","en"]:
		game.preferences.values.language=language;game._title();await create_timer(.4).timeout
		await move(Vector2(1500,850));game.stage.get_node("ContinueShift").release_focus();await create_timer(.2).timeout
		await shot(language+"_composition")
		await click(game.stage.get_node("OpenSettings"))
		check(is_instance_valid(game.modal),language+" Settings mouse action")
		game.modal.closed.emit();await create_timer(.3).timeout
		check(not is_instance_valid(game.modal) and game.view=="title",language+" Settings returns to cover")
		game.stage.get_node("ContinueShift").grab_focus();await key(KEY_DOWN)
		check(view.gui_get_focus_owner()==game.stage.get_node("OpenSettings"),language+" Down moves focus to Settings")
		await key(KEY_ENTER)
		check(is_instance_valid(game.modal),language+" Enter activates focused paper")
		game.modal.closed.emit();await create_timer(.2).timeout
	check("paper" in cues,"activation produces existing paper confirmation sound")
	game.sound.shutdown();game.queue_free();await process_frame;view.queue_free();await process_frame
	await create_timer(.2).timeout
	FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"audio_peak":peak,"audio_cues":cues},"  "))
	print("TITLE_PAPER_CHECKS ",checks," / ",failures.size())
	quit(0 if failures.is_empty() else 1)
