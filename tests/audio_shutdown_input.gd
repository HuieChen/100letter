extends SceneTree
## Actual stream/playback teardown while the tree and audio mixer are alive.
## The official forced-quit release probe is a separate shutdown observation.
const Sound=preload("res://scripts/ui/audio_feedback.gd")
var checks:=0
var failures:Array[String]=[]
var cues:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.unfocusable=true
	var sound:=Sound.new()
	sound.settings_path="user://qa/audio-shutdown/"+str(Time.get_ticks_usec())+".cfg"
	root.add_child(sound)
	await process_frame
	_check(sound._beds.size()==4,"four actual ambient beds are mounted before shutdown")
	_check(sound.music.stream is AudioStreamWAV and sound.music.playing,"actual looping WAV motif plays before shutdown")
	var loop_refs:Array[WeakRef]=[weakref(sound.music.stream),weakref(sound.menu_music.stream)]
	var loop_roles:Array[String]=["afternoon.wav duplicated motif","settings_vaporware.ogg duplicated track"]
	for name:String in sound.BEDS:
		var bed:AudioStreamPlayer=sound._beds[name]
		_check(bed.stream is AudioStreamOggVorbis and (bed.stream as AudioStreamOggVorbis).loop,"actual ambient bed has its own looping Ogg stream "+name)
		_check(bed.playing and bed.has_stream_playback(),"actual ambient playback is active "+name)
		loop_refs.append(weakref(bed.stream))
		loop_roles.append(name+" duplicated bed")
	sound.settings_music(true)
	sound.cue_played.connect(func(kind:String,_sample:String):cues.append(kind))
	sound.play_water_touch(Vector2(250,250),1.0)
	_check(sound.menu_music.playing,"actual Settings soundtrack plays before shutdown")
	_check(sound._shots.size()==1 and not cues.is_empty(),"actual water one-shot exists before shutdown")
	var owned:Array[AudioStreamPlayer]=[]
	var playback_refs:Array[WeakRef]=[]
	var playback_roles:Array[String]=[]
	for child:Node in sound.get_children():
		if child is AudioStreamPlayer:
			owned.append(child)
			if child.has_stream_playback():
				playback_refs.append(weakref(child.get_stream_playback()))
				playback_roles.append(str(child.bus)+" player "+str(child.get_index()))
	# A separate owner's looping voice uses the same music bus. It must survive.
	var foreign:=AudioStreamPlayer.new();foreign.bus=sound.MUSIC_BUS
	var foreign_track:AudioStreamWAV=load("res://assets/audio/afternoon.wav").duplicate() as AudioStreamWAV
	foreign_track.loop_mode=AudioStreamWAV.LOOP_FORWARD
	foreign_track.loop_end=int(foreign_track.get_length()*foreign_track.mix_rate)
	foreign.stream=foreign_track;foreign_track=null
	root.add_child(foreign);foreign.play()
	var buses_before:=_buses()
	var retirement_started:=Time.get_ticks_usec()
	sound.shutdown()
	_check(sound._shutdown_complete and not sound.is_processing(),"shutdown is explicit and disables this owner's processing")
	_check(sound._beds.is_empty() and sound._streams.is_empty() and sound._shots.is_empty(),"shutdown releases every owned stream cache/player list")
	_check(sound.music==null and sound.menu_music==null and sound.ambience==null,"shutdown releases direct owned music/ambience references")
	for player:AudioStreamPlayer in owned:
		_check(not player.playing and not player.has_stream_playback(),"owned native playback stops without another input")
		_check(player.stream==null,"owned player relinquishes its actual resource")
	_check(foreign.playing and foreign.has_stream_playback(),"another owner's voice on the same bus keeps playing")
	_check(_buses()==buses_before,"shutdown neither removes shared buses nor changes their sends/effects/gain/mute")
	sound.shutdown()
	_check(_buses()==buses_before,"repeat shutdown is idempotent and leaves shared audio intact")
	var cue_count:=cues.size();var child_count:=sound.get_child_count()
	sound.settings_music(true);sound.play();sound.play_water_touch(Vector2(500,300),1.0);sound._spawn("water","water_touch_1.wav",-7.0,sound.SFX_BUS)
	sound._process(1.0)
	_check(cues.size()==cue_count and sound.get_child_count()==child_count,"late callbacks cannot restart or allocate a voice after shutdown")
	print("AUDIO RETIREMENT before drain streams: ",JSON.stringify(_held_resources(loop_refs,loop_roles)))
	while sound.has_pending_playbacks() and Time.get_ticks_usec()-retirement_started<1000000:
		await process_frame
	print("AUDIO RETIREMENT fence elapsed milliseconds: ",float(Time.get_ticks_usec()-retirement_started)/1000.0)
	print("AUDIO RETIREMENT after fence streams: ",JSON.stringify(_held_resources(loop_refs,loop_roles)))
	print("AUDIO RETIREMENT after fence native playbacks: ",JSON.stringify(_held_resources(playback_refs,playback_roles)))
	_check(not sound.has_pending_playbacks() and sound._retiring_playbacks.is_empty(),"owned native voice retirement completes within the one-second live fence")
	_check(loop_refs.all(func(reference:WeakRef):return reference.get_ref()==null),"owned duplicated music and Ogg streams retire after the live mixer drain")
	_check(foreign.playing,"shutdown drain does not stop another owner's looping voice")
	var foreign_playback:WeakRef=weakref(foreign.get_stream_playback())
	foreign.stop();foreign.stream=null
	var foreign_retirement_started:=Time.get_ticks_usec()
	while foreign_playback.get_ref()!=null and Time.get_ticks_usec()-foreign_retirement_started<1000000:
		await process_frame
	_check(foreign_playback.get_ref()==null,"fixture's separate owner completes its own bounded voice retirement")
	print("AUDIO RETIREMENT after separate owner's fence, owned players alive: ",JSON.stringify(_held_resources(loop_refs,loop_roles)))
	sound.queue_free();foreign.queue_free()
	await process_frame;await process_frame
	print("AUDIO RETIREMENT after owned nodes freed: ",JSON.stringify(_held_resources(loop_refs,loop_roles)))
	print("AUDIO SHUTDOWN INPUT: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _buses()->Array:
	var state:Array=[]
	for index:int in AudioServer.bus_count:
		state.append({"name":AudioServer.get_bus_name(index),"send":AudioServer.get_bus_send(index),"effects":AudioServer.get_bus_effect_count(index),"gain":AudioServer.get_bus_volume_db(index),"mute":AudioServer.is_bus_mute(index),"solo":AudioServer.is_bus_solo(index)})
	return state
func _check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func _held_resources(references:Array[WeakRef],roles:Array[String])->Array:
	# Return primitive diagnostic data only. These observation references are
	# discarded on helper return; reported counts include the temporary lookup.
	var held:Array=[]
	for index:int in references.size():
		var value:Object=references[index].get_ref()
		if value==null:continue
		var record:Dictionary={"index":index,"role":roles[index],"class":value.get_class(),"instance_id":value.get_instance_id(),"reference_count_including_observation":value.get_reference_count() if value is RefCounted else 0}
		if value is Resource:record.path=(value as Resource).resource_path
		if value is AudioStreamPlayback:record.native_playing=(value as AudioStreamPlayback).is_playing()
		held.append(record)
	return held
