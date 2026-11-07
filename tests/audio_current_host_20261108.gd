extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var checks:=0
var failures:Array[String]=[]
var observed:Dictionary={}
var out:="user://qa/audio-current-host/"
func _initialize():
	var isolated:=false
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--final-save=user://qa/"):isolated=true
		if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=").trim_suffix("/")
	if not isolated:
		push_error("QA-only --final-save is required");quit(1);return
	run.call_deferred()
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func settle(seconds:float=.12):await create_timer(seconds).timeout;await process_frame
func run():
	root.unfocusable=true
	DirAccess.make_dir_recursive_absolute(out)
	var view:=SubViewport.new();view.size=Vector2i(1600,900);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var game:=Host.new();game.allow_display_changes=false;view.add_child(game)
	game.core.new_game();game._post_office_room();await settle(.3)
	var sound:AudioFeedback=game.sound
	var original_voice:int=sound.music.get_stream_playback().get_instance_id()
	var cues:Array[String]=[]
	sound.cue_played.connect(func(kind:String,_file:String):cues.append(kind))
	for cycle:int in 3:
		game._settings_page(false);await settle()
		ck(sound._settings_feedback_mode,"settings feedback activates cycle "+str(cycle))
		ck(not sound.menu_music.playing,"settings keeps original music cycle "+str(cycle))
		ck(sound.music.get_stream_playback().get_instance_id()==original_voice,"original guitar voice uninterrupted cycle "+str(cycle))
		game._close();await settle()
		ck(not sound._settings_feedback_mode,"settings feedback clears cycle "+str(cycle))
	game.preferences.set_value("music",.39);game.preferences.set_value("sfx",.61);game.preferences.set_value("ambience",.27)
	ck(sound.get_volumes()=={"music":.39,"effects":.61,"ambience":.27},"host independently routes three channel values")
	game.preferences.set_value("master",0.0)
	ck(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"master zero mutes entire mix")
	game.preferences.set_value("sfx",.52)
	ck(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"channel change preserves master mute")
	game.preferences.set_value("master",1.0)
	ck(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")) and is_equal_approx(sound.get_volumes().effects,.52),"unmute retains chosen channel gain")
	game.preferences.set_value("sfx",0.0)
	var before_cat:=cues.count("cat");sound.play("cat")
	ck(cues.count("cat")==before_cat,"effects zero suppresses cat voice allocation")
	game.preferences.set_value("sfx",.52)
	for n:int in 10:sound.play("cat")
	ck(cues.count("cat")==before_cat+1,"ten rapid cat callbacks create one voice")
	game.core.state.minute=1980;game._save()
	ck(sound.minute==540,"cumulative day host save normalizes sound clock")
	ck(sound.music.get_stream_playback().get_instance_id()==original_voice,"clock update retains original music playback")
	sound.set_location("bus_stop",720,false)
	sound._spawn("tram_ambient","tram_pass.wav",-28.0,sound.AMBIENT_BUS)
	ck(sound._shots.any(func(s):return s.bus==sound.AMBIENT_BUS),"ambient transition fixture has actual tram voice")
	sound.set_location("post_office",720,true);await settle()
	ck(not sound._shots.any(func(s):return is_instance_valid(s) and s.bus==sound.AMBIENT_BUS),"entering room retires outside transient")
	var baseline_buses:=AudioServer.bus_count
	game._settings_page(false);await settle()
	sound.play_water_touch(Vector2(750,400),1.0);await settle(.5)
	var water_buses:=AudioServer.bus_count
	for n:int in 3:
		game._close();game._settings_page(false);await settle(.3);sound.play_water_touch(Vector2(750,400),1.0)
	ck(AudioServer.bus_count==water_buses,"repeated settings reuse same water bus")
	ck(water_buses<=baseline_buses+1,"one center-water route allocates at most one bus")
	game._close();await settle()
	ck(game.preferences.save_settings(),"preferences persist under isolated userdata")
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.preferences.path))
	ck(saved.values.music==.39 and saved.values.sfx==.52 and saved.values.ambience==.27,"saved channel values remain independent")
	observed={"userdata":OS.get_user_data_dir(),"bus_count":AudioServer.bus_count,"cues":cues,"original_music_voice":original_voice,"scope":"GPU actual Main settings modal lifecycle, internal audio playback identity, callback and bus assertions; not OS input or human listening."}
	game._close();sound.shutdown()
	var deadline:=Time.get_ticks_msec()+1000
	while sound.has_pending_playbacks() and Time.get_ticks_msec()<deadline:await process_frame
	ck(not sound.has_pending_playbacks(),"owned native voices retire before host is freed")
	game.queue_free();await process_frame;view.queue_free();await process_frame
	FileAccess.open(out+"/receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"observed":observed},"  "))
	print("AUDIO_AUDIT ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
