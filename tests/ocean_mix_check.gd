extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var s=load("res://scripts/ui/audio_feedback.gd").new();s.settings_path="user://qa/ocean.cfg";root.add_child(s)
 assert(s.ambience.stream is AudioStreamMP3)
 assert(s.ambience.stream.get_length()>700)
 s.set_location("tarot_shop");s._process(10)
 assert(s.ambience.volume_db > -21 and s.music.volume_db > -13)
 assert(s.ambience.playing and s.music.playing)
 print("OCEAN_MIX_PASS duration=",s.ambience.stream.get_length()," sea_db=",s.ambience.volume_db," guitar_db=",s.music.volume_db)
 s.shutdown();await create_timer(0.3).timeout;s.queue_free();await process_frame;quit()
