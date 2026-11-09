extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var out:=""
var checks:=0
var failures:Array[String]=[]
func _initialize():
 if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):quit(1);return
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
 root.unfocusable=true;run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run():
 DirAccess.make_dir_recursive_absolute(out)
 var game=Host.new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
 await create_timer(.6).timeout
 check(game.sound.location_id=="title" and game.sound.music.playing,"cover starts guitar")
 check(FileAccess.get_sha256("res://assets/audio/user_guitar_loop.wav")=="a29e290e8702404b178124729490ccb003a4d5a04c8235606f608f5adf4011c9","supplied guitar bytes preserved")
 var playback_id:int=game.sound.music.get_stream_playback().get_instance_id()
 var bus:=AudioServer.get_bus_index(game.sound.MUSIC_BUS)
 var capture:=AudioEffectCapture.new();capture.buffer_length=1.0;AudioServer.add_bus_effect(bus,capture)
 await create_timer(.6).timeout
 var peak:=0.0
 for sample:Vector2 in capture.get_buffer(capture.get_frames_available()):peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
 check(peak>0.00001,"actual music bus contains guitar samples")
 AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 game.preferences.set_value("music",0.0)
 check(AudioServer.is_bus_mute(bus) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(game.sound.SFX_BUS)),"music mute stays independent from effects")
 game.preferences.set_value("music",.75);check(not AudioServer.is_bus_mute(bus),"music slider restores guitar")
 game.core.state.location="community_center";game._world();await process_frame
 check(game.sound.music.get_stream_playback().get_instance_id()==playback_id,"world keeps the same playback")
 game._title();await create_timer(.3).timeout
 check(game.sound.music.get_stream_playback().get_instance_id()==playback_id,"return to title keeps playback continuous")
 game.sound.shutdown();game.queue_free();await process_frame;await process_frame
 FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"guitar_peak":peak,"method":"Actual PCK native audio mixer and Host scene transitions; no UI screenshot wait or listening acceptance."},"  "))
 print("TITLE_MUSIC_CONTINUITY ",checks," / ",failures.size());quit(0 if failures.is_empty() else 1)
