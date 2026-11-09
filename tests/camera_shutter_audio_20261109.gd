extends SceneTree
const Host=preload("res://scripts/rebuild/final_playable.gd")
var out:=""
var game:Control
var checks:=0
var failures:Array[String]=[]
var cues:Array[String]=[]
func _initialize():
 if not str(OS.get_cmdline_user_args()).contains("--final-save=user://qa/"):
  quit(1);return
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-out="):out=arg.trim_prefix("--qa-out=")+"/"
 root.unfocusable=true;root.size=Vector2i(1280,720)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run():
 DirAccess.make_dir_recursive_absolute(out)
 game=Host.new();game.allow_display_changes=false;root.add_child(game);game.size=Vector2(1600,900)
 game.sound.set_muted(false);game.sound.set_volumes(.75,.85,.85)
 game.sound.cue_played.connect(func(kind:String,_file:String):cues.append(kind))
 game.core.state.location="community_center";game._world();await process_frame
 game._camera();await process_frame
 var camera=game.modal
 camera.save_directory=out+"photos"
 var music_id:int=game.sound.music.get_stream_playback().get_instance_id()
 var initial_photo:String=camera.last_photo_path
 camera.shutter.pressed.emit()
 check(cues.count("camera")==1,"shutter sounds immediately before PNG completion")
 check(camera.capture_busy and camera.last_photo_path==initial_photo,"cue occurs before asynchronous save")
 camera.take_photo()
 check(cues.count("camera")==1,"busy duplicate does not replay shutter")
 var shot:AudioStreamPlayer=game.sound._shots.back()
 check(shot.bus==game.sound.SFX_BUS,"camera uses effects bus")
 check(shot.volume_db==-10.0 and shot.has_stream_playback(),"camera has active audible-gain voice")
 var stream:AudioStreamWAV=shot.stream
 check(stream.get_length()>.3 and stream.get_length()<.45,"short non-looping shutter")
 check(stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"shutter does not loop")
 var peak:=0.0;var energy:=0.0
 for i in range(0,stream.data.size(),2):
  var value:=float(stream.data.decode_s16(i))/32768.0
  peak=maxf(peak,absf(value));energy+=value*value
 check(peak>.35 and peak<.41,"non-silent waveform without clipping")
 check(sqrt(energy/(stream.data.size()/2))>.025,"waveform has measurable body")
 stream.save_to_wav(out+"shutter-preview.wav")
 await create_timer(.5).timeout
 check(cues.count("camera")==1,"save completion does not duplicate sound")
 check(not camera.last_photo_path.is_empty() and FileAccess.file_exists(camera.last_photo_path),"photo still saves")
 check(game.sound.music.get_stream_playback().get_instance_id()==music_id,"guitar voice remains continuous")
 game._close();await process_frame
 game._camera();await process_frame
 camera=game.modal;camera.save_directory=out+"photos";camera.capture_provider=func():return null
 var previous_photo:String=camera.last_photo_path
 camera.shutter.pressed.emit();await create_timer(.25).timeout
 check(cues.count("camera")==2,"failed capture still has one physical shutter cue")
 check(not camera.capture_busy and camera.last_photo_path==previous_photo,"failure releases camera without false success")
 game.sound.set_volumes(.75,0.0,.85);game.sound.play("camera")
 check(cues.count("camera")==2,"effects zero suppresses shutter")
 game.sound.set_volumes(.75,.85,.85);game.sound.set_muted(true);game.sound.play("camera")
 check(cues.count("camera")==2,"master mute suppresses shutter")
 game.sound.set_muted(false);await create_timer(.2).timeout;game.sound.play("camera")
 check(cues.count("camera")==3,"unmute restores shutter")
 for kind in ["door","door_close"]:
  game.sound.play(kind)
  var door:AudioStreamPlayer=game.sound._shots.back()
  check(door.bus==game.sound.SFX_BUS and door.has_stream_playback(),kind+" uses active effects voice")
  check(door.volume_db==(-18.0 if kind=="door" else -19.0),kind+" quieter independent gain")
  check(door.stream==game.sound._stream("door_open_soft.wav" if kind=="door" else "door_close_soft.wav"),kind+" uses softened recording")
 game.sound.shutdown();await create_timer(.35).timeout;game.queue_free();await process_frame;await process_frame
 FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"waveform_peak":peak,"method":"Actual Host camera and native playback; isolated QA data/offscreen GPU, not human listening acceptance."},"  "))
 print("CAMERA_SHUTTER_AUDIO ",checks," checks / ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
