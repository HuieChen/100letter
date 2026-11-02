extends SceneTree
var failures:=0
func check(ok:bool,label:String)->void:
 if not ok:failures+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var s=load("res://scripts/ui/audio_feedback.gd").new();s.settings_path="user://qa/ocean.cfg";root.add_child(s)
 check(s.ambience.stream is AudioStreamMP3,"Licensed ocean MP3 is loaded")
 check(s.ambience.stream.get_length()>700,"Long natural ocean recording remains selected")
 s.set_muted(false)
 s.set_location("tarot_shop");s._process(10)
 check(s.ambience.volume_db > -24 and s.music.volume_db > -13,"Ocean remains a quiet bed under the guitar")
 check(s.ambience.playing and s.music.playing,"Ocean and supplied guitar are both playing")
 s.set_weather(.2,0,1);s._process(10);var low:float=s.ambience.volume_db
 s.set_weather(.2,1,1);s._process(10)
 check(s.ambience.volume_db>low+2 and s.ambience.volume_db<=-19.9,"Wave envelope changes the real ocean player without overpowering the mix")
 print("OCEAN_MIX 5 checks, %d failures"%failures)
 s.shutdown();await create_timer(0.3).timeout;s.queue_free();await process_frame;quit(1 if failures else 0)
