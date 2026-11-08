extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var game:Control
var sound:AudioFeedback
var checks:=0
var failures:Array[String]=[]
var observations:Dictionary={}
var voices:Dictionary={}
var voice_changes:Array[String]=[]
var snapshots:Array=[]
var out:="user://qa/audio-transition"
func _initialize():
	if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):
		push_error("QA-only --final-save required");quit(1);return
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func snapshot(label:String):
	var record:Dictionary={"label":label,"elapsed":sound._elapsed,"location":sound.location_id,"indoors":sound.indoors,"minute":sound.minute,"gains":sound._bed_gains.duplicate(),"settings":sound._settings_feedback_mode}
	snapshots.append(record)
func inspect_voices():
	for role:String in voices:
		var player:AudioStreamPlayer=sound.music if role=="music" else sound._beds[role]
		if not player.playing or not player.has_stream_playback() or player.get_stream_playback().get_instance_id()!=voices[role]:
			if not role in voice_changes:voice_changes.append(role)
func settle(seconds:float):
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		await process_frame
		if sound!=null:inspect_voices()
func passage(build:Callable):
	game._change_scene(build)
	var deadline:=Time.get_ticks_msec()+6000
	while game.busy and Time.get_ticks_msec()<deadline:
		await process_frame;inspect_voices()
	check(not game.busy,"scene passage completes")
func run():
	root.unfocusable=true
	DirAccess.make_dir_recursive_absolute(out)
	var view:=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=Host.new();game.allow_display_changes=false;view.add_child(game)
	game.core.new_game();game.core.state.location="post_office";game.core.state.minute=720;game._world()
	sound=game.sound
	voices.music=sound.music.get_stream_playback().get_instance_id()
	for file:String in sound.BEDS:voices[file]=sound._beds[file].get_stream_playback().get_instance_id()
	await settle(.8);snapshot("outside_before")
	var elapsed_before:float=sound._elapsed
	await passage(func():game._post_office_room())
	await settle(.8);snapshot("inside_after")
	check(sound.indoors and sound.location_id=="post_office","actual indoor host selects room profile")
	check(float(sound._bed_gains["room_bed.ogg"])>.06,"room bed fades in naturally")
	check(float(sound._bed_gains["wind_bed.ogg"])<float(snapshots[0].gains["wind_bed.ogg"]),"outside wind fades down indoors")
	check(float(sound._bed_gains["sea_bed.ogg"])<float(snapshots[0].gains["sea_bed.ogg"]),"outside sea fades down indoors")
	await passage(func():game._world("post_office"))
	await settle(.8);snapshot("outside_return")
	check(not sound.indoors,"actual exit restores outdoor audio profile")
	check(float(sound._bed_gains["room_bed.ogg"])<float(snapshots[1].gains["room_bed.ogg"]),"room bed fades away on exit")
	check(float(sound._bed_gains["sea_bed.ogg"])>float(snapshots[1].gains["sea_bed.ogg"]),"sea returns on exit")
	check(sound._elapsed>elapsed_before+2.0,"audio clock advances through native passage")
	game._pause();var pause_elapsed:float=sound._elapsed;await settle(.3)
	check(sound._elapsed>pause_elapsed+.2,"pause overlay leaves atmosphere clock moving")
	game._settings_page(true);await settle(.2)
	check(sound._settings_feedback_mode,"pause settings enters settings feedback")
	game.modal.closed.emit();await settle(.2)
	check(not sound._settings_feedback_mode and is_instance_valid(game.modal),"settings close returns pause and resets feedback route")
	game._close()
	for index:int in 3:
		game._settings_page(false);await settle(.05);game._close()
	await settle(.15)
	check(not sound._settings_feedback_mode and not sound.menu_music.playing,"rapid settings reopen leaves no alternate music")
	var old_detail:float=sound._detail_after
	game.core.state.minute=2880+1200;game._save()
	check(sound.minute==1200,"second-day save follows night clock")
	check(is_equal_approx(float(sound._targets["town_bed.ogg"]),sound._town_base_gain*.68),"night town gain uses unchanged night factor")
	check(is_equal_approx(sound._detail_after,old_detail),"clock save does not reset ambient detail scheduler")
	game.preferences.set_value("master",0.0)
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"simulated focus events preserve explicit master mute")
	game._settings_page(false);game._close()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"rapid modal change does not clear master mute")
	game.preferences.set_value("master",1.0)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"visible master restores sound")
	check(voice_changes.is_empty(),"original guitar and all four bed native voices never stop or restart")
	snapshot("final")
	observations={"snapshots":snapshots,"voice_changes":voice_changes,"userdata":OS.get_user_data_dir(),"method":"GPU Main scene_passage indoor/outdoor, natural process clocks, actual native voice identities; pause and modal signals; programmatic focus notifications only, no OS input or listening acceptance.","note":"No background-mute preference exists; lack of automatic focus mute is not treated as a defect."}
	game._close();sound.shutdown()
	var deadline:=Time.get_ticks_msec()+1000
	while sound.has_pending_playbacks() and Time.get_ticks_msec()<deadline:await process_frame
	check(not sound.has_pending_playbacks(),"owned audio retires before freeing host")
	game.queue_free();await process_frame;view.queue_free();await process_frame
	FileAccess.open(out+"/receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"  "))
	print("AUDIO_TRANSITION_PASS2 ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
